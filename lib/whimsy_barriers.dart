import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// "The barriers between stacks are gone": four little stacks, each walled
/// in behind a brick wall labelled with the language you used to need to get
/// in (Swift, Kotlin, JS, Dart), only their eyes peeking over. When the slide
/// appears the walls crack, then crumble: the bricks (label and all) tumble
/// down with a bit of physics, bounce and fade. The four separate plots of
/// ground join into one open field and the stacks hop over to stand
/// together on it. Drawn by Flutter, no image. Laid out like SplitImage,
/// with the scene where the picture was.
class BarriersSlide extends StatelessWidget {
  const BarriersSlide({super.key, required this.text, this.size = 50});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(200, 40, 40, 40),
    child: Row(
      children: [
        Expanded(
          flex: 5,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(text, style: headline(size)),
          ),
        ),
        const SizedBox(width: 60),
        const Expanded(
          flex: 5,
          child: Padding(
            padding: EdgeInsets.fromLTRB(0, 120, 40, 120),
            child: Barriers(),
          ),
        ),
      ],
    ),
  );
}

class Barriers extends StatefulWidget {
  const Barriers({super.key});

  @override
  State<Barriers> createState() => _BarriersState();
}

class _BarriersState extends State<Barriers>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _BarriersPainter.totalMs),
  )..forward();
  final _cache = _BarriersCache();

  @override
  void dispose() {
    _clock.dispose();
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _BarriersPainter(_clock, _cache),
      size: Size.infinite,
    ),
  );
}

/// What the painter keeps between frames: the wall labels, laid out once per
/// alpha step (so fading pieces carry their alpha in the text color instead
/// of each needing a saveLayer), and when each brick first lands, so bricks
/// that have crumbled away skip the physics.
class _BarriersCache {
  static const _alphaSteps = 20;
  final _labels = <(String, int), TextPainter>{};
  final _landedAt = <int, double>{};
  Size? _size;

  TextPainter label(String text, double alpha) {
    final step = (alpha * _alphaSteps).round();
    return _labels.putIfAbsent((text, step), () {
      final a = step / _alphaSteps;
      return TextPainter(
        text: TextSpan(
          text: text,
          style:
              zalando(
                20,
                weight: 800,
                color: const Color(0xFFFFFFFF).withValues(alpha: a),
              ).copyWith(
                shadows: [
                  Shadow(
                    color: const Color(0x88000000)
                        .withValues(alpha: 0x88 / 255 * a),
                    blurRadius: 6,
                  ),
                ],
              ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  /// Landing times depend on the layout; forget them if the size changes.
  Map<int, double> landedAt(Size size) {
    if (size != _size) {
      _size = size;
      _landedAt.clear();
    }
    return _landedAt;
  }

  void dispose() {
    for (final p in _labels.values) {
      p.dispose();
    }
    _labels.clear();
  }
}

class _Stack {
  const _Stack(this.label, this.color, this.slabs);
  final String label;
  final Color color;
  final int slabs;
}

class _BarriersPainter extends CustomPainter {
  _BarriersPainter(this.clock, this.cache) : super(repaint: clock);
  final Animation<double> clock;
  final _BarriersCache cache;

  static const totalMs = 4600;

  static const stacks = [
    _Stack('Swift', Color(0xFFF05138), 3),
    _Stack('Kotlin', Color(0xFF8F6BFF), 4),
    _Stack('JS', Color(0xFFF7DF1E), 3),
    _Stack('Dart', Color(0xFF13B9FD), 4),
  ];

  // Timeline, in seconds.
  static const crackStart = 0.55, crackEnd = 1.35;
  static const crumble = 1.35; // first wall goes; the rest follow
  static const crumbleStagger = 0.14;
  static const fadeStart = 2.5, fadeEnd = 3.1;
  static const walkStart = 2.9, walkEnd = 4.1;
  static const gravity = 2600.0;
  // Seconds after its first bounce that a brick has crumbled to nothing.
  static const _vanish = 0.55;

  // Sizes on the canvas.
  static const slabH = 58.0, slabGap = 8.0, stackW = 132.0;
  static const brickH = 30.0, brickGap = 5.0, courses = 4;
  static const wallH = courses * brickH + (courses - 1) * brickGap;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * totalMs / 1000;
    final ground = size.height * 0.74;
    final cell = size.width / stacks.length;
    final wallW = cell - 20;

    // Stacks, behind the walls.
    final placed = <(_Stack, Offset, double, double)>[];
    for (final (i, s) in stacks.indexed) {
      final from = cell * (i + 0.5);
      final to = size.width / 2 + (i - (stacks.length - 1) / 2) * (stackW + 18);
      final p = Curves.easeInOut.transform(
        ((t - walkStart - i * 0.05) / (walkEnd - walkStart - 0.15)).clamp(
          0.0,
          1.0,
        ),
      );
      final x = from + (to - from) * p;
      // Little hops on the way over, and one for joy when the walls fall.
      final hop = p > 0 && p < 1 ? (math.sin(p * math.pi * 3)).abs() * 26 : 0.0;
      final joy = _bump(t, crumble + 0.55 + i * crumbleStagger, 0.35) * 18;
      // Eyes: glance about, look down at the rubble, then at each other.
      final center = (stacks.length - 1) / 2;
      final double look;
      if (t < crumble) {
        look = math.sin(t * 5 + i * 1.7) * 0.8;
      } else if (p == 0) {
        look = 0;
      } else {
        look = (i < center ? 1.0 : -1.0) * math.min(1.0, p * 3);
      }
      final down = t >= crumble && t < walkStart
          ? _bump(t, crumble + 0.1, walkStart - crumble)
          : 0.0;
      placed.add((s, Offset(x, ground - hop - joy), look, down));
    }
    // Shadows under the ground line, so where two meet they don't pinch it.
    for (final (_, foot, _, _) in placed) {
      canvas.drawOval(
        Rect.fromCenter(center: foot, width: stackW * 1.1, height: 14),
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.35),
      );
    }
    _paintGround(canvas, size, ground, cell, t);
    for (final (s, foot, look, down) in placed) {
      _paintStack(canvas, s, foot, look, down);
    }

    // Walls: whole, cracked, then flying bricks.
    for (final (i, s) in stacks.indexed) {
      final wall = Rect.fromLTWH(
        cell * (i + 0.5) - wallW / 2,
        ground - wallH,
        wallW,
        wallH,
      );
      _paintWall(canvas, wall, s.label, i, ground, t, cache.landedAt(size));
    }
  }

  /// 0 → 1 → 0 over [length] seconds starting at [start].
  static double _bump(double t, double start, double length) {
    final u = (t - start) / length;
    if (u <= 0 || u >= 1) return 0;
    return math.sin(u * math.pi);
  }

  void _paintGround(
    Canvas canvas,
    Size size,
    double ground,
    double cell,
    double t,
  ) {
    // Four plots with gaps between them close into one long field.
    final join = Curves.easeInOut.transform(
      ((t - fadeStart) / (walkStart + 0.4 - fadeStart)).clamp(0.0, 1.0),
    );
    final line = Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final gap = 28 * (1 - join);
    line.color = Color.lerp(Palette.muted, Palette.accent, join)!;
    if (join >= 1) {
      // One field: a single line, no round caps meeting at the old seams.
      canvas.drawLine(Offset(0, ground), Offset(size.width, ground), line);
    } else {
      for (var i = 0; i < stacks.length; i++) {
        final l = i == 0 ? 0.0 : cell * i + gap / 2;
        final r = i == stacks.length - 1
            ? size.width
            : cell * (i + 1) - gap / 2;
        canvas.drawLine(Offset(l, ground), Offset(r, ground), line);
      }
    }
    if (join > 0) {
      // A soft glow along the open field.
      canvas.drawLine(
        Offset(size.width * 0.08, ground),
        Offset(size.width * 0.92, ground),
        Paint()
          ..strokeWidth = 30
          ..strokeCap = StrokeCap.round
          ..color = Palette.accent.withValues(alpha: 0.22 * join)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
      );
    }
  }

  void _paintStack(
    Canvas canvas,
    _Stack s,
    Offset foot,
    double look,
    double down,
  ) {
    // Slabs bottom up, each a touch lighter (the shadow is drawn earlier).
    late Rect top;
    for (var k = 0; k < s.slabs; k++) {
      final y = foot.dy - (k + 1) * slabH - k * slabGap;
      final r = Rect.fromLTWH(foot.dx - stackW / 2, y, stackW, slabH);
      final shade = 0.62 + 0.38 * (k + 1) / s.slabs;
      final c = Color.from(
        alpha: 1,
        red: s.color.r * shade,
        green: s.color.g * shade,
        blue: s.color.b * shade,
      );
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(12));
      canvas.drawRRect(rr, Paint()..color = c);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r.left, r.top, r.width, 10),
          const Radius.circular(12),
        ),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.22),
      );
      top = r;
    }
    // Eyes on the top slab.
    final eyeY = top.top + 24;
    for (final dx in [-24.0, 24.0]) {
      final e = Offset(foot.dx + dx, eyeY);
      canvas.drawCircle(e, 13, Paint()..color = const Color(0xFFFFFFFF));
      canvas.drawCircle(
        e + Offset(look * 5, -1 + down * 5),
        6,
        Paint()..color = Palette.background,
      );
    }
  }

  void _paintWall(
    Canvas canvas,
    Rect wall,
    String label,
    int w,
    double ground,
    double t,
    Map<int, double> landedAt,
  ) {
    final rng = math.Random(17 + w * 101);
    final go = crumble + w * crumbleStagger;
    final fade =
        1 -
        ((t - fadeStart - w * 0.05) / (fadeEnd - fadeStart)).clamp(0.0, 1.0);
    if (fade <= 0) return;

    // While cracking, the wall shudders.
    final crack = ((t - crackStart - w * 0.08) / (crackEnd - crackStart)).clamp(
      0.0,
      1.0,
    );
    final shake = t < go && crack > 0
        ? math.sin(t * 90 + w) * 2.2 * crack
        : 0.0;

    final labelPainter = cache.label(label, 1);
    final labelAt =
        wall.center - Offset(labelPainter.width / 2, labelPainter.height / 2);

    // Mortar behind the bricks, so the wall hides what's behind it.
    if (t < go + 0.1) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          wall.shift(Offset(shake, 0)).deflate(2),
          const Radius.circular(4),
        ),
        Paint()
          ..color = const Color(0xFF3B2A22)
              .withValues(alpha: 1 - ((t - go) / 0.1).clamp(0.0, 1.0)),
      );
    }
    const cols = 4;
    final standing = <Rect>[];
    final bw = (wall.width - (cols - 1) * brickGap) / cols;
    for (var r = 0; r < courses; r++) {
      final y = wall.bottom - (r + 1) * brickH - r * brickGap;
      final offset = r.isOdd ? -(bw + brickGap) / 2 : 0.0;
      for (var c = 0; c <= cols; c++) {
        var x = wall.left + offset + c * (bw + brickGap);
        var bwid = bw;
        if (x < wall.left) {
          bwid -= wall.left - x;
          x = wall.left;
        }
        if (x + bwid > wall.right) bwid = wall.right - x;
        // Every brick draws the same random numbers, used or not, so the
        // layout is stable.
        final tint = rng.nextDouble();
        final shade = 0.85 + rng.nextDouble() * 0.3;
        final delay = rng.nextDouble() * 0.22 + (courses - 1 - r) * 0.025;
        final vx0 = (rng.nextDouble() - 0.5) * 220;
        final vy0 = -60 - rng.nextDouble() * 300;
        final spin0 = (rng.nextDouble() - 0.5) * 10;
        if (bwid <= 6) continue;
        final home = Rect.fromLTWH(x, y, bwid, brickH);

        var pos = home.center + Offset(shake, 0);
        var angle = 0.0;
        var alpha = fade;
        final fall = t - go - delay;
        if (fall <= 0) standing.add(home.inflate(brickGap / 2 + 0.5));
        final key = (r * (cols + 1) + c) * stacks.length + w;
        final landed = landedAt[key];
        if (fall > 0 && landed != null && fall - landed >= _vanish) continue;
        if (fall > 0) {
          final spread = (home.center.dx - wall.center.dx) / wall.width;
          final s = _simulate(
            home.center,
            Offset(vx0 + spread * 260, vy0),
            spin0,
            brickH / 2,
            ground,
            fall,
          );
          pos = s.$1;
          angle = s.$2;
          if (s.$3 > 0) landedAt[key] ??= fall - s.$3;
          // After its first bounce a brick crumbles to nothing.
          alpha *= 1 - ((s.$3 - 0.15) / (_vanish - 0.15)).clamp(0.0, 1.0);
          if (alpha <= 0) continue;
        }

        final base = Color.lerp(
          const Color(0xFFB4532A),
          const Color(0xFFD9733F),
          tint,
        )!;
        final color = Color.from(
          alpha: alpha,
          red: (base.r * shade).clamp(0, 1),
          green: (base.g * shade).clamp(0, 1),
          blue: (base.b * shade).clamp(0, 1),
        );
        canvas
          ..save()
          ..translate(pos.dx, pos.dy)
          ..rotate(angle);
        final local = Rect.fromCenter(
          center: Offset.zero,
          width: home.width,
          height: home.height,
        );
        final rr = RRect.fromRectAndRadius(local, const Radius.circular(4));
        canvas.drawRRect(rr, Paint()..color = color);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(local.left, local.top, local.width, 5),
            const Radius.circular(4),
          ),
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.18 * alpha),
        );
        // Once falling, this brick's piece of the label rides along with it.
        if (fall <= 0) {
          canvas.restore();
          continue;
        }
        canvas
          ..save()
          ..clipRRect(rr)
          ..translate(-home.center.dx, -home.center.dy);
        // Faded through the text color, not a layer: no offscreen pass per
        // brick.
        cache.label(label, alpha).paint(canvas, labelAt);
        canvas
          ..restore()
          ..restore();
      }
    }
    // While the wall stands, the label is painted across it whole.
    if (standing.isNotEmpty) {
      canvas.save();
      canvas.translate(shake, 0);
      // Clipped to the bricks still standing, so it leaves with them.
      final clip = Path();
      for (final r in standing) {
        clip.addRect(r);
      }
      canvas.clipPath(clip);
      labelPainter.paint(canvas, labelAt);
      canvas.restore();
    }

    // Cracks: zigzags running down from the top, drawn progressively, gone
    // once the bricks fly apart.
    if (crack > 0 && t < go + 0.05) {
      final paint = Paint()
        ..color = const Color(0xFF2A1408)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final crng = math.Random(5 + w * 13);
      for (var k = 0; k < 2; k++) {
        final path = Path();
        var p = Offset(
          wall.left + wall.width * (0.25 + 0.5 * crng.nextDouble()) + shake,
          wall.top,
        );
        path.moveTo(p.dx, p.dy);
        const steps = 7;
        final shown = crack * steps;
        for (var j = 0; j < steps; j++) {
          final next = Offset(
            p.dx + (crng.nextDouble() - 0.5) * 50,
            p.dy + wall.height / steps,
          );
          final f = (shown - j).clamp(0.0, 1.0);
          if (f <= 0) break;
          final q = Offset.lerp(p, next, f)!;
          path.lineTo(q.dx, q.dy);
          p = next;
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  /// Where a brick thrown from [p0] at [v0] (spinning at [spin]) is after
  /// [time] seconds, and how long since it first hit the ground: it falls,
  /// bounces, skids and loses its spin. Stepped, so it's deterministic.
  static (Offset, double, double) _simulate(
    Offset p0,
    Offset v0,
    double spin,
    double half,
    double ground,
    double time,
  ) {
    const dt = 1 / 240;
    var x = p0.dx, y = p0.dy, vx = v0.dx, vy = v0.dy, a = 0.0, w = spin;
    final floor = ground - half;
    double? landed;
    for (var s = 0.0; s < time; s += dt) {
      vy += gravity * dt;
      x += vx * dt;
      y += vy * dt;
      a += w * dt;
      if (y > floor) {
        y = floor;
        landed ??= s;
        vy = -vy * 0.32;
        vx *= 0.55;
        w *= 0.4;
        if (vy.abs() < 40) vy = 0;
        // Lying down: settle the spin toward flat.
        final flat = (a / math.pi).roundToDouble() * math.pi;
        a += (flat - a) * 0.5;
      }
    }
    return (Offset(x, y), a, landed == null ? 0.0 : time - landed);
  }

  @override
  bool shouldRepaint(_BarriersPainter old) => false;
}
