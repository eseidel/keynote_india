import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Thank you slide: the Shorebird logo's own bird flies in from the right
/// along a gentle arc, bobbing and flapping (a quick vertical squash), and
/// lands on [perch] (the top of the title's last letter, the "u" in
/// "Thank you"). Positioned in the title's coordinates.
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

  static const size = 80.0;
  static const flyEnd = 0.82; // fraction of the run spent flying

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _flight,
    builder: (context, child) {
      final v = _flight.value;
      final perch = widget.perch;
      final start = perch + const Offset(1100, -520);
      final control = perch + const Offset(500, -640);
      final f = Curves.easeOutCubic.transform((v / flyEnd).clamp(0.0, 1.0));
      final u = 1 - f;
      var feet = start * (u * u) + control * (2 * u * f) + perch * (f * f);
      final flying = v < flyEnd;
      if (flying) feet += Offset(0, math.sin(v * 40) * 8 * (1 - f));
      final landing = ((v - flyEnd) / (1 - flyEnd)).clamp(0.0, 1.0);
      // Flapping reads as a fast vertical squash; a little squash on landing.
      final flap = flying
          ? math.sin(v * 2 * math.pi * 9) * 0.18 * (0.4 + 0.6 * (1 - f))
          : -math.sin(landing * math.pi) * 0.14;
      // Tilted into the dive, level once perched.
      final tilt = flying ? -0.35 * (1 - f) : 0.0;
      return Positioned(
        left: feet.dx - size / 2,
        top: feet.dy - size * 0.86,
        width: size,
        height: size,
        child: Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()
            ..rotateZ(tilt)
            // Faces left, the way it flies in.
            ..scaleByDouble(-1.0, 1 + flap, 1.0, 1.0),
          child: child,
        ),
      );
    },
    child: Image.asset('assets/images/logo.png'),
  );
}
