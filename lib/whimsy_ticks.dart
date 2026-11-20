import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

/// "Why portable matters more": the three reasons get checked off one by
/// one, each with a hand-inked tick that a pen draws in beside it: a short
/// heavy down-stroke, then a flick up that tapers to a point. Each tick is
/// its own (seeded) hand-drawn shape, and its line gives a small nod as it
/// is ticked, in time with Eric counting them out loud. Laid out exactly
/// like ListSlide.
class TickedList extends StatefulWidget {
  const TickedList({
    super.key,
    required this.title,
    required this.items,
    this.size = 36,
  });
  final String title;
  final List<String> items;
  final double size;

  @override
  State<TickedList> createState() => _TickedListState();
}

/// When each tick starts, and how long the pen takes to draw it, in seconds.
const _start = 0.6, _gap = 0.8, _draw = 0.42;

class _TickedListState extends State<TickedList>
    with SingleTickerProviderStateMixin {
  static const _seconds = 3.0;
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..forward();

  late final _ticks = [
    for (var i = 0; i < widget.items.length; i++) _Tick(math.Random(29 + i)),
  ];

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  /// Each line's width as the Text will lay it out (same style and text
  /// scale), so each tick sits just left of its line.
  var _widths = const <double>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scaler = MediaQuery.textScalerOf(context);
    _widths = [for (final item in widget.items) _measure(item, scaler)];
  }

  double _measure(String item, TextScaler scaler) {
    final tp = TextPainter(
      text: TextSpan(text: item, style: headline(widget.size)),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final style = headline(widget.size);
    final pad = pt(widget.size) * 0.25;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 160, vertical: 90),
      child: Column(
        children: [
          Text(widget.title, style: headline(36, color: Palette.accent)),
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: _clock,
                builder: (context, _) {
                  final t = _clock.value * _seconds;
                  return CustomPaint(
                    foregroundPainter: _InkPainter(t, _ticks, _widths),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (i, item) in widget.items.indexed)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: pad),
                            child: Transform.scale(
                              scale: 1 + 0.035 * _nod(t, i),
                              child: Text(
                                item,
                                textAlign: TextAlign.center,
                                style: style,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double _tickStart(int i) => _start + i * _gap;

/// How much of tick [i] the pen has drawn at [t], 0..1.
double _drawn(double t, int i) => ((t - _tickStart(i)) / _draw).clamp(0.0, 1.0);

/// A small nod of line [i], landing as the pen flicks off its tick.
double _nod(double t, int i) {
  final s = t - _tickStart(i) - _draw * 0.7;
  return s <= 0 || s >= 0.35 ? 0.0 : math.sin(s / 0.35 * math.pi);
}

/// One hand-drawn tick: a centerline sampled along two curved strokes, and
/// the pen's width at each sample.
class _Tick {
  _Tick(math.Random r) {
    double j(double a) => (r.nextDouble() * 2 - 1) * a;
    const b = box;
    final a = Offset(b * (0.08 + j(0.04)), b * (0.52 + j(0.05)));
    final corner = Offset(b * (0.36 + j(0.04)), b * (0.9 + j(0.03)));
    final end = Offset(b * (0.97 + j(0.03)), b * (0.06 + j(0.05)));
    // Each stroke bows a little, the way a wrist swings.
    final c1 = Offset.lerp(a, corner, 0.5)! + Offset(b * 0.04, -b * 0.02);
    final c2 =
        Offset.lerp(corner, end, 0.45)! +
        Offset(b * (0.07 + j(0.03)), b * 0.06);
    const n1 = 12, n2 = 30;
    Offset quad(Offset p0, Offset c, Offset p1, double u) =>
        p0 * ((1 - u) * (1 - u)) + c * (2 * u * (1 - u)) + p1 * (u * u);
    for (var k = 0; k < n1; k++) {
      points.add(quad(a, c1, corner, k / n1));
    }
    for (var k = 0; k <= n2; k++) {
      points.add(quad(corner, c2, end, k / n2));
    }
    final heavy = 13 + j(1.5);
    for (var k = 0; k < points.length; k++) {
      final u = k / (points.length - 1);
      final w = k < n1
          // Pen down: a blot, then a heavy short stroke.
          ? heavy * (1.0 + 0.25 * math.exp(-k * 0.9))
          // The flick: full weight out of the corner, tapering to a hair.
          : heavy *
                    math.pow(
                      1 - (u - n1 / points.length) / (1 - n1 / points.length),
                      0.75,
                    ) +
                1.2;
      widths.add(w);
    }
  }

  static const box = 84.0;

  /// The samples the pen has reached at [progress], with the last one
  /// interpolated to where the pen is now. The pen speeds up into the flick.
  (List<Offset>, List<double>) upTo(double progress) {
    final along = Curves.easeIn.transform(progress) * (points.length - 1);
    final k = along.floor();
    final f = along - k;
    final ps = [...points.take(k + 1)];
    final wd = [...widths.take(k + 1)];
    if (k < points.length - 1 && f > 0) {
      ps.add(Offset.lerp(points[k], points[k + 1], f)!);
      wd.add(lerpDouble(widths[k], widths[k + 1], f)!);
    }
    return (ps, wd);
  }

  final points = <Offset>[];
  final widths = <double>[];
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.t, this.ticks, this.widths);
  final double t;
  final List<_Tick> ticks;
  final List<double> widths;

  static final _ink = Paint()
    ..color = Palette.accent
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final _fill = Paint()..color = Palette.accent;

  @override
  void paint(Canvas canvas, Size size) {
    final row = size.height / ticks.length;
    // Each tick's box sits just left of its line, centered on the text.
    final origins = [
      for (final (i, w) in widths.indexed)
        Offset(
          (size.width - w) / 2 - _Tick.box - 34,
          row * (i + 0.5) - _Tick.box / 2 - 6,
        ),
    ];
    for (final (i, tick) in ticks.indexed) {
      final p = _drawn(t, i);
      if (p <= 0) continue;
      canvas.save();
      canvas.translate(origins[i].dx, origins[i].dy);
      _paintTick(canvas, tick, p);
      canvas.restore();
    }
    _paintPen(canvas, origins);
  }

  void _paintTick(Canvas canvas, _Tick tick, double progress) {
    final (ps, wd) = tick.upTo(progress);
    // Short round-capped pen segments, each as wide as the pen there, so
    // the sharp corner can't fold an outline over itself.
    for (var i = 1; i < ps.length; i++) {
      _ink.strokeWidth = (wd[i - 1] + wd[i]) / 2;
      canvas.drawLine(ps[i - 1], ps[i], _ink);
    }
    if (ps.length == 1) canvas.drawCircle(ps.first, wd.first / 2, _fill);
  }

  /// The pen: it comes in from the right, draws each tick, hops to the next
  /// line between them, and lifts off after the third and fades.
  void _paintPen(Canvas canvas, List<Offset> origins) {
    final n = ticks.length;
    Offset first(int i) => origins[i] + ticks[i].points.first;
    Offset last(int i) => origins[i] + ticks[i].points.last;
    final enter = _tickStart(0) - 0.45;
    final done = _tickStart(n - 1) + _draw;
    if (t <= enter || t >= done + 0.35) return;

    Offset tip;
    var lift = 0.0, alpha = 1.0;
    if (t < _tickStart(0)) {
      final u = Curves.easeOutCubic.transform((t - enter) / 0.45);
      tip = Offset.lerp(first(0) + const Offset(160, -110), first(0), u)!;
      lift = 1 - u;
      alpha = (u * 2).clamp(0, 1);
    } else if (t >= done) {
      final u = Curves.easeInCubic.transform((t - done) / 0.35);
      tip = Offset.lerp(last(n - 1), last(n - 1) + const Offset(50, -60), u)!;
      lift = u;
      alpha = 1 - u;
    } else {
      final i = math.min(((t - _start) / _gap).floor(), n - 1);
      final p = _drawn(t, i);
      if (p < 1 || i == n - 1) {
        final (ps, _) = ticks[i].upTo(p);
        tip = origins[i] + ps.last;
      } else {
        // Between ticks: up off the paper and over to the next line.
        final u = ((t - _tickStart(i) - _draw) / (_gap - _draw)).clamp(
          0.0,
          1.0,
        );
        final e = Curves.easeInOut.transform(u);
        tip = Offset.lerp(last(i), first(i + 1), e)!;
        lift = math.sin(u * math.pi);
      }
    }
    _Pen.paint(canvas, tip, lift, alpha);
  }

  @override
  bool shouldRepaint(_InkPainter old) => old.t != t;
}

/// A fountain pen drawn with its nib's tip at the origin, the barrel up and
/// to the right, the way a right hand holds it.
abstract final class _Pen {
  static const angle = -0.95; // radians from pointing right; up-right

  static final Path _barrel = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(58, -13, 150, 26),
        const Radius.circular(13),
      ),
    );
  static final Path _grip = Path()
    ..moveTo(30, -8)
    ..lineTo(60, -12)
    ..lineTo(60, 12)
    ..lineTo(30, 8)
    ..close();
  static final Path _nib = Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(14, -9, 34, -9)
    ..lineTo(34, 9)
    ..quadraticBezierTo(14, 9, 0, 0)
    ..close();

  static void paint(Canvas canvas, Offset tip, double lift, double alpha) {
    if (alpha <= 0) return;
    Paint p(Color c, [double a = 1]) =>
        Paint()..color = c.withValues(alpha: a * alpha);
    // Its shadow on the page, further off the higher the pen is.
    canvas.save();
    canvas.translate(tip.dx + 10 + 22 * lift, tip.dy + 14 + 26 * lift);
    canvas.rotate(angle);
    canvas.drawPath(_barrel, p(Colors.black, 0.28 * (1 - 0.5 * lift)));
    canvas.drawPath(_grip, p(Colors.black, 0.28 * (1 - 0.5 * lift)));
    canvas.restore();

    canvas.save();
    canvas.translate(tip.dx, tip.dy - 10 * lift);
    canvas.rotate(angle);
    canvas.scale(1 + 0.06 * lift);
    canvas.drawPath(_barrel, p(const Color(0xFF2E3A4D)));
    // A highlight along the barrel, and the cap band.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(66, -9, 134, 5),
        const Radius.circular(3),
      ),
      p(Palette.soft, 0.35),
    );
    canvas.drawRect(const Rect.fromLTWH(150, -13, 8, 26), p(Palette.accent));
    canvas.drawPath(_grip, p(const Color(0xFF1C2431)));
    canvas.drawPath(_nib, p(const Color(0xFFE4C46A)));
    // The nib's slit and breather hole.
    canvas.drawLine(
      Offset.zero,
      const Offset(22, 0),
      p(const Color(0xFF8A6A1E))..strokeWidth = 1.5,
    );
    canvas.drawCircle(const Offset(23, 0), 2.2, p(const Color(0xFF8A6A1E)));
    canvas.restore();
  }
}
