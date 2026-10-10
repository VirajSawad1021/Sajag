// Scam X-Ray: the user's own screenshot with Gemma-located boxes drawn over messages that carry a verified
// warning. Boxes come from the backend (normalised 0-1000 [ymin, xmin, ymax, xmax]); a box is only drawn when it is
// attached to a grounded signal, so nothing unverified lights up.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n.dart';
import '../theme.dart';

class XRayMark {
  XRayMark({required this.box, required this.number, required this.severity, required this.title, required this.signal});
  final List<int> box;
  final int number;
  final String severity;
  final String title;
  final Map<String, dynamic> signal;
}

class XRayImage extends StatefulWidget {
  const XRayImage({super.key, required this.bytes, required this.marks, this.onTapMark, this.scanning = false});
  final Uint8List bytes;
  final List<XRayMark> marks;
  final void Function(XRayMark)? onTapMark;
  final bool scanning;

  @override
  State<XRayImage> createState() => _XRayImageState();
}

class _XRayImageState extends State<XRayImage> with SingleTickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  late final AnimationController _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  int? _active;

  @override
  void initState() {
    super.initState();
    if (widget.scanning) _scan.repeat();
    _reveal.forward();
  }

  @override
  void didUpdateWidget(XRayImage old) {
    super.didUpdateWidget(old);
    if (widget.scanning && !_scan.isAnimating) _scan.repeat();
    if (!widget.scanning && _scan.isAnimating) _scan.stop();
    if (old.marks.length != widget.marks.length) _reveal.forward(from: 0);
  }

  @override
  void dispose() {
    _scan.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(R.card),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: C.border), borderRadius: BorderRadius.circular(R.card)),
        child: LayoutBuilder(builder: (context, constraints) {
          return Stack(children: [
            Image.memory(widget.bytes, width: constraints.maxWidth, fit: BoxFit.fitWidth, gaplessPlayback: true),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_scan, _reveal]),
                builder: (context, _) => CustomPaint(
                  painter: _XRayPainter(
                    marks: widget.marks,
                    scan: widget.scanning ? _scan.value : null,
                    reveal: Curves.easeOutCubic.transform(_reveal.value),
                    active: _active,
                  ),
                ),
              ),
            ),
            // Tap targets for each mark.
            ...widget.marks.map((m) => Positioned.fill(
                  child: LayoutBuilder(builder: (context, c) {
                    final r = _rect(m.box, c.biggest);
                    return Stack(children: [
                      Positioned.fromRect(
                        rect: r,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            setState(() => _active = m.number);
                            widget.onTapMark?.call(m);
                          },
                        ),
                      ),
                    ]);
                  }),
                )),
          ]);
        }),
      ),
    );
  }
}

Rect _rect(List<int> box, Size size) => Rect.fromLTRB(
      box[1] / 1000 * size.width,
      box[0] / 1000 * size.height,
      box[3] / 1000 * size.width,
      box[2] / 1000 * size.height,
    );

class _XRayPainter extends CustomPainter {
  _XRayPainter({required this.marks, required this.scan, required this.reveal, required this.active});
  final List<XRayMark> marks;
  final double? scan;
  final double reveal;
  final int? active;

  @override
  void paint(Canvas canvas, Size size) {
    if (scan != null) {
      // A soft scanning band while Gemma reads the screenshot.
      final y = scan! * size.height;
      final band = Rect.fromLTWH(0, y - 60, size.width, 60);
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, C.sage.withValues(alpha: 0.28)],
          ).createShader(band),
      );
      canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()
        ..color = C.sage.withValues(alpha: 0.9)
        ..strokeWidth = 2);
    }
    if (marks.isEmpty) return;
    // Dim everything except the marked messages.
    final dim = Path()..addRect(Offset.zero & size);
    for (final m in marks) {
      dim.addRRect(RRect.fromRectAndRadius(_rect(m.box, size).inflate(4), const Radius.circular(12)));
    }
    dim.fillType = PathFillType.evenOdd;
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.32 * reveal));

    for (final m in marks) {
      final colors = severityColors(m.severity);
      final r = RRect.fromRectAndRadius(_rect(m.box, size).inflate(4), const Radius.circular(12));
      final isActive = active == m.number;
      canvas.drawRRect(r, Paint()
        ..color = colors.fg.withValues(alpha: (isActive ? 0.16 : 0.08) * reveal)
        ..style = PaintingStyle.fill);
      canvas.drawRRect(r, Paint()
        ..color = colors.fg.withValues(alpha: reveal)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? 3 : 2);
      // Numbered badge at the top-left corner.
      // Badge in the free space right of the message when there is room (seller bubbles sit on the left),
      // otherwise just inside the left edge, so it never covers the words being flagged.
      final y = (r.top + 16).clamp(14.0, size.height - 14);
      final c = r.right + 30 < size.width ? Offset(r.right + 16, y) : Offset((r.left - 16).clamp(14.0, size.width - 14), y);
      canvas.drawCircle(c, 12 * reveal, Paint()..color = colors.fg);
      final tp = TextPainter(
        text: TextSpan(text: '${m.number}', style: T.pill.copyWith(color: Colors.white, fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout();
      if (reveal > 0.6) tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_XRayPainter old) =>
      old.scan != scan || old.reveal != reveal || old.active != active || old.marks != marks;
}

/// Builds X-Ray marks for one image source from the analysis (only grounded signals with a matched region).
List<XRayMark> marksFor(Map<String, dynamic> source, List<Map<String, dynamic>> grounded) {
  final regions = (source['regions'] as List? ?? const []).cast<Map>();
  final marks = <XRayMark>[];
  final seenRegions = <int>{};
  var n = 1;
  for (final s in grounded) {
    final idx = s['region'];
    if (s['source_id'] != source['id'] || idx is! int || idx >= regions.length) continue;
    if (!seenRegions.add(idx)) continue; // one badge per message even if two warnings point at it
    final box = (regions[idx]['box'] as List).map((v) => (v as num).toInt()).toList();
    marks.add(XRayMark(
      box: box,
      number: n++,
      severity: '${s['severity']}',
      title: '${lang.ne ? s['title_ne'] : s['title_en']}',
      signal: s,
    ));
  }
  return marks;
}
