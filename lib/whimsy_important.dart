import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// "AI makes Flutter more important, not less": the line arrives plain, then
/// "more important" swells, heavier and bigger with a springy overshoot, and
/// turns accent blue, while "less" deflates to a thin, small, muted word.
/// The weights move along the font's variable weight axis, so the letters
/// themselves get bolder and thinner. Plays once and settles in ~3s.
class ImportantStatement extends StatefulWidget {
  const ImportantStatement({super.key});

  @override
  State<ImportantStatement> createState() => _ImportantState();
}

const _totalMs = 2800;
const _size = 65.0;

class _ImportantState extends State<ImportantStatement>
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

  static double _ramp(double ms, double a, double b) =>
      ((ms - a) / (b - a)).clamp(0.0, 1.0);

  static const _swell = ElasticOutCurve(0.55);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 160),
    child: Center(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final ms = _clock.value * _totalMs;
          // More: springs up from 0.5s; less: deflates from 0.7s.
          final more = _swell.transform(_ramp(ms, 500, 2600));
          final less = Curves.easeInOutCubic.transform(_ramp(ms, 700, 1900));
          // A pulse of blue light as it swells, gone by the end.
          final glow =
              Curves.easeOut.transform(_ramp(ms, 500, 900)) *
              (1 - Curves.easeInOut.transform(_ramp(ms, 1100, 2700)));
          final moreStyle =
              zalando(
                lerpDouble(_size, 69, more)!,
                weight: lerpDouble(700, 900, more)!.clamp(100, 1000),
                color: Color.lerp(
                  Palette.text,
                  Palette.accent,
                  _ramp(ms, 500, 1100),
                )!,
              ).copyWith(
                shadows: [
                  if (glow > 0)
                    Shadow(
                      color: Palette.accent.withValues(alpha: 0.7 * glow),
                      blurRadius: 45,
                    ),
                ],
              );
          final lessStyle = zalando(
            lerpDouble(_size, 50, less)!,
            weight: lerpDouble(700, 300, less)!,
            color: Color.lerp(Palette.text, Palette.muted, less)!,
          );
          return Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'AI makes Flutter\n'),
                TextSpan(text: 'more important', style: moreStyle),
                const TextSpan(text: ',\nnot '),
                TextSpan(text: 'less', style: lessStyle),
              ],
            ),
            textAlign: TextAlign.center,
            // The lines are fixed, so nothing rewraps while words resize.
            softWrap: false,
            style: headline(_size),
          );
        },
      ),
    ),
  );
}
