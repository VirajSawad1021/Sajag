// The Casebook: every case is saved on this device only (shared_preferences / app storage).
// "Your cases stay on your phone" — no account, no server-side copy.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class CaseStore extends ChangeNotifier {
  static const _key = 'sajag.cases.v1';
  static const _profileKey = 'sajag.profile.v1';
  static const _serverKey = 'sajag.server.v1';

  final List<SajagCase> cases = [];
  Map<String, String> profile = {};
  String? serverOverride;
  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        cases
          ..clear()
          ..addAll((jsonDecode(raw) as List).map((c) => SajagCase.fromJson(Map<String, dynamic>.from(c))));
      } catch (e) {
        debugPrint('Could not read saved cases: $e');
      }
    }
    final p = _prefs!.getString(_profileKey);
    if (p != null) profile = Map<String, String>.from(jsonDecode(p));
    serverOverride = _prefs!.getString(_serverKey);
    cases.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
  }

  SajagCase? byId(String id) => cases.where((c) => c.id == id).firstOrNull;

  Future<void> save(SajagCase c) async {
    c.updatedAt = DateTime.now();
    if (!cases.contains(c)) cases.insert(0, c);
    cases.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _persist();
  }

  Future<void> delete(SajagCase c) async {
    cases.remove(c);
    await _persist();
  }

  Future<void> saveProfile(Map<String, String> p) async {
    profile = p;
    await _prefs?.setString(_profileKey, jsonEncode(p));
  }

  Future<void> setServer(String? url) async {
    serverOverride = (url == null || url.trim().isEmpty) ? null : url.trim();
    if (serverOverride == null) {
      await _prefs?.remove(_serverKey);
    } else {
      await _prefs?.setString(_serverKey, serverOverride!);
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    await _prefs?.setString(_key, jsonEncode(cases.map((c) => c.toJson()).toList()));
    notifyListeners();
  }
}

final store = CaseStore();
