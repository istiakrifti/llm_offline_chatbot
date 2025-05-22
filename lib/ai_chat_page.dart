import 'package:flutter/material.dart';
import 'package:aub_ai/aub_ai.dart';
import 'package:aub_ai/prompt_template.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';

Future<String> loadModelToLocalFile(String assetPath) async {
  final byteData = await rootBundle.load(assetPath);
  final tempDir = await getTemporaryDirectory();
  final tempFile = File('${tempDir.path}/${assetPath.split('/').last}');
  await tempFile.writeAsBytes(byteData.buffer.asUint8List());
  return tempFile.path;
}

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _controller = TextEditingController();
  String outputByAI = '';
  bool isLoading = false;

  Future<void> example() async {
  try {
    final filePathLLM = await loadModelToLocalFile('assets/models/tinyllama-1.1b-chat-v1.0.Q4_0.gguf');

    final promptByUser = _controller.text.trim();
    if (promptByUser.isEmpty) return;

    setState(() {
      outputByAI = '';
      isLoading = true;
    });

    final promptTemplate = PromptTemplate.chatML().copyWith(
      prompt: promptByUser,
    );

    String fullOutput = '';

    await talkAsync(
      filePathToModel: filePathLLM,
      promptTemplate: promptTemplate,
      onTokenGenerated: (String token) {
        fullOutput += token;
      },
    );

    // Extract text after the assistant's start marker
    final parts = fullOutput.split('<|im_start|>assistant\n');
    final aiResponse = parts.length > 1 ? parts.last.trim() : fullOutput.trim();

    setState(() {
      outputByAI = aiResponse;
    });
  } catch (e) {
    setState(() {
      outputByAI = 'Error: ${e.toString()}';
    });
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask the AI')),
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
              onPressed: isLoading ? null : example,
              child: Text(isLoading ? 'Generating...' : 'Submit'),
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
