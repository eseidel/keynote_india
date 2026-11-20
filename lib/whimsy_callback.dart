import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// The opening question again, answered by three rubber stamps: each answer
/// slams down from above the slide in turn, the slide jolts, and a ring of
/// ink kicks out from where it hit. Own two. Pay 3x. Two answers. Settles
/// in under three seconds as the ordinary Callback layout.
class StampedCallback extends StatefulWidget {
  const StampedCallback({
    super.key,
    required this.question,
    required this.answers,
  });
  final String question;
  final List<String> answers;

  @override
  State<StampedCallback> createState() => _StampedCallbackState();
}

const _first = 800; // ms: the question has the stage first
const _gap = 650; // ms between stamps
const _fall = 200; // ms from lifted to landed
const _after = 700; // ms of ink and wobble after the last lands

class _StampedCallbackState extends State<StampedCallback>
    with SingleTickerProviderStateMixin {
  late final int _total =
      _first + (widget.answers.length - 1) * _gap + _fall + _after;

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _total),
  )..forward();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  /// When answer [i] hits the page (ms).
  int _hit(int i) => _first + i * _gap + _fall;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) {
      final ms = _clock.value * _total;
      final live = _clock.isAnimating;
      // The jolt: each landing shakes everything a little, the last most.
      var shake = Offset.zero;
      for (var i = 0; i < widget.answers.length && live; i++) {
        final w = (ms - _hit(i)) / 1000;
        if (w < 0 || w > 0.35) continue;
        final a =
            (i == widget.answers.length - 1 ? 14.0 : 8.0) * math.exp(-14 * w);
        shake += Offset(
          a * math.sin(w * 2 * math.pi * 19) * 0.5,
          a * math.cos(w * 2 * math.pi * 23),
        );
      }
      final question = Text(widget.question, style: headline(32));
      return Center(
        child: Transform.translate(
          offset: shake,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (live)
                Opacity(opacity: (ms / 300).clamp(0.0, 1.0), child: question)
              else
                question,
              const SizedBox(height: 70),
              for (final (i, a) in widget.answers.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: live
                      ? _Stamp(a, ms: ms - _hit(i), seed: i)
                      : Text(a, style: headline(40, color: Palette.accent)),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// One answer, [ms] relative to when it lands (negative: not yet).
class _Stamp extends StatelessWidget {
  const _Stamp(this.text, {required this.ms, required this.seed});
  final String text;
  final double ms;
  final int seed;

  @override
  Widget build(BuildContext context) {
    // A flash of glow on impact.
    final glow = ms < 0 ? 0.0 : math.max(0.0, 1 - ms / 350);
    final style = headline(40, color: Palette.accent);
    final child = Text(
      text,
      style: glow == 0
          ? style
          : style.copyWith(
              shadows: [
                Shadow(
                  color: Palette.accent.withValues(alpha: 0.7 * glow),
                  blurRadius: 36,
                ),
              ],
            ),
    );
    if (ms < -_fall) {
      // Not yet: hold its place.
      return Visibility.maintain(visible: false, child: child);
    }
    double scale, opacity = 1, angle = 0;
    if (ms < 0) {
      // Coming down: from big and faint, accelerating, slightly askew.
      final f = Curves.easeIn.transform(1 + ms / _fall);
      scale = 2.6 - 1.6 * f;
      opacity = f;
      angle = (seed.isEven ? -1 : 1) * 0.06 * (1 - f);
    } else {
      // Landed: a squash into the page, springing back.
      final w = ms / 1000;
      scale = 1 - 0.07 * math.exp(-12 * w) * math.cos(2 * math.pi * 6 * w);
    }
    return CustomPaint(
      foregroundPainter: ms >= 0 ? _InkPainter(ms / 1000, seed) : null,
      child: Transform.rotate(
        angle: angle,
        child: Transform.scale(
          scale: scale,
          child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
        ),
      ),
    );
  }
}

/// The ink kicked out by a landing [w] seconds ago: an outline of the stamp
/// pushing outward and a spray of specks, both fading.
class _InkPainter extends CustomPainter {
  _InkPainter(this.w, this.seed);
  final double w;
  final int seed;

  static const _life = 0.6; // s

  @override
  void paint(Canvas canvas, Size size) {
    final f = (w / _life).clamp(0.0, 1.0);
    if (f >= 1) return;
    final out = Curves.easeOutCubic.transform(f);
    final rect = (Offset.zero & size).inflate(8 + 46 * out);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 * (1 - f)
        ..color = Palette.accent.withValues(alpha: 0.85 * (1 - f)),
    );
    final rng = math.Random(seed * 17 + 5);
    final c = size.center(Offset.zero);
    final speck = Paint()..color = Palette.accent.withValues(alpha: 1 - f);
    for (var i = 0; i < 18; i++) {
      // Specks leave from the stamp's edge and fly outward.
      final a = rng.nextDouble() * 2 * math.pi;
      final dir = Offset(math.cos(a), math.sin(a));
      final edge = Offset(dir.dx * size.width / 2, dir.dy * size.height / 2);
      final dist = (30 + rng.nextDouble() * 90) * out;
      canvas.drawCircle(
        c + edge + dir * dist,
        (4 + rng.nextDouble() * 7) * (1 - f),
        speck,
      );
    }
  }

  @override
  bool shouldRepaint(_InkPainter old) => old.w != w || old.seed != seed;
}
