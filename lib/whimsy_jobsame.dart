import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// "Our jobs changed. / And stayed the same.": the first line's letters
/// jump up and trade places, twice, hopping over and under each other into
/// anagram gibberish. On the second shuffle three of them miss and drop
/// onto the line below, which doesn't budge: they land on its letters,
/// squash, and bounce back up. Then the first line sorts itself back into
/// order. The second line never moves a pixel. Runs once, settles in about
/// 2.6s.
///
/// Slide 59 (whimsy_owning.dart) has a deliberate copy of this shuffle
/// (`_Letters`, `_ShufflePainter`, minus the drops), so either slide can
/// land or change on its own. The callback only works if both shuffle the
/// same way: change one, change the other.
class JobsSameStatement extends StatefulWidget {
  const JobsSameStatement(this.text, {super.key, this.size = 50});

  /// Two lines, split on '\n': the one that changes, the one that stays.
  final String text;
  final double size;

  @override
  State<JobsSameStatement> createState() => _JobsSameStatementState();
}

const _totalMs = 2700;

class _JobsSameStatementState extends State<JobsSameStatement>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  )..forward();

  late final List<String> _lines = widget.text.split('\n');
  _Letters? _letters;
  (TextStyle, TextScaler)? _builtFor;

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

  /// Measures with exactly what the `Text`s get: the inherited default
  /// style merged with the headline style, and the text scale.
  void _measure(BuildContext context) {
    final style = DefaultTextStyle.of(context).style
        .merge(headline(widget.size));
    final scaler = MediaQuery.textScalerOf(context);
    if (_builtFor == (style, scaler)) return;
    _builtFor = (style, scaler);
    _letters?.dispose();
    _letters = _Letters(
      _lines[0],
      _lines[1],
      style,
      scaler,
      pt(widget.size) * 0.3,
    );
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
              // letters (and the hits) and the Text is hidden.
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
              child: Text(
                _lines[1],
                textAlign: TextAlign.center,
                style: headline(widget.size),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Line one cut into letters, each at the spot the whole line's layout gave
/// it, plus the shuffle plan: two seeded permutations of the letter slots,
/// and which letters fall onto line two.
class _Letters {
  _Letters(String text, String below, TextStyle style, this.scaler, double pad)
    : line = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout(),
      under = TextPainter(
        text: TextSpan(text: below, style: style),
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
    // for descenders (g, j, p, q, y).
    final lm = line.computeLineMetrics().first;
    final letters = text.replaceAll(' ', '');
    feet = [
      for (var i = 0; i < n; i++)
        lm.baseline + ('gjpqy'.contains(letters[i]) ? lm.descent * 0.8 : 0),
    ];
    // Where each falling letter lands: the top of the ink of line two's
    // letters under its foot (caps and ascenders stand taller than the
    // x-height), in line one's coordinates.
    final m = under.computeLineMetrics().first;
    final top = line.height + 2 * pad + m.baseline; // line two's baseline
    final shift = (line.width - under.width) / 2;
    final boxes = [
      for (var c = 0; c < below.length; c++)
        under
            .getBoxesForSelection(
              TextSelection(baseOffset: c, extentOffset: c + 1),
            )
            .first
            .toRect()
            .shift(Offset(shift, 0)),
    ];
    double inkTop(String ch) {
      if (ch == ' ') return top;
      if (ch == '.') return top - m.ascent * 0.14;
      if (ch == 't') return top - m.ascent * 0.64;
      if (ch.toUpperCase() == ch || 'bdfhkl'.contains(ch)) {
        return top - m.ascent * 0.74;
      }
      return top - m.ascent * 0.54; // x-height
    }

    for (final i in _drops.keys) {
      final x = contactX(i);
      final half = glyphs[i].$2.width * 0.4;
      var y = top;
      for (var c = 0; c < below.length; c++) {
        final b = boxes[c];
        if (b.right > x - half && b.left < x + half) {
          y = math.min(y, inkTop(below[c]));
        }
      }
      floors[i] = y;
    }
  }

  /// Where letter [i] meets line two: a quarter of the way from its first
  /// slot to its second.
  double contactX(int i) => first[i] + (second[i] - first[i]) * 0.25;

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

  final TextPainter line, under;
  final TextScaler scaler;
  final glyphs = <(TextPainter, Rect)>[];

  /// Letter i's center x after the first and second shuffles.
  late final List<double> first, second;
  late final List<double> delays, feet;
  final floors = <int, double>{};

  void dispose() {
    line.dispose();
    under.dispose();
    for (final g in glyphs) {
      g.$1.dispose();
    }
  }
}

/// Letters that miss on the second shuffle and land on line two: (index
/// among line one's letters, ms after its own delay that it starts to
/// fall). j, g, d.
const _drops = {3: 1000.0, 11: 1080.0, 13: 1160.0};
const _fallMs = 300.0;

/// Letters start each move up to this many ms apart.
const _maxDelay = 90.0;

class _ShufflePainter extends CustomPainter {
  _ShufflePainter(this.t, this.l) : super(repaint: t);
  final Animation<double> t;
  final _Letters l;

  static double _ramp(double ms, double a, double b) =>
      ((ms - a) / (b - a)).clamp(0.0, 1.0);

  // Shuffle timeline (ms).
  static const _one = (250.0, 760.0);
  static const _two = (1000.0, 1500.0);
  static const _home = (1750.0, 2450.0);

  /// A hop from slot center [a] to [b]: up and over when going right,
  /// down and under when going left, and each letter on one of three
  /// lanes (by [i]), so most pass each other. Going under stays shallow,
  /// clear of line two.
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
    final n = l.glyphs.length;

    for (var i = 0; i < n; i++) {
      final (p, box) = l.glyphs[i];
      final d = l.delays[i];
      final x1 = l.first[i], x2 = l.second[i];
      var pos = Offset(box.center.dx, 0);
      var spin = 0.0;
      var squash = 1.0;
      // Each falling letter's fall starts after its own delay, so it
      // leaves its first slot from rest.
      final drop = _drops[i] == null ? null : _drops[i]! + d;

      final p1 = Curves.easeInOutCubic.transform(
        _ramp(ms, _one.$1 + d, _one.$2 + d),
      );
      final p2 = Curves.easeInOutCubic.transform(
        _ramp(ms, _two.$1 + d, _two.$2 + d),
      );
      final p3 = Curves.easeOutBack.transform(
        _ramp(ms, _home.$1 + d, _home.$2 + d),
      );

      if (ms < _two.$1 + d || (drop != null && ms < drop)) {
        pos = _hop(box.center.dx, x1, p1, i);
        spin = 0.25 * math.sin(math.pi * p1) * (i.isEven ? 1 : -1);
      } else if (drop != null && ms < _home.$1 + d) {
        // Falls from its first slot, lands on line two, bounces back up
        // to its second slot in time for the sort.
        final land = l.floors[i]! - l.feet[i]; // box top at contact
        final hit = drop + _fallMs;
        if (ms < hit) {
          final f = _ramp(ms, drop, hit);
          pos = Offset(x1 + (l.contactX(i) - x1) * f, land * f * f);
          spin = 0.35 * f * (i.isEven ? 1 : -1);
        } else {
          final u = _ramp(ms, hit, _home.$1 + d);
          final up = Curves.easeOut.transform(u);
          // A rebound arc: up past its slot a little, then back to it.
          final y = land * (1 - up) - 40 * math.sin(math.pi * u);
          pos = Offset(l.contactX(i) + (x2 - l.contactX(i)) * up, y);
          spin = 0.35 * (1 - up) * (i.isEven ? 1 : -1);
          // Squashes flat for a beat on contact.
          final c = _ramp(ms, hit, hit + 140);
          squash = 1 - 0.3 * math.sin(math.pi * c);
        }
      } else if (ms < _home.$1 + d) {
        pos = _hop(x1, x2, p2, i);
        spin = 0.25 * math.sin(math.pi * p2) * (i.isEven ? -1 : 1);
      } else {
        // Everyone sorts back home.
        final hop = _hop(x2, box.center.dx, p3.clamp(0.0, 1.0), i, k: 0.5);
        pos = Offset(x2 + (box.center.dx - x2) * p3, hop.dy);
      }

      // Draw centered on its own box, moved to [pos]. Squash pivots on the
      // ink bottom so it flattens against the line it hit.
      final dx = pos.dx - box.center.dx;
      canvas.save();
      final pivot = Offset(box.center.dx, l.feet[i]);
      canvas.translate(pivot.dx + dx, pivot.dy + pos.dy);
      if (spin != 0) canvas.rotate(spin);
      // Only ever shrinks one axis: the max scale stays 1, so Impeller
      // keeps using the glyphs it already rasterized.
      if (squash != 1) canvas.scale(1, squash);
      canvas.translate(-pivot.dx, -pivot.dy);
      p.paint(canvas, Offset(box.left, 0));
      canvas.restore();
    }

    _impacts(canvas, ms);
  }

  /// Little strike lines where each letter hits line two: short dashes
  /// fanning out sideways along the line's top, gone by the time the
  /// letter is back up.
  void _impacts(Canvas canvas, double ms) {
    for (final MapEntry(key: i, value: drop) in _drops.entries) {
      final hit = drop + l.delays[i] + _fallMs;
      final k = _ramp(ms, hit, hit + 220);
      if (k <= 0 || k >= 1) continue;
      final at = Offset(l.contactX(i), l.floors[i]! - 2);
      final half = l.glyphs[i].$2.width * 0.4;
      final e = Curves.easeOut.transform(k);
      final paint = Paint()
        ..color = Palette.warn.withValues(alpha: 1 - k)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      for (final side in [-1.0, 1.0]) {
        for (final a in [0.18, 0.55]) {
          final dir = Offset(side * math.cos(a), -math.sin(a));
          final from = at + Offset(side * half, 0) + dir * (6 + 14 * e);
          canvas.drawLine(from, from + dir * 16, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ShufflePainter old) => old.t != t || old.l != l;
}
