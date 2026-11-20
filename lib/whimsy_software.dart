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
      CustomPaint(painter: _IconsPainter(_clock)),
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
  final int color; // index into _colors
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
        rnd.nextInt(_colors.length),
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

/// Where the logo sits (main.dart's SlideFrame). It paints under the slide
/// body, so icons fade out softly as they near it instead of covering it.
const _logo = Offset(43, 64);

/// 0 near the logo, 1 well clear of it, smooth in between.
double _logoClear(Offset c) {
  final u = (((c - _logo).distance - 60) / 110).clamp(0.0, 1.0);
  return u * u * (3 - 2 * u);
}

/// One unit-space (centered on the origin, 1 wide) gradient per color, built
/// once. Each icon is drawn under translate/scale and fades via the paint's
/// alpha, so a frame allocates no shaders or paths.
final List<Paint> _fills = [
  for (final color in _colors)
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, -0.5),
        const Offset(0, 0.5),
        [Color.lerp(color, const Color(0xFFFFFFFF), 0.18)!, color],
      ),
];

final RRect _tile = RRect.fromRectAndRadius(
  Rect.fromCenter(center: Offset.zero, width: 1, height: 1),
  const Radius.circular(0.23),
);

/// Each glyph as a filled path plus a stroked path (either may be empty), in
/// a unit square centered on the origin.
final List<(Path, Path)> _glyphs = _buildGlyphs();

List<(Path, Path)> _buildGlyphs() {
  Path dot(Offset c, double r) =>
      Path()..addOval(Rect.fromCircle(center: c, radius: r));
  final star = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? 0.25 : 0.11;
    final a = -math.pi / 2 + i * math.pi / 5;
    final o = Offset(math.cos(a) * r, math.sin(a) * r + 0.02);
    i == 0 ? star.moveTo(o.dx, o.dy) : star.lineTo(o.dx, o.dy);
  }
  star.close();
  final bars = Path();
  for (final (i, h) in [0.18, 0.34, 0.26].indexed) {
    bars.addRRect(
      RRect.fromLTRBR(
        -0.21 + i * 0.15,
        0.2 - h,
        -0.11 + i * 0.15,
        0.2,
        const Radius.circular(0.03),
      ),
    );
  }
  final listDots = Path();
  final listLines = Path();
  for (var i = 0; i < 3; i++) {
    final y = -0.14 + i * 0.14;
    listDots.addOval(Rect.fromCircle(center: Offset(-0.17, y), radius: 0.035));
    listLines
      ..moveTo(-0.07, y)
      ..lineTo(0.2, y);
  }
  final glyphs = [
    // play
    (
      Path()
        ..moveTo(-0.13, -0.2)
        ..lineTo(0.22, 0)
        ..lineTo(-0.13, 0.2)
        ..close(),
      Path(),
    ),
    // chat bubble
    (
      Path()
        ..addRRect(
          RRect.fromLTRBR(-0.24, -0.2, 0.24, 0.12, const Radius.circular(0.1)),
        )
        ..moveTo(-0.12, 0.08)
        ..lineTo(-0.16, 0.24)
        ..lineTo(0.02, 0.1)
        ..close(),
      Path(),
    ),
    // heart
    (
      Path()
        ..moveTo(0, 0.22)
        ..cubicTo(-0.34, 0, -0.24, -0.3, 0, -0.1)
        ..cubicTo(0.24, -0.3, 0.34, 0, 0, 0.22)
        ..close(),
      Path(),
    ),
    // bolt
    (
      Path()
        ..moveTo(0.06, -0.26)
        ..lineTo(-0.16, 0.04)
        ..lineTo(-0.01, 0.04)
        ..lineTo(-0.06, 0.26)
        ..lineTo(0.16, -0.05)
        ..lineTo(0.01, -0.05)
        ..close(),
      Path(),
    ),
    // bar chart
    (bars, Path()),
    // ring with dot (camera)
    (
      dot(Offset.zero, 0.06),
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 0.17)),
    ),
    // star
    (star, Path()),
    // map pin
    (
      Path()
        ..moveTo(0, 0.26)
        ..cubicTo(-0.28, -0.04, -0.18, -0.25, 0, -0.25)
        ..cubicTo(0.18, -0.25, 0.28, -0.04, 0, 0.26)
        ..close(),
      Path(),
    ),
    // list
    (listDots, listLines),
    // music note
    (
      dot(const Offset(-0.07, 0.15), 0.08),
      Path()
        ..moveTo(0, 0.15)
        ..lineTo(0, -0.22)
        ..lineTo(0.15, -0.14),
    ),
  ];
  assert(glyphs.length == _glyphCount);
  return glyphs;
}

/// A soft background-colored ellipse (unit radius; scale it into place) with
/// a fixed gradient; callers fade it in with the paint's alpha.
Paint _shade(double mid, double stop) => Paint()
  ..shader = ui.Gradient.radial(
    Offset.zero,
    1,
    [
      Palette.background,
      Palette.background.withValues(alpha: mid),
      Palette.background.withValues(alpha: 0),
    ],
    [0, stop, 1],
  );

final Paint _headlineShade = _shade(0.85 / 0.93, 0.55);
final Paint _cornerShade = _shade(0.8 / 0.95, 0.5);

class _IconsPainter extends CustomPainter {
  _IconsPainter(this.clock) : super(repaint: clock);
  final Animation<double> clock;

  // Reused every frame; only their colors change.
  final Paint _glyphFill = Paint();
  final Paint _glyphStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 0.08;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = clock.value * _total;
    final cell = _cellAt(ms);
    final icon = cell * 0.8;
    // Small icons fade back a little so the wall reads as texture.
    final fade = 0.5 + 0.5 * ((cell - _finalCell) / (190 - _finalCell));
    for (final it in _icons) {
      final age = (ms - it.born) / _pop;
      if (age <= 0) continue;
      final c = _seed + it.pos * cell;
      if (c.dx < -cell || c.dy < -cell) continue;
      if (c.dx > size.width + cell || c.dy > size.height + cell) continue;
      final s = icon * _popScale(age.clamp(0.0, 1.0));
      if (s <= 0.5) continue;
      final a = (fade * math.min(1, age * 3) * _logoClear(c)).clamp(0.0, 1.0);
      if (a <= 0.01) continue;
      final fill = _fills[it.color]..color = Color.fromRGBO(0, 0, 0, a);
      _glyphFill.color = Color.fromRGBO(255, 255, 255, 0.95 * a);
      _glyphStroke.color = _glyphFill.color;
      final (glyphFill, glyphStroke) = _glyphs[it.glyph];
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(s);
      canvas.drawRRect(_tile, fill);
      canvas.drawPath(glyphFill, _glyphFill);
      canvas.drawPath(glyphStroke, _glyphStroke);
      canvas.restore();
    }
    // Shade behind the headline and counter so they read over the wall. It
    // is fully in by the time the 100x icons grow past the headline.
    if (ms > 1000) {
      final t = ((ms - 1000) / 1000).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2 + 30);
      canvas.scale(900, 900 * 0.3);
      canvas.drawCircle(
        Offset.zero,
        1,
        _headlineShade..color = Color.fromRGBO(0, 0, 0, 0.93 * t),
      );
      canvas.restore();
    }
    // And under the slide number and section tracker.
    if (ms > 2200) {
      final t = ((ms - 2200) / 800).clamp(0.0, 1.0);
      _cornerShade.color = Color.fromRGBO(0, 0, 0, 0.95 * t);
      for (final (at, r) in [
        (const Offset(42, 1026), 70.0),
        (const Offset(1725, 1026), 230.0),
      ]) {
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.scale(r, r > 100 ? r * 0.35 : r);
        canvas.drawCircle(Offset.zero, 1, _cornerShade);
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

  @override
  bool shouldRepaint(_IconsPainter old) => false;
}
