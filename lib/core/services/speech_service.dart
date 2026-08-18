import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Thin wrapper around `speech_to_text` for the "Setor Cerdas" voice modal.
class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;

  Future<bool> ensurePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> init() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize();
    return _initialized;
  }

  bool get isListening => _speech.isListening;
  bool get isAvailable => _speech.isAvailable;

  Future<void> startListening({
    required void Function(String transcript, bool isFinal) onResult,
    String localeId = 'id_ID',
    Duration listenFor = const Duration(seconds: 20),
  }) async {
    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
        listenFor: listenFor,
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
      ),
    );
  }

  Future<void> stopListening() => _speech.stop();

  void cancel() => _speech.cancel();
}
