// Cases are stored on the phone (no account, no server copy). The analysis from the API is kept as raw JSON
// with small typed helpers, so the app keeps working when the backend adds fields.
import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum EvidenceKind { image, audio, text }

class Evidence {
  Evidence({required this.kind, required this.name, this.mime = '', this.bytes, this.text, String? id, DateTime? addedAt})
      : id = id ?? _uuid.v4(),
        addedAt = addedAt ?? DateTime.now();

  final String id;
  final EvidenceKind kind;
  final String name;
  final String mime;
  final Uint8List? bytes;
  final String? text;
  final DateTime addedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'name': name,
        'mime': mime,
        if (bytes != null) 'bytes': base64Encode(bytes!),
        if (text != null) 'text': text,
        'addedAt': addedAt.toIso8601String(),
      };

  factory Evidence.fromJson(Map<String, dynamic> j) => Evidence(
        id: j['id'],
        kind: EvidenceKind.values.byName(j['kind']),
        name: j['name'] ?? '',
        mime: j['mime'] ?? '',
        bytes: j['bytes'] != null ? base64Decode(j['bytes']) : null,
        text: j['text'],
        addedAt: DateTime.tryParse(j['addedAt'] ?? '') ?? DateTime.now(),
      );
}

/// One run of the analysis (the first check, or a re-check after the seller replied).
class CheckRun {
  CheckRun({required this.at, required this.analysis, required this.evidenceIds});
  final DateTime at;
  final Map<String, dynamic> analysis;
  final List<String> evidenceIds; // which evidence was sent, in order (maps img_N / aud_N back to files)

  Analysis get a => Analysis(analysis);

  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'analysis': analysis, 'evidenceIds': evidenceIds};
  factory CheckRun.fromJson(Map<String, dynamic> j) => CheckRun(
        at: DateTime.parse(j['at']),
        analysis: Map<String, dynamic>.from(j['analysis']),
        evidenceIds: List<String>.from(j['evidenceIds'] ?? const []),
      );
}

enum CaseStatus { watching, paid, recovery, resolved }

class SajagCase {
  SajagCase({
    String? id,
    this.title = '',
    this.stage = 'before_payment',
    this.status = CaseStatus.watching,
    List<Evidence>? evidence,
    List<CheckRun>? checks,
    this.agent,
    Map<String, String>? recovery,
    this.petition,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        evidence = evidence ?? [],
        checks = checks ?? [],
        recovery = recovery ?? {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String stage;
  CaseStatus status;
  final List<Evidence> evidence;
  final List<CheckRun> checks;
  Map<String, dynamic>? agent;
  final Map<String, String> recovery; // step id -> ISO time it was done
  Map<String, dynamic>? petition;
  final DateTime createdAt;
  DateTime updatedAt;

  CheckRun? get latest => checks.isEmpty ? null : checks.last;
  String? get level => latest?.a.level;

  Evidence? evidenceFor(String sourceId, CheckRun run) {
    // img_2 -> the 2nd image sent in that run, aud_1 -> 1st audio, etc.
    final parts = sourceId.split('_');
    if (parts.length != 2) return null;
    final n = int.tryParse(parts[1]);
    if (n == null) return null;
    final kind = parts[0] == 'img' ? EvidenceKind.image : parts[0] == 'aud' ? EvidenceKind.audio : null;
    if (kind == null) return null;
    final sent = run.evidenceIds.map((id) => evidence.where((e) => e.id == id).firstOrNull).whereType<Evidence>();
    final ofKind = sent.where((e) => e.kind == kind).toList();
    return n - 1 < ofKind.length ? ofKind[n - 1] : null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'stage': stage,
        'status': status.name,
        'evidence': evidence.map((e) => e.toJson()).toList(),
        'checks': checks.map((c) => c.toJson()).toList(),
        'agent': agent,
        'recovery': recovery,
        'petition': petition,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SajagCase.fromJson(Map<String, dynamic> j) => SajagCase(
        id: j['id'],
        title: j['title'] ?? '',
        stage: j['stage'] ?? 'before_payment',
        status: CaseStatus.values.asNameMap()[j['status']] ?? CaseStatus.watching,
        evidence: (j['evidence'] as List? ?? []).map((e) => Evidence.fromJson(Map<String, dynamic>.from(e))).toList(),
        checks: (j['checks'] as List? ?? []).map((c) => CheckRun.fromJson(Map<String, dynamic>.from(c))).toList(),
        agent: j['agent'] == null ? null : Map<String, dynamic>.from(j['agent']),
        recovery: Map<String, String>.from(j['recovery'] ?? {}),
        petition: j['petition'] == null ? null : Map<String, dynamic>.from(j['petition']),
        createdAt: DateTime.tryParse(j['createdAt'] ?? ''),
        updatedAt: DateTime.tryParse(j['updatedAt'] ?? ''),
      );
}

/// Typed read access to the API's analysis JSON.
class Analysis {
  Analysis(this.j);
  final Map<String, dynamic> j;

  String get level => '${(j['overall'] as Map?)?['level'] ?? 'insufficient'}';
  String summary(bool ne) {
    final overall = j['overall'] as Map? ?? const {};
    return '${overall[ne ? 'summary_ne' : 'summary_en'] ?? ''}';
  }
  String get stage => j['stage'] ?? 'before_payment';
  String get engine => j['engine'] ?? '';
  List<Map<String, dynamic>> _list(String k) =>
      (j[k] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  List<Map<String, dynamic>> get sources => _list('sources');
  List<Map<String, dynamic>> get signals => _list('signals');
  List<Map<String, dynamic>> get grounded => signals.where((s) => s['grounded'] == true).toList();
  List<Map<String, dynamic>> get qr => _list('qr');
  List<Map<String, dynamic>> get events => _list('events');
  List<Map<String, dynamic>> get facts => _list('facts');
  List<Map<String, dynamic>> get nextSteps => _list('next_steps');
  List<Map<String, dynamic>> get deadlines => _list('deadlines');
  List<Map<String, dynamic>> get payments => _list('payments');
  List<String> get warnings => List<String>.from(j['warnings'] ?? const []);

  Map<String, dynamic>? source(String id) => sources.where((s) => s['id'] == id).firstOrNull;

  // Names the seller uses for their shop/page (not receipt receivers or QR payees); falls back to facts.
  List<String> get sellerNames {
    final claimed = List<String>.from(j['seller_names'] ?? const []);
    if (claimed.isNotEmpty) return claimed;
    return facts.where((f) => f['field'] == 'seller_name').map((f) => '${f['value']}').toSet().toList();
  }
}
