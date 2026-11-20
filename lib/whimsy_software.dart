import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// "A lot more software": one app icon pops in above the headline, then the
/// camera pulls back as they multiply, 10x, 100x, 1000x, until a screenful of
/// apps tiles out to the edges. Every icon (rounded square, color, glyph) is
/// painted by Flutter; a soft shadow keeps the headline legible on top.
/// Runs once when the slide appears and settles in under four seconds.
class SoftwareSlide extends StatefulWidget {
  const SoftwareSlide(this.text, {super.key});
  final String text;

  @override
  State<SoftwareSlide> createState() => _SoftwareSlideState();
}

/// Each stage: how many apps, how big a grid cell is (canvas px), and when
/// (ms) the stage is reached. The growth from one stage to the next takes
/// [_grow] ms and ends at the stage's time.
const _stages = [(1, 190.0, 500), (10, 120.0, 1300), (100, 74.0, 2100)];
const _finalCell = 46.0; // the last stage: every cell on screen
const _finalAt = 3000;
const _grow = 550;
const _pop = 420; // ms for one icon's pop
const _total = _finalAt + _pop + 100;

/// Where the first app appears: centered, above the headline.
const _seed = Offset(960, 290);

class _SoftwareSlideState extends State<SoftwareSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _total),
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
      IgnorePointer(child: CustomPaint(painter: _IconsPainter(_clock))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 160),
        child: Center(
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: headline(50),
          ),
        ),
      ),
      Align(
        alignment: const Alignment(0, 0.27),
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) => _Counter(_clock.value * _total),
        ),
      ),
    ],
  );
}

/// "10x", "100x", "1000x" under the headline, punching in as each stage
/// lands.
class _Counter extends StatelessWidget {
  const _Counter(this.ms);
  final double ms;

  @override
  Widget build(BuildContext context) {
    final marks = [
      for (final (n, _, at) in _stages.skip(1)) (n, at),
      (1000, _finalAt),
    ];
    (int, int)? shown;
    for (final m in marks) {
      if (ms >= m.$2 - _grow * 0.5) shown = m;
    }
    if (shown == null) return const SizedBox();
    final since = (ms - (shown.$2 - _grow * 0.5)) / 350;
    final punch = 1 + 0.35 * math.max(0, 1 - since) * math.max(0, 1 - since);
    return Transform.scale(
      scale: punch,
      child: Text('${shown.$1}x', style: headline(30, color: Palette.accent)),
    );
  }
}

class _Icon {
  _Icon(this.pos, this.rank, this.color, this.glyph, this.born);
  final Offset pos; // grid coordinates, in cells from the seed
  final int rank;
  final Color color;
  final int glyph;
  final double born; // ms when it pops in
}

/// Every cell that's on screen at the final size, nearest the seed first.
final List<_Icon> _icons = _layout();

List<_Icon> _layout() {
  final rnd = math.Random(52);
  final cells = <(Offset, double)>[];
  final left = (_seed.dx / _finalCell).ceil();
  final right = ((canvasSize.width - _seed.dx) / _finalCell).ceil();
  final up = (_seed.dy / _finalCell).ceil();
  final down = ((canvasSize.height - _seed.dy) / _finalCell).ceil();
  for (var j = -up; j <= down; j++) {
    for (var i = -left; i <= right; i++) {
      // A little jitter so each ring fills in raggedly, not as a circle.
      final d = math.sqrt(i * i + j * j * 1.3) + rnd.nextDouble() * 1.4;
      cells.add((
        Offset(i.toDouble(), j.toDouble()),
        i == 0 && j == 0 ? -1 : d,
      ));
    }
  }
  cells.sort((a, b) => a.$2.compareTo(b.$2));
  return [
    for (final (rank, (pos, _)) in cells.indexed)
      _Icon(
        pos,
        rank,
        _colors[rnd.nextInt(_colors.length)],
        rnd.nextInt(_glyphCount),
        _bornAt(rank, cells.length),
      ),
  ];
}

/// When the visible count first exceeds [rank].
double _bornAt(int rank, int total) {
  if (rank == 0) return _stages.first.$3 - _grow * 0.6;
  final counts = [for (final s in _stages) s.$1.toDouble(), total.toDouble()];
  final ends = [for (final s in _stages) s.$3.toDouble(), _finalAt.toDouble()];
  for (var k = 1; k < counts.length; k++) {
    if (rank < counts[k]) {
      // count = from * (to/from)^e, e = easeOut(u); invert both.
      final e =
          math.log((rank + 1) / counts[k - 1]) /
          math.log(counts[k] / counts[k - 1]);
      final u = 1 - math.pow(1 - e.clamp(0.0, 1.0), 1 / 3);
      return ends[k] - _grow + u * _grow;
    }
  }
  return _finalAt.toDouble();
}

/// Grid cell size at [ms]: shrinks with the same easing as the count grows.
double _cellAt(double ms) {
  final sizes = [for (final s in _stages) s.$2, _finalCell];
  final ends = [for (final s in _stages) s.$3.toDouble(), _finalAt.toDouble()];
  if (ms <= ends.first - _grow) return sizes.first;
  for (var k = 1; k < sizes.length; k++) {
    if (ms <= ends[k]) {
      final u = ((ms - (ends[k] - _grow)) / _grow).clamp(0.0, 1.0);
      final e = 1 - math.pow(1 - u, 3);
      return sizes[k - 1] * math.pow(sizes[k] / sizes[k - 1], e);
    }
  }
  return _finalCell;
}

const _colors = [
  Color(0xFF27C4F5), // accent
  Color(0xFF4F7DF9),
  Color(0xFF7C5CF2),
  Color(0xFFE2559B),
  Color(0xFFF2545B),
  Color(0xFFFF8A3D),
  Color(0xFFFFB259), // warn
  Color(0xFFF7D046),
  Color(0xFF3CCB7F),
  Color(0xFF18B5A4),
];

const _glyphCount = 10;

class _IconsPainter extends CustomPainter {
  _IconsPainter(this.clock) : super(repaint: clock);
  final Animation<double> clock;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = clock.value * _total;
    final cell = _cellAt(ms);
    final icon = cell * 0.8;
    // Small icons fade back a little so the wall reads as texture.
    final fade = 0.5 + 0.5 * ((cell - _finalCell) / (190 - _finalCell));
    final fill = Paint();
    final glyph = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final it in _icons) {
      final age = (ms - it.born) / _pop;
      if (age <= 0) continue;
      final c = _seed + it.pos * cell;
      if (c.dx < -cell || c.dy < -cell) continue;
      if (c.dx > size.width + cell || c.dy > size.height + cell) continue;
      // The logo is painted under the slide body: leave its corner clear.
      if (c.dx < 100 && c.dy < 120) continue;
      final s = icon * _popScale(age.clamp(0.0, 1.0));
      if (s <= 0.5) continue;
      final a = (fade * math.min(1, age * 3)).clamp(0.0, 1.0);
      fill.shader = ui.Gradient.linear(
        c - Offset(0, s / 2),
        c + Offset(0, s / 2),
        [
          Color.lerp(
            it.color,
            const Color(0xFFFFFFFF),
            0.18,
          )!.withValues(alpha: a),
          it.color.withValues(alpha: a),
        ],
      );
      glyph.color = Color.fromRGBO(255, 255, 255, 0.95 * a);
      stroke.color = glyph.color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: s, height: s),
          Radius.circular(s * 0.23),
        ),
        fill,
      );
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(s);
      stroke.strokeWidth = 0.08;
      _paintGlyph(canvas, it.glyph, glyph, stroke);
      canvas.restore();
    }
    // Shade behind the headline and counter so they read over the wall.
    if (ms > 1000) {
      final t = ((ms - 1000) / 1500).clamp(0.0, 1.0);
      final center = Offset(size.width / 2, size.height / 2 + 30);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1, 0.3);
      canvas.drawCircle(
        Offset.zero,
        900,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            900,
            [
              Palette.background.withValues(alpha: 0.93 * t),
              Palette.background.withValues(alpha: 0.85 * t),
              Palette.background.withValues(alpha: 0),
            ],
            [0, 0.55, 1],
          ),
      );
      canvas.restore();
    }
    // And under the slide number and section tracker.
    if (ms > 2200) {
      final t = ((ms - 2200) / 800).clamp(0.0, 1.0);
      for (final (at, r) in [
        (const Offset(42, 1026), 70.0),
        (const Offset(1725, 1026), 230.0),
      ]) {
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.scale(1, r > 100 ? 0.35 : 1);
        canvas.drawCircle(
          Offset.zero,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset.zero,
              r,
              [
                Palette.background.withValues(alpha: 0.95 * t),
                Palette.background.withValues(alpha: 0.8 * t),
                Palette.background.withValues(alpha: 0),
              ],
              [0, 0.5, 1],
            ),
        );
        canvas.restore();
      }
    }
  }

  /// 0 to 1 with a springy overshoot.
  static double _popScale(double t) {
    if (t >= 1) return 1;
    const c = 1.9;
    final x = t - 1;
    return 1 + (c + 1) * x * x * x + c * x * x;
  }

  /// A simple white glyph in a unit square centered on the origin.
  static void _paintGlyph(Canvas c, int g, Paint fill, Paint stroke) {
    switch (g) {
      case 0: // play
        c.drawPath(
          Path()
            ..moveTo(-0.13, -0.2)
            ..lineTo(0.22, 0)
            ..lineTo(-0.13, 0.2)
            ..close(),
          fill,
        );
      case 1: // chat bubble
        c.drawRRect(
          RRect.fromLTRBR(-0.24, -0.2, 0.24, 0.12, const Radius.circular(0.1)),
          fill,
        );
        c.drawPath(
          Path()
            ..moveTo(-0.12, 0.08)
            ..lineTo(-0.16, 0.24)
            ..lineTo(0.02, 0.1)
            ..close(),
          fill,
        );
      case 2: // heart
        c.drawPath(
          Path()
            ..moveTo(0, 0.22)
            ..cubicTo(-0.34, 0, -0.24, -0.3, 0, -0.1)
            ..cubicTo(0.24, -0.3, 0.34, 0, 0, 0.22)
            ..close(),
          fill,
        );
      case 3: // bolt
        c.drawPath(
          Path()
            ..moveTo(0.06, -0.26)
            ..lineTo(-0.16, 0.04)
            ..lineTo(-0.01, 0.04)
            ..lineTo(-0.06, 0.26)
            ..lineTo(0.16, -0.05)
            ..lineTo(0.01, -0.05)
            ..close(),
          fill,
        );
      case 4: // bar chart
        for (final (i, h) in [0.18, 0.34, 0.26].indexed) {
          c.drawRRect(
            RRect.fromLTRBR(
              -0.21 + i * 0.15,
              0.2 - h,
              -0.11 + i * 0.15,
              0.2,
              const Radius.circular(0.03),
            ),
            fill,
          );
        }
      case 5: // ring with dot (camera)
        c.drawCircle(Offset.zero, 0.17, stroke);
        c.drawCircle(Offset.zero, 0.06, fill);
      case 6: // star
        final p = Path();
        for (var i = 0; i < 10; i++) {
          final r = i.isEven ? 0.25 : 0.11;
          final a = -math.pi / 2 + i * math.pi / 5;
          final o = Offset(math.cos(a) * r, math.sin(a) * r + 0.02);
          i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
        }
        c.drawPath(p..close(), fill);
      case 7: // map pin
        c.drawPath(
          Path()
            ..moveTo(0, 0.26)
            ..cubicTo(-0.28, -0.04, -0.18, -0.25, 0, -0.25)
            ..cubicTo(0.18, -0.25, 0.28, -0.04, 0, 0.26)
            ..close(),
          fill,
        );
      case 8: // list
        for (var i = 0; i < 3; i++) {
          final y = -0.14 + i * 0.14;
          c.drawCircle(Offset(-0.17, y), 0.035, fill);
          c.drawLine(Offset(-0.07, y), Offset(0.2, y), stroke);
        }
      default: // music note
        c.drawCircle(const Offset(-0.07, 0.15), 0.08, fill);
        c.drawLine(const Offset(0.0, 0.15), const Offset(0.0, -0.22), stroke);
        c.drawLine(const Offset(0.0, -0.22), const Offset(0.15, -0.14), stroke);
    }
  }

  @override
  bool shouldRepaint(_IconsPainter old) => false;
}
