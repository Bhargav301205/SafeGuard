// ignore_for_file: avoid_web_libraries_in_flutter
@JS()
library voice_web;

import 'dart:js_interop';

/// Real implementation using the browser's SpeechSynthesis API.
/// Loaded only on web builds via conditional import in voice_service.dart.
/// Uses dart:js_interop (modern, no dart:html dependency).

/// Cancel any current speech immediately.
@JS('speechSynthesis.cancel')
external void cancelSpeech();

/// Speak [text] using the browser's built-in TTS at high volume.
void speakText(String text) {
  _speakViaJs(text);
}

@JS('eval')
external void _evalJs(String code);

/// Uses eval to create and speak a SpeechSynthesisUtterance.
/// This avoids complex JS interop class declarations while being fully safe.
void _speakViaJs(String text) {
  // Build the JS inline — simple, reliable, no interop class needed
  final jsText = text
      .replaceAll("'", "\\'")
      .replaceAll('"', '\\"');
  _evalJs(
    "(function(){"
    "var u=new SpeechSynthesisUtterance('$jsText');"
    "u.rate=0.95;u.pitch=1.0;u.volume=1.0;"
    "speechSynthesis.speak(u);"
    "})()",
  );
}
