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
///
/// The shuffle (`_Letters`, `_ShufflePainter`) is a deliberate copy of
/// slide 51's in whimsy_jobsame.dart, so either slide can land or change on
/// its own. The callback only works if both shuffle the same way: change
/// one, change the other.
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

  /// Whether line one's letters are off their spots (the painter draws
  /// them) or at rest (the Text does).
  bool _moving = false;

  @override
  void initState() {
    super.initState();
    _clock.addListener(() {
      final moving = _ShufflePainter.moving(_clock.value * _totalMs);
      if (moving != _moving) setState(() => _moving = moving);
    });
  }

  late final List<String> _lines = widget.text.split('\n');
  _Letters? _letters;
  _Loop? _loop;
  (TextStyle, TextScaler)? _builtFor;

  /// Measures with exactly what the line-two `Text` gets: the inherited
  /// default style merged with the headline style, and the text scale. So
  /// line one settles where a `Text` would put it, and the loop fits.
  void _measure(BuildContext context) {
    final style = DefaultTextStyle.of(context).style
        .merge(headline(widget.size));
    final scaler = MediaQuery.textScalerOf(context);
    if (_builtFor == (style, scaler)) return;
    _builtFor = (style, scaler);
    _letters?.dispose();
    _letters = _Letters(_lines[0], style, scaler);
    _loop = _Loop(_lines[1], style, scaler);
  }

  @override
  void dispose() {
    _clock.dispose();
    _letters?.dispose();
    super.dispose();
  }

  // Same layout as Statement: two centered lines with the same padding.
  @override
  Widget build(BuildContext context) {
    _measure(context);
    final pad = pt(widget.size) * 0.3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 160),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: pad),
              // At rest the line is the real Text, pixel for pixel what
              // Statement draws; while it shuffles, the painter draws the
              // letters and the Text is hidden.
              child: CustomPaint(
                foregroundPainter: _ShufflePainter(_clock, _letters!),
                child: Opacity(
                  opacity: _moving ? 0 : 1,
                  child: Text(
                    _lines[0],
                    textAlign: TextAlign.center,
                    style: headline(widget.size),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: pad),
              child: CustomPaint(
                // Over the letters, like a marker on the page; the loop's
                // shape keeps it clear of the ink.
                foregroundPainter: _LoopPainter(_clock, _loop!),
                child: Text(
                  _lines[1],
                  textAlign: TextAlign.center,
                  style: headline(widget.size),
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
  _Letters(String text, TextStyle style, this.scaler)
    : line = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
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
          // No letterSpacing on a lone letter: the paragraph puts the
          // spacing after each letter, inside its box, and a lone letter
          // with it would sit a pixel off its box.
          text: TextSpan(
            text: text[i],
            style: style.copyWith(letterSpacing: 0),
          ),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout(),
        box,
      ));
    }
    final n = glyphs.length;
    final r = math.Random(51);
    first = _packed(text, style, _derange(n, r));
    second = _packed(text, style, _derange(n, r));
    delays = [for (var i = 0; i < n; i++) r.nextDouble() * _maxDelay];
    // Each letter's ink bottom below its box top: the baseline, or lower
    // for g and j. Letters spin about it, as on slide 51.
    final lm = line.computeLineMetrics().first;
    final letters = text.replaceAll(' ', '');
    feet = [
      for (var i = 0; i < n; i++)
        lm.baseline + ('gjpqy'.contains(letters[i]) ? lm.descent * 0.8 : 0),
    ];
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
      textScaler: scaler,
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
  final TextScaler scaler;
  final glyphs = <(TextPainter, Rect)>[];

  /// Letter i's center x after the first and second shuffles.
  late final List<double> first, second;
  late final List<double> delays, feet;

  void dispose() {
    line.dispose();
    for (final g in glyphs) {
      g.$1.dispose();
    }
  }
}

/// Letters start each move up to this many ms apart.
const _maxDelay = 90.0;

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
  /// when going left, and each letter on one of three lanes (by [i]), so
  /// most pass each other. Going under stays shallow, clear of line two.
  static Offset _hop(double a, double b, double p, int i, {double k = 1}) {
    final d = b - a;
    final lift = k * (16 + 0.16 * d.abs() + 26 * (i % 3));
    final h = d >= 0 ? math.min(lift, 110.0 * k) : math.min(lift, 60.0 * k);
    return Offset(a + d * p, -d.sign * h * math.sin(math.pi * p));
  }

  /// Before the first hop and once the last letter is home, nothing moves.
  static bool moving(double ms) => ms > _one.$1 && ms < _home.$2 + _maxDelay;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _totalMs;
    if (!moving(ms)) return; // the Text is showing

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
        pos = _hop(box.center.dx, x1, q, i);
        spin = 0.25 * math.sin(math.pi * q) * (i.isEven ? 1 : -1);
      } else if (ms < _home.$1 + d) {
        final q = Curves.easeInOutCubic.transform(
          _ramp(ms, _two.$1 + d, _two.$2 + d),
        );
        pos = _hop(x1, x2, q, i);
        spin = 0.25 * math.sin(math.pi * q) * (i.isEven ? -1 : 1);
      } else {
        // Everyone sorts back home, with a little overshoot.
        final q = Curves.easeOutBack.transform(
          _ramp(ms, _home.$1 + d, _home.$2 + d),
        );
        final hop = _hop(x2, box.center.dx, q.clamp(0.0, 1.0), i, k: 0.5);
        pos = Offset(x2 + (box.center.dx - x2) * q, hop.dy);
      }
      // Rotation only: the glyph scale stays 1, so Impeller reuses the
      // glyphs it already rasterized.
      final pivot = Offset(box.center.dx, l.feet[i]);
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

/// A marker loop around line two's first word, built once per size: a
/// little more than one lap of a slightly lumpy squircle, starting at the
/// upper left and overshooting past where it began, the way a hand circles
/// a word.
class _Loop {
  _Loop(this.text, this.style, this.scaler);
  final String text;
  final TextStyle style;
  final TextScaler scaler;

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
      textScaler: scaler,
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
    // Around the ink: cap height down to the bottom of the g's tail.
    final ink = Rect.fromLTRB(
      word.left,
      m.baseline - m.ascent * 0.74,
      word.right,
      m.baseline + m.descent,
    );
    // Roomier on the left; "what" is close on the right, so the loop
    // clears the g by less there.
    final u = scaler.scale(1);
    final left = ink.left - 30 * u, right = ink.right + 10 * u;
    final c = Offset((left + right) / 2, ink.center.dy);
    final rx = (right - left) / 2, ry = ink.height / 2 + 28 * u;
    const laps = 1.12;
    const start = -2.5; // radians: upper left
    final path = Path();
    const steps = 160;
    for (var s = 0; s <= steps; s++) {
      final f = s / steps;
      final a = start + f * laps * 2 * math.pi;
      // Small lumps, and a lap that doesn't close on itself: the second
      // pass runs a bit wider. Lumps only push outward, so the loop never
      // dips into the word.
      final wob = 1 + 0.015 * (1 + math.sin(3 * a + 0.7)) + 0.05 * f;
      // A squircle (superellipse, n = 4), not an ellipse: an ellipse
      // that clears the word's corners would bulge into its neighbors.
      final ca = math.cos(a), sa = math.sin(a);
      final x = ca.sign * math.pow(ca.abs(), 0.5) * rx * wob;
      final y = sa.sign * math.pow(sa.abs(), 0.5) * ry * wob;
      final p = Offset(c.dx + x, c.dy + y);
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
