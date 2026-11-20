import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Thank you slide: the bird in the Shorebird logo above the title (drawn
/// from the brand logo SVG, standing in for the logo's own bird) sits a
/// beat, crouches, takes off, flaps up and over in an arc, and lands on
/// [perch] (the right stem of the "u" in "Thank you"), growing a little
/// as it comes forward. Then it folds its wings and holds. Positioned in
/// the title's coordinates; [logo] is the logo image's top left there.
class LandingBird extends StatefulWidget {
  const LandingBird({super.key, required this.perch, required this.logo});
  final Offset perch;
  final Offset logo;

  /// Where the logo's own bird stands, for a logo [logoHeight] tall: its
  /// feet, from the logo's top left, and its scale in SVG units.
  static const logoHeight = 82.0;
  static const logoFeet = Offset(40, 70);
  static const logoScale = 0.375;

  /// The logo image's left part, holding its bird, as a fraction of its
  /// width: hidden, so this bird takes its place.
  static const logoBirdWidth = 0.215;

  @override
  State<LandingBird> createState() => _LandingBirdState();
}

class _LandingBirdState extends State<LandingBird>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
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
    child: CustomPaint(
      painter: _BirdPainter(
        _flight,
        widget.perch,
        widget.logo + LandingBird.logoFeet,
      ),
    ),
  );
}

class _BirdPainter extends CustomPainter {
  _BirdPainter(this.t, this.perch, this.from) : super(repaint: t);
  final Animation<double> t;
  final Offset perch;
  final Offset from; // the feet, standing in the logo

  // Fractions of the run: sit in the logo, crouch, fly, land.
  static const sitEnd = 0.22, crouchEnd = 0.3, flyEnd = 0.84;
  static const scale = 0.4; // perched, the 218-unit-wide SVG bird is ~87 px
  static const feet = Offset(162, 237.5); // bottom of the body, SVG units

  static double _ramp(double v, double a, double b) =>
      ((v - a) / (b - a)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    final f = Curves.easeInOutCubic.transform(_ramp(v, crouchEnd, flyEnd));
    // Up and over: the control point sits well above both ends.
    final control = Offset(
      (from.dx + perch.dx) / 2,
      math.min(from.dy, perch.dy) - 320,
    );
    final u = 1 - f;
    var at = from * (u * u) + control * (2 * u * f) + perch * (f * f);
    final flying = v >= crouchEnd && v < flyEnd;
    // A little bob with each wingbeat.
    if (flying) at += Offset(0, math.sin(v * 2 * math.pi * 9) * 6);

    final crouch = math.sin(_ramp(v, sitEnd, crouchEnd) * math.pi);
    final landing = _ramp(v, flyEnd, 1);
    final flap = flying
        ? math.sin(v * 2 * math.pi * 9) * (0.5 + 0.5 * math.sin(f * math.pi))
        : v >= flyEnd
        ? math.sin(landing * math.pi * 2) * 0.25 * (1 - landing)
        : crouch * -0.15;
    final squash = v >= flyEnd
        ? math.sin(landing * math.pi) * 0.12
        : crouch * 0.14;
    final s = LandingBird.logoScale + (scale - LandingBird.logoScale) * f;

    canvas
      ..save()
      ..translate(at.dx, at.dy)
      // Faces right, as in the logo and the way it flies.
      ..scale(s * (1 + squash * 0.5), s * (1 - squash))
      ..translate(-feet.dx, -feet.dy);
    _drawBird(canvas, flap);
    canvas.restore();
  }

  // The bird from brand/logo/logo_transparent.svg (shorebirdtech/_shorebird),
  // in the SVG's 300-unit coordinates.
  static final Path _beak = Path()
    ..moveTo(259.51, 146.47)
    ..lineTo(239.193, 126.154)
    ..cubicTo(240.354, 130.239, 243.155, 142.811, 243.316, 144.823)
    ..lineTo(259.51, 146.47)
    ..close();

  static final Path _body = Path()
    ..moveTo(224.224, 201.419)
    ..lineTo(224.393, 201.202)
    ..lineTo(224.543, 200.972)
    ..cubicTo(240.488, 176.635, 245.827, 155.5, 243.78, 137.283)
    ..cubicTo(241.733, 119.058, 232.411, 104.803, 221.079, 94.0045)
    ..cubicTo(198.71, 72.6905, 167.264, 63.6535, 162.017, 62.2435)
    ..cubicTo(160.56, 61.8515, 158.832, 61.8915, 157.182, 62.6685)
    ..cubicTo(155.581, 63.4225, 154.507, 64.6555, 153.892, 65.8825)
    ..cubicTo(152.706, 68.2475, 152.974, 70.9485, 154.293, 72.9865)
    ..lineTo(158.956, 80.1885)
    ..cubicTo(157.63, 80.4185, 156.278, 80.7865, 154.905, 81.3145)
    ..cubicTo(144.752, 85.2195, 136.621, 96.8145, 131.069, 117.636)
    ..cubicTo(124.781, 141.216, 112.454, 153.224, 100.574, 159.536)
    ..cubicTo(88.4342, 165.985, 76.1662, 166.786, 69.8902, 166.786)
    ..cubicTo(64.5502, 166.786, 60.1452, 165.118, 57.0232, 163.396)
    ..cubicTo(55.4692, 162.539, 54.2742, 161.689, 53.4942, 161.08)
    ..cubicTo(53.1062, 160.776, 52.8262, 160.537, 52.6622, 160.391)
    ..cubicTo(52.5802, 160.318, 52.5272, 160.27, 52.5052, 160.249)
    ..lineTo(52.4972, 160.241)
    ..cubicTo(49.9382, 157.748, 45.8782, 157.672, 43.2262, 160.074)
    ..cubicTo(40.5622, 162.486, 40.2472, 166.559, 42.5082, 169.353)
    ..cubicTo(42.5082, 169.353, 42.5092, 169.355, 42.5122, 169.358)
    ..lineTo(42.5182, 169.366)
    ..lineTo(42.5382, 169.39)
    ..lineTo(42.6042, 169.471)
    ..cubicTo(42.6612, 169.541, 42.7422, 169.639, 42.8462, 169.765)
    ..cubicTo(43.0542, 170.016, 43.3572, 170.379, 43.7512, 170.842)
    ..cubicTo(44.5382, 171.769, 45.6872, 173.099, 47.1682, 174.749)
    ..cubicTo(50.1292, 178.047, 54.4222, 182.634, 59.7962, 187.84)
    ..cubicTo(70.5072, 198.216, 85.6812, 211.218, 103.286, 221.333)
    ..cubicTo(120.835, 231.416, 141.363, 238.953, 162.587, 237.562)
    ..cubicTo(184.133, 236.15, 205.416, 225.6, 224.224, 201.419)
    ..close();

  static final Path _wing = Path()
    ..moveTo(120.559, 133.558)
    ..cubicTo(125.146, 125.111, 134.094, 119.375, 144.383, 119.375)
    ..cubicTo(158.003, 119.375, 169.275, 129.427, 171.186, 142.517)
    ..cubicTo(177.312, 162.925, 148.312, 187.411, 121.017, 187.411)
    ..cubicTo(96.9782, 187.411, 57.3492, 169.46, 73.6122, 153.55)
    ..cubicTo(78.6252, 148.645, 84.2222, 148.671, 90.2202, 148.698)
    ..cubicTo(94.6482, 148.718, 99.2942, 148.739, 104.087, 146.778)
    ..cubicTo(109.922, 144.39, 113.77, 140.444, 117.468, 136.652)
    ..cubicTo(118.497, 135.596, 119.514, 134.553, 120.559, 133.558)
    ..close();

  static final Path _eye = Path()
    ..moveTo(205.06, 137.359)
    ..cubicTo(199.45, 137.359, 194.902, 132.811, 194.902, 127.2)
    ..cubicTo(194.902, 121.59, 199.45, 117.042, 205.06, 117.042)
    ..cubicTo(210.671, 117.042, 215.219, 121.59, 215.219, 127.2)
    ..cubicTo(215.219, 132.811, 210.671, 137.359, 205.06, 137.359)
    ..close();

  void _drawBird(Canvas canvas, double flap) {
    canvas.drawPath(_beak, Paint()..color = const Color(0xFFA79772));
    canvas.drawPath(
      _body,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(123.895, 133.32),
          const Offset(215.924, 213.988),
          const [Color(0xFFD1C2B0), Color(0xFFFBEDDD)],
        ),
    );
    // The wing, hinged at the shoulder, raised in flight.
    canvas
      ..save()
      ..translate(165, 125)
      ..rotate(-flap * 0.9)
      ..translate(-165, -125)
      ..drawPath(_wing, Paint()..color = const Color(0xFFA78F72))
      ..restore();
    canvas.drawPath(_eye, Paint()..color = const Color(0xFF161619));
  }

  @override
  bool shouldRepaint(_BirdPainter old) =>
      old.perch != perch || old.from != from;
}
