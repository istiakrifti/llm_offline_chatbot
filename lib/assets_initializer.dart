import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AssetManager {
  static const _assets = {
    // Binaries & Libraries
    // 'assets/helper/llama-embedding',
    // 'assets/helper/llama-run',
    // 'assets/helper/libllama.so',
    // 'assets/helper/libggml.so',
    // 'assets/helper/libggml-cpu.so',
    // 'assets/helper/libggml-base.so',
    // Models
    'assets/models/multilingual-e5-base-q4_0.gguf',
    // 'assets/models/qwen1.5-1.8b-finetuned-q3_k_m.gguf',
    'assets/models/tinyllama-1.1b-chat-v1.0.Q4_0.gguf',
    // Vector stores
    'assets/vectorstores/vectorstore_bn_recursive.json',
    'assets/vectorstores/vectorstore_en_recursive.json',
  };

  static late String _basePath;

  static Future<void> prepareAssets() async {
    final dir = await getApplicationSupportDirectory();
    _basePath = dir.path;

    for (final asset in _assets) {
      final filename = asset.split('/').last;
      final destPath = '$_basePath/$filename';
      final destFile = File(destPath);

      if (!destFile.existsSync()) {
        print('Copying $filename to $destPath');
        final byteData = await rootBundle.load(asset);
        await destFile.writeAsBytes(byteData.buffer.asUint8List());

        // Set executable permissions if necessary
        if (_isExecutableFile(filename)) {
          try {
            final result = await Process.run('chmod', ['+x', destFile.path]);
            if (result.exitCode != 0) {
              print('chmod failed for $filename: ${result.stderr}');
            } else {
              print('chmod success for $filename');
            }
          } catch (e) {
            print('chmod error for $filename: $e');
          }
        }
      }
    }
  }

  static bool _isExecutableFile(String filename) {
    return filename.startsWith('llama') ||
        filename.startsWith('libggml') ||
        filename.startsWith('libllama');
  }

  static Future<String> getLocalPath(String filename) async {
    if (_basePath.isEmpty) {
      final dir = await getApplicationSupportDirectory();
      _basePath = dir.path;
    }
    return '$_basePath/$filename';
  }

  static Future<void> deleteCopiedAssets() async {
    final dir = await getApplicationSupportDirectory();
    final files = Directory(dir.path).listSync();

    for (final file in files) {
      try {
        if (file is File) {
          await file.delete();
          print('[Cleanup] Deleted: ${file.path}');
        }
      } catch (e) {
        print('[Cleanup] Failed to delete ${file.path}: $e');
      }
    }
  }

}
