import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Thank you slide: a small shorebird, drawn to match the logo's (teardrop
/// body, tuft, swept tail, big rounded wing, eye and tiny beak, the logo's
/// colors), flies in from the right along a gentle arc, flapping, and lands
/// on [perch] (the top of the "u" in "Thank you"). Then it folds its wings
/// and holds. Positioned in the title's coordinates.
class LandingBird extends StatefulWidget {
  const LandingBird({super.key, required this.perch});
  final Offset perch;

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
    child: CustomPaint(painter: _BirdPainter(_flight, widget.perch)),
  );
}

class _BirdPainter extends CustomPainter {
  _BirdPainter(this.t, this.perch) : super(repaint: t);
  final Animation<double> t;
  final Offset perch;

  static const flyEnd = 0.82; // fraction of the run spent flying
  static const scale = 0.8; // the 100-unit bird is 80 px
  static const feet = Offset(52, 88); // bottom of the body, bird units

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    final start = perch + const Offset(1100, -520);
    final control = perch + const Offset(500, -640);
    final f = Curves.easeOutCubic.transform((v / flyEnd).clamp(0.0, 1.0));
    final u = 1 - f;
    var at = start * (u * u) + control * (2 * u * f) + perch * (f * f);
    final flying = v < flyEnd;
    if (flying) at += Offset(0, math.sin(v * 40) * 8 * (1 - f));

    // Wings beat fast in flight, slow on approach, fold once landed.
    final landing = ((v - flyEnd) / (1 - flyEnd)).clamp(0.0, 1.0);
    final flap = flying
        ? math.sin(v * 2 * math.pi * 9) * (0.3 + 0.7 * (1 - f))
        : math.sin(landing * math.pi * 2) * 0.25 * (1 - landing);
    final squash = flying ? 0.0 : math.sin(landing * math.pi) * 0.12;

    canvas
      ..save()
      ..translate(at.dx, at.dy)
      // Faces left, the way it flies in.
      ..scale(-scale * (1 + squash * 0.5), scale * (1 - squash))
      ..translate(-feet.dx, -feet.dy);
    _drawBird(canvas, flap);
    canvas.restore();
  }

  // Outlines traced from assets/images/logo.png, in 100-unit bird space.
  static const _body = <Offset>[
    Offset(54.3, 8.2),
    Offset(52.1, 8.9),
    Offset(50.9, 10.7),
    Offset(51.1, 12.7),
    Offset(53.5, 16.3),
    Offset(49.5, 18.1),
    Offset(45.9, 21.7),
    Offset(42.7, 27.8),
    Offset(40.0, 36.4),
    Offset(37.6, 38.4),
    Offset(36.2, 40.6),
    Offset(32.6, 44.3),
    Offset(30.8, 45.7),
    Offset(28.0, 47.1),
    Offset(24.9, 47.7),
    Offset(19.1, 47.7),
    Offset(16.1, 48.7),
    Offset(14.1, 50.5),
    Offset(13.3, 51.9),
    Offset(13.1, 54.1),
    Offset(13.7, 55.3),
    Offset(13.5, 55.9),
    Offset(10.9, 55.7),
    Offset(8.2, 54.9),
    Offset(4.0, 52.1),
    Offset(2.0, 52.1),
    Offset(1.2, 52.5),
    Offset(0.0, 54.3),
    Offset(0.0, 55.7),
    Offset(0.8, 57.1),
    Offset(10.3, 67.0),
    Offset(15.3, 71.4),
    Offset(23.3, 77.5),
    Offset(30.4, 81.7),
    Offset(37.4, 84.9),
    Offset(44.1, 86.9),
    Offset(49.1, 87.7),
    Offset(56.3, 87.7),
    Offset(63.2, 86.3),
    Offset(69.2, 83.7),
    Offset(74.6, 80.1),
    Offset(81.1, 73.8),
    Offset(82.9, 71.6),
    Offset(85.9, 66.8),
    Offset(88.5, 61.6),
    Offset(90.5, 56.1),
    Offset(91.8, 50.7),
    Offset(92.0, 46.1),
    Offset(92.6, 45.7),
    Offset(99.0, 46.5),
    Offset(91.1, 38.6),
    Offset(89.3, 33.2),
    Offset(86.5, 28.4),
    Offset(84.3, 25.6),
    Offset(78.9, 20.3),
    Offset(72.8, 16.1),
    Offset(65.6, 12.3),
    Offset(60.2, 10.1),
  ];
  static const _wing = <Offset>[
    Offset(58.6, 43.1),
    Offset(56.3, 38.8),
    Offset(52.7, 35.8),
    Offset(48.5, 34.4),
    Offset(44.1, 34.6),
    Offset(41.2, 35.6),
    Offset(38.8, 37.2),
    Offset(36.8, 39.4),
    Offset(36.2, 40.6),
    Offset(32.6, 44.3),
    Offset(29.8, 46.3),
    Offset(26.4, 47.5),
    Offset(19.1, 47.7),
    Offset(16.1, 48.7),
    Offset(13.7, 51.1),
    Offset(13.1, 52.5),
    Offset(13.1, 54.1),
    Offset(13.9, 55.9),
    Offset(15.9, 58.1),
    Offset(19.1, 60.4),
    Offset(23.3, 62.4),
    Offset(28.4, 64.0),
    Offset(32.6, 64.8),
    Offset(37.6, 65.0),
    Offset(40.6, 64.6),
    Offset(44.3, 63.6),
    Offset(48.7, 61.6),
    Offset(52.3, 59.2),
    Offset(55.3, 56.3),
    Offset(57.7, 52.9),
    Offset(59.2, 49.1),
    Offset(59.2, 45.7),
  ];
  static const _beak = <Offset>[
    Offset(91.5, 39.0),
    Offset(92.2, 42.1),
    Offset(92.4, 45.7),
    Offset(99.0, 46.5),
  ];

  /// A smooth closed path through [pts] (midpoint quadratic curves).
  static Path _smooth(List<Offset> pts) {
    final path = Path();
    Offset mid(int i) => (pts[i % pts.length] + pts[(i + 1) % pts.length]) / 2;
    path.moveTo(mid(0).dx, mid(0).dy);
    for (var i = 1; i <= pts.length; i++) {
      final p = pts[i % pts.length];
      final m = mid(i);
      path.quadraticBezierTo(p.dx, p.dy, m.dx, m.dy);
    }
    return path..close();
  }

  void _drawBird(Canvas canvas, double flap) {
    // The logo's colors.
    const top = Color(0xFFD8C8B4);
    const bottom = Color(0xFFFBEBD8);
    const wing = Color(0xFFB29E88);

    canvas.drawPath(
      _smooth(_body),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
    );
    canvas.drawPath(Path()..addPolygon(_beak, true), Paint()..color = wing);
    canvas.drawCircle(
      const Offset(74.4, 37.8),
      4.5,
      Paint()..color = Colors.black,
    );

    // The big rounded wing: hinged at the shoulder, raised in flight.
    canvas
      ..save()
      ..translate(52, 40)
      ..rotate(-flap * 1.1)
      ..translate(-52, -40);
    canvas.drawPath(_smooth(_wing), Paint()..color = wing);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BirdPainter old) => old.perch != perch;
}
