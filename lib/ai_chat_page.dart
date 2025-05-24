import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'llama_ffi.dart';
import 'llama_chat_ffi.dart';

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, String>> messages = []; // {"role": "user"/"assistant", "text": "..."}
  bool isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _detectLanguage(String text) {
    final hasBengali = RegExp(r'[\u0980-\u09FF]').hasMatch(text);
    final lang = hasBengali ? 'bn' : 'en';
    print('\n[Language Detection] Detected: $lang');
    return lang;
  }

  Future<List<double>> _getEmbedding(String input) async {
    print('\n[Embedding] Input: "$input"');
    final dir = await getApplicationSupportDirectory();
    final modelPath = '${dir.path}/multilingual-e5-base-q4_0.gguf';

    final rawOutput = await compute(runEmbeddingFromPath, {
      'prompt': input,
      'modelPath': modelPath,
    });

    print('[Embedding] Raw output: $rawOutput');
    final lines = rawOutput.split('\n');
    final vectorLine = lines.lastWhere((line) => line.trim().startsWith('['));
    final List<double> vector = (jsonDecode(vectorLine) as List)
        .map((e) => (e as num).toDouble())
        .toList();

    print('[Embedding] Vector size: ${vector.length}');
    return vector;
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    final dot = a.asMap().entries.fold(0.0, (sum, entry) => sum + entry.value * b[entry.key]);
    final normA = sqrt(a.map((x) => x * x).reduce((a, b) => a + b));
    final normB = sqrt(b.map((x) => x * x).reduce((a, b) => a + b));
    return dot / (normA * normB);
  }

  Future<String> _searchAndAnswer(String query) async {
    final dir = await getApplicationSupportDirectory();
    final lang = _detectLanguage(query);
    final vectorPath = '${dir.path}/vectorstore_${lang}_recursive.json';

    final queryVec = await _getEmbedding(query);
    print('[Search] Vector path: $vectorPath');

    final vectorFile = File(vectorPath);
    if (!vectorFile.existsSync()) {
      throw Exception('Vectorstore not found: $vectorPath');
    }

    final List<dynamic> store = jsonDecode(await vectorFile.readAsString());
    print('[Search] Documents found: ${store.length}');

    store.sort((a, b) {
      final simA = _cosineSimilarity(queryVec, List<double>.from(a['embedding']));
      final simB = _cosineSimilarity(queryVec, List<double>.from(b['embedding']));
      return simB.compareTo(simA);
    });

    final topContext = store.take(1).map((e) => e['text']).join('\n');
    print('[Search] Top context:\n$topContext');

    final prompt = """
      <|im_start|>system
      Use only the information to answer the question<|im_end|>
      <|im_start|>user

      $query

      Information:

      ```
      $topContext
      ```
      <|im_end|>
      <|im_start|>assistant
    """;

    print('[LLM] Prompt:\n$prompt');

    final modelPath = '${dir.path}/tinyllama-1.1b-chat-v1.0.Q4_0.gguf';
    print('[FFI] Model Path: $modelPath');
    final output = await compute(runChatFromFlutterWithPath, {
      'prompt': prompt,
      'modelPath': modelPath,
    });

    print('[LLM] Output:\n$output');
    return output;
  }

  Future<void> _handleQuery() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      messages.add({'role': 'user', 'text': query});
      isLoading = true;
      _controller.clear();
    });

    _scrollToBottom();

    try {
      final response = await _searchAndAnswer(query);
      setState(() => messages.add({'role': 'assistant', 'text': response}));
    } catch (e) {
      setState(() => messages.add({'role': 'assistant', 'text': 'Error: ${e.toString()}'}));
    } finally {
      setState(() => isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(String text, String role) {
    final isUser = role == 'user';
    final alignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = isUser ? Colors.deepPurpleAccent : Colors.grey[200];
    final textColor = isUser ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(text, style: TextStyle(color: textColor, fontSize: 15)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: messages.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == messages.length && isLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text("Assistant is typing...", style: TextStyle(fontStyle: FontStyle.italic)),
                  );
                }
                final msg = messages[index];
                return _buildMessageBubble(msg['text']!, msg['role']!);
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _handleQuery(),
                    decoration: const InputDecoration(
                      hintText: 'Ask something...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(isLoading ? Icons.hourglass_empty : Icons.send),
                  onPressed: isLoading ? null : _handleQuery,
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
