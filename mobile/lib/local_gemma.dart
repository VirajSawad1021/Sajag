// On-device Gemma 4 (E2B) through Google's LiteRT-LM engine: the check runs on the phone, with no internet and
// no evidence leaving it. The model (~2.6 GB) is downloaded once, or found where a developer pushed it over adb.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:path_provider/path_provider.dart';

const modelFile = 'gemma-4-E2B-it.litertlm';
const modelUrl = 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/$modelFile';

/// Timings and raw output of one on-device run, shown to the user so the speed claim is checkable.
class LocalRun {
  LocalRun({required this.text, required this.loadMs, required this.firstTokenMs, required this.totalMs, required this.tokens, required this.backend});
  final String text;
  final int loadMs, firstTokenMs, totalMs, tokens;
  final String backend;

  double get tokensPerSecond => tokens / ((totalMs - firstTokenMs).clamp(1, 1 << 30) / 1000);
  String get summary =>
      'load ${(loadMs / 1000).toStringAsFixed(1)}s · first token ${(firstTokenMs / 1000).toStringAsFixed(1)}s · '
      'total ${(totalMs / 1000).toStringAsFixed(1)}s · ${tokensPerSecond.toStringAsFixed(1)} tok/s · $backend';
}

class LocalGemma extends ChangeNotifier {
  bool _initialized = false;
  bool installed = false;
  double? downloadProgress; // 0–100 while downloading
  InferenceModel? _model;

  Future<void> init() async {
    if (_initialized) return;
    await FlutterEdgeAi.initialize(inferenceEngines: const [LiteRtLmEngine()]);
    _initialized = true;
    installed = FlutterEdgeAi.hasActiveModel();
    notifyListeners();
  }

  /// Where `adb push` can drop the model during development (the app's own external files folder).
  Future<File?> pushedModel() async {
    final dir = await getExternalStorageDirectory();
    final f = File('${dir?.path}/$modelFile');
    return dir != null && await f.exists() ? f : null;
  }

  Future<void> install() async {
    await init();
    final pushed = await pushedModel();
    final builder = FlutterEdgeAi.installModel(modelType: ModelType.gemma4, fileType: ModelFileType.litertlm);
    if (pushed != null) {
      await builder.fromFile(pushed.path).install();
    } else {
      downloadProgress = 0;
      notifyListeners();
      await builder.fromNetwork(modelUrl).withProgress((p) {
        downloadProgress = p.toDouble();
        notifyListeners();
      }).install();
    }
    downloadProgress = null;
    installed = true;
    notifyListeners();
  }

  /// One prompt with optional screenshots, streamed so the first-token time can be measured.
  Future<LocalRun> run(String prompt, {List<Uint8List> images = const [], void Function(String partial)? onText}) async {
    await init();
    final t = Stopwatch()..start();
    _model ??= await FlutterEdgeAi.getActiveModel(
      maxTokens: 4096,
      preferredBackend: PreferredBackend.gpu,
      supportImage: images.isNotEmpty,
      maxNumImages: images.isEmpty ? null : images.length,
    );
    final loadMs = t.elapsedMilliseconds;
    final chat = await _model!.createChat(supportImage: images.isNotEmpty, temperature: 0.2, topK: 1, maxOutputTokens: 1024);
    if (images.isEmpty) {
      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
    } else {
      await chat.addQueryChunk(Message.withImages(text: prompt, imageBytes: images, isUser: true));
    }
    final out = StringBuffer();
    var firstTokenMs = 0, tokens = 0;
    await for (final r in chat.generateChatResponseAsync()) {
      if (r is! TextResponse) continue;
      if (tokens == 0) firstTokenMs = t.elapsedMilliseconds;
      tokens++;
      out.write(r.token);
      onText?.call(out.toString());
    }
    return LocalRun(
      text: out.toString(),
      loadMs: loadMs,
      firstTokenMs: firstTokenMs,
      totalMs: t.elapsedMilliseconds,
      tokens: tokens,
      backend: '${_model!.activeBackend ?? 'unknown'}',
    );
  }
}

final localGemma = LocalGemma();

/// Short prompt for the phone: the server prompt is too long for a 2B model's prefill on a mid-range phone.
const scamCheckPrompt = '''
You check chats from Nepali online sellers for scam warning signs. The chat may be Nepali, English or Romanized Nepali.
1. Copy the chat messages exactly as written.
2. List warning signs. For each, give one pattern id from this list and the exact words from the chat that show it:
advance_payment, terms_changed, no_cod_or_verification, urgency_pressure, otp_credential_request,
identity_document_request, price_too_good, extra_fee_to_release, qr_payee_mismatch, friend_impersonation,
fake_bank_kyc, fake_prize_lottery.
Only list a sign if the exact words are in the chat.
Answer with JSON only:
{"transcript": "...", "signals": [{"pattern_id": "...", "quote": "..."}], "summary_en": "one sentence", "summary_ne": "एक वाक्य नेपालीमा"}
''';

/// Pulls the JSON object out of the model's reply (it sometimes wraps it in ```json fences).
Map<String, dynamic>? parseJson(String text) {
  final start = text.indexOf('{'), end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    return jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}
