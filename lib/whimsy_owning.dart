import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'theme.dart';

/// "Our jobs changed. / Owning what we build didn't.": the callback to
/// slide 51. Line one does the same shuffle (same seed, same gibberish):
/// its letters jump up and trade places twice, then sort back into order.
/// Line two holds still, and once line one has settled, a hand-drawn marker
/// loop circles "Owning": that part is ours. Runs once, settles in about
/// 3.3s.
class OwningStatement extends StatefulWidget {
  const OwningStatement(this.text, {super.key, this.size = 50});

  /// Two lines, split on '\n': the one that changes, the one that stays.
  /// The circle goes around line two's first word.
  final String text;
  final double size;

  @override
  State<OwningStatement> createState() => _OwningStatementState();
}

const _totalMs = 3300;

class _OwningStatementState extends State<OwningStatement>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  )..forward();

  late final List<String> _lines = widget.text.split('\n');
  late final TextStyle _style = headline(widget.size);
  late final _Letters _letters = _Letters(_lines[0], _style);
  late final _Loop _loop = _Loop(_lines[1], _style);

  @override
  void dispose() {
    _clock.dispose();
    _letters.dispose();
    super.dispose();
  }

  // Same layout as Statement: two centered lines with the same padding.
  @override
  Widget build(BuildContext context) {
    final pad = pt(widget.size) * 0.3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 160),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: pad),
              child: CustomPaint(
                size: _letters.size,
                painter: _ShufflePainter(_clock, _letters),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: pad),
              child: CustomPaint(
                painter: _LoopPainter(_clock, _loop), // under the letters
                child: Text(
                  _lines[1],
                  textAlign: TextAlign.center,
                  style: _style,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Line one cut into letters, each at the spot the whole line's layout gave
/// it, plus the shuffle plan: two seeded permutations of the letter slots.
/// Same seed as slide 51, so the gibberish is the same.
class _Letters {
  _Letters(String text, TextStyle style)
    : line = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout() {
    for (var i = 0; i < text.length; i++) {
      if (text[i] == ' ') continue;
      final box = line
          .getBoxesForSelection(
            TextSelection(baseOffset: i, extentOffset: i + 1),
          )
          .first
          .toRect();
      glyphs.add((
        TextPainter(
          text: TextSpan(text: text[i], style: style),
          textDirection: TextDirection.ltr,
        )..layout(),
        box,
      ));
    }
    final n = glyphs.length;
    final r = math.Random(51);
    first = _packed(text, style, _derange(n, r));
    second = _packed(text, style, _derange(n, r));
    delays = [for (var i = 0; i < n; i++) r.nextDouble() * 90];
    baseline = line.computeLineMetrics().first.baseline;
  }

  /// Where each letter's center sits when the letters are rearranged by
  /// [perm] (letter i to slot perm[i]) and set as real text, so the
  /// gibberish has proper spacing. Spaces stay where they were.
  List<double> _packed(String text, TextStyle style, List<int> perm) {
    final letters = text.replaceAll(' ', '');
    final bySlot = List.filled(letters.length, 0);
    for (var i = 0; i < perm.length; i++) {
      bySlot[perm[i]] = i;
    }
    final buf = StringBuffer();
    final slotAt = <int>[]; // string index of each slot
    var slot = 0;
    for (var i = 0; i < text.length; i++) {
      if (text[i] == ' ') {
        buf.write(' ');
      } else {
        slotAt.add(i);
        buf.write(letters[bySlot[slot++]]);
      }
    }
    final tp = TextPainter(
      text: TextSpan(text: buf.toString(), style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = (line.width - tp.width) / 2;
    final centers = [
      for (var i = 0; i < perm.length; i++)
        tp
                .getBoxesForSelection(
                  TextSelection(
                    baseOffset: slotAt[perm[i]],
                    extentOffset: slotAt[perm[i]] + 1,
                  ),
                )
                .first
                .toRect()
                .center
                .dx +
            dx,
    ];
    tp.dispose();
    return centers;
  }

  /// A shuffle where no letter stays put.
  static List<int> _derange(int n, math.Random r) {
    while (true) {
      final p = List.generate(n, (i) => i)..shuffle(r);
      var ok = true;
      for (var i = 0; i < n; i++) {
        if (p[i] == i) ok = false;
      }
      if (ok) return p;
    }
  }

  final TextPainter line;
  final glyphs = <(TextPainter, Rect)>[];

  /// Letter i's center x after the first and second shuffles.
  late final List<double> first, second;
  late final List<double> delays;
  late final double baseline;

  Size get size => line.size;

  void dispose() {
    line.dispose();
    for (final g in glyphs) {
      g.$1.dispose();
    }
  }
}

class _ShufflePainter extends CustomPainter {
  _ShufflePainter(this.t, this.l) : super(repaint: t);
  final Animation<double> t;
  final _Letters l;

  static double _ramp(double ms, double a, double b) =>
      ((ms - a) / (b - a)).clamp(0.0, 1.0);

  // Shuffle timeline (ms), as on slide 51.
  static const _one = (250.0, 760.0);
  static const _two = (1000.0, 1500.0);
  static const _home = (1750.0, 2450.0);

  /// A hop from [a] to [b]: up and over when going right, down and under
  /// when going left, so letters pass instead of collide.
  static Offset _hop(double a, double b, double p, {double max = 90}) {
    final d = b - a;
    final lift = (18 + 0.22 * d.abs()).clamp(14.0, max);
    return Offset(a + d * p, -d.sign * lift * math.sin(math.pi * p));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _totalMs;
    for (var i = 0; i < l.glyphs.length; i++) {
      final (p, box) = l.glyphs[i];
      final d = l.delays[i];
      final x1 = l.first[i], x2 = l.second[i];
      final Offset pos;
      var spin = 0.0;
      if (ms < _two.$1 + d) {
        final q = Curves.easeInOutCubic.transform(
          _ramp(ms, _one.$1 + d, _one.$2 + d),
        );
        pos = _hop(box.center.dx, x1, q);
        spin = 0.25 * math.sin(math.pi * q) * (i.isEven ? 1 : -1);
      } else if (ms < _home.$1 + d) {
        final q = Curves.easeInOutCubic.transform(
          _ramp(ms, _two.$1 + d, _two.$2 + d),
        );
        pos = _hop(x1, x2, q);
        spin = 0.25 * math.sin(math.pi * q) * (i.isEven ? -1 : 1);
      } else {
        // Everyone sorts back home, with a little overshoot.
        final q = Curves.easeOutBack.transform(
          _ramp(ms, _home.$1 + d, _home.$2 + d),
        );
        final dd = box.center.dx - x2;
        final lift = (18 + 0.12 * dd.abs()).clamp(14.0, 56.0);
        pos = Offset(
          x2 + dd * q,
          -dd.sign * lift * math.sin(math.pi * q.clamp(0.0, 1.0)),
        );
      }
      // Rotation only: the glyph scale stays 1, so Impeller reuses the
      // glyphs it already rasterized.
      final pivot = Offset(box.center.dx, l.baseline);
      canvas.save();
      canvas.translate(pos.dx, pivot.dy + pos.dy);
      if (spin != 0) canvas.rotate(spin);
      canvas.translate(-pivot.dx, -pivot.dy);
      p.paint(canvas, Offset(box.left, 0));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ShufflePainter old) => old.t != t || old.l != l;
}

/// A marker loop around line two's first word, built once: a little more
/// than one lap of a slightly tilted, slightly lumpy ellipse, starting at
/// the upper left and overshooting past where it began, the way a hand
/// circles a word.
class _Loop {
  _Loop(this.text, this.style);
  final String text;
  final TextStyle style;

  Size? _size;
  late PathMetric _metric;

  /// The loop for line two laid out at [size] (the Text's box; the line may
  /// wrap, as "didn't." does at 1920 wide). Built once per size.
  PathMetric metricFor(Size size) {
    if (_size != size) {
      _size = size;
      _metric = _build(size);
    }
    return _metric;
  }

  PathMetric _build(Size size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: size.width, maxWidth: size.width);
    final end = text.indexOf(' ');
    final word = tp
        .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: end))
        .fold<Rect?>(
          null,
          (a, b) => a?.expandToInclude(b.toRect()) ?? b.toRect(),
        )!;
    final m = tp.computeLineMetrics().first;
    tp.dispose();
    // Around the ink: cap height to just under the descenders.
    final ink = Rect.fromLTRB(
      word.left,
      m.baseline - m.ascent * 0.74,
      word.right,
      m.baseline + m.descent * 0.8,
    );
    final c = ink.center - const Offset(5, 0); // "what" is close on the right
    final rx = ink.width / 2 + 24, ry = ink.height / 2 + 24;
    const tilt = -0.025;
    const laps = 1.12;
    const start = -2.5; // radians: upper left
    final path = Path();
    const steps = 120;
    for (var s = 0; s <= steps; s++) {
      final f = s / steps;
      final a = start + f * laps * 2 * math.pi;
      // Lumps and a lap that doesn't close on itself: the second pass
      // runs a bit wider.
      final wob = 1 + 0.025 * math.sin(3 * a + 0.7) + 0.05 * f;
      // A squircle, not an ellipse, so it clears the word's corners
      // without bulging into the neighbors.
      final ca = math.cos(a), sa = math.sin(a);
      final x = ca.sign * math.pow(ca.abs(), 0.6) * rx * wob;
      final y = sa.sign * math.pow(sa.abs(), 0.6) * ry * wob;
      final p = Offset(
        c.dx + x * math.cos(tilt) - y * math.sin(tilt),
        c.dy + x * math.sin(tilt) + y * math.cos(tilt),
      );
      s == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path.computeMetrics().first;
  }
}

class _LoopPainter extends CustomPainter {
  _LoopPainter(this.t, this.loop) : super(repaint: t);
  final Animation<double> t;
  final _Loop loop;

  // Drawn after line one has settled.
  static const _draw = (2500.0, 3150.0);

  static final _ink = Paint()
    ..color = Palette.accent
    ..style = PaintingStyle.stroke
    ..strokeWidth = 7
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _totalMs;
    final f = ((ms - _draw.$1) / (_draw.$2 - _draw.$1)).clamp(0.0, 1.0);
    if (f <= 0) return;
    // A hand speeds up through the stroke and eases off at the end.
    final e = Curves.easeInOutSine.transform(f);
    final metric = loop.metricFor(size);
    canvas.drawPath(metric.extractPath(0, metric.length * e), _ink);
  }

  @override
  bool shouldRepaint(_LoopPainter old) => old.t != t || old.loop != loop;
}
