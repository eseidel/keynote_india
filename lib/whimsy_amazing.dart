import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// "Flutter is good with agents. It could be *amazing*.": the word amazing
/// gets its moment. It lifts, a bright shimmer sweeps through it, turning it
/// from white to the accent blue, and sparkles twinkle off the letters as the
/// sweep passes them. Then the glow fades and it settles, blue, at rest.
/// Plays once when the slide appears and settles in ~3s.
class AmazingStatement extends StatefulWidget {
  const AmazingStatement({
    super.key,
    required this.before,
    required this.lead,
    required this.word,
    this.size = 40,
  });

  /// The first line, then the start of the last line up to [word].
  final String before;
  final String lead;
  final String word;
  final double size;

  @override
  State<AmazingStatement> createState() => _AmazingStatementState();
}

const _totalMs = 3000;

class _AmazingStatementState extends State<AmazingStatement>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  )..forward();
  final _painters = _WordPainters();

  @override
  void dispose() {
    _clock.dispose();
    _painters.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = headline(widget.size);
    final italic = style.copyWith(fontStyle: FontStyle.italic);
    Widget line(Widget child) => Padding(
      padding: EdgeInsets.symmetric(vertical: pt(widget.size) * 0.3),
      child: child,
    );
    // Laid out like a three-line Statement (the middle line is a spacer).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 160),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            line(
              Text(widget.before, textAlign: TextAlign.center, style: style),
            ),
            line(Text('', style: style)),
            line(
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: widget.lead),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Holds the word's space and baseline; the painter
                          // draws it.
                          Text(
                            widget.word,
                            style: italic.copyWith(
                              color: const Color(0x00000000),
                            ),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _AmazingPainter(
                                _clock,
                                _painters..update(widget.word, italic),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                textAlign: TextAlign.center,
                style: style,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sparkles around the word: (x, y as fractions of the word box, size, delay
/// after the sweep passes x in ms). They pop as the shimmer reaches them.
const _sparkles = [
  (0.02, 0.10, 26.0, 0),
  (0.12, 0.95, 16.0, 80),
  (0.24, -0.08, 20.0, 40),
  (0.36, 1.02, 22.0, 120),
  (0.47, 0.02, 30.0, 0),
  (0.58, 0.90, 14.0, 60),
  (0.68, -0.12, 18.0, 100),
  (0.80, 0.98, 24.0, 30),
  (0.90, 0.05, 20.0, 140),
  (1.04, 0.30, 34.0, 60),
  (0.30, 0.40, 12.0, 220),
  (0.75, 0.45, 12.0, 260),
];

/// The word's painters, laid out once rather than every frame: the fill,
/// and the glow halo at a handful of strengths.
class _WordPainters {
  static const _glowSteps = 24;
  String? _word;
  TextStyle? _style;
  TextPainter? _fill;
  final _halos = <int, TextPainter>{};

  void update(String word, TextStyle style) {
    if (word == _word && style == _style) return;
    dispose();
    _word = word;
    _style = style;
  }

  TextPainter get fill => _fill ??= TextPainter(
    text: TextSpan(text: _word, style: _style),
    textDirection: TextDirection.ltr,
  )..layout();

  /// The blurred accent halo for [glow] in 0..1, in [_glowSteps] steps.
  TextPainter halo(double glow) {
    final step = (glow * _glowSteps).round();
    return _halos.putIfAbsent(step, () {
      final g = step / _glowSteps;
      return TextPainter(
        text: TextSpan(
          text: _word,
          style: _style!.copyWith(
            foreground: Paint()
              ..color = Palette.accent.withValues(alpha: 0.85 * g)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + 18 * g),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  void dispose() {
    _fill?.dispose();
    _fill = null;
    for (final h in _halos.values) {
      h.dispose();
    }
    _halos.clear();
  }
}

class _AmazingPainter extends CustomPainter {
  _AmazingPainter(this.t, this.painters) : super(repaint: t);
  final Animation<double> t;
  final _WordPainters painters;

  static double _ramp(double ms, double a, double b) =>
      ((ms - a) / (b - a)).clamp(0.0, 1.0);

  static const _sweepStart = 650.0;
  static const _sweepMs = 900.0;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _totalMs;
    final w = size.width;
    final h = size.height;
    final sweep = Curves.easeInOutSine.transform(
      _ramp(ms, _sweepStart, _sweepStart + _sweepMs),
    );
    // The band travels from just left of the word to just right of it.
    final band = -0.25 * w + sweep * 1.5 * w;
    final lift =
        Curves.easeOutCubic.transform(_ramp(ms, 450, 900)) *
        (1 - Curves.easeInOutCubic.transform(_ramp(ms, 1550, 2300)));
    final glow =
        Curves.easeOut.transform(_ramp(ms, 600, 1300)) *
        (1 - Curves.easeInOut.transform(_ramp(ms, 1500, 2700)));

    canvas.save();
    // Pivot on the right edge, so the lift never pushes the word into the
    // period after it.
    final c = Offset(w, h * 0.55);
    canvas.translate(c.dx, c.dy);
    canvas.scale(1 + 0.035 * lift);
    canvas.rotate(-0.012 * lift);
    canvas.translate(-c.dx, -c.dy - 10 * lift);

    if (glow > 0) painters.halo(glow).paint(canvas, Offset.zero);

    // The word, filled white ahead of the band and blue behind it, with a
    // bright edge where the band is.
    final area = (Offset.zero & size).inflate(40);
    canvas.saveLayer(area, Paint());
    painters.fill.paint(canvas, Offset.zero);
    final x0 = area.left;
    final x1 = area.right;
    double at(double x) => ((x - x0) / (x1 - x0)).clamp(0.0, 1.0);
    const shine = Color(0xFFFFFFFF);
    const lit = Color(0xFFB8EEFF);
    canvas.drawRect(
      area,
      Paint()
        ..blendMode = BlendMode.srcIn
        ..shader = ui.Gradient.linear(
          Offset(x0, 0),
          Offset(x1, 0),
          [
            Palette.accent,
            Palette.accent,
            lit,
            shine,
            Palette.text,
            Palette.text,
          ],
          [
            0,
            at(band - 0.22 * w),
            at(band - 0.06 * w),
            at(band),
            at(band + 0.05 * w),
            1,
          ],
        ),
    );
    canvas.restore();

    // A soft streak of light riding the band.
    if (sweep > 0 && sweep < 1) {
      final streak = math.sin(sweep * math.pi);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(band, h * 0.55),
          width: 60,
          height: h * 1.3,
        ),
        Paint()
          ..color = shine.withValues(alpha: 0.35 * streak)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
      );
    }
    canvas.restore();

    for (final (fx, fy, r, delay) in _sparkles) {
      // When the band reaches this x, plus a little stagger.
      final passFrac = ((fx * w + 0.25 * w) / (1.5 * w)).clamp(0.0, 1.0);
      final born = _sweepStart + _sweepMs * _sweepAt(passFrac) + delay;
      final k = _ramp(ms, born, born + 750);
      if (k <= 0 || k >= 1) continue;
      final pop = math.sin(k * math.pi); // grows then shrinks
      final p = Offset(fx * w, fy * h - 10 * lift);
      _star(canvas, p, r * pop, k * math.pi / 2, delay.isEven);
    }
  }

  /// Inverse of the sweep's easeInOutSine: the sweep fraction at which the
  /// band is [x] of the way along.
  static double _sweepAt(double x) => math.acos(1 - 2 * x) / math.pi;

  void _star(Canvas canvas, Offset p, double r, double spin, bool blue) {
    if (r <= 0.5) return;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(spin);
    final color = blue ? const Color(0xFFB8EEFF) : const Color(0xFFFFFFFF);
    canvas.drawCircle(
      Offset.zero,
      r * 0.9,
      Paint()
        ..color = Palette.accent.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
    );
    const k = 0.14;
    final star = Path()
      ..moveTo(0, -r)
      ..quadraticBezierTo(r * k, -r * k, r, 0)
      ..quadraticBezierTo(r * k, r * k, 0, r)
      ..quadraticBezierTo(-r * k, r * k, -r, 0)
      ..quadraticBezierTo(-r * k, -r * k, 0, -r)
      ..close();
    canvas.drawPath(star, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AmazingPainter old) =>
      old.t != t || old.painters != painters;
}
