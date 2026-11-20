import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'layouts.dart';
import 'theme.dart';

/// "Flutter was built for humans": a little convertible drives in along a
/// road under the line with a person at the wheel. It stops, the person
/// hops out over the back, and a small robot walks in from the right, hops
/// over the hood into the driver's seat, and grips the wheel. The car revs
/// happily; the person waves. Built for humans to drive; now agents drive.
/// Plays once when the slide appears and settles in about four seconds.
class DriversStatement extends StatefulWidget {
  const DriversStatement(this.text, {super.key});
  final String text;

  @override
  State<DriversStatement> createState() => _DriversStatementState();
}

const _totalMs = 4200;
const _lift = 90.0;

class _DriversStatementState extends State<DriversStatement>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  )..forward();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // The line moves up a little to make room for the road.
      Padding(
        padding: const EdgeInsets.only(bottom: _lift * 2),
        child: Statement(widget.text),
      ),
      LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            Positioned(
              left: box.maxWidth / 2 - _RoadPainter.size.width / 2,
              top: box.maxHeight / 2 + 36,
              child: CustomPaint(
                size: _RoadPainter.size,
                painter: _RoadPainter(_clock),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

double _phase(double ms, double from, double to) =>
    ((ms - from) / (to - from)).clamp(0.0, 1.0);

class _RoadPainter extends CustomPainter {
  _RoadPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  static const _scale = 1.3;
  static const size = Size(1400 * _scale, 300 * _scale);
  static const _g = 280.0; // the road
  static const _cx = 700.0; // where the car parks

  // Timeline (ms).
  static const _driveEnd = 1100.0;
  static const _humanHop = (1350.0, 1850.0);
  static const _robotWalk = (1650.0, 2500.0);
  static const _robotHop = (2550.0, 3000.0);
  static const _rev = (3100.0, 3550.0);
  static const _wave = (3050.0, 4150.0);

  // Where people stand and sit, relative to the car's center.
  static const _seat = Offset(-25, -55); // feet of whoever's driving
  static const _humanSpot = Offset(-265, 0);
  static const _robotSpot = Offset(225, 0);

  static const _carRed = Color(0xFFFF6B5A);
  static const _carDark = Color(0xFFD2483B);
  static const _tire = Color(0xFF1E242E);
  static const _skin = Color(0xFFD99A6C);
  static const _hair = Color(0xFF2E2019);
  static const _shirt = Palette.warn;
  static const _pants = Color(0xFF3A4A6B);
  static const _metal = Color(0xFFB8C2D1);
  static const _metalLight = Color(0xFFDDE3EC);
  static const _visor = Color(0xFF16202C);

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _totalMs;
    canvas.scale(_scale);

    // Road: a line with dashes that end where the car parks.
    canvas.drawLine(
      const Offset(0, _g),
      const Offset(1400, _g),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 2,
    );
    canvas.drawPath(_dashes, _dashPaint);

    // The car drives in and stops with a nod of its springs.
    final drive = Curves.easeOutCubic.transform(_phase(ms, 0, _driveEnd));
    final cx = _cx + (1 - drive) * -1250;
    final travel = cx - (_cx - 1250);
    final s = math.max(0.0, ms - _driveEnd) / 1000;
    var pitch = ms < _driveEnd
        ? 0.0
        : 0.035 * math.exp(-s * 6) * math.sin(s * 18);
    var bounce = ms < _driveEnd ? -1.5 * math.sin(travel / 22).abs() : 0.0;
    // A happy rev once the robot has the wheel.
    final rev = _phase(ms, _rev.$1, _rev.$2);
    if (rev > 0 && rev < 1) {
      bounce -= 5 * math.sin(rev * math.pi * 4).abs() * (1 - rev);
      pitch -= 0.015 * math.sin(rev * math.pi * 4) * (1 - rev);
    }

    // Who's where.
    final humanHop = _phase(ms, _humanHop.$1, _humanHop.$2);
    final robotHop = _phase(ms, _robotHop.$1, _robotHop.$2);
    final car = Offset(cx, _g);

    // Exhaust puffs behind the car as it revs.
    if (rev > 0) _paintPuffs(canvas, car, ms - _rev.$1);

    // Shadow under the car.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, _g + 3), width: 290, height: 12),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );

    canvas.save();
    // The body pivots on its rear wheel.
    final pivot = car + const Offset(-82, -28);
    canvas.translate(pivot.dx, pivot.dy + bounce);
    canvas.rotate(pitch);
    canvas.translate(-pivot.dx, -pivot.dy);

    _paintSeat(canvas, car);
    // Riders are drawn behind the body, so the door hides their legs.
    if (humanHop == 0) {
      _human(canvas, car + _seat, face: 1, arm: 1.25);
    }
    if (robotHop == 1) {
      _robot(canvas, car + _seat, ms, face: 1, arm: 1.25, seated: true);
    }
    _paintBody(canvas, car);
    canvas.restore();

    // Wheels don't pitch; they roll.
    _paintWheel(canvas, car + const Offset(-82, -28), travel);
    _paintWheel(canvas, car + const Offset(86, -28), travel);

    // The human hops out over the back and lands beside the car.
    if (humanHop > 0) {
      final from = car + _seat, to = Offset(_cx, _g) + _humanSpot;
      final e = Curves.easeInOut.transform(humanHop);
      final p =
          Offset.lerp(from, to, e)! +
          Offset(0, -75 * math.sin(math.pi * humanHop));
      final land = math.max(0.0, ms - _humanHop.$2) / 1000;
      final squash = humanHop < 1
          ? 0.0
          : 0.14 * math.exp(-land * 10) * math.cos(land * 22);
      // Waving at the new driver.
      final w = _phase(ms, _wave.$1, _wave.$2);
      final raise = w <= 0
          ? 0.0
          : math.min(1.0, math.min(w / 0.15, (1 - w) / 0.25));
      final arm = humanHop < 1
          ? 2.4 // arms up for the hop
          : 0.25 + raise * (2.35 + 0.4 * math.sin(w * math.pi * 7));
      _human(canvas, p, face: humanHop < 1 ? -1 : 1, arm: arm, squash: squash);
    }

    // The robot walks in from the right, then hops over the hood.
    if (robotHop < 1) {
      final walk = _phase(ms, _robotWalk.$1, _robotWalk.$2);
      if (walk > 0) {
        final spot = Offset(_cx, _g) + _robotSpot;
        final walkIn = Curves.easeOut.transform(walk);
        var p = spot + Offset((1 - walkIn) * 700, 0);
        var arm = 0.25 + 0.25 * math.sin(walk * math.pi * 8) * (1 - walk);
        if (walk < 1) {
          p += Offset(0, -6 * math.sin(walk * math.pi * 8).abs() * (1 - walk));
        }
        if (robotHop > 0) {
          final e = Curves.easeInOut.transform(robotHop);
          p =
              Offset.lerp(spot, car + _seat, e)! +
              Offset(0, -70 * math.sin(math.pi * robotHop));
          arm = 2.4;
        }
        _robot(canvas, p, ms, face: -1, arm: arm);
      }
    }
  }

  static final _dashPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.10)
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  static final Path _dashes = () {
    final p = Path();
    for (var x = 20.0; x < 1400; x += 70) {
      p
        ..moveTo(x, _g + 16)
        ..lineTo(x + 30, _g + 16);
    }
    return p;
  }();

  void _paintPuffs(Canvas canvas, Offset car, double ms) {
    for (var k = 0; k < 3; k++) {
      final p = ((ms - k * 140) / 700).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final e = Curves.easeOut.transform(p);
      canvas.drawCircle(
        car + Offset(-150 - 60 * e, -34 - 18 * e),
        6 + 12 * e,
        Paint()..color = Palette.soft.withValues(alpha: 0.4 * (1 - p)),
      );
    }
  }

  void _paintSeat(Canvas canvas, Offset car) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(car.dx - 70, car.dy - 140, car.dx - 44, car.dy - 90),
        const Radius.circular(11),
      ),
      Paint()..color = const Color(0xFF5B3A2E),
    );
  }

  static final Path _body = () {
    const g = 0.0;
    return Path()
      ..moveTo(-140, g - 34)
      ..lineTo(-140, g - 78)
      ..quadraticBezierTo(-140, g - 96, -118, g - 98)
      ..lineTo(40, g - 98)
      ..quadraticBezierTo(110, g - 94, 132, g - 78)
      ..quadraticBezierTo(146, g - 68, 146, g - 52)
      ..lineTo(146, g - 34)
      ..quadraticBezierTo(146, g - 24, 136, g - 24)
      ..lineTo(-130, g - 24)
      ..quadraticBezierTo(-140, g - 24, -140, g - 34)
      ..close();
  }();

  void _paintBody(Canvas canvas, Offset car) {
    canvas.save();
    canvas.translate(car.dx, car.dy);
    // Windshield and steering wheel, behind the body line.
    canvas.drawPath(
      Path()
        ..moveTo(38, -96)
        ..lineTo(20, -140)
        ..lineTo(30, -140)
        ..lineTo(52, -96)
        ..close(),
      Paint()..color = const Color(0xFF9FDCF5).withValues(alpha: 0.55),
    );
    final wheel = Paint()
      ..color = const Color(0xFF2B2F38)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(10, -96), const Offset(18, -118), wheel);
    canvas.drawLine(const Offset(10, -126), const Offset(24, -110), wheel);
    canvas.drawPath(_body, Paint()..color = _carRed);
    // A darker skirt, a racing stripe, the door seam.
    canvas.save();
    canvas.clipPath(_body);
    canvas.drawRect(
      const Rect.fromLTRB(-150, -40, 150, -20),
      Paint()..color = _carDark,
    );
    canvas.drawRect(
      const Rect.fromLTRB(-150, -78, 150, -70),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    canvas.drawRect(
      const Rect.fromLTRB(-150, -98, 150, -92),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    canvas.restore();
    canvas.drawLine(
      const Offset(-8, -90),
      const Offset(-8, -42),
      Paint()
        ..color = _carDark
        ..strokeWidth = 2.5,
    );
    // Headlight and taillight.
    canvas.drawCircle(
      const Offset(136, -62),
      8,
      Paint()..color = const Color(0xFFFFE89A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-144, -76, 8, 18),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFB0201A),
    );
    canvas.restore();
  }

  void _paintWheel(Canvas canvas, Offset c, double travel) {
    canvas.drawCircle(c, 28, Paint()..color = _tire);
    canvas.drawCircle(c, 14, Paint()..color = const Color(0xFFC9D1DC));
    final spoke = Paint()
      ..color = const Color(0xFF7A8494)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final a0 = travel / 28;
    for (var k = 0; k < 3; k++) {
      final a = a0 + k * 2 * math.pi / 3;
      canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * 12, spoke);
    }
    canvas.drawCircle(c, 4, Paint()..color = const Color(0xFF7A8494));
  }

  /// A person standing on [feet], facing right ([face] 1) or left (-1).
  /// [arm] is the front arm's angle up from hanging straight down.
  void _human(
    Canvas canvas,
    Offset feet, {
    required double face,
    required double arm,
    double squash = 0,
  }) {
    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.scale(face * (1 + squash * 0.6), 1 - squash);
    final limb = Paint()
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    // Legs.
    limb.color = _pants;
    canvas.drawLine(const Offset(-7, -44), const Offset(-9, -4), limb);
    canvas.drawLine(const Offset(7, -44), const Offset(10, -4), limb);
    // Back arm.
    limb
      ..color = Color.lerp(_shirt, Colors.black, 0.2)!
      ..strokeWidth = 9;
    canvas.drawLine(const Offset(-10, -82), const Offset(-18, -54), limb);
    // Torso.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-17, -94, 17, -40),
        const Radius.circular(13),
      ),
      Paint()..color = _shirt,
    );
    // Front arm, from the shoulder.
    const shoulder = Offset(8, -84);
    limb.color = _shirt;
    final hand = shoulder + Offset(math.sin(arm), math.cos(arm)) * 32;
    canvas.drawLine(shoulder, hand, limb);
    canvas.drawCircle(hand, 6, Paint()..color = _skin);
    // Head.
    const head = Offset(2, -114);
    canvas.drawCircle(head, 19, Paint()..color = _skin);
    canvas.drawPath(
      Path()
        ..moveTo(head.dx - 20, head.dy + 2)
        ..arcTo(
          Rect.fromCircle(center: head, radius: 20),
          math.pi,
          math.pi * 0.95,
          false,
        )
        ..quadraticBezierTo(head.dx + 4, head.dy - 8, head.dx - 8, head.dy - 6)
        ..quadraticBezierTo(
          head.dx - 14,
          head.dy - 2,
          head.dx - 13,
          head.dy + 8,
        )
        ..close(),
      Paint()..color = _hair,
    );
    canvas.drawCircle(head + const Offset(9, -1), 2.6, Paint()..color = _hair);
    canvas.drawArc(
      Rect.fromCircle(center: head + const Offset(8, 5), radius: 6),
      0.3,
      1.4,
      false,
      Paint()
        ..color = _hair
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  /// A small robot standing on [feet]; see [_human].
  void _robot(
    Canvas canvas,
    Offset feet,
    double ms, {
    required double face,
    required double arm,
    bool seated = false,
  }) {
    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.scale(face, 1);
    // Legs.
    final dark = Paint()..color = const Color(0xFF6E7A8C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-13, -26, -4, 0),
        const Radius.circular(3),
      ),
      dark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(4, -26, 13, 0),
        const Radius.circular(3),
      ),
      dark,
    );
    // Body with a chest light.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-22, -72, 22, -24),
        const Radius.circular(9),
      ),
      Paint()..color = _metal,
    );
    canvas.drawCircle(const Offset(6, -50), 5, Paint()..color = Palette.accent);
    // Arm.
    const shoulder = Offset(6, -64);
    final hand = shoulder + Offset(math.sin(arm), math.cos(arm)) * 28;
    canvas.drawLine(
      shoulder,
      hand,
      Paint()
        ..color = const Color(0xFF8E99AB)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(hand, 5.5, dark);
    // Antenna, wobbling after it sits down.
    final sat = seated ? math.max(0.0, ms - _robotHop.$2) / 1000 : 0.0;
    final wobble = seated ? 0.5 * math.exp(-sat * 5) * math.sin(sat * 20) : 0.0;
    canvas.save();
    canvas.translate(0, -106);
    canvas.rotate(wobble);
    canvas.drawLine(
      Offset.zero,
      const Offset(0, -14),
      Paint()
        ..color = const Color(0xFF8E99AB)
        ..strokeWidth = 3,
    );
    canvas.drawCircle(const Offset(0, -16), 4.5, Paint()..color = Palette.warn);
    canvas.restore();
    // Head, visor, eyes (they blink once it's driving).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-20, -108, 20, -76),
        const Radius.circular(9),
      ),
      Paint()..color = _metalLight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-13, -101, 17, -83),
        const Radius.circular(6),
      ),
      Paint()..color = _visor,
    );
    final blink = seated ? _phase(ms, 3600, 3750) : 0.0;
    final open = 1 - math.sin(blink * math.pi);
    for (final x in [-3.0, 9.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, -92),
          width: 6.5,
          height: math.max(1.2, 7 * open),
        ),
        Paint()..color = Palette.accent,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.t != t;
}
