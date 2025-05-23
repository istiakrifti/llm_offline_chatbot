import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'llama_ffi.dart';
import 'llama_chat_ffi.dart';
import 'package:flutter/foundation.dart';

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _controller = TextEditingController();
  String outputByAI = '';
  bool isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _detectLanguage(String text) {
    final hasBengali = RegExp(r'[\u0980-\u09FF]').hasMatch(text);
    final lang = hasBengali ? 'bn' : 'en';
    print('\n[Language Detection] Detected: $lang');
    return lang;
  }

  // Future<List<double>> _getEmbedding(String input) async {
  //   final dir = await getApplicationSupportDirectory();
  //   print('[Embedding] Directory: ${dir.path}');
  //   final embeddingBin = '${dir.path}/llama-embedding';
  //   final modelPath = '${dir.path}/multilingual-e5-base-q4_0.gguf';

  //   print('\n[Embedding] Input: "$input"');
  //   print('[Embedding] Binary: $embeddingBin');
  //   print('[Embedding] Model: $modelPath');

  //   print('Executable exists: ${File(embeddingBin).existsSync()}');
  //   print('Executable permissions: ${await Process.run('ls', ['-l', embeddingBin])}');
  //   final result1 = await Process.run('ls', ['-l']);
  //   print(result1.stdout);

  //   final result = await Process.run(
  //     embeddingBin,
  //     ['-m', modelPath, '-p', input],
  //     environment: {'LD_LIBRARY_PATH': '$dir.path'}
  //   );

  //   if (result.exitCode != 0) {
  //     print('[Embedding] Error: ${result.stderr}');
  //     throw Exception('Embedding error: ${result.stderr}');
  //   }

  //   final lines = result.stdout.toString().split('\n');
  //   final vectorLine = lines.lastWhere((line) => line.trim().isNotEmpty);
  //   print('[Embedding] Raw output: $vectorLine');

  //   // Safely parse and cast each element to double
  //   final List<double> vector = (jsonDecode(vectorLine) as List)
  //       .map((e) => (e as num).toDouble())
  //       .toList();

  //   print('[Embedding] Vector size: ${vector.length}');
  //   return vector;
  // }
  Future<List<double>> _getEmbedding(String input) async {
    print('\n[Embedding] Input: "$input"');
    // final rawOutput = await runEmbeddingFromNative(input);
    // final rawOutput = await compute(runEmbeddingInBackground, input);
    
    final dir = await getApplicationSupportDirectory();
    final modelPath = '${dir.path}/multilingual-e5-base-q4_0.gguf';

    final rawOutput = await compute(runEmbeddingFromPath, {
      'prompt': input,
      'modelPath': modelPath,
    });

    print('[Embedding] Raw output: $rawOutput');
    // If your C++ prints JSON at the end (like: [0.1, 0.2, ...])
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

    // final llmBin = '${dir.path}/llama-run';
    // final modelPath = '${dir.path}/qwen1.5-1.8b-finetuned-q3_k_m.gguf';
    // final prompt = "Context:\n$topContext\n\nUser: $query\nAssistant:";
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

    // final output = await runChatFromFlutter(prompt);
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
      isLoading = true;
      outputByAI = '';
    });

    try {
      final response = await _searchAndAnswer(query);
      setState(() => outputByAI = response);
    } catch (e) {
      setState(() => outputByAI = 'Error: ${e.toString()}');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Chat')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Enter your question',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: isLoading ? null : _handleQuery,
              child: Text(isLoading ? 'Thinking...' : 'Ask'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  outputByAI,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
