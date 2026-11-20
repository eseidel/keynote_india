import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

/// "Today: AI, Flutter, Us" as a metro map. A faint route runs down the
/// left of the agenda, with 45-degree bends like a transit map. A train
/// travels it, AI, then Flutter, then Us, inking the line behind it. Each
/// stop lights up in accent as the train pulls in and goes back to white
/// when it leaves, the way the section tracker in the slide corner marks
/// the current section. The ride ends at Us, the last stop, which stays lit.
/// Laid out exactly like ListSlide.
class TodayRoute extends StatefulWidget {
  const TodayRoute({
    super.key,
    required this.title,
    required this.items,
    this.size = 40,
  });
  final String title;
  final List<String> items;
  final double size;

  @override
  State<TodayRoute> createState() => _TodayRouteState();
}

class _TodayRouteState extends State<TodayRoute>
    with SingleTickerProviderStateMixin {
  static const _seconds = 3.4;
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..forward();

  late final List<double> _widths = [
    for (final item in widget.items)
      (TextPainter(
        text: TextSpan(text: item, style: headline(widget.size)),
        textDirection: TextDirection.ltr,
      )..layout()).width,
  ];
  final _geometry = _RouteCache();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = headline(widget.size);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 160, vertical: 90),
      child: Column(
        children: [
          Text(widget.title, style: headline(36, color: Palette.accent)),
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: _clock,
                builder: (context, child) {
                  final t = _clock.value * _seconds;
                  return CustomPaint(
                    painter: _RoutePainter(t, _widths, _geometry),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (i, item) in widget.items.indexed)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: pt(widget.size) * 0.25,
                            ),
                            child: Transform.scale(
                              scale: 1 + 0.07 * _bump(t - _arrive[i]),
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

/// When the train pulls into each stop, in seconds.
const _arrive = [0.95, 1.8, 2.65];

/// The train's schedule: (seconds, stop it is at or leaving). It leaves the
/// start at 0.5s and waits 0.3s at each stop.
const _schedule = [
  (0.5, -1),
  (0.95, 0),
  (1.25, 0),
  (1.8, 1),
  (2.1, 1),
  (2.65, 2),
];

/// A quick swell and return over 0.4s, for a stop that was just reached.
double _bump(double s) => s <= 0 || s >= 0.4 ? 0 : math.sin(s / 0.4 * math.pi);

/// The route, built once per size: the path, its metric, and where along it
/// each stop sits.
class _RouteCache {
  Size? size;
  late Path path;
  late PathMetric metric;
  late List<Offset> stops;
  late List<double> stopAt; // distance along the path, -1 is the start
  late Offset start;

  void ensure(Size s, List<double> widths) {
    if (s == size) return;
    size = s;
    final row = s.height / widths.length;
    stops = [
      for (final (i, w) in widths.indexed)
        Offset((s.width - w) / 2 - 62, row * (i + 0.5)),
    ];
    start = stops.first - const Offset(0, 120);
    path = Path()..moveTo(start.dx, start.dy);
    var length = 0.0;
    var at = start;
    void to(Offset p) {
      path.lineTo(p.dx, p.dy);
      length += (p - at).distance;
      at = p;
    }

    stopAt = [];
    to(stops.first);
    stopAt.add(length);
    for (var i = 1; i < stops.length; i++) {
      final a = stops[i - 1], b = stops[i];
      final dx = (b.dx - a.dx).abs();
      // Straight, a 45-degree jog, straight again: transit-map geometry.
      final v = math.max(0.0, (b.dy - a.dy) - dx) / 2;
      to(Offset(a.dx, a.dy + v));
      to(Offset(b.dx, b.dy - v));
      to(b);
      stopAt.add(length);
    }
    metric = path.computeMetrics().first;
  }

  /// How far along the route the train is at [t] seconds.
  double trainAt(double t) {
    double d(int stop) => stop < 0 ? 0 : stopAt[stop];
    if (t <= _schedule.first.$1) return 0;
    for (var i = 1; i < _schedule.length; i++) {
      final (t0, s0) = _schedule[i - 1];
      final (t1, s1) = _schedule[i];
      if (t < t1) {
        final p = Curves.easeInOutCubic.transform((t - t0) / (t1 - t0));
        return lerpDouble(d(s0), d(s1), p)!;
      }
    }
    return stopAt.last;
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.t, this.widths, this.cache);
  final double t;
  final List<double> widths;
  final _RouteCache cache;

  static const line = 14.0, stopRadius = 19.0;
  static final _ghost = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = line
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final _ink = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = line
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = Palette.accent;
  static final _glow = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

  @override
  void paint(Canvas canvas, Size size) {
    cache.ensure(size, widths);
    final fadeIn = Curves.easeOut.transform(((t - 0.1) / 0.4).clamp(0, 1));
    if (fadeIn == 0) return;

    // The whole route, faint, so you can see where today is going.
    _ghost.color = Palette.muted.withValues(alpha: 0.22 * fadeIn);
    canvas.drawPath(cache.path, _ghost);

    // The start: a terminus bar.
    final bar = Paint()
      ..color = Color.lerp(
        Palette.muted.withValues(alpha: 0.3 * fadeIn),
        Palette.accent,
        ((t - 0.4) / 0.2).clamp(0, 1),
      )!
      ..strokeWidth = line
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      cache.start - const Offset(22, 0),
      cache.start + const Offset(22, 0),
      bar,
    );

    // The line inked so far, behind the train.
    final d = cache.trainAt(t);
    if (d > 0) canvas.drawPath(cache.metric.extractPath(0, d), _ink);

    // The train: a bright car with a headlight glow. It slips under each
    // stop while it waits there, and fades into Us at the end of the line.
    final end = _arrive.last;
    if (t >= _schedule.first.$1 && t < end + 0.25) {
      final fade = t < end ? 1.0 : 1 - (t - end) / 0.25;
      final tan = cache.metric.getTangentForOffset(d)!;
      final p = tan.position;
      _glow.color = Palette.accent.withValues(alpha: 0.8 * fade);
      canvas.drawCircle(p, 22, _glow);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(math.atan2(tan.vector.dy, tan.vector.dx));
      final car = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 40, height: 24),
        const Radius.circular(12),
      );
      canvas.drawRRect(
        car,
        Paint()..color = Palette.text.withValues(alpha: fade),
      );
      canvas.drawCircle(
        const Offset(12, 0),
        5,
        Paint()..color = Palette.accent.withValues(alpha: fade),
      );
      canvas.restore();
    }

    // The stops.
    final last = cache.stops.length - 1;
    for (final (i, c) in cache.stops.indexed) {
      final since = t - _arrive[i];
      final reached = since >= 0;
      final leaves = i < last ? _schedule[2 * i + 2].$1 : double.infinity;
      final current = reached && t < leaves;
      final pop = reached
          ? Curves.easeOutBack.transform((since / 0.3).clamp(0, 1))
          : 0.0;

      // A ripple when the train pulls in.
      if (reached && since < 0.7) {
        final p = since / 0.7;
        canvas.drawCircle(
          c,
          stopRadius + 34 * Curves.easeOut.transform(p),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * (1 - p) + 1
            ..color = Palette.accent.withValues(alpha: 0.6 * (1 - p)),
        );
      }
      // The last stop keeps a soft halo: this is where the talk is headed.
      if (i == last && reached) {
        _glow.color = Palette.accent.withValues(
          alpha: 0.35 * (since / 0.5).clamp(0, 1),
        );
        canvas.drawCircle(c, stopRadius + 10, _glow);
      }

      final r = stopRadius * (reached ? 0.85 + 0.15 * pop : 0.85);
      final ring = reached
          ? Palette.background
          : Palette.muted.withValues(alpha: 0.35 * fadeIn);
      canvas.drawCircle(c, r, Paint()..color = ring);
      final fill = !reached
          ? Palette.background
          : current || i == last
          ? Palette.accent
          : Palette.text;
      canvas.drawCircle(c, r - 6, Paint()..color = fill);
      if (!reached) {
        canvas.drawCircle(
          c,
          r - 1.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Palette.muted.withValues(alpha: 0.4 * fadeIn),
        );
      } else {
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = current || i == last ? Palette.text : Palette.accent,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.t != t;
}
