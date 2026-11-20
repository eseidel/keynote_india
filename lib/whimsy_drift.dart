import 'package:flutter/material.dart';

import 'theme.dart';

/// "Two copies drift": the statement over two checkout buttons, iOS and
/// Android, identical when the slide appears. Over a few seconds the Android
/// copy drifts: its corners square off, its label slides off center, and its
/// price ends up a rupee off. Then it holds, wrong.
class DriftSlide extends StatefulWidget {
  const DriftSlide(this.text, {super.key});
  final String text;

  @override
  State<DriftSlide> createState() => _DriftSlideState();
}

class _DriftSlideState extends State<DriftSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..forward();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 160),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.text,
            textAlign: TextAlign.center,
            style: headline(50),
          ),
          const SizedBox(height: 110),
          AnimatedBuilder(
            animation: _drift,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Copy(platform: 'iOS', drift: _Drift.none),
                const SizedBox(width: 140),
                _Copy(platform: 'Android', drift: _Drift.at(_drift.value)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// How far one copy has drifted, each change on its own stretch of time so
/// they land one after another rather than all at once.
class _Drift {
  const _Drift(this.squareness, this.shift, this.rupeeOff);
  static const none = _Drift(0, 0, false);

  factory _Drift.at(double t) {
    double ease(double begin, double end) => Curves.easeInOut.transform(
      ((t - begin) / (end - begin)).clamp(0.0, 1.0),
    );
    return _Drift(ease(0.12, 0.42), ease(0.38, 0.66), t >= 0.8);
  }

  final double squareness; // 0 rounded like iOS, 1 nearly square
  final double shift; // 0 centered, 1 label pushed right
  final bool rupeeOff;
}

class _Copy extends StatelessWidget {
  const _Copy({required this.platform, required this.drift});
  final String platform;
  final _Drift drift;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        platform.toUpperCase(),
        style: zalando(
          14,
          weight: 700,
          color: Palette.muted,
        ).copyWith(letterSpacing: 3),
      ),
      const SizedBox(height: 28),
      Container(
        width: 480,
        height: 120,
        decoration: BoxDecoration(
          color: Palette.accent,
          borderRadius: BorderRadius.circular(60 - 54 * drift.squareness),
        ),
        child: Align(
          alignment: Alignment(0.28 * drift.shift, 0.1 * drift.shift),
          child: Text(
            drift.rupeeOff ? 'Pay ₹1,298' : 'Pay ₹1,299',
            style: zalando(24, weight: 700, color: Palette.background),
          ),
        ),
      ),
    ],
  );
}
