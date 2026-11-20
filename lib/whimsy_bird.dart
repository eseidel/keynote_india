import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Thank you slide: a small shorebird, drawn like the one in the logo, flies
/// in from the right along a gentle arc, flapping, and lands on the top of the
/// wordmark's "d", facing the logo's bird. Then it folds its wings and holds.
/// Sits in the Cover's logo Stack (logo coordinates, logo 82 px tall).
class LandingBird extends StatefulWidget {
  const LandingBird({super.key});

  @override
  State<LandingBird> createState() => _LandingBirdState();
}

class _LandingBirdState extends State<LandingBird>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..forward();

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    top: 0,
    child: CustomPaint(painter: _BirdPainter(_flight)),
  );
}

class _BirdPainter extends CustomPainter {
  _BirdPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  // Where the feet land: the top of the wordmark's "d" (logo coordinates).
  static const perch = Offset(358, 11);
  static const start = Offset(1750, -260);
  static const control = Offset(950, -400);
  static const flyEnd = 0.82; // fraction of the run spent flying
  static const scale = 0.5; // the 100-unit bird is 50 px

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    final f = Curves.easeOutCubic.transform((v / flyEnd).clamp(0.0, 1.0));
    // Quadratic Bezier from start to the perch, plus a little bob in flight.
    final u = 1 - f;
    var feet = start * (u * u) + control * (2 * u * f) + perch * (f * f);
    final flying = v < flyEnd;
    if (flying) feet += Offset(0, math.sin(v * 40) * 6 * (1 - f));

    // Wings beat fast in flight, slow on approach, fold once landed.
    final landing = ((v - flyEnd) / (1 - flyEnd)).clamp(0.0, 1.0);
    final flap = flying
        ? math.sin(v * 2 * math.pi * 9) * (0.3 + 0.7 * (1 - f))
        : math.sin(landing * math.pi * 2) * 0.25 * (1 - landing);
    // A small squash on touchdown.
    final squash = flying ? 0.0 : math.sin(landing * math.pi) * 0.12;

    canvas
      ..save()
      ..translate(feet.dx, feet.dy)
      // Faces left, toward the logo's bird.
      ..scale(-scale * (1 + squash * 0.5), scale * (1 - squash))
      ..translate(-58, -82);
    _drawBird(canvas, flap);
    canvas.restore();
  }

  void _drawBird(Canvas canvas, double flap) {
    const light = Color(0xFFF6E7D4);
    const mid = Color(0xFFD9C8B3);
    const wing = Color(0xFFAE9A83);

    // Tail sweeping back to the left, the round body, a crest on top.
    final body = Path()
      ..addOval(Rect.fromCircle(center: const Offset(58, 52), radius: 30))
      ..addPath(
        Path()
          ..moveTo(2, 44)
          ..quadraticBezierTo(20, 40, 38, 36)
          ..lineTo(44, 74)
          ..quadraticBezierTo(18, 64, 2, 44)
          ..close(),
        Offset.zero,
      )
      ..addPath(
        Path()
          ..moveTo(46, 26)
          ..quadraticBezierTo(42, 14, 46, 8)
          ..quadraticBezierTo(60, 12, 66, 24)
          ..close(),
        Offset.zero,
      );
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [mid, light],
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
    );

    // Beak and eye.
    canvas.drawPath(
      Path()
        ..moveTo(86, 36)
        ..lineTo(98, 44)
        ..lineTo(86, 46)
        ..close(),
      Paint()..color = wing,
    );
    canvas.drawCircle(const Offset(72, 40), 4.5, Paint()..color = Colors.black);

    // Wing: hinged at the shoulder, raised in flight, folded at rest.
    canvas
      ..save()
      ..translate(54, 46)
      ..rotate(-flap * 1.1)
      ..translate(-54, -46);
    canvas.drawPath(
      Path()
        ..moveTo(56, 44)
        ..quadraticBezierTo(64, 66, 42, 68)
        ..quadraticBezierTo(24, 68, 22, 60)
        ..quadraticBezierTo(34, 42, 56, 44)
        ..close(),
      Paint()..color = wing,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BirdPainter old) => false;
}
