import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// "Flutter is the best we have.", said with conviction: a sheen of light
/// sweeps across the words, an accent underline draws itself under the
/// [emphasis] word, and the full stop lands last like a stamp, sending out
/// one ripple. Runs once when the slide appears and settles in about two
/// seconds on the headline with "best" underlined.
class BestStatement extends StatefulWidget {
  const BestStatement(
    this.text, {
    super.key,
    required this.emphasis,
    this.size = 50,
  });

  /// The headline, ending in the full stop that stamps down.
  final String text;

  /// The word that gets underlined.
  final String emphasis;
  final double size;

  @override
  State<BestStatement> createState() => _BestStatementState();
}

const _totalMs = 2100;

class _BestStatementState extends State<BestStatement>
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
  Widget build(BuildContext context) => Semantics(
    label: widget.text,
    child: CustomPaint(
      painter: _BestPainter(
        _clock,
        text: widget.text,
        emphasis: widget.emphasis,
        style: headline(widget.size),
        textScaler: MediaQuery.textScalerOf(context),
      ),
      child: const SizedBox.expand(),
    ),
  );
}

class _BestPainter extends CustomPainter {
  _BestPainter(
    this.t, {
    required this.text,
    required this.emphasis,
    required this.style,
    required this.textScaler,
  }) : super(repaint: t);
  final Animation<double> t;
  final String text;
  final String emphasis;
  final TextStyle style;
  final TextScaler textScaler;

  // Three copies of the same layout, built once per width rather than per
  // frame: the whole line, the line with its full stop transparent (before
  // the stamp), and only the full stop (the stamp itself). Hiding glyphs by
  // colour rather than by clipping keeps the neighbouring "e" whole.
  double? _width;
  late TextPainter _all, _noStop, _stopOnly;

  TextPainter _layout(TextSpan span, double maxWidth) => TextPainter(
    text: span,
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout(maxWidth: maxWidth);

  void _prepare(double maxWidth, bool hasStop) {
    if (_width == maxWidth) return;
    if (_width != null) {
      _all.dispose();
      _noStop.dispose();
      _stopOnly.dispose();
    }
    _width = maxWidth;
    final clear = style.copyWith(color: const Color(0x00000000));
    final words = hasStop ? text.substring(0, text.length - 1) : text;
    final stop = hasStop ? '.' : '';
    _all = _layout(TextSpan(text: text, style: style), maxWidth);
    _noStop = _layout(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: words),
          TextSpan(text: stop, style: clear),
        ],
      ),
      maxWidth,
    );
    _stopOnly = _layout(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: words, style: clear),
          TextSpan(text: stop),
        ],
      ),
      maxWidth,
    );
  }

  // Timeline (ms).
  static const _sheen = (150, 1050);
  static const _underline = (650, 1100);
  static const _stampAt = 1050, _stampMs = 200;
  static const _rippleMs = 700;

  static double _phase(double ms, (int, int) span) =>
      ((ms - span.$1) / (span.$2 - span.$1)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _totalMs;
    final hasStop = text.endsWith('.');
    // Laid out like a Statement: centred, wrapping inside its padding.
    _prepare(size.width - 320, hasStop);
    final tp = _all;
    final origin = Offset(
      (size.width - tp.width) / 2,
      (size.height - tp.height) / 2,
    );
    final bounds = origin & tp.size;
    Rect box(int from, int to) => tp
        .getBoxesForSelection(TextSelection(baseOffset: from, extentOffset: to))
        .first
        .toRect()
        .shift(origin);

    final stopBox = hasStop ? box(text.length - 1, text.length) : null;
    final stamped = !hasStop || ms >= _stampAt + _stampMs;

    // The words (the full stop held back until it stamps), with a sheen
    // of light sweeping across them.
    final words = stamped ? tp : _noStop;
    final sheen = _phase(ms, _sheen);
    if (sheen > 0 && sheen < 1) {
      canvas.saveLayer(bounds.inflate(40), Paint());
      words.paint(canvas, origin);
      final x =
          bounds.left -
          300 +
          (bounds.width + 600) * Curves.easeInOut.transform(sheen);
      canvas.drawRect(
        bounds.inflate(40),
        Paint()
          ..blendMode = BlendMode.srcATop
          ..shader =
              LinearGradient(
                colors: [
                  Palette.accent.withValues(alpha: 0),
                  const Color(0xFFBFEFFF),
                  Palette.accent.withValues(alpha: 0),
                ],
                transform: const GradientRotation(0.35),
              ).createShader(
                Rect.fromLTWH(x - 160, bounds.top, 320, bounds.height),
              ),
      );
      canvas.restore();
    } else {
      words.paint(canvas, origin);
    }

    // The underline under the emphasis word, drawn left to right.
    final at = text.indexOf(emphasis);
    final u = Curves.easeOutCubic.transform(_phase(ms, _underline));
    if (at >= 0 && u > 0) {
      final r = box(at, at + emphasis.length);
      final y = r.bottom - style.fontSize! * 0.06;
      final left = r.left + 4, right = r.right - 4;
      canvas.drawLine(
        Offset(left, y),
        Offset(left + (right - left) * u, y),
        Paint()
          ..color = Palette.accent
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round,
      );
    }

    // The full stop stamps down last, with one ripple.
    if (hasStop && ms >= _stampAt) {
      final r = stopBox!;
      // The dot's ink sits near the baseline, not in the middle of its box.
      final baseline = origin.dy + tp.computeLineMetrics().last.baseline;
      final dot = Offset(
        r.left + r.width * 0.42,
        baseline - style.fontSize! * 0.08,
      );
      if (!stamped) {
        final s = ((ms - _stampAt) / _stampMs).clamp(0.0, 1.0);
        final scale = 2.6 - 1.6 * Curves.easeIn.transform(s);
        canvas.save();
        canvas.translate(dot.dx, dot.dy);
        canvas.scale(scale);
        canvas.translate(-dot.dx, -dot.dy);
        canvas.saveLayer(
          r.inflate(8),
          Paint()..color = Color.fromRGBO(0, 0, 0, math.min(1, s * 2.5)),
        );
        _stopOnly.paint(canvas, origin);
        canvas.restore();
        canvas.restore();
      }
      final ripple = ((ms - _stampAt - _stampMs) / _rippleMs).clamp(0.0, 1.0);
      if (ripple > 0 && ripple < 1) {
        final re = Curves.easeOutCubic.transform(ripple);
        canvas.drawCircle(
          dot,
          14 + 110 * re,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * (1 - re) + 1
            ..color = Palette.accent.withValues(alpha: 0.8 * (1 - ripple)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BestPainter old) =>
      old.text != text ||
      old.emphasis != emphasis ||
      old.style != style ||
      old.textScaler != textScaler;
}
