import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:js_interop';

@JS('eval')
external void _evalJs(JSString script);

class FeedbackService {
  FeedbackService._();

  /// Joue un retour haptique si activé dans les paramètres
  static void triggerHaptic({bool enabled = true, bool isError = false}) {
    if (!enabled) return;
    try {
      if (isError) {
        HapticFeedback.vibrate();
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }

  /// Joue un bip sonore de validation si activé dans les paramètres
  static void triggerSound({bool enabled = true, bool isError = false}) {
    if (!enabled) return;
    try {
      if (kIsWeb) {
        _playWebAudioBeep(isError: isError);
      } else {
        SystemSound.play(isError ? SystemSoundType.alert : SystemSoundType.click);
      }
    } catch (_) {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// Scan réussi : bip aigu + vibration
  static void scanSuccess({bool haptic = true, bool sound = true}) {
    triggerHaptic(enabled: haptic, isError: false);
    triggerSound(enabled: sound, isError: false);
  }

  /// Scan inconnu / Erreur : double vibration + son grave
  static void scanError({bool haptic = true, bool sound = true}) {
    triggerHaptic(enabled: haptic, isError: true);
    triggerSound(enabled: sound, isError: true);
  }

  static void _playWebAudioBeep({required bool isError}) {
    try {
      final freq = isError ? 420 : 1760;
      final duration = isError ? 0.22 : 0.08;
      final type = isError ? 'sawtooth' : 'sine';
      final jsCode = '''
(function() {
  try {
    var AudioCtx = window.AudioContext || window.webkitAudioContext;
    if (!AudioCtx) return;
    if (!window._stockioAudioCtx) {
      window._stockioAudioCtx = new AudioCtx();
    }
    var ctx = window._stockioAudioCtx;
    if (ctx.state === 'suspended') {
      ctx.resume();
    }
    var osc = ctx.createOscillator();
    var gain = ctx.createGain();
    osc.type = '$type';
    osc.frequency.setValueAtTime($freq, ctx.currentTime);
    gain.gain.setValueAtTime(0.12, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + $duration);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + $duration);
  } catch(e) {}
})();
''';
      _evalJs(jsCode.toJS);
    } catch (_) {
      SystemSound.play(isError ? SystemSoundType.alert : SystemSoundType.click);
    }
  }
}
