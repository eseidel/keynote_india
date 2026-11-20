import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// "AI makes Flutter more important, not less": the line arrives plain, then
/// "more important" swells, heavier and bigger with a springy overshoot, and
/// turns accent blue, while "less" deflates to a thin, small, muted word.
/// The weights move along the font's variable weight axis, so the letters
/// themselves get bolder and thinner. Plays once and settles in ~3s.
class ImportantStatement extends StatefulWidget {
  /// Renders `lead`, then [more] + "," on its own line, then [rest] + [less].
  const ImportantStatement({
    super.key,
    required this.lead,
    required this.more,
    required this.rest,
    required this.less,
  });

  final String lead;
  final String more;
  final String rest;
  final String less;

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

  /// Sizes and weights move in steps: every new (size, weight) is a fresh
  /// set of glyphs for Impeller's atlas, and a smooth ramp makes hundreds,
  /// which overflows it and drops the text for a frame.
  static double _step(double v, double by) => (v / by).roundToDouble() * by;

  /// The span at time [ms]; [ms] past the end gives the settled line.
  TextSpan _span(double ms) {
    // More: springs up from 0.5s; less: deflates from 0.7s.
    final more = _swell.transform(_ramp(ms, 500, 2600));
    final less = Curves.easeInOutCubic.transform(_ramp(ms, 700, 1900));
    // A pulse of blue light as it swells, gone by the end.
    final glow =
        Curves.easeOut.transform(_ramp(ms, 500, 900)) *
        (1 - Curves.easeInOut.transform(_ramp(ms, 1100, 2700)));
    final moreStyle =
        zalando(
          _step(lerpDouble(_size, 69, more)!, 0.5),
          weight: _step(lerpDouble(700, 900, more)!.clamp(100, 1000), 50),
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
      _step(lerpDouble(_size, 50, less)!, 0.5),
      weight: _step(lerpDouble(700, 300, less)!, 50),
      color: Color.lerp(Palette.text, Palette.muted, less)!,
    );
    return TextSpan(
      style: headline(_size),
      children: [
        TextSpan(text: '${widget.lead}\n'),
        // The comma belongs to the word it follows, so it swells with it.
        TextSpan(text: '${widget.more},', style: moreStyle),
        TextSpan(text: '\n${widget.rest} '),
        TextSpan(text: widget.less, style: lessStyle),
      ],
    );
  }

  /// Height of the settled text. The block is pinned to it, top-aligned, so
  /// the first line holds still while the middle line springs.
  late final double _settledHeight = (TextPainter(
    text: _span(_totalMs + 1.0),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout()).height;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 160),
    child: Center(
      child: SizedBox(
        height: _settledHeight,
        child: Align(
          alignment: Alignment.topCenter,
          child: AnimatedBuilder(
            animation: _clock,
            builder: (context, _) => Text.rich(
              _span(_clock.value * _totalMs),
              textAlign: TextAlign.center,
              // The lines are fixed, so nothing rewraps while words resize,
              // and the spring's overshoot may paint past the pinned box.
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
        ),
      ),
    ),
  );
}
