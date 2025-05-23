import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
// import 'package:path_provider/path_provider.dart';

final DynamicLibrary dylib = Platform.isAndroid
    ? DynamicLibrary.open("libllama_chat.so")
    : throw UnsupportedError("Only Android is supported");

// FFI function signature
typedef RunChatNative = Pointer<Utf8> Function(Int32 argc, Pointer<Pointer<Utf8>>);
typedef RunChatDart = Pointer<Utf8> Function(int argc, Pointer<Pointer<Utf8>>);

// FFI lookup
final RunChatDart runChat = dylib
    .lookup<NativeFunction<RunChatNative>>('run_llama_chat')
    .asFunction<RunChatDart>();

Future<String> runChatFromFlutterWithPath(Map<String, String> input) async {
  final prompt = input['prompt']!;
  final modelPath = input['modelPath']!;

  print('[FFI] Using model: $modelPath');
  print('[FFI] Prompt: $prompt');

  final args = [
    './llama-run'.toNativeUtf8(),
    modelPath.toNativeUtf8(),
    prompt.toNativeUtf8(),
  ];

  final Pointer<Pointer<Utf8>> argv = calloc<Pointer<Utf8>>(args.length);
  for (int i = 0; i < args.length; i++) {
    argv[i] = args[i];
  }

  final Pointer<Utf8> resultPtr = runChat(args.length, argv);
  final String result = resultPtr.toDartString();

  for (final arg in args) {
    calloc.free(arg);
  }
  calloc.free(argv);

  return result;
}

/// Run LLaMA model chat via native shared library.
// Future<String> runChatFromFlutter(String prompt) async {
//   // Prepare arguments as UTF-8 strings
//   final dir = await getApplicationSupportDirectory();
//   final modelPath = '${dir.path}/tinyllama-1.1b-chat-v1.0.Q4_0.gguf';

//   print('[FFI] Model Path: $modelPath');

//   final args = [
//     './llama-run'.toNativeUtf8(),  // argv[0], dummy
//     modelPath.toNativeUtf8(),      // argv[1], model path
//     prompt.toNativeUtf8(),         // argv[2], user input
//   ];

//   // Allocate pointer array
//   final Pointer<Pointer<Utf8>> argv = calloc<Pointer<Utf8>>(args.length);
//   for (int i = 0; i < args.length; i++) {
//     argv[i] = args[i];
//   }

//   // Call native function
//   final Pointer<Utf8> resultPtr = runChat(args.length, argv);
//   final String result = resultPtr.toDartString();

//   // Free allocated memory
//   for (final arg in args) {
//     calloc.free(arg);
//   }
//   calloc.free(argv);

//   return result;
// }