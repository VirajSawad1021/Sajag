// Demo mode: replays *recorded real runs* (scripts/record_demo.py) of the sample scenarios, so a live demo never
// depends on venue Wi-Fi or the API's speed. Replays are always labelled as such in the UI.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';
import 'store.dart';

class Recording {
  Recording(this.id, this.j);
  final String id;
  final Map<String, dynamic> j;

  List<String> get files => List<String>.from(j['files']);
  String get stage => j['stage'];
  Map<String, dynamic> get result => Map<String, dynamic>.from(j['result']);
  Map<String, dynamic>? get agent => j['agent'] == null ? null : Map<String, dynamic>.from(j['agent']);
  Map<String, dynamic>? get petition => j['petition'] == null ? null : Map<String, dynamic>.from(j['petition']);
  List<Map<String, dynamic>> get events => (j['events'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
}

class Demo extends ChangeNotifier {
  static const _key = 'sajag.demo.v1';
  static const replaySeconds = 11.0; // a recorded ~35 s run replays in about 11 s

  bool enabled = false;
  final Map<String, Recording> _recordings = {};

  Future<void> load() async {
    enabled = (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    try {
      final raw = jsonDecode(await rootBundle.loadString('assets/demo/recordings.json')) as Map<String, dynamic>;
      raw.forEach((id, v) => _recordings[id] = Recording(id, Map<String, dynamic>.from(v)));
    } catch (e) {
      debugPrint('No demo recordings: $e');
    }
  }

  Future<void> setEnabled(bool on) async {
    enabled = on;
    await (await SharedPreferences.getInstance()).setBool(_key, on);
    notifyListeners();
  }

  /// The recording whose sample files and stage match exactly what is being checked (demo mode only).
  Recording? match(List<Evidence> sent, String stage) {
    if (!enabled) return null;
    final names = sent.map((e) => e.name).toList()..sort();
    for (final r in _recordings.values) {
      final files = [...r.files]..sort();
      if (r.stage == stage && listEquals(files, names)) return r;
    }
    return null;
  }

  Recording? forAnalysis(Map<String, dynamic> analysis) {
    if (!enabled) return null;
    for (final r in _recordings.values) {
      if (jsonEncode(r.result['overall']) == jsonEncode(analysis['overall'])) return r;
    }
    return null;
  }

  /// Replay recorded progress events on a compressed clock, then return the recorded result.
  Future<Map<String, dynamic>> replay(Recording r, void Function(ProgressEvent) onProgress) async {
    final events = r.events;
    final total = events.isEmpty ? 1.0 : (events.last['t'] as num).toDouble();
    final scale = total > 0 ? replaySeconds / total : 1.0;
    var clock = 0.0;
    for (final e in events) {
      final t = (e['t'] as num).toDouble() * scale;
      await Future.delayed(Duration(milliseconds: ((t - clock) * 1000).round().clamp(0, 4000)));
      clock = t;
      onProgress(ProgressEvent('${e['step']}', e));
    }
    await Future.delayed(const Duration(milliseconds: 600));
    return r.result;
  }

  /// Add the recorded scenarios to the Casebook as ready-made cases (with their sample evidence).
  Future<void> loadCases() async {
    for (final id in ['victim', 'scam_reply', 'honest']) {
      final r = _recordings[id];
      if (r == null) continue;
      final evidence = <Evidence>[];
      for (final f in r.files) {
        final bytes = (await rootBundle.load('assets/demo/$f')).buffer.asUint8List();
        final audio = f.endsWith('.ogg');
        evidence.add(Evidence(kind: audio ? EvidenceKind.audio : EvidenceKind.image, name: f,
            mime: audio ? 'audio/ogg' : 'image/png', bytes: bytes));
      }
      final a = Analysis(r.result);
      final c = SajagCase(
        title: a.sellerNames.isNotEmpty ? a.sellerNames.first : id,
        stage: r.stage,
        status: r.stage == 'after_payment' ? CaseStatus.paid : CaseStatus.watching,
        evidence: evidence,
        agent: r.agent,
        petition: r.petition,
      );
      c.checks.add(CheckRun(at: DateTime.now(), analysis: r.result, evidenceIds: evidence.map((e) => e.id).toList()));
      await store.save(c);
    }
  }

  Future<void> reset() async {
    for (final c in [...store.cases]) {
      await store.delete(c);
    }
  }
}

final demo = Demo();
