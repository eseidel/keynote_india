import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'layouts.dart' show Statement;
import 'theme.dart';

/// "Half a million lines. One person. One month." with the half million
/// counted out: under the first line an odometer races from 000,000 to
/// 500,000, its fast digits a blur that sharpens left to right as it
/// eases to a stop, while faint code streams up behind the text at the
/// counter's speed and slows with it. Settles in under four seconds.
class HalfMillion extends StatefulWidget {
  const HalfMillion(this.text, {super.key});
  final String text;

  @override
  State<HalfMillion> createState() => _HalfMillionState();
}

const _lines = 500000;
const _startMs = 350, _runMs = 3300, _totalMs = _startMs + _runMs;

class _HalfMillionState extends State<HalfMillion>
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

  /// Progress 0..1 (an ease-out quartic: fast off the line, a long glide in)
  /// and its rate, in progress per second.
  static (double, double) _progress(double ms) {
    final x = ((ms - _startMs) / _runMs).clamp(0.0, 1.0);
    final p = 1 - math.pow(1 - x, 4).toDouble();
    final rate = x >= 1 ? 0.0 : 4 * math.pow(1 - x, 3) / (_runMs / 1000);
    return (p, rate.toDouble());
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(child: CustomPaint(painter: _StreamPainter(_clock))),
      Statement(
        widget.text,
        below: {
          0: AnimatedBuilder(
            animation: _clock,
            builder: (context, _) {
              final (p, rate) = _progress(_clock.value * _totalMs);
              // Land exactly on the number.
              final v = p >= 1 ? _lines.toDouble() : _lines * p;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _Odometer(value: v, rate: _lines * rate),
              );
            },
          ),
        },
      ),
    ],
  );
}

/// "500,000" with rolling digits. [rate] is lines per second; digits
/// moving faster than the eye can read smear vertically.
class _Odometer extends StatelessWidget {
  const _Odometer({required this.value, required this.rate});
  final double value;
  final double rate;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: _OdometerPainter.size,
    painter: _OdometerPainter(value, rate),
  );
}

class _OdometerPainter extends CustomPainter {
  _OdometerPainter(this.value, this.rate);
  final double value;
  final double rate;

  static final _style = zalando(30, weight: 700, color: Palette.accent);
  static List<TextPainter> _set(TextStyle style) => [
    for (var d = 0; d < 10; d++)
      TextPainter(
        text: TextSpan(text: '$d', style: style),
        textDirection: TextDirection.ltr,
      )..layout(),
  ];
  static final _digits = _set(_style);
  static final _comma = TextPainter(
    text: TextSpan(text: ',', style: _style),
    textDirection: TextDirection.ltr,
  )..layout();
  static final double _slot = _digits.map((d) => d.width).reduce(math.max) + 2;
  static final double _h = _digits.first.height;
  static final size = Size(6 * _slot + _comma.width, _h);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    // Rolls like a real odometer: a digit turns only while the one to its
    // right turns from 9 to 0.
    final rolls = List.filled(6, 0.0);
    final digits = List.filled(6, 0);
    var roll = value - value.floor();
    for (var i = 0; i < 6; i++) {
      final p = math.pow(10, i).toDouble();
      digits[i] = (value / p).floor() % 10;
      if (i > 0) roll = digits[i - 1] == 9 ? roll : 0;
      rolls[i] = roll;
    }
    var x = 0.0;
    for (var col = 0; col < 6; col++) {
      final i = 5 - col; // place value, left to right
      if (col == 3) {
        _comma.paint(canvas, Offset(x, 0));
        x += _comma.width;
      }
      final pos = digits[i] + rolls[i];
      // Digits per second this column turns, on average.
      final speed = rate / math.pow(10, i);
      _strip(canvas, x, pos, speed);
      x += _slot;
    }
  }

  /// Draws the digit wheel at [pos] (a continuous digit, 3.5 = halfway from
  /// 3 to 4), blurred vertically by how fast it turns: a digit spinning
  /// faster than the eye can follow is a soft smear.
  void _strip(Canvas canvas, double x, double pos, double speed) {
    final blur = (speed / 40).clamp(0.0, 1.2) * _h * 0.3; // sigma, px
    final slot = Rect.fromLTWH(x, 0, _slot, _h);
    if (blur > 0.3) {
      canvas.saveLayer(
        slot.inflate(4),
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaY: blur),
      );
    }
    final base = pos.floor();
    final f = pos - base;
    // The wheel: the digit going out the top, the next coming in below, and
    // the ones after it for the blur to smear in.
    for (var k = -1; k < 3; k++) {
      final d = _digits[(base + k) % 10];
      d.paint(canvas, Offset(x + (_slot - d.width) / 2, (k - f) * _h));
    }
    if (blur > 0.3) canvas.restore();
  }

  @override
  bool shouldRepaint(_OdometerPainter old) =>
      old.value != value || old.rate != rate;
}

/// Faint code (minimap bars) streaming up behind the slide, scrolled by the
/// counter so it races and glides to a stop with it; streaks when fast.
class _StreamPainter extends CustomPainter {
  _StreamPainter(this.clock) : super(repaint: clock);
  final Animation<double> clock;

  static const _rowH = 12.0, _pitch = 26.0, _scroll = 60000.0;
  static const _colors = [
    Palette.accent,
    Palette.statBlue,
    Palette.soft,
    Color(0xFFC792EA),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final ms = clock.value * _totalMs;
    final (p, rate) = _HalfMillionState._progress(ms);
    final offset = p * _scroll;
    final speed = rate * _scroll; // px per second
    // Brighter while it races, settling to a whisper of texture.
    final appear = (ms / 400).clamp(0.0, 1.0);
    final alpha = appear * (0.035 + 0.14 * (speed / 70000).clamp(0.0, 1.0));
    final streak = (speed / 60).clamp(0.0, _pitch * 3); // px of smear
    const columns = 4;
    final colW = size.width / columns;
    final first = (offset / _pitch).floor() - 2;
    final rows = (size.height / _pitch).ceil() + 4;
    for (var c = 0; c < columns; c++) {
      for (var r = 0; r < rows; r++) {
        final n = first + r;
        final y = n * _pitch - offset;
        if (y < -_pitch * 4 || y > size.height + _pitch) continue;
        final rng = math.Random(n * 7919 + c * 104729);
        final indent = rng.nextInt(4);
        final tokens = rng.nextDouble() < 0.12 ? 0 : 1 + rng.nextInt(4);
        var x = c * colW + 60 + indent * 30.0;
        for (var t = 0; t < tokens; t++) {
          final w = 20 + rng.nextDouble() * 110;
          if (x + w > (c + 1) * colW - 40) break;
          final color = _colors[rng.nextInt(_colors.length)];
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, w, _rowH + streak),
              const Radius.circular(6),
            ),
            Paint()
              ..color = color.withValues(
                alpha: alpha * _rowH / (_rowH + streak * 0.6),
              ),
          );
          x += w + 10;
        }
      }
    }
  }

  @override
  bool shouldRepaint(_StreamPainter old) => false;
}
