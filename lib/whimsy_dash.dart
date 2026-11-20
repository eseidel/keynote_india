import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'layouts.dart' show Picture;
import 'theme.dart';

/// "It goes everywhere": the pictures in a row with captions (like Gallery),
/// and a tiny Dash who drops onto the first picture when the slide appears,
/// then hops to the next and the next, ending perched on the last. The same
/// app, wherever there's a screen.
class HopGallery extends StatefulWidget {
  const HopGallery({super.key, required this.items});

  /// Each picture, its caption, and where Dash perches on it as a fraction
  /// of the picture (0,0 top left; 1,1 bottom right).
  final List<(String image, String caption, Offset perch)> items;

  @override
  State<HopGallery> createState() => _HopGalleryState();
}

class _HopGalleryState extends State<HopGallery>
    with SingleTickerProviderStateMixin {
  final _stack = GlobalKey();
  late final _pictures = [for (final _ in widget.items) GlobalKey()];
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..forward();

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    key: _stack,
    fit: StackFit.expand,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (image, caption, _)) in widget.items.indexed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(child: Picture(image, key: _pictures[i])),
                    ),
                    const SizedBox(height: 20),
                    Text(caption, style: zalando(16, color: Palette.muted)),
                  ],
                ),
              ),
            ),
        ],
      ),
      IgnorePointer(
        child: CustomPaint(
          painter: _DashPainter(
            _hop,
            perches: () => [
              for (final (i, (_, _, perch)) in widget.items.indexed)
                _perch(_pictures[i], perch),
            ],
          ),
        ),
      ),
    ],
  );

  /// Where Dash's feet go on picture [key], in the stack's coordinates.
  Offset? _perch(GlobalKey key, Offset fraction) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.hasSize || box.size.isEmpty) {
      return null;
    }
    final topLeft = stack.globalToLocal(box.localToGlobal(Offset.zero));
    return topLeft +
        Offset(box.size.width * fraction.dx, box.size.height * fraction.dy);
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.t, {required this.perches}) : super(repaint: t);
  final Animation<double> t;

  /// Read at paint time, after layout, so the pictures' real positions are
  /// known (they size themselves once their images load).
  final List<Offset?> Function() perches;

  // Timeline, as fractions of the whole: drop in, then each hop, each
  // followed by a squash on landing.
  static const _drop = (0.0, 0.16);
  static const _hops = [(0.34, 0.56), (0.70, 0.92)];
  static const _squash = 0.07;

  @override
  void paint(Canvas canvas, Size size) {
    final spots = perches();
    if (spots.any((p) => p == null)) return;
    final p = spots.cast<Offset>();
    final v = t.value;

    var feet = p.first;
    var airborne = false;
    var landedAt = _drop.$2;
    var tilt = 0.0;
    if (v < _drop.$2) {
      final u = Curves.easeIn.transform(v / _drop.$2);
      feet = p.first - Offset(0, 260 * (1 - u));
      airborne = true;
    }
    for (final (i, (start, end)) in _hops.indexed) {
      if (i + 1 >= p.length) break;
      if (v >= end) {
        feet = p[i + 1];
        landedAt = end;
      } else if (v > start) {
        final u = Curves.easeInOut.transform((v - start) / (end - start));
        final a = p[i];
        final b = p[i + 1];
        final rise = 90 + (a.dy - b.dy).abs() * 0.3;
        feet = Offset.lerp(a, b, u)! - Offset(0, rise * math.sin(math.pi * u));
        airborne = true;
        tilt = -0.35 * math.cos(math.pi * u); // nose up, then down
        break;
      }
    }
    // Squash on landing, springing back.
    final since = v - landedAt;
    final squash = !airborne && since >= 0 && since < _squash
        ? math.sin(math.pi * since / _squash)
        : 0.0;

    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.rotate(tilt);
    canvas.scale(1.25 * (1 + 0.3 * squash), 1.25 * (1 - 0.3 * squash));
    _paintDash(canvas, wingUp: airborne && (v * 60).floor().isEven);
    canvas.restore();
  }

  /// A small Dash-like hummingbird facing right, feet at the origin.
  static void _paintDash(Canvas canvas, {required bool wingUp}) {
    const blue = Color(0xFF42A5F5);
    const deep = Color(0xFF1565C0);
    const belly = Color(0xFFBBDEFB);
    const beak = Color(0xFFC8A27A);
    const r = 30.0;
    const c = Offset(0, -r - 8);

    // Shadow-free, flat: feet, tail, body, belly, wing, eye, beak, tuft.
    final stroke = Paint()
      ..color = beak
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-8, -9), const Offset(-10, 0), stroke);
    canvas.drawLine(const Offset(8, -9), const Offset(10, 0), stroke);

    final tail = Path()
      ..moveTo(c.dx - r * 0.7, c.dy + 6)
      ..lineTo(c.dx - r * 1.7, c.dy - 6)
      ..lineTo(c.dx - r * 1.5, c.dy + 18)
      ..close();
    canvas.drawPath(tail, Paint()..color = deep);

    canvas.drawCircle(c, r, Paint()..color = blue);
    canvas.drawOval(
      Rect.fromCenter(center: c + const Offset(6, 12), width: 34, height: 26),
      Paint()..color = belly,
    );

    canvas.save();
    canvas.translate(c.dx - 6, c.dy - 2);
    canvas.rotate(wingUp ? -0.9 : 0.25);
    canvas.drawOval(
      const Rect.fromLTWH(-30, -10, 34, 20),
      Paint()..color = deep,
    );
    canvas.restore();

    final eye = c + const Offset(12, -8);
    canvas.drawCircle(eye, 9, Paint()..color = Colors.white);
    canvas.drawCircle(
      eye + const Offset(2, 0),
      4.5,
      Paint()..color = Colors.black,
    );

    final bill = Path()
      ..moveTo(c.dx + r - 4, c.dy - 6)
      ..lineTo(c.dx + r + 26, c.dy + 1)
      ..lineTo(c.dx + r - 4, c.dy + 4)
      ..close();
    canvas.drawPath(bill, Paint()..color = beak);

    final tuft = Paint()
      ..color = deep
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      c + const Offset(-2, -r + 2),
      c + const Offset(-8, -r - 12),
      tuft,
    );
    canvas.drawLine(
      c + const Offset(4, -r + 1),
      c + const Offset(4, -r - 14),
      tuft,
    );
  }

  @override
  bool shouldRepaint(_DashPainter old) => true;
}
