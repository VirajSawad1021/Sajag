// Read aloud: speaks results in Nepali with the phone's own text-to-speech (works offline, nothing is sent
// anywhere). Uses Google's engine when installed because it has a Nepali voice; falls back to English.
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'l10n.dart';
import 'models.dart';

class Speaker extends ChangeNotifier {
  final _tts = FlutterTts();
  bool _ready = false;
  bool nepaliAvailable = false;
  String? speakingKey; // which button is currently speaking, so it can show "stop"

  Future<void> _init() async {
    if (_ready || kIsWeb) return;
    try {
      final engines = List<String>.from(await _tts.getEngines ?? const []);
      if (engines.contains('com.google.android.tts')) await _tts.setEngine('com.google.android.tts');
      nepaliAvailable = await _tts.isLanguageAvailable('ne-NP') == true;
      await _tts.setSpeechRate(0.42); // slower and clearer, for older listeners
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      _tts.setCompletionHandler(_done);
      _tts.setCancelHandler(_done);
      _tts.setErrorHandler((_) => _done());
      _ready = true;
    } catch (e) {
      debugPrint('Text-to-speech unavailable: $e');
    }
  }

  void _done() {
    speakingKey = null;
    notifyListeners();
  }

  /// Speak [ne] (Nepali) or [en] text. Returns false if Nepali was wanted but no Nepali voice is installed
  /// (English is spoken instead), so the UI can suggest installing it.
  Future<bool> speak(String key, {required String ne, required String en}) async {
    await _init();
    if (speakingKey == key) {
      await stop();
      return true;
    }
    await _tts.stop();
    final useNepali = lang.ne && nepaliAvailable;
    await _tts.setLanguage(useNepali ? 'ne-NP' : 'en-US');
    speakingKey = key;
    notifyListeners();
    await _tts.speak(useNepali ? ne : en);
    return !lang.ne || nepaliAvailable;
  }

  Future<void> stop() async {
    await _tts.stop();
    _done();
  }

  // ---- what to say

  static String _lvl(String level, String stage, bool ne) {
    final paid = stage == 'after_payment' && level == 'high';
    final key = paid ? 'paidLevel_high' : 'level_$level';
    final body = paid ? 'paidBody_high' : 'levelBody_$level';
    final code = ne ? 'ne' : 'en';
    return '${trIn(key, code)}। ${trIn(body, code)}';
  }

  /// The result read as a short spoken briefing: verdict, summary, warnings (without quotes, which are often
  /// Romanized and sound wrong), then the first next steps.
  static ({String ne, String en}) caseScript(Analysis a) {
    String build(bool ne) {
      final parts = <String>[_lvl(a.level, a.stage, ne)];
      final summary = a.summary(ne);
      if (summary.isNotEmpty && a.engine == 'gemma') parts.add(summary);
      final warnings = a.grounded;
      if (warnings.isNotEmpty) {
        parts.add(ne ? 'चेतावनीका संकेत।' : 'Warning signs.');
        for (final (i, s) in warnings.take(5).indexed) {
          final title = ne ? s['title_ne'] : s['title_en'];
          final why = ne ? (s['explanation_ne'] ?? s['explanation_en']) : s['explanation_en'];
          parts.add('${i + 1}. $title। ${why ?? ''}');
        }
      }
      final steps = a.nextSteps.take(3).toList();
      if (steps.isNotEmpty) {
        parts.add(ne ? 'अब के गर्ने।' : 'What to do now.');
        for (final (i, s) in steps.indexed) {
          parts.add('${i + 1}. ${ne ? s['text_ne'] : s['text_en']}');
        }
      }
      parts.add(ne ? 'यी चेतावनीका संकेत हुन्, ठगीको प्रमाण होइनन्।' : 'These are warning signs, not proof of fraud.');
      return parts.join(' ');
    }

    return (ne: build(true), en: build(false));
  }
}

final speaker = Speaker();
