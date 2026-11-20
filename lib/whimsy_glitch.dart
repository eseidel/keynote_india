import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// A Statement whose [wrong] line sits slightly askew and glitches for a
/// moment when the slide appears: the same confident bold as the lines
/// around it, just a little off. Laid out like a multi-line Statement.
class GlitchStatement extends StatefulWidget {
  const GlitchStatement(this.text, {super.key, required this.wrong});
  final String text;

  /// Index of the line that's wrong.
  final int wrong;

  @override
  State<GlitchStatement> createState() => _GlitchStatementState();
}

class _GlitchStatementState extends State<GlitchStatement>
    with SingleTickerProviderStateMixin {
  // 0.8s calm, ~0.7s of glitch, then it settles askew.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 50.0;
    final style = headline(size);
    final lines = widget.text.split('\n');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 160),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, line) in lines.indexed)
              Padding(
                padding: EdgeInsets.symmetric(vertical: pt(size) * 0.3),
                child: i == widget.wrong
                    ? AnimatedBuilder(
                        animation: _clock,
                        builder: (context, _) =>
                            _Glitch(line, style: style, t: _clock.value),
                      )
                    : Text(line, textAlign: TextAlign.center, style: style),
              ),
          ],
        ),
      ),
    );
  }
}

class _Glitch extends StatelessWidget {
  const _Glitch(this.line, {required this.style, required this.t});
  final String line;
  final TextStyle style;
  final double t; // 0..1 over 1.5s

  @override
  Widget build(BuildContext context) {
    // Askew: tilts in as the glitch starts and stays.
    final tilt = Curves.easeOut.transform(((t - 0.53) / 0.2).clamp(0.0, 1.0));
    final angle = -2.2 * math.pi / 180 * tilt;
    final offset = Offset(14 * tilt, 4 * tilt);
    // Glitch window: 0.8s..1.5s, strongest early, gone by the end.
    final g = t < 0.53 || t >= 1 ? 0.0 : 1 - (t - 0.53) / 0.47;
    // A deterministic shudder from the clock, so frames are repeatable.
    final frame = (t * 90).floor();
    final r = math.Random(frame);
    final split = g * (8 + 18 * r.nextDouble());
    final text = Text(line, textAlign: TextAlign.center, style: style);
    Widget ghost(Color c, double dx) => Transform.translate(
      offset: Offset(dx, 0),
      child: Text(
        line,
        textAlign: TextAlign.center,
        style: style.copyWith(color: c.withValues(alpha: 0.75)),
      ),
    );
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: g == 0
            ? text
            : Stack(
                alignment: Alignment.center,
                children: [
                  ghost(const Color(0xFFFF2D55), -split),
                  ghost(const Color(0xFF00E5FF), split),
                  // Two horizontal slices of the line, jolted sideways.
                  _Sliced(
                    slices: [
                      (r.nextDouble() * 0.6, 0.12 + 0.15 * r.nextDouble()),
                      (0.4 + r.nextDouble() * 0.5, 0.1 + 0.1 * r.nextDouble()),
                    ],
                    shifts: [
                      g * (r.nextDouble() * 60 - 30),
                      g * (r.nextDouble() * 60 - 30),
                    ],
                    child: text,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Paints [child] whole, except that each slice band (top fraction, height
/// fraction) is drawn shifted sideways by its shift.
class _Sliced extends StatelessWidget {
  const _Sliced({
    required this.slices,
    required this.shifts,
    required this.child,
  });
  final List<(double, double)> slices;
  final List<double> shifts;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      ClipPath(clipper: _Bands(slices, keep: false), child: child),
      for (final (i, s) in slices.indexed)
        Transform.translate(
          offset: Offset(shifts[i], 0),
          child: ClipPath(clipper: _Bands([s], keep: true), child: child),
        ),
    ],
  );
}

class _Bands extends CustomClipper<Path> {
  _Bands(this.bands, {required this.keep});
  final List<(double, double)> bands;
  final bool keep; // true: only the bands; false: everything but the bands

  @override
  Path getClip(Size size) {
    final b = Path();
    for (final (top, h) in bands) {
      b.addRect(
        Rect.fromLTWH(
          -200,
          top * size.height,
          size.width + 400,
          h * size.height,
        ),
      );
    }
    if (keep) return b;
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(
        Rect.fromLTWH(-200, -50, size.width + 400, size.height + 100),
      ),
      b,
    );
  }

  @override
  bool shouldReclip(_Bands old) => true;
}
