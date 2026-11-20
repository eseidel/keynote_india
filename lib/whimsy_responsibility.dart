import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'layouts.dart' show verdictWord;
import 'theme.dart';

/// Slide 11's "BAD AT / Responsibility": a little robot rolls in, grabs the
/// end of the word and tries to pick it up. It lifts a sliver, strains, and
/// drops it with a thud. It tries again, harder (antenna glowing, a bead of
/// sweat), drops it again, then backs away and shrugs. Someone else has to
/// own this one. At rest the word is the plain verdict word, with the robot
/// beside it, still shrugging.
class HeavyWord extends StatefulWidget {
  const HeavyWord(this.word, {super.key});
  final String word;

  @override
  State<HeavyWord> createState() => _HeavyWordState();
}

const _total = 4.2; // seconds

class _HeavyWordState extends State<HeavyWord>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..forward();
  double _baseline = 0;
  double _descent = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tp = TextPainter(
      text: TextSpan(
        text: widget.word,
        style: DefaultTextStyle.of(context).style.merge(verdictWord),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    _descent = tp.height - _baseline;
    tp.dispose();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final word = Text(widget.word, style: verdictWord);
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final t = _clock.value * _total;
        final angle = _wordAngle(t);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (angle == 0)
              word
            else
              Transform.rotate(
                angle: angle,
                // Pivots on the first letter's foot, on the baseline.
                alignment: Alignment.bottomLeft,
                origin: Offset(0, -_descent),
                child: word,
              ),
            Positioned.fill(
              child: CustomPaint(painter: _RobotPainter(t, _baseline, angle)),
            ),
          ],
        );
      },
    );
  }
}

double _clamp01(double x) => x.clamp(0.0, 1.0);
double _seg(double t, double a, double b) => _clamp01((t - a) / (b - a));

// Two tries: when each lift starts, peaks and drops, and how far it gets.
const _tries = [
  (lift: 1.15, peak: 1.75, drop: 1.85, angle: 0.012, shake: 0.0012),
  (lift: 2.2, peak: 2.95, drop: 3.05, angle: 0.022, shake: 0.0022),
];

/// How far the word's right end is lifted (negative: counterclockwise).
double _wordAngle(double t) {
  // Only the latest try that has started counts, so a lift takes over from
  // the previous drop's bounce without a frame of it lying flat.
  for (final k in _tries.reversed) {
    if (t < k.lift) continue;
    if (t < k.drop) {
      // Up slowly, trembling more as it strains.
      final up = Curves.easeOut.transform(_seg(t, k.lift, k.peak));
      final tremble = math.sin(t * 70) * k.shake * up;
      return -(k.angle * up + tremble);
    }
    // Let go: it falls (quadratic), then bounces once on the floor.
    final f = t - k.drop;
    final fallTime = 0.09;
    if (f < fallTime) {
      final p = f / fallTime;
      return -k.angle * (1 - p * p);
    }
    final b = f - fallTime;
    if (b < 0.35) {
      return -k.angle * 0.12 * math.sin(b / 0.35 * math.pi) * (1 - b / 0.35);
    }
    return 0;
  }
  return 0;
}

class _RobotPainter extends CustomPainter {
  _RobotPainter(this.t, this.baseline, this.angle);
  final double t;
  final double baseline;
  final double angle;

  static const _metal = Color(0xFFC3CCDA);
  static const _metalDark = Color(0xFF8C9EB8);
  static const _ink = Color(0xFF2A3342);
  static const _screen = Color(0xFF111821);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    // Where the hands grip: the top of the last letter's stem-ish, so the
    // grip point rides up with the word as it tilts.
    final gripLocal = Offset(w - 18, baseline - 60);
    final pivot = Offset(0, baseline);
    final grip = _rotate(gripLocal, pivot, angle);

    // --- Choreography -----------------------------------------------------
    // Rolls in from off the slide (0.2-1.0s), grips (to 1.1s), two tries,
    // backs off (3.25-3.75s), shrugs (3.6-4.0s).
    const gripX = 96.0, restX = 300.0;
    final enter = Curves.easeOutCubic.transform(_seg(t, 0.2, 1.0));
    final back = Curves.easeInOutCubic.transform(_seg(t, 3.2, 3.7));
    var x = 900 - (900 - gripX) * enter + (restX - gripX) * back;
    var strain = 0.0, crouch = 0.0, recoil = 0.0;
    for (final (i, k) in _tries.indexed) {
      // Crouch just before each lift, straighten as it heaves.
      final pre = _seg(t, k.lift - 0.25, k.lift);
      final up = _seg(t, k.lift, k.peak);
      // After the drop both ease back to nothing over 0.2s, rather than
      // snapping the upper body upright in one frame.
      final relax = 1 - Curves.easeOut.transform(_seg(t, k.drop, k.drop + 0.2));
      if (t >= k.lift - 0.25) {
        crouch = math.max(crouch, pre * (1 - up * 0.6) * relax);
        strain = math.max(strain, (i + 1) / _tries.length * up * relax);
      }
      // Jolt backwards when it lets go.
      final r = t - k.drop;
      if (r >= 0 && r < 0.4) {
        recoil = math.max(recoil, math.sin(r / 0.4 * math.pi) * (1 - r / 0.4));
      }
    }
    x += recoil * 26;
    final reach = _seg(t, 0.95, 1.1) * (1 - _seg(t, 3.05, 3.25));
    final relaxBetween =
        _seg(t, _tries[0].drop, _tries[0].drop + 0.1) *
        (1 - _seg(t, _tries[1].lift - 0.3, _tries[1].lift - 0.15));
    final grabbing = reach * (1 - relaxBetween * 0.85);
    final shrug = Curves.easeOutBack.transform(_seg(t, 3.6, 4.0));
    // Snaps to amber (a slow blend passes through a muddy grey-green).
    final glow =
        _seg(t, _tries[1].lift, _tries[1].lift + 0.12) *
        (1 - _seg(t, _tries[1].drop + 0.3, _tries[1].drop + 0.45));
    final sweat = _seg(t, _tries[1].lift + 0.3, _tries[1].peak);
    final sweatFall = _seg(t, _tries[1].drop, _tries[1].drop + 0.6);

    final ground = baseline;
    final base = Offset(w + x, ground);
    final shake = strain * math.sin(t * 90) * 1.6;

    // --- Dust from each thud ----------------------------------------------
    for (final (i, k) in _tries.indexed) {
      final d = (t - k.drop - 0.09) / 0.6;
      if (d <= 0 || d >= 1) continue;
      final rng = math.Random(11 + i);
      final paint = Paint();
      final e = Curves.easeOutCubic.transform(d);
      for (var p = 0; p < 9; p++) {
        // Most puff out to the right, past the word; a few go under it.
        final dir = p % 3 == 0 ? -0.4 : 1.0;
        final speed = (30 + rng.nextDouble() * 60) * (0.8 + 0.5 * i);
        final c = Offset(
          w - 10 + dir * (10 + speed * e) + rng.nextDouble() * 20,
          ground + 30 - (6 + rng.nextDouble() * 30) * e,
        );
        paint.color = _metalDark.withValues(alpha: 0.35 * (1 - d) * (1 - d));
        canvas.drawCircle(c, (6 + rng.nextDouble() * 8) * (0.5 + e), paint);
      }
    }

    // --- The robot ---------------------------------------------------------
    canvas.save();
    canvas.translate(base.dx + shake, base.dy);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint();

    // Treads.
    final tread = RRect.fromLTRBR(-58, -40, 58, 0, const Radius.circular(20));
    canvas.drawRRect(tread, fill..color = _ink);
    final roll = -x / 18; // wheels turn as it moves
    for (final cx in [-36.0, 0.0, 36.0]) {
      final c = Offset(cx, -20);
      canvas.drawCircle(c, 13, fill..color = _metalDark);
      canvas.drawCircle(c, 4, fill..color = _ink);
      final spoke = Offset(math.cos(roll), math.sin(roll)) * 10;
      canvas.drawLine(
        c - spoke,
        c + spoke,
        stroke
          ..color = _ink
          ..strokeWidth = 3,
      );
    }

    // Everything above the treads squats when it crouches.
    final squat = crouch * 14;
    final lean = -0.10 * strain - 0.05 * crouch + 0.04 * recoil;
    canvas.save();
    canvas.translate(0, -40 + squat * 0.4);
    canvas.rotate(lean);

    // Arms: shoulder to hand, a little elbow bend, a two-finger claw.
    void arm(int side) {
      final shoulder = Offset(side == 0 ? -40 : 40, -70 + squat);
      // Hanging at rest; up and out in the shrug; at the grip when lifting.
      final hang = shoulder + Offset(side == 0 ? -14 : 14, 52);
      final up = shoulder + Offset(side == 0 ? -46 : 46, -40);
      var hand = Offset.lerp(hang, up, shrug)!;
      if (grabbing > 0) {
        // The grip point, in the robot's rotated frame.
        final g =
            _toLocal(grip, base, shake, squat, lean) +
            Offset(side == 0 ? 0 : 14, side == 0 ? 0 : 8);
        hand = Offset.lerp(hand, g, Curves.easeOut.transform(grabbing))!;
      }
      final mid =
          Offset.lerp(shoulder, hand, 0.5)! + Offset(0, 16 + 10 * shrug);
      final arm = Path()
        ..moveTo(shoulder.dx, shoulder.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, hand.dx, hand.dy);
      canvas.drawPath(
        arm,
        stroke
          ..color = side == 0 ? _metalDark : _metal
          ..strokeWidth = 11,
      );
      // Claw: opens up in the shrug like upturned palms.
      final dir = (hand - shoulder).direction;
      final open = 0.5 + 0.5 * shrug - 0.25 * grabbing;
      for (final f in [-1.0, 1.0]) {
        final a = dir + f * open;
        canvas.drawLine(
          hand,
          hand + Offset(math.cos(a), math.sin(a)) * 16,
          stroke
            ..color = side == 0 ? _metalDark : _metal
            ..strokeWidth = 6,
        );
      }
      canvas.drawCircle(hand, 7, fill..color = side == 0 ? _metalDark : _metal);
    }

    arm(0); // the far arm, behind the body

    // Body.
    final body = RRect.fromLTRBR(
      -42,
      -92 + squat,
      42,
      0,
      const Radius.circular(16),
    );
    canvas.drawRRect(body, fill..color = _metal);
    canvas.drawRRect(
      RRect.fromLTRBR(-24, -66 + squat, 24, -24, const Radius.circular(8)),
      fill..color = _screen,
    );
    // A little status light on the chest: blue, amber with the antenna on
    // the big try.
    final lamp = Color.lerp(Palette.accent, Palette.warn, glow)!;
    canvas.drawCircle(Offset(-10, -45 + squat / 2), 6, fill..color = lamp);
    canvas.drawCircle(
      Offset(10, -45 + squat / 2),
      6,
      fill..color = _metalDark.withValues(alpha: 0.6),
    );

    // Head, tilted when it shrugs.
    final neckTop = -104 + squat;
    canvas.drawRect(
      Rect.fromLTRB(-9, neckTop, 9, -88 + squat),
      fill..color = _metalDark,
    );
    canvas.save();
    canvas.translate(0, neckTop);
    canvas.rotate(0.16 * shrug);
    final head = RRect.fromLTRBR(-54, -84, 54, 0, const Radius.circular(22));
    canvas.drawRRect(head, fill..color = _metal);
    final face = RRect.fromLTRBR(-42, -70, 42, -14, const Radius.circular(14));
    canvas.drawRRect(face, fill..color = _screen);
    // Antenna, its bulb glowing amber on the big try.
    canvas.drawLine(
      const Offset(0, -84),
      const Offset(6, -112),
      stroke
        ..color = _metalDark
        ..strokeWidth = 5,
    );
    final bulb = Color.lerp(Palette.accent, Palette.warn, glow)!;
    if (glow > 0) {
      canvas.drawCircle(
        const Offset(6, -116),
        18 * glow,
        fill..color = Palette.warn.withValues(alpha: 0.25 * glow),
      );
    }
    canvas.drawCircle(const Offset(6, -116), 9, fill..color = bulb);
    _eyes(canvas, strain, shrug);
    // Sweat: beads up on the second try, then drips off.
    if (sweat > 0 && sweatFall < 1) {
      final at = Offset(48, -70 + 40 * sweatFall * sweatFall);
      final r = 7 * sweat;
      final drop = Path()
        ..moveTo(at.dx, at.dy - r * 1.9)
        ..quadraticBezierTo(at.dx + r, at.dy - r * 0.2, at.dx, at.dy + r)
        ..quadraticBezierTo(at.dx - r, at.dy - r * 0.2, at.dx, at.dy - r * 1.9);
      canvas.drawPath(
        drop,
        fill..color = Palette.statBlue.withValues(alpha: 1 - sweatFall),
      );
    }
    canvas.restore();

    arm(1); // the near arm, in front
    canvas.restore();
    canvas.restore();
  }

  /// Screen [p] into the robot's upper-body frame (after the translate,
  /// the crouch offset and the lean).
  Offset _toLocal(
    Offset p,
    Offset base,
    double shake,
    double squat,
    double lean,
  ) {
    var q = p - base - Offset(shake, 0);
    q -= Offset(0, -40 + squat * 0.4);
    final c = math.cos(-lean), s = math.sin(-lean);
    return Offset(q.dx * c - q.dy * s, q.dx * s + q.dy * c);
  }

  static Offset _rotate(Offset p, Offset pivot, double a) {
    final d = p - pivot;
    final c = math.cos(a), s = math.sin(a);
    return pivot + Offset(d.dx * c - d.dy * s, d.dx * s + d.dy * c);
  }

  void _eyes(Canvas canvas, double strain, double shrug) {
    final eye = Paint()..color = Palette.accent;
    final line = Paint()
      ..color = Palette.accent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;
    const l = Offset(-20, -44), r = Offset(14, -44);
    if (strain > 0.15) {
      // Squeezed shut: > <
      for (final (c, f) in [(l, 1.0), (r, -1.0)]) {
        final p = Path()
          ..moveTo(c.dx - 8 * f, c.dy - 8)
          ..lineTo(c.dx + 6 * f, c.dy)
          ..lineTo(c.dx - 8 * f, c.dy + 8);
        canvas.drawPath(p, line);
      }
      return;
    }
    if (shrug > 0.05) {
      // Shrug: one brow up, eyes looking off, a flat little mouth.
      canvas.drawOval(
        Rect.fromCenter(center: l + const Offset(4, 2), width: 14, height: 18),
        eye,
      );
      canvas.drawOval(
        Rect.fromCenter(center: r + const Offset(4, 2), width: 14, height: 18),
        eye,
      );
      canvas.drawLine(
        l + const Offset(-6, -18),
        l + const Offset(10, -20),
        line..strokeWidth = 4,
      );
      canvas.drawLine(
        r + const Offset(-4, -22),
        r + const Offset(12, -16),
        line,
      );
      canvas.drawLine(const Offset(-10, -24), const Offset(10, -26), line);
      return;
    }
    // Normal: looking left at the word.
    canvas.drawOval(Rect.fromCenter(center: l, width: 16, height: 22), eye);
    canvas.drawOval(Rect.fromCenter(center: r, width: 16, height: 22), eye);
  }

  @override
  bool shouldRepaint(_RobotPainter old) =>
      old.t != t || old.baseline != baseline || old.angle != angle;
}
