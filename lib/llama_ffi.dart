import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
// import 'package:path_provider/path_provider.dart';

final DynamicLibrary dylib = Platform.isAndroid
    ? DynamicLibrary.open("libllama_embedding.so")
    : throw UnsupportedError("Only Android is supported");

/// Native function signature: const char * run_embedding(int argc, char **argv)
typedef RunEmbeddingNative = Pointer<Utf8> Function(Int32, Pointer<Pointer<Utf8>>);
typedef RunEmbeddingDart = Pointer<Utf8> Function(int, Pointer<Pointer<Utf8>>);

final RunEmbeddingDart runEmbedding = dylib
    .lookup<NativeFunction<RunEmbeddingNative>>('run_embedding')
    .asFunction<RunEmbeddingDart>();

Future<String> runEmbeddingFromPath(Map<String, String> input) async {
  final prompt = input['prompt']!;
  final modelPath = input['modelPath']!;

  print('[FFI] Using embedding model: $modelPath');
  print('[FFI] Prompt: $prompt');

  final args = [
    './llama-embedding'.toNativeUtf8(),
    '-m'.toNativeUtf8(),
    modelPath.toNativeUtf8(),
    '-p'.toNativeUtf8(),
    prompt.toNativeUtf8(),
  ];

  final argv = calloc<Pointer<Utf8>>(args.length);
  for (int i = 0; i < args.length; i++) {
    argv[i] = args[i];
  }

  final Pointer<Utf8> resultPtr = runEmbedding(args.length, argv);
  final String result = resultPtr.toDartString();

  for (final arg in args) {
    calloc.free(arg);
  }
  calloc.free(argv);

  return result;
}

// Future<String> runEmbeddingFromNative(String prompt) async {
//   final dir = await getApplicationSupportDirectory();
//   final modelPath = '${dir.path}/multilingual-e5-base-q4_0.gguf';

//   print('[FFI] Model Path: $modelPath');

//   // Convert arguments to Utf8 pointers
//   final args = [
//     './llama-embedding'.toNativeUtf8(), // dummy argv[0]
//     '-m'.toNativeUtf8(),
//     modelPath.toNativeUtf8(),
//     '-p'.toNativeUtf8(),
//     prompt.toNativeUtf8(),
//   ];

//   // Create argv pointer array
//   final argv = calloc<Pointer<Utf8>>(args.length);
//   for (int i = 0; i < args.length; i++) {
//     argv[i] = args[i];
//   }

//   // Run the function
//   final Pointer<Utf8> resultPtr = runEmbedding(args.length, argv);
//   final String result = resultPtr.toDartString();

//   // Free argument memory
//   for (final arg in args) {
//     calloc.free(arg);
//   }
//   calloc.free(argv);

//   print('[FFI] run_embedding returned string:\n$result');

//   return result;
// }
