import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Pad de signature manuscrite : capture les traits au doigt et les rend en
/// PNG (RepaintBoundary.toImage). Natif Flutter (CustomPainter), pas de
/// dependance signature/canvas externe pour un besoin aussi simple.
class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, required this.onChanged});
  final ValueChanged<bool> onChanged;
  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final _boundaryKey = GlobalKey();
  final List<Offset?> _points = [];

  void _addPoint(Offset? p) {
    setState(() => _points.add(p));
    widget.onChanged(_points.any((p) => p != null));
  }

  void clear() {
    setState(() => _points.clear());
  }

  Future<Uint8List?> capture() async {
    if (_points.every((p) => p == null)) return null;
    final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        key: _boundaryKey,
        child: Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
              border: Border.all(color: Colors.black26),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white),
          // ClipRRect : le trait ne doit jamais deborder du cadre arrondi,
          // sinon la capture (boundary.toImage) inclut des pixels hors zone.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, // capte le geste meme sur zone non peinte
              onPanStart: (d) => _addPoint(d.localPosition),
              onPanUpdate: (d) => _addPoint(d.localPosition),
              onPanEnd: (_) => _addPoint(null),
              child: SizedBox.expand(child: CustomPaint(painter: _SignaturePainter(_points))),
            ),
          ),
        ),
      );
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.points);
  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    // ponytail: noir opaque + trait plus epais -- Colors.black87 (87%
    // d'opacite) + strokeWidth 2.4 pouvait paraitre invisible sur certains
    // ecrans/backends de rendu. Colors.black (100%) + 3.5 est net partout.
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    for (var i = 0; i < points.length - 1; i++) {
      final p1 = points[i], p2 = points[i + 1];
      if (p1 != null && p2 != null) canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => old.points != points;
}
