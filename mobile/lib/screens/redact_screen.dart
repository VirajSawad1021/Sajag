// Hide private details before upload: drag boxes over OTPs, balances, account numbers or faces. The boxes are
// painted solid into the image's pixels (not an overlay, not a reversible blur), and only that copy is sent.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../l10n.dart';
import '../theme.dart';
import '../widgets/common.dart';

class RedactScreen extends StatefulWidget {
  const RedactScreen({super.key, required this.bytes});
  final Uint8List bytes;

  /// Opens the editor; returns new PNG bytes, or null if nothing was hidden / cancelled.
  static Future<Uint8List?> open(BuildContext context, Uint8List bytes) =>
      Navigator.of(context).push<Uint8List>(MaterialPageRoute(builder: (_) => RedactScreen(bytes: bytes)));

  @override
  State<RedactScreen> createState() => _RedactScreenState();
}

class _RedactScreenState extends State<RedactScreen> {
  ui.Image? _image;
  final List<Rect> _boxes = []; // in image pixel coordinates
  Offset? _start;
  Rect? _drawing;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ui.instantiateImageCodec(widget.bytes).then((codec) => codec.getNextFrame()).then((f) {
      if (mounted) setState(() => _image = f.image);
    });
  }

  Future<void> _done() async {
    if (_boxes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    final img = _image!;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(img, Offset.zero, Paint());
    final fill = Paint()..color = const Color(0xFF111111);
    for (final r in _boxes) {
      canvas.drawRect(r, fill);
    }
    final out = await recorder.endRecording().toImage(img.width, img.height);
    final png = await out.toByteData(format: ui.ImageByteFormat.png);
    if (mounted) Navigator.of(context).pop(png!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('hideDetails')),
        actions: [
          IconButton(
            tooltip: tr('undo'),
            icon: const Icon(Icons.undo_rounded),
            onPressed: _boxes.isEmpty ? null : () => setState(_boxes.removeLast),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(tr('hideHelp'), style: T.small),
        ),
        Expanded(
          child: img == null
              ? const Center(child: CircularProgressIndicator(color: C.ink))
              : Center(
                  // The image is laid out at its native pixel size and scaled to fit, so touch positions
                  // inside it are already in image pixels.
                  child: FittedBox(
                    child: SizedBox(
                      width: img.width.toDouble(),
                      height: img.height.toDouble(),
                      child: _Canvas(
                        image: img,
                        boxes: _boxes,
                        drawing: _drawing,
                        onStart: (p) => setState(() {
                          _start = p;
                          _drawing = Rect.fromPoints(p, p);
                        }),
                        onUpdate: (p) => setState(() => _drawing = Rect.fromPoints(_start!, p)),
                        onEnd: () => setState(() {
                          final r = _drawing;
                          if (r != null && r.width.abs() > 8 && r.height.abs() > 8) _boxes.add(r);
                          _drawing = null;
                        }),
                      ),
                    ),
                  ),
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(children: [
              Expanded(child: Text('${_boxes.length} ${tr('hiddenCount')}', style: T.meta)),
              Pill(tr('useHidden'), big: true, busy: _saving, icon: Icons.check_rounded, onTap: img == null ? null : _done),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Draws the image at its native size (inside a FittedBox) with the hidden boxes and the one being drawn.
class _Canvas extends StatelessWidget {
  const _Canvas({
    required this.image,
    required this.boxes,
    required this.drawing,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });
  final ui.Image image;
  final List<Rect> boxes;
  final Rect? drawing;
  final ValueChanged<Offset> onStart, onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) => onStart(d.localPosition),
      onPanUpdate: (d) => onUpdate(d.localPosition),
      onPanEnd: (_) => onEnd(),
      child: CustomPaint(painter: _Painter(image, boxes, drawing)),
    );
  }
}

class _Painter extends CustomPainter {
  _Painter(this.image, this.boxes, this.drawing);
  final ui.Image image;
  final List<Rect> boxes;
  final Rect? drawing;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());
    final fill = Paint()..color = const Color(0xFF111111);
    for (final r in boxes) {
      canvas.drawRect(r, fill);
    }
    if (drawing != null) {
      canvas.drawRect(drawing!, Paint()..color = const Color(0xCC111111));
      canvas.drawRect(drawing!, Paint()
        ..color = C.high
        ..style = PaintingStyle.stroke
        ..strokeWidth = image.width / 200);
    }
  }

  @override
  bool shouldRepaint(_Painter old) => true;
}
