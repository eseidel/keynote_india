import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'layouts.dart';
import 'theme.dart';

/// "But first …": Eric asks the room for a show of hands ("Agents writing
/// your code?"). Under the title, a crowd seen from the back of the hall,
/// drawn by Flutter, sits under two sweeping stage lights. Hands go up across
/// the room, eager ones first, a couple of people half-raise, think again,
/// then commit. The first hand up is an eager one in the third row, right
/// of center. Everyone waves a little, then holds still. Plays once and settles in under four seconds.
class ShowOfHands extends StatefulWidget {
  const ShowOfHands({super.key, required this.title, this.size = 40});
  final String title;
  final double size;

  @override
  State<ShowOfHands> createState() => _ShowOfHandsState();
}

const _totalMs = 3800;
const _total = _totalMs / 1000;

class _ShowOfHandsState extends State<ShowOfHands>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  )..forward();

  late final _Crowd _crowd = _Crowd();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _CrowdPainter(_clock, _crowd)),
        // The title exactly where TitleOver puts it.
        TitleOver(
          title: widget.title,
          size: widget.size,
          child: const SizedBox(),
        ),
      ],
    ),
  );
}

/// One member of the audience, seen from behind.
class _Person {
  _Person({
    required this.x,
    required this.r,
    required this.hy,
    required this.skin,
    required this.shirt,
    required this.hair,
    required this.side,
    required this.up,
    required this.lean,
    required this.phase,
    this.hesitant = false,
  });
  final double x, r, hy; // head center and radius
  final Color skin, shirt, hair;
  final double side; // which arm goes up: -1 left, 1 right
  final double? up; // seconds: when the hand starts up (null: stays down)
  final double lean; // how far out the raised hand leans
  final double phase; // for the wave
  final bool hesitant; // half up, back down, then up for real
}

class _Crowd {
  _Crowd() {
    final rng = math.Random(3);
    // Back row to front: head radius, head height, spacing, haze.
    const layout = [
      (r: 21.0, hy: 520.0, sp: 68.0, haze: 0.55),
      (r: 28.0, hy: 615.0, sp: 90.0, haze: 0.38),
      (r: 37.0, hy: 740.0, sp: 118.0, haze: 0.2),
      (r: 50.0, hy: 905.0, sp: 158.0, haze: 0.0),
    ];
    for (final (k, row) in layout.indexed) {
      final people = <_Person>[];
      final offset = (k.isOdd ? 0.5 : 0.0) * row.sp - 40;
      for (var x = offset; x < 1920 + row.sp; x += row.sp) {
        final jx = x + (rng.nextDouble() - 0.5) * row.sp * 0.3;
        final r = row.r * (0.92 + rng.nextDouble() * 0.16);
        final hy = row.hy + (rng.nextDouble() - 0.5) * row.r * 0.5;
        final raises = rng.nextDouble() < 0.72;
        // Eager hands go up first; most follow within a second and a half.
        final up = 0.55 + math.pow(rng.nextDouble(), 1.6) * 1.5;
        Color haze(Color c) => Color.lerp(c, _hazeColor, row.haze)!;
        people.add(
          _Person(
            x: jx,
            r: r,
            hy: hy,
            skin: haze(_skins[rng.nextInt(_skins.length)]),
            shirt: haze(_shirts[rng.nextInt(_shirts.length)]),
            hair: haze(_hairs[rng.nextInt(_hairs.length)]),
            side: rng.nextBool() ? 1 : -1,
            up: raises ? up : null,
            lean: (rng.nextDouble() - 0.3) * r * 0.9,
            phase: rng.nextDouble() * 2 * math.pi,
          ),
        );
      }
      rows.add(people);
    }
    // The eager one sits in the third row, right of center: first hand up.
    final row = rows[2];
    var best = 0;
    for (var i = 0; i < row.length; i++) {
      if ((row[i].x - _eagerX).abs() < (row[best].x - _eagerX).abs()) best = i;
    }
    final e = row[best];
    eager = row[best] = _Person(
      x: e.x,
      r: e.r,
      hy: e.hy,
      skin: e.skin,
      shirt: e.shirt,
      hair: e.hair,
      side: e.side,
      up: 0.3,
      lean: e.lean,
      phase: e.phase,
    );
    // The row in front keeps its hands out of the eager one's way: raise the
    // arm on the far side, or, if that's still in the way, don't raise.
    final front = rows[3];
    for (var i = 0; i < front.length; i++) {
      final p = front[i];
      if (p.up == null) continue;
      double handX(double side) => p.x + side * (1.65 * p.r + p.lean);
      bool blocks(double side) => (handX(side) - eager.x).abs() < 150;
      if (!blocks(p.side)) continue;
      final away = p.x < eager.x ? -1.0 : 1.0;
      front[i] = _Person(
        x: p.x,
        r: p.r,
        hy: p.hy,
        skin: p.skin,
        shirt: p.shirt,
        hair: p.hair,
        side: away,
        up: blocks(away) ? null : p.up,
        lean: p.lean,
        phase: p.phase,
        hesitant: p.hesitant,
      );
    }
    // Two people in the front rows who aren't sure yet, both clear of the
    // eager one (this runs after the clearance pass, so it can't be undone).
    for (final (k, i) in [(2, 4), (3, 10)]) {
      final p = rows[k][i];
      rows[k][i] = _Person(
        x: p.x,
        r: p.r,
        hy: p.hy,
        skin: p.skin,
        shirt: p.shirt,
        hair: p.hair,
        side: p.side,
        up: 0.8,
        lean: p.lean,
        phase: p.phase,
        hesitant: true,
      );
    }
    assert(
      rows[3][10].x - eager.x > 300,
      'the front-row hesitant hand must stay clear of the eager one',
    );
  }

  static const _eagerX = 1290.0;
  static const _hazeColor = Color(0xFF1E2636);

  final rows = <List<_Person>>[];
  late final _Person eager; // the eager one, first hand up

  static const _skins = [
    Color(0xFFE2B08C),
    Color(0xFFC98E66),
    Color(0xFFAD744F),
    Color(0xFF8E593B),
    Color(0xFFD9A27C),
    Color(0xFF6E442D),
  ];
  static const _shirts = [
    Color(0xFF2D3850),
    Color(0xFF3B3352),
    Color(0xFF233D4E),
    Color(0xFF4A3646),
    Color(0xFF2F4140),
    Color(0xFF4B3D33),
    Color(0xFF34405A),
  ];
  static const _hairs = [
    Color(0xFF0D0E12),
    Color(0xFF17120F),
    Color(0xFF241A15),
    Color(0xFF101318),
    Color(0xFF3A3A40),
  ];
}

double _clamp01(double v) => v.clamp(0.0, 1.0);

/// How far a hand is up (0 down, 1 up, a little past 1 on the overshoot).
double _raise(_Person p, double t) {
  final up = p.up;
  if (up == null) return 0;
  if (!p.hesitant) {
    return Curves.easeOutBack.transform(_clamp01((t - up) / 0.45));
  }
  // Half up ... no, wait ... all the way up.
  final first = Curves.easeOut.transform(_clamp01((t - up) / 0.35)) * 0.45;
  final back = Curves.easeIn.transform(_clamp01((t - up - 0.55) / 0.35));
  final again = Curves.easeOutBack.transform(_clamp01((t - 2.05) / 0.45));
  return first * (1 - back) + again;
}

/// When a hand finished going up, for its wave.
double _upAt(_Person p) => p.hesitant ? 2.5 : p.up! + 0.45;

/// A gentle wave that dies out exactly at the end of the clock.
double _wave(double upAt, double phase, double t, double amp, double hz) {
  final s = t - upAt + 0.3;
  if (s <= 0) return 0;
  final env = math.pow(_clamp01(1 - s / (_total - upAt + 0.3)), 2);
  return amp * math.sin(2 * math.pi * hz * s + phase) * env;
}

class _CrowdPainter extends CustomPainter {
  _CrowdPainter(this.clock, this.crowd) : super(repaint: clock);
  final Animation<double> clock;
  final _Crowd crowd;

  // Reused for every person, every frame. Every use sets the color, and
  // every stroke use also sets the width; set both before drawing.
  final _fill = Paint();
  final _stroke = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  // The rim light keeps the default butt ends.
  final _rim = Paint()..style = PaintingStyle.stroke;

  /// A raised open hand in units of the head radius: wrist at the origin,
  /// fingers up (-y), thumb out to +x.
  static final Path _hand = () {
    final p = Path()
      ..addOval(
        Rect.fromCenter(center: const Offset(0, -0.5), width: 0.9, height: 1.0),
      );
    const fingers = [
      (-0.3, -0.2, 0.62),
      (-0.1, -0.06, 0.78),
      (0.1, 0.06, 0.74),
      (0.28, 0.2, 0.58),
    ];
    for (final (x, a, len) in fingers) {
      final f = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-0.1, -len, 0.2, len + 0.1),
            const Radius.circular(0.1),
          ),
        );
      p.addPath(
        f,
        Offset.zero,
        matrix4: (Matrix4.translationValues(x, -0.85, 0)..rotateZ(a)).storage,
      );
    }
    final thumb = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-0.11, -0.5, 0.22, 0.6),
          const Radius.circular(0.11),
        ),
      );
    p.addPath(
      thumb,
      Offset.zero,
      matrix4: (Matrix4.translationValues(
        0.38,
        -0.35,
        0,
      )..rotateZ(0.9)).storage,
    );
    return p;
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * _total;
    _paintGlow(canvas);
    _paintBeams(canvas, t);
    for (final row in crowd.rows) {
      for (final p in row) {
        _paintPerson(canvas, p, t);
      }
    }
  }

  void _paintGlow(Canvas canvas) {
    // The stage, somewhere beyond the crowd, lights the hall.
    canvas.drawRect(
      Offset.zero & canvasSize,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Palette.statBlue.withValues(alpha: 0.16),
                Palette.statBlue.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: const Offset(960, 560), radius: 820),
            ),
    );
  }

  void _paintBeams(Canvas canvas, double t) {
    // Two stage lights sweep the room, cross, and come to rest dimmed.
    final on = _clamp01(t / 0.5);
    final rest =
        1 - 0.55 * Curves.easeInOut.transform(_clamp01((t - 2.6) / 1.0));
    for (final (origin, color, dir) in [
      (const Offset(260, -80), Palette.accent, 1.0),
      (const Offset(1660, -80), Palette.warn, -1.0),
    ]) {
      final sweep = Curves.easeInOutSine.transform(_clamp01(t / 3.2));
      final angle = dir * (-0.35 + 1.15 * math.sin(sweep * math.pi * 0.85));
      const len = 1350.0, half = 0.075;
      final a = math.pi / 2 - angle;
      Offset at(double ang) =>
          origin + Offset(math.cos(ang), math.sin(ang)) * len;
      final beam = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(at(a - half).dx, at(a - half).dy)
        ..lineTo(at(a + half).dx, at(a + half).dy)
        ..close();
      canvas.drawPath(
        beam,
        Paint()
          ..blendMode = BlendMode.plus
          // Bright at the light, fading down the beam.
          ..shader = ui.Gradient.linear(origin, at(a), [
            color.withValues(alpha: 0.22 * on * rest),
            color.withValues(alpha: 0),
          ]),
      );
    }
  }

  void _paintArm(
    Canvas canvas,
    Offset shoulder,
    double side,
    double r,
    double u,
    double lean,
    double wave,
    Color sleeve,
    Color skin,
  ) {
    if (u <= 0) return;
    // The hand rises from behind the shoulders to well above the head.
    final hidden = shoulder + Offset(side * 0.3 * r, 2.2 * r);
    final raised = shoulder + Offset(side * (0.45 * r + lean), -4.6 * r);
    final hand = Offset.lerp(hidden, raised, u)! + Offset(wave * r * 0.6, 0);
    final elbow =
        Offset.lerp(shoulder, hand, 0.5)! +
        Offset(side * 0.55 * r * math.sin(math.pi * _clamp01(u)), 0);
    final arm = _stroke;
    canvas
      ..drawLine(
        shoulder,
        elbow,
        arm
          ..color = sleeve
          ..strokeWidth = 0.78 * r,
      )
      ..drawLine(
        elbow,
        hand,
        arm
          ..color = skin
          ..strokeWidth = 0.56 * r,
      );
    final d = hand - elbow;
    canvas
      ..save()
      ..translate(hand.dx, hand.dy)
      ..rotate(math.atan2(d.dy, d.dx) + math.pi / 2 + wave)
      ..scale(-side * r, r)
      ..drawPath(_hand, _fill..color = skin)
      ..restore();
  }

  void _paintPerson(Canvas canvas, _Person p, double t) {
    final r = p.r;
    final u = _raise(p, t);
    // The arm first, so the body hides where it comes from.
    _paintArm(
      canvas,
      Offset(p.x + p.side * 1.2 * r, p.hy + 1.5 * r),
      p.side,
      r,
      u,
      p.lean,
      p.up == null ? 0 : _wave(_upAt(p), p.phase, t, 0.22, 1.4),
      p.shirt,
      p.skin,
    );
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        p.x - 1.8 * r,
        p.hy + 0.75 * r,
        p.x + 1.8 * r,
        p.hy + 8 * r,
        topLeft: Radius.circular(1.2 * r),
        topRight: Radius.circular(1.2 * r),
      ),
      _fill..color = p.shirt,
    );
    final head = Rect.fromCenter(
      center: Offset(p.x, p.hy),
      width: 1.8 * r,
      height: 2.1 * r,
    );
    canvas
      ..drawOval(head, _fill..color = p.hair)
      // Rim light from the stage, along the top of the head.
      ..drawArc(
        head.deflate(0.04 * r),
        math.pi * 1.15,
        math.pi * 0.7,
        false,
        _rim
          ..strokeWidth = 0.09 * r
          ..color = Palette.soft.withValues(alpha: 0.22),
      );
  }

  @override
  bool shouldRepaint(_CrowdPainter old) => old.crowd != crowd;
}
