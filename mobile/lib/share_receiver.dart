// "Share to Sajag": receive screenshots, voice notes, forwarded text (e.g. a bank SMS) and WhatsApp
// "Export chat" files from other apps, and turn them into evidence for a new check.
import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'models.dart';

typedef SharedHandler = void Function(List<Evidence> evidence);

const _imageExt = {'png': 'image/png', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'webp': 'image/webp'};
const _audioExt = {'opus': 'audio/ogg', 'ogg': 'audio/ogg', 'm4a': 'audio/mp4', 'aac': 'audio/mp4', 'mp3': 'audio/mpeg', 'wav': 'audio/wav', 'amr': 'audio/amr'};
const _maxChatChars = 15000;

class ShareReceiver {
  StreamSubscription? _sub;

  /// Starts listening. Shares that arrive while the app is open and the one that launched it both go to [onShared].
  Future<void> start(SharedHandler onShared) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      // ignore: avoid_print
      print('SAJAG-SHARE initial: ${initial.map((f) => '${f.type.value} ${f.mimeType} ${f.path}').toList()}');
      if (initial.isNotEmpty) {
        onShared(await toEvidence(initial));
        await ReceiveSharingIntent.instance.reset();
      }
      _sub = ReceiveSharingIntent.instance.getMediaStream().listen((files) async {
        // ignore: avoid_print
        print('SAJAG-SHARE stream: ${files.map((f) => '${f.type.value} ${f.mimeType} ${f.path}').toList()}');
        if (files.isEmpty) return;
        onShared(await toEvidence(files));
        await ReceiveSharingIntent.instance.reset();
      });
    } catch (e) {
      // ignore: avoid_print
      print('SAJAG-SHARE unavailable: $e');
    }
  }

  void dispose() => _sub?.cancel();

  static String _ext(String name) => name.contains('.') ? name.split('.').last.toLowerCase() : '';

  static Future<List<Evidence>> toEvidence(List<SharedMediaFile> files) async {
    final out = <Evidence>[];
    for (final f in files) {
      final name = f.path.split('/').last;
      final ext = _ext(name);
      final mime = (f.mimeType ?? '').toLowerCase();
      Uint8List? bytes;
      try {
        bytes = await XFile(f.path).readAsBytes();
      } catch (e) {
        // ignore: avoid_print
        print('SAJAG-SHARE not a readable file (${f.type.value}): $e');
        bytes = null; // not a file: plain shared text (EXTRA_TEXT arrives in `path`)
      }
      if (bytes == null) {
        final text = (f.message ?? f.path).trim();
        if (text.isNotEmpty) out.add(Evidence(kind: EvidenceKind.text, name: 'shared-text.txt', text: text));
        continue;
      }
      if (mime.startsWith('image/') || _imageExt.containsKey(ext)) {
        out.add(Evidence(kind: EvidenceKind.image, name: name, mime: mime.startsWith('image/') ? mime : _imageExt[ext]!, bytes: bytes));
      } else if (mime.startsWith('audio/') || _audioExt.containsKey(ext)) {
        out.add(Evidence(kind: EvidenceKind.audio, name: name, mime: mime.startsWith('audio/') ? mime : _audioExt[ext]!, bytes: bytes));
      } else if (ext == 'zip' || mime.contains('zip')) {
        out.addAll(whatsAppZip(bytes));
      } else if (ext == 'txt' || mime.startsWith('text/')) {
        out.add(_chatText(name, _utf8(bytes)));
      }
    }
    return out;
  }

  /// WhatsApp "Export chat → Include media" is a zip with `_chat.txt` (or "WhatsApp Chat with X.txt"),
  /// photos and .opus voice notes. Keep the chat text, up to 6 images and 3 voice notes.
  static List<Evidence> whatsAppZip(Uint8List zipBytes) {
    final out = <Evidence>[];
    var images = 0, audios = 0;
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final name = file.name.split('/').last;
        final ext = _ext(name);
        final data = file.readBytes();
        if (data == null) continue;
        if (ext == 'txt') {
          out.insert(0, _chatText(name, _utf8(data)));
        } else if (_imageExt.containsKey(ext) && images < 6) {
          images++;
          out.add(Evidence(kind: EvidenceKind.image, name: name, mime: _imageExt[ext]!, bytes: data));
        } else if (_audioExt.containsKey(ext) && audios < 3) {
          audios++;
          out.add(Evidence(kind: EvidenceKind.audio, name: name, mime: _audioExt[ext]!, bytes: data));
        }
      }
    } catch (e) {
      debugPrint('Could not read zip: $e');
    }
    return out;
  }

  static Evidence _chatText(String name, String text) {
    // Long chats: the most recent part is what matters for a purchase.
    final trimmed = text.length > _maxChatChars ? text.substring(text.length - _maxChatChars) : text;
    return Evidence(kind: EvidenceKind.text, name: name, text: '[Chat export: $name]\n$trimmed');
  }

  static String _utf8(Uint8List bytes) {
    try {
      return const Utf8Decoder(allowMalformed: true).convert(bytes);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }
}

final shareReceiver = ShareReceiver();
