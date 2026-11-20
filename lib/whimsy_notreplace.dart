import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// "AI does not replace engineers", said emphatically: the slide opens on
/// "AI ____ replace engineers" with a gap, then "does not" slams down into
/// it like a rubber stamp. On impact the line jolts, a shockwave rings out
/// and dust kicks up, and it rests in accent blue. Plays once, ~2s.
class NotReplaceStatement extends StatefulWidget {
  const NotReplaceStatement({super.key});

  @override
  State<NotReplaceStatement> createState() => _NotReplaceStatementState();
}

const _totalMs = 2100;
const _dropMs = 550.0; // the stamp starts falling
const _hitMs = 800.0; // and lands

double _ramp(double ms, double a, double b) =>
    ((ms - a) / (b - a)).clamp(0.0, 1.0);

class _NotReplaceStatementState extends State<NotReplaceStatement>
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
  Widget build(BuildContext context) {
    final style = headline(50);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 160),
      child: Center(
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, child) {
            final ms = _clock.value * _totalMs;
            // The jolt: a quick damped bounce of the whole line on impact.
            final since = ms - _hitMs;
            final jolt = since < 0 || since > 450
                ? 0.0
                : 16 * math.exp(-since / 90) * math.cos(since / 30);
            return Transform.translate(offset: Offset(0, jolt), child: child);
          },
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'AI '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: _Stamp(clock: _clock, style: style),
                ),
                const TextSpan(text: ' replace engineers'),
              ],
            ),
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.clock, required this.style});
  final Animation<double> clock;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      // Behind the word, so the flash glows under it.
      Positioned.fill(
        child: IgnorePointer(child: CustomPaint(painter: _Impact(clock))),
      ),
      AnimatedBuilder(
        animation: clock,
        builder: (context, child) {
          final ms = clock.value * _totalMs;
          if (ms < _dropMs) return Opacity(opacity: 0, child: child);
          // Falls from big and tilted, accelerating, then squashes on impact
          // and springs back.
          final fall = Curves.easeInCubic.transform(_ramp(ms, _dropMs, _hitMs));
          final scale = 1 + 2.4 * (1 - fall);
          final tilt = -0.14 * (1 - fall);
          final since = ms - _hitMs;
          final squash = since < 0 || since > 260
              ? 0.0
              : math.exp(-since / 70) * math.cos(since / 40);
          return Opacity(
            opacity: Curves.easeOut.transform(
              _ramp(ms, _dropMs, _dropMs + 120),
            ),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateZ(tilt)
                ..scaleByDouble(
                  scale * (1 + 0.08 * squash),
                  scale * (1 - 0.12 * squash),
                  1,
                  1,
                ),
              child: child,
            ),
          );
        },
        child: Text('does not', style: style.copyWith(color: Palette.accent)),
      ),
    ],
  );
}

/// The impact around the stamped word: a flash under it, a ring rolling
/// out, impact streaks and dust thrown up and down out of the line (not
/// sideways, where the neighbouring words are). Nothing is drawn before the
/// hit or after it fades.
class _Impact extends CustomPainter {
  _Impact(this.t) : super(repaint: t);
  final Animation<double> t;

  static final _dust = () {
    final r = math.Random(14);
    return [
      for (var i = 0; i < 30; i++)
        (
          r.nextDouble(), // where along the word
          r.nextBool(), // thrown up, else down
          0.5 + r.nextDouble(), // speed
          3.0 + 4.5 * r.nextDouble(), // radius
        ),
    ];
  }();

  /// Impact streaks: (angle from straight up in radians, length factor).
  static const _streaks = [
    (-1.0, 0.8),
    (-0.6, 1.0),
    (-0.25, 0.7),
    (0.15, 1.0),
    (0.5, 0.8),
    (0.95, 0.9),
    (math.pi - 1.0, 0.8),
    (math.pi - 0.5, 1.0),
    (math.pi - 0.1, 0.7),
    (math.pi + 0.35, 1.0),
    (math.pi + 0.8, 0.8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _totalMs;
    final since = ms - _hitMs;
    if (since < 0 || since > 900) return;
    final word = Offset.zero & size;
    final c = word.center;

    // Flash under the word.
    final flash = 1 - _ramp(since, 0, 400);
    if (flash > 0) {
      canvas.drawOval(
        word.inflate(18),
        Paint()
          ..color = Palette.accent.withValues(alpha: 0.55 * flash)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34),
      );
    }

    // A ring rolling out, wide and flat like a shockwave seen side-on.
    final wave = Curves.easeOutCubic.transform(_ramp(since, 0, 650));
    if (wave < 1) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c,
          width: word.width * (1.05 + 0.9 * wave),
          height: word.height * (0.9 + 1.6 * wave),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + 7 * (1 - wave)
          ..color = Palette.accent.withValues(alpha: 0.55 * (1 - wave))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // Streaks shooting out from the word's edge and shrinking.
    final s = Curves.easeOutCubic.transform(_ramp(since, 0, 380));
    if (s < 1) {
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5 * (1 - s) + 1
        ..color = Palette.text.withValues(alpha: 0.85 * (1 - s));
      final rx = word.width / 2 + 10;
      final ry = word.height / 2 + 6;
      for (final (a, len) in _streaks) {
        final d = Offset(math.sin(a), -math.cos(a));
        final edge = c + Offset(d.dx * rx, d.dy * ry);
        final from = edge + d * (16 + 90 * s);
        final to = edge + d * (16 + 90 * s + 60 * len * (1 - s));
        canvas.drawLine(from, to, paint);
      }
    }

    // Dust thrown up and down, arcing back under a little gravity.
    final k = _ramp(since, 0, 850);
    final travel = Curves.easeOutCubic.transform(k);
    final fade = 1 - Curves.easeIn.transform(k);
    final dust = Paint()..color = Palette.soft.withValues(alpha: 0.8 * fade);
    for (final (along, up, speed, radius) in _dust) {
      final x = word.left + word.width * (0.05 + 0.9 * along);
      final from = Offset(x, up ? word.top + size.height * 0.25 : word.bottom);
      final out = (x - c.dx) / (word.width / 2); // -1..1
      final dir = Offset(out * 0.9, up ? -1.0 : 0.7);
      final p = from + dir * (120 * speed * travel) + Offset(0, 90 * k * k);
      canvas.drawCircle(p, radius * (0.4 + 0.6 * fade), dust);
    }
  }

  @override
  bool shouldRepaint(_Impact old) => old.t != t;
}
