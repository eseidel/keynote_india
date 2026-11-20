import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'layouts.dart';
import 'theme.dart';

/// "This community can lead": dozens of small dots, people, drift in from
/// every edge of the slide on curving paths, find each other and gather
/// under the line into a V pointing forward, like a flock. One warm dot
/// arrives first and takes the point. Once everyone is in place the whole
/// group sets off together, a short glide forward, and holds. Runs once
/// and settles in about three and a half seconds. The line stays where a
/// plain Statement puts it.
class LeadStatement extends StatefulWidget {
  const LeadStatement(this.text, {super.key});
  final String text;

  @override
  State<LeadStatement> createState() => _LeadStatementState();
}

const _totalMs = 3600;

class _LeadStatementState extends State<LeadStatement>
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
      RepaintBoundary(child: CustomPaint(painter: _FlockPainter(_clock))),
      Statement(widget.text),
    ],
  );
}

/// How one dot flies in: a quadratic path, when it starts, and its size.
class _Flight {
  const _Flight(this.from, this.bend, this.to, this.delay, this.r);
  final Offset from, bend, to; // quadratic path: from, control, to
  final double delay; // ms
  final double r;
}

/// A follower: its flight and its color.
class _Dot {
  const _Dot(this.flight, this.color);
  final _Flight flight;
  final int color; // index into _colors
}

class _FlockPainter extends CustomPainter {
  _FlockPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  static const _flyMs = 1500.0;
  static const _goMs = (2700.0, 3600.0); // the group sets off
  static const _go = 70.0; // how far forward it glides

  // The V, under the line: tip on the right, arms trailing back left.
  static const _tip = Offset(1140, 810);
  static const _armDx = 560.0, _armDy = 125.0;

  static const _leaderColor = Palette.warn;
  static const _colors = [
    Palette.accent,
    Palette.statBlue,
    Palette.soft,
    Color(0xFFFFC98A), // a lighter warn
  ];

  static final List<_Dot> _dots = _build();
  static const _leader = _Flight(
    Offset(1990, 640),
    Offset(1600, 900),
    Offset(1180, 810), // 40px ahead of the tip
    150,
    13,
  );

  static List<_Dot> _build() {
    final rnd = math.Random(60);
    final dots = <_Dot>[];
    // Each arm: two staggered ranks, so it reads as a crowd, not a line.
    // The inner rank runs parallel to the arm, 20px inside it, and starts
    // a third of the way back: nearer the tip the two arms are too close
    // together for it, and its dots would cross the middle and clump.
    const perRank = 13;
    const armLen = 573.8; // |(_armDx, _armDy)|
    for (final side in [-1.0, 1.0]) {
      // Unit normal from this arm toward the middle of the V.
      const nx = -_armDy / armLen, ny = _armDx / armLen;
      final inward = Offset(nx, -side * ny);
      for (var rank = 0; rank < 2; rank++) {
        for (var k = rank * 4; k < perRank; k++) {
          final f = (k + 1.3 + rank * 0.5) / perRank; // 0 near the tip
          if (f > 1) continue;
          final back = Offset(-_armDx * f, side * _armDy * f);
          final inner = inward * 20.0 * rank.toDouble();
          final jitter = Offset(
            (rnd.nextDouble() - 0.5) * 8,
            (rnd.nextDouble() - 0.5) * 8,
          );
          final to = _tip + back + inner + jitter;
          final from = _edgePoint(rnd);
          // Curve each path a little sideways, so they swoop in.
          final mid = Offset.lerp(from, to, 0.5)!;
          final d = to - from;
          final normal = Offset(-d.dy, d.dx) / d.distance;
          final bend = mid + normal * (rnd.nextDouble() - 0.5) * 520;
          // Closer to the tip arrive sooner: the V grows back from its point.
          final delay = 250 + 700 * f + rnd.nextDouble() * 350;
          dots.add(
            _Dot(
              _Flight(from, bend, to, delay, 6 + rnd.nextDouble() * 3.5),
              rnd.nextInt(_colors.length),
            ),
          );
        }
      }
    }
    return dots;
  }

  // A point just off one of the slide's four edges.
  static Offset _edgePoint(math.Random rnd) {
    final u = rnd.nextDouble();
    return switch (rnd.nextInt(4)) {
      0 => Offset(u * 1920, -30),
      1 => Offset(u * 1920, 1110),
      2 => Offset(-30, u * 1080),
      _ => Offset(1950, u * 1080),
    };
  }

  static Offset _at(_Flight d, double ms) {
    final p = ((ms - d.delay) / _flyMs).clamp(0.0, 1.0);
    final e = Curves.easeOutCubic.transform(p);
    final a = Offset.lerp(d.from, d.bend, e)!;
    final b = Offset.lerp(d.bend, d.to, e)!;
    return Offset.lerp(a, b, e)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _totalMs;
    final goT = ((ms - _goMs.$1) / (_goMs.$2 - _goMs.$1)).clamp(0.0, 1.0);
    // Setting off: the leader goes first and every follower a little
    // later the further back it sits, so no one ever passes the leader.
    double glide(double lag) => Curves.easeInOutCubic.transform(
      ((goT + lag * 0.18) / 0.82).clamp(0.0, 1.0),
    );
    final paths = [for (final _ in _colors) Path()];
    final trails = [for (final _ in _colors) Path()];
    for (final dot in _dots) {
      final d = dot.flight;
      if (ms < d.delay) continue;
      // 0 at the tip, -1 at the tail; every follower is behind the tip.
      final lag = math.min(0.0, (d.to.dx - _tip.dx) / _armDx);
      final g = glide(lag);
      final p = _at(d, ms) + Offset(_go * g, 0);
      // A little pulse as each one finds its place.
      final land = ((ms - d.delay) / _flyMs - 0.8) / 0.2;
      final pulse = land > 0 && land < 1 ? 0.35 * math.sin(land * math.pi) : 0;
      paths[dot.color].addOval(
        Rect.fromCircle(center: p, radius: d.r * (1 + pulse)),
      );
      // A short streak behind a dot still in flight.
      final q = _at(d, ms - 70) + Offset(_go * g, 0);
      if ((p - q).distance > 3) {
        trails[dot.color]
          ..moveTo(q.dx, q.dy)
          ..lineTo(p.dx, p.dy);
      }
    }
    for (final (i, c) in _colors.indexed) {
      canvas.drawPath(
        trails[i],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 7
          ..color = c.withValues(alpha: 0.18),
      );
      canvas.drawPath(paths[i], Paint()..color = c);
    }

    // The leader: first in, warm, with a soft glow, out in front.
    if (ms >= _leader.delay) {
      final g = glide(0);
      final p = _at(_leader, ms) + Offset(_go * g, 0);
      final arrived = ((ms - _leader.delay - _flyMs * 0.8) / 500).clamp(
        0.0,
        1.0,
      );
      canvas.drawCircle(
        p,
        34,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _leaderColor.withValues(alpha: 0.35 + 0.15 * arrived),
              _leaderColor.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: p, radius: 34)),
      );
      final q = _at(_leader, ms - 70) + Offset(_go * g, 0);
      if ((p - q).distance > 3) {
        canvas.drawLine(
          q,
          p,
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 10
            ..color = _leaderColor.withValues(alpha: 0.3),
        );
      }
      canvas.drawCircle(p, _leader.r, Paint()..color = _leaderColor);
    }
  }

  @override
  bool shouldRepaint(_FlockPainter old) => false;
}
