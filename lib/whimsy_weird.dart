import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// "The new world is weird": the line arrives straight, then comes loose.
/// Every letter floats on its own, bobbing and spinning as a ripple rolls
/// through the line, and a few flip clean over in 3D. Then it all drifts
/// back into place, mostly: the letters land a little off, and "weird" lands
/// the most off. Plays once when the slide appears and settles in ~4s.
class WeirdStatement extends StatefulWidget {
  const WeirdStatement(this.text, {super.key});
  final String text;

  @override
  State<WeirdStatement> createState() => _WeirdStatementState();
}

const _totalMs = 4200;

class _WeirdStatementState extends State<WeirdStatement>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  )..forward();

  late final _Glyphs _glyphs = _Glyphs(widget.text, headline(50));

  @override
  void dispose() {
    _clock.dispose();
    _glyphs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 160),
    child: Center(
      child: CustomPaint(
        size: _glyphs.size,
        painter: _WeirdPainter(_clock, _glyphs),
      ),
    ),
  );
}

/// The line laid out once, then cut into one painter per letter, each at the
/// spot the whole line's layout gave it (so kerning survives).
class _Glyphs {
  _Glyphs(String text, TextStyle style)
    : line = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout() {
    var word = 0;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == ' ') {
        word++;
        continue;
      }
      final box = line
          .getBoxesForSelection(
            TextSelection(baseOffset: i, extentOffset: i + 1),
          )
          .first
          .toRect();
      final p = TextPainter(
        text: TextSpan(text: ch, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      // Each letter's own bob: a fixed phase and frequency, seeded per index.
      final r = math.Random(glyphs.length * 31 + 7);
      glyphs.add((p, box, word));
      motion.add((r.nextDouble() * 2 * math.pi, 0.55 + 0.5 * r.nextDouble()));
    }
    lastWord = word;
  }

  final TextPainter line;
  final glyphs = <(TextPainter, Rect, int)>[]; // painter, box, word index
  final motion = <(double, double)>[]; // phase, freq
  late final int lastWord;

  Size get size => line.size;

  void dispose() {
    line.dispose();
    for (final g in glyphs) {
      g.$1.dispose();
    }
  }
}

/// Where each letter ends up: (rotation in degrees, dy in px). Most are a
/// hair off; the letters of "weird" (the last five) are visibly off.
const _restOther = [
  (0.0, 0.0), (1.2, -2.0), (-0.8, 1.0), // The
  (0.0, 1.5), (-1.5, 0.0), (1.0, -1.5), // new
  (0.6, 0.0), (-1.0, 2.0), (1.4, -1.0), (0.0, 1.0), (-0.8, -2.0), // world
  (1.6, -2.5), (-1.2, 1.0), // is
];
const _restWeird = [
  (-5.0, -3.0),
  (4.0, 6.0),
  (-3.0, -9.0),
  (7.5, 2.0),
  (-4.0, 5.0),
];

/// Letters that do a full 3D flip mid-float: (glyph index, start ms).
const _flips = {1: 1250, 4: 1500, 8: 1850, 11: 1350, 15: 2050};

class _WeirdPainter extends CustomPainter {
  _WeirdPainter(this.t, this.g) : super(repaint: t);
  final Animation<double> t;
  final _Glyphs g;

  static double _ramp(double ms, double a, double b) =>
      ((ms - a) / (b - a)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _totalMs;
    final s = ms / 1000;
    // Comes loose over 0.35..1.0s, floats, drifts home over 2.6..4.0s.
    final loose =
        Curves.easeInOut.transform(_ramp(ms, 350, 1000)) *
        (1 - Curves.easeInOutCubic.transform(_ramp(ms, 2600, 4000)));
    final settle = Curves.easeOutBack.transform(_ramp(ms, 2700, 4200));
    final n = g.glyphs.length;
    final weirdStart = n - _restWeird.length;
    for (var i = 0; i < n; i++) {
      final (p, box, word) = g.glyphs[i];
      final isWeird = word == g.lastWord;
      final (phase, freq) = g.motion[i];
      final amp = isWeird ? 1.35 : 1.0;
      // Zero-g bob, a ripple rolling left to right, a lazy spin and breathe.
      final ripple = math.sin(box.center.dx / 150 - s * 5.0);
      final dy =
          loose *
          amp *
          (34 * math.sin(2 * math.pi * freq * s + phase) + 22 * ripple);
      // The line also spreads a little, so floating letters don't pile up.
      final dx =
          loose *
          ((box.center.dx - size.width / 2) * 0.07 +
              amp * 6 * math.sin(2 * math.pi * freq * 0.7 * s + phase * 2));
      final spin =
          loose *
          amp *
          0.32 *
          math.sin(2 * math.pi * freq * 0.8 * s + phase + 1);
      final scale =
          1 +
          loose * amp * 0.14 * math.sin(2 * math.pi * freq * 1.3 * s + phase);
      final (restDeg, restDy) = i >= weirdStart
          ? _restWeird[i - weirdStart]
          : (i < _restOther.length ? _restOther[i] : (0.0, 0.0));
      final angle = spin + settle * restDeg * math.pi / 180;
      final y = dy + settle * restDy;

      var flip = 0.0;
      final flipAt = _flips[i];
      if (flipAt != null) {
        flip =
            Curves.easeInOutCubic.transform(
              _ramp(ms, flipAt.toDouble(), flipAt + 900.0),
            ) *
            2 *
            math.pi;
      }

      final c = Offset(box.center.dx, box.top + box.height * 0.58);
      canvas.save();
      canvas.translate(c.dx + dx, c.dy + y);
      if (flip != 0 && flip < 2 * math.pi) {
        canvas.transform(
          (Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateY(flip))
              .storage,
        );
      }
      canvas.rotate(angle);
      canvas.scale(scale);
      canvas.translate(-c.dx, -c.dy);
      p.paint(canvas, Offset(box.left, 0));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_WeirdPainter old) => old.t != t || old.g != g;
}
