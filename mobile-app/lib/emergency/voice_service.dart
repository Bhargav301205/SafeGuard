import 'dart:async';
import 'package:flutter/foundation.dart';

// JS interop is only compiled on web builds — tree-shaken on native.
import 'voice_service_web_stub.dart'
    if (dart.library.js_interop) 'voice_service_web_impl.dart';

/// Speaks emergency alerts using the browser's Web Speech API (SpeechSynthesis).
///
/// - Works completely FREE — built into Chrome, Edge, Safari.
/// - Falls back silently on native (non-web) platforms.
/// - Exhibition-ready: dramatically announces the crash out loud.
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  bool _speaking = false;
  bool get isSpeaking => _speaking;

  /// Speaks [text] using the browser's built-in TTS engine.
  Future<void> speak(String text) async {
    if (!kIsWeb) {
      debugPrint('[Voice] Not a web platform — skipping TTS.');
      return;
    }
    try {
      cancelSpeech(); // Cancel any ongoing speech first
      _speaking = true;
      speakText(text);
      // Safety: mark as not speaking after estimated duration
      Timer(Duration(seconds: text.length ~/ 8 + 5), () => _speaking = false);
    } catch (e) {
      debugPrint('[Voice] SpeechSynthesis error: $e');
      _speaking = false;
    }
  }

  /// Cancels any ongoing speech immediately.
  void cancel() {
    if (!kIsWeb) return;
    try {
      cancelSpeech();
    } catch (e) {
      debugPrint('[Voice] cancel error: $e');
    }
    _speaking = false;
  }

  // ── Announcement helpers ────────────────────────────────────────────────────

  /// Speaks the crash-detected announcement immediately.
  Future<void> announceCrashDetected({String? address}) async {
    final location = (address != null &&
            address.isNotEmpty &&
            address != 'Unknown location')
        ? address
        : 'an unknown location';
    await speak(
      'Emergency! Possible accident detected. '
      'Location: $location. '
      'Emergency services will be notified in 30 seconds. '
      'If you are safe, please tap cancel now.',
    );
  }

  /// Speaks when countdown expires and alert is triggered.
  Future<void> announceAlertTriggered({String? address}) async {
    final location = (address != null &&
            address.isNotEmpty &&
            address != 'Unknown location')
        ? address
        : 'your current location';
    await speak(
      'Emergency alert triggered! '
      'Contacting emergency services now. '
      'Location: $location. '
      'Help is on the way.',
    );
  }

  /// Speaks safety confirmation on cancel.
  Future<void> announceCancelled() async {
    cancel(); // immediately stop the crash announcement
    await speak('Alert cancelled. You are marked as safe. Stay calm.');
  }
}
