import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// "Code compounds": a column of code for each day, every day carrying all
/// of yesterday's lines forward (you still own them) and adding new ones on
/// top. The new lines drop in bright; the old ones you're still paying for
/// fade to grey. Each day comes quicker and adds more than the last, until
/// the columns trace a compound curve, drawn in at the end. Drawn by Flutter,
/// no image. Laid out like SplitImage, with the chart where the picture was.
class CompoundsSlide extends StatelessWidget {
  const CompoundsSlide({super.key, required this.text, this.size = 50});
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
            padding: EdgeInsets.fromLTRB(20, 150, 100, 170),
            child: Compounds(),
          ),
        ),
      ],
    ),
  );
}

class Compounds extends StatefulWidget {
  const Compounds({super.key});

  @override
  State<Compounds> createState() => _CompoundsState();
}

class _CompoundsState extends State<Compounds>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_Timeline.total * 1000).round()),
  )..forward();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(painter: _CompoundsPainter(_clock), size: Size.infinite),
  );
}

/// When each day's column starts and how long it takes: each day quicker.
abstract final class _Timeline {
  static const days = 10;
  static const delay = 0.35;
  static const first = 0.62;
  static const speedup = 0.84;
  static const curve = 0.8;

  /// Lines of code owned at the end of each day: each day adds about 45%
  /// of what's already there.
  static final lines = () {
    final l = [2];
    while (l.length < days) {
      l.add(l.last + math.max(1, (l.last * 0.45).round()));
    }
    return l;
  }();

  static final starts = () {
    final s = <double>[];
    var t = delay;
    for (var i = 0; i < days; i++) {
      s.add(t);
      t += first * math.pow(speedup, i);
    }
    return s..add(t);
  }();

  static double get curveStart => starts.last + 0.1;
  static double get total => curveStart + curve + 0.1;
}

class _CompoundsPainter extends CustomPainter {
  _CompoundsPainter(this.clock) : super(repaint: clock);
  final Animation<double> clock;

  static const gap = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * _Timeline.total;
    const days = _Timeline.days;
    final lines = _Timeline.lines;
    final cw = (size.width - gap * (days - 1)) / days;
    final lh = size.height / lines.last;
    final barH = math.max(3.0, lh * 0.62);

    // Baseline.
    canvas.drawLine(
      Offset(-10, size.height + 6),
      Offset(size.width + 10, size.height + 6),
      Paint()
        ..color = Palette.muted.withValues(alpha: 0.5)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    final tops = <Offset>[];
    for (var d = 0; d < days; d++) {
      final start = _Timeline.starts[d];
      final dur = _Timeline.starts[d + 1] - start;
      final u = (t - start) / dur;
      if (u <= 0) break;
      final x = d * (cw + gap);
      final owned = lines[d];
      final carried = d == 0 ? 0 : lines[d - 1];
      // Yesterday's lines slide over from the last column, then today's
      // new lines drop onto the top one by one.
      final slide = Curves.easeOutCubic.transform((u / 0.35).clamp(0.0, 1.0));
      final dropping = ((u - 0.2) / 0.8).clamp(0.0, 1.0);
      final fresh = owned - carried;
      for (var k = 0; k < owned; k++) {
        final double dx, dy, alpha;
        final isNew = k >= carried;
        if (!isNew) {
          dx = -(cw + gap) * (1 - slide);
          dy = 0;
          alpha = 1;
        } else {
          // Each new line falls in turn, its fall easing out.
          final j = k - carried;
          final f = ((dropping * (fresh + 1.5) - j) / 1.5).clamp(0.0, 1.0);
          if (f <= 0) continue;
          final e = Curves.easeOutCubic.transform(f);
          dx = 0;
          dy = -(1 - e) * 90;
          alpha = e;
        }
        // A new line is bright for its day, then greys as it ages.
        final born = _Line.all[k].born;
        final age = isNew
            ? 0.0
            : born < d - 1
            ? 1.0
            : (t - start).clamp(0.0, 0.5) / 0.5;
        final y = size.height - (k + 1) * lh + (lh - barH) / 2 + dy;
        _paintLine(canvas, k, Offset(x + dx, y), cw, barH, alpha, age, d);
      }
      // The curve rides each column's top-left corner, so on the steep last
      // days it climbs beside the columns rather than across their lines.
      if (u >= 1) tops.add(Offset(x, size.height - owned * lh));
    }

    // The compound curve through the tops of the columns.
    final c = ((t - _Timeline.curveStart) / _Timeline.curve).clamp(0.0, 1.0);
    if (c > 0 && tops.length == days) {
      // A smooth Catmull-Rom spline a little above and left of the tops.
      final p = [for (final top in tops) top - const Offset(4, 14)];
      final path = Path()..moveTo(p.first.dx, p.first.dy);
      for (var i = 0; i < p.length - 1; i++) {
        final p0 = p[math.max(i - 1, 0)], p1 = p[i], p2 = p[i + 1];
        final p3 = p[math.min(i + 2, p.length - 1)];
        final c1 = p1 + (p2 - p0) / 6, c2 = p2 - (p3 - p1) / 6;
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
      }
      final metric = path.computeMetrics().first;
      final shown = metric.extractPath(
        0,
        metric.length * Curves.easeInOut.transform(c),
      );
      canvas.drawPath(
        shown,
        Paint()
          ..color = Palette.warn.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawPath(
        shown,
        Paint()
          ..color = Palette.warn
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      final head = metric
          .getTangentForOffset(metric.length * Curves.easeInOut.transform(c))!
          .position;
      canvas.drawCircle(head, 11, Paint()..color = Palette.warn);
      canvas.drawCircle(
        head,
        5,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9),
      );
    }
  }

  final _paint = Paint();

  /// Line [k] of the codebase: the same indent and tokens in every column it
  /// appears in, since it's the same line, still there.
  void _paintLine(
    Canvas canvas,
    int k,
    Offset at,
    double w,
    double h,
    double alpha,
    double age,
    int day,
  ) {
    final line = _Line.all[k];
    final indent = line.indent * w;
    final avail = w - indent;
    final first = avail * line.first;
    final second = (avail - first - 5) * line.second;
    final r = Radius.circular(h / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(at.dx + indent, at.dy, first, h),
        r,
      ),
      _paint..color = _tone(line.c1, alpha, age),
    );
    if (second > h) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(at.dx + indent + first + 5, at.dy, second, h),
          r,
        ),
        _paint..color = _tone(line.c2, alpha, age),
      );
    }
  }

  static final _aged = Palette.muted.withValues(alpha: 0.45);

  static Color _tone(Color c, double alpha, double age) {
    if (age == 0 && alpha == 1) return c;
    return Color.lerp(
      c,
      _aged,
      age,
    )!.withValues(alpha: alpha * (1 - age * 0.55));
  }

  @override
  bool shouldRepaint(_CompoundsPainter old) => false;
}

/// One line of the codebase, the same wherever it appears: its indent and
/// token widths (as fractions of the column) and colors, and the day it was
/// written. Worked out once, not per frame.
class _Line {
  const _Line(
    this.born,
    this.indent,
    this.first,
    this.second,
    this.c1,
    this.c2,
  );

  factory _Line.at(int k) {
    final rng = math.Random(k * 7919 + 13);
    return _Line(
      _Timeline.lines.indexWhere((n) => n > k),
      [0, 1, 1, 2, 2, 3][rng.nextInt(6)] * 0.12,
      0.25 + rng.nextDouble() * 0.4,
      0.3 + rng.nextDouble() * 0.7,
      _hues[rng.nextInt(_hues.length)],
      _hues[rng.nextInt(_hues.length)],
    );
  }

  final int born;
  final double indent, first, second;
  final Color c1, c2;

  static final all = [
    for (var k = 0; k < _Timeline.lines.last; k++) _Line.at(k),
  ];

  static const _hues = [
    Palette.accent,
    Palette.statBlue,
    Palette.text,
    Palette.soft,
  ];
}
