// Talks to the Sajag backend (FastAPI). Analysis streams as Server-Sent Events so the app can show Gemma's
// progress live; on the web, the browser client buffers the stream, so progress arrives together at the end.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'models.dart';
import 'store.dart';

/// Default server: same origin on the web build (served by FastAPI); the Android emulator's host alias otherwise.
/// Override in Settings (e.g. http://192.168.1.10:8000 when the phone and laptop share Wi-Fi), or at build time
/// with --dart-define=SAJAG_API=http://...
String get apiBase {
  if (store.serverOverride != null) return store.serverOverride!;
  const fromBuild = String.fromEnvironment('SAJAG_API');
  if (fromBuild.isNotEmpty) return fromBuild;
  if (kIsWeb) return Uri.base.origin;
  return 'http://10.0.2.2:8000';
}

class ApiError implements Exception {
  ApiError(this.message);
  final String message;
  @override
  String toString() => message;
}

class ProgressEvent {
  ProgressEvent(this.step, this.data);
  final String step;
  final Map<String, dynamic> data;
}

class Api {
  final _client = http.Client();

  Future<bool> health() async {
    try {
      final r = await _client.get(Uri.parse('$apiBase/api/health')).timeout(const Duration(seconds: 6));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Streams progress events; completes with the analysis JSON.
  Future<Map<String, dynamic>> analyze({
    required String text,
    required String stage,
    required List<Evidence> evidence,
    required void Function(ProgressEvent) onProgress,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBase/api/analyze/stream'))
      ..fields['text'] = text
      ..fields['stage'] = stage;
    for (final e in evidence) {
      if (e.bytes == null) continue;
      final field = e.kind == EvidenceKind.image ? 'images' : 'audios';
      req.files.add(http.MultipartFile.fromBytes(field, e.bytes!, filename: e.name, contentType: _mediaType(e.mime)));
    }
    final http.StreamedResponse res;
    try {
      res = await _client.send(req).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw ApiError('Could not reach the Sajag server at $apiBase.');
    } catch (e) {
      throw ApiError('Could not reach the Sajag server at $apiBase. ($e)');
    }
    if (res.statusCode != 200) {
      final body = await res.stream.bytesToString();
      throw ApiError(_detail(body) ?? 'Server error ${res.statusCode}');
    }
    String? event;
    final result = Completer<Map<String, dynamic>>();
    final lines = res.stream.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines.timeout(const Duration(seconds: 150))) {
      if (line.startsWith('event: ')) {
        event = line.substring(7).trim();
      } else if (line.startsWith('data: ')) {
        final data = Map<String, dynamic>.from(jsonDecode(line.substring(6)));
        if (event == 'progress') {
          onProgress(ProgressEvent('${data['step']}', data));
        } else if (event == 'result') {
          result.complete(data);
        } else if (event == 'error') {
          throw ApiError('${data['detail']}');
        }
      }
    }
    if (!result.isCompleted) throw ApiError('The check ended without a result. Try again.');
    return result.future;
  }

  List<Map<String, dynamic>>? _resources;

  /// Verified official contacts (data/resources.yaml on the server), cached for the session.
  Future<List<Map<String, dynamic>>> resources() async {
    if (_resources != null) return _resources!;
    final r = await _client.get(Uri.parse('$apiBase/api/resources')).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw ApiError('Could not load official contacts.');
    _resources = (jsonDecode(utf8.decode(r.bodyBytes)) as List).map((e) => Map<String, dynamic>.from(e)).toList();
    return _resources!;
  }

  Future<Map<String, dynamic>> agent(Map<String, dynamic> analysis) =>
      _postJson('/api/agent', {'analysis': analysis}, const Duration(seconds: 120));

  Future<Map<String, dynamic>> petitionDraft(Map<String, dynamic> analysis, String story) =>
      _postJson('/api/petition/draft', {'analysis': analysis, 'user_story_ne': story}, const Duration(seconds: 90));

  Future<Uint8List> petitionPdf(Map<String, dynamic> fields, Map<String, String> complainant, List<Evidence> exhibits) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBase/api/petition/pdf'))
      ..fields['payload'] = jsonEncode({'fields': fields, 'complainant': complainant});
    for (final e in exhibits.where((e) => e.kind == EvidenceKind.image && e.bytes != null)) {
      req.files.add(http.MultipartFile.fromBytes('exhibits', e.bytes!, filename: e.name, contentType: _mediaType(e.mime)));
    }
    final res = await http.Response.fromStream(await _client.send(req).timeout(const Duration(seconds: 90)));
    if (res.statusCode != 200) throw ApiError(_detail(res.body) ?? 'Server error ${res.statusCode}');
    return res.bodyBytes;
  }

  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body, Duration timeout) async {
    try {
      final res = await _client
          .post(Uri.parse('$apiBase$path'), headers: {'content-type': 'application/json'}, body: jsonEncode(body))
          .timeout(timeout);
      if (res.statusCode != 200) throw ApiError(_detail(utf8.decode(res.bodyBytes)) ?? 'Server error ${res.statusCode}');
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)));
    } on TimeoutException {
      throw ApiError('The server took too long. Try again.');
    }
  }

  static String? _detail(String body) {
    try {
      final d = jsonDecode(body)['detail'];
      return d is String ? d : jsonEncode(d);
    } catch (_) {
      return body.isEmpty ? null : body.substring(0, body.length.clamp(0, 200));
    }
  }

  static MediaType? _mediaType(String mime) {
    try {
      return mime.isEmpty ? null : MediaType.parse(mime);
    } catch (_) {
      return null;
    }
  }
}

final api = Api();
