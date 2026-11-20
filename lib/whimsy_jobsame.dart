import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// "Our jobs changed. / And stayed the same.": the first line's letters
/// jump up and trade places, twice, hopping over and under each other into
/// anagram gibberish. On the second shuffle three of them miss and drop
/// onto the line below, which doesn't budge: they bonk off it, squash, and
/// bounce back up. Then the first line sorts itself back into order. The
/// second line never moves a pixel. Runs once, settles in about 2.6s.
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
  late final TextStyle _style = headline(widget.size);
  late final _Letters _letters = _Letters(
    _lines[0],
    _lines[1],
    _style,
    pt(widget.size) * 0.3,
  );

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
              child: Text(
                _lines[1],
                textAlign: TextAlign.center,
                style: _style,
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
  _Letters(String text, String below, TextStyle style, double pad)
    : line = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout(),
      under = TextPainter(
        text: TextSpan(text: below, style: style),
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
    // Line two's cap height, in line one's coordinates: past this line's
    // own height and both paddings. Falling letters land on it.
    final m = under.computeLineMetrics().first;
    floor = line.height + 2 * pad + m.baseline - m.ascent * 0.72;
    // Each letter's ink bottom below its box top: the baseline, or lower
    // for g and j.
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
  final glyphs = <(TextPainter, Rect)>[];

  /// Letter i's center x after the first and second shuffles.
  late final List<double> first, second;
  late final List<double> delays, feet;
  late final double floor;

  Size get size => line.size;

  void dispose() {
    line.dispose();
    under.dispose();
    for (final g in glyphs) {
      g.$1.dispose();
    }
  }
}

/// Letters that miss on the second shuffle and land on line two: (index
/// among line one's letters, ms it starts to fall). j, g, d.
const _drops = {3: 1000.0, 11: 1080.0, 13: 1160.0};
const _fallMs = 300.0;

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
  /// down and under when going left, so letters pass instead of collide.
  static Offset _hop(double a, double b, double p) {
    final d = b - a;
    final lift = (18 + 0.22 * d.abs()).clamp(18.0, 90.0);
    return Offset(a + d * p, -d.sign * lift * math.sin(math.pi * p));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _totalMs;
    final n = l.glyphs.length;

    for (var i = 0; i < n; i++) {
      final (p, box) = l.glyphs[i];
      final d = l.delays[i];
      final x1 = l.first[i], x2 = l.second[i];
      var pos = Offset(box.center.dx, 0);
      var spin = 0.0;
      var squash = 1.0;
      final drop = _drops[i];

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
        pos = _hop(box.center.dx, x1, p1);
        spin = 0.25 * math.sin(math.pi * p1) * (i.isEven ? 1 : -1);
      } else if (drop != null && ms < _home.$1 + d) {
        // Falls from its first slot, lands on line two, bounces back up
        // to its second slot in time for the sort.
        final land = l.floor - l.feet[i]; // box top at contact
        final hit = drop + _fallMs;
        if (ms < hit) {
          final f = _ramp(ms, drop, hit);
          pos = Offset(x1 + (x2 - x1) * 0.25 * f, land * f * f);
          spin = 0.35 * f * (i.isEven ? 1 : -1);
        } else {
          final u = _ramp(ms, hit, _home.$1 + d);
          final up = Curves.easeOut.transform(u);
          // A rebound arc: up past its slot a little, then back to it.
          final y = land * (1 - up) - 40 * math.sin(math.pi * u);
          pos = Offset(x1 + (x2 - x1) * (0.25 + 0.75 * up), y);
          spin = 0.35 * (1 - up) * (i.isEven ? 1 : -1);
          // Squashes flat for a beat on contact.
          final c = _ramp(ms, hit, hit + 140);
          squash = 1 - 0.3 * math.sin(math.pi * c);
        }
      } else if (ms < _home.$1 + d) {
        pos = _hop(x1, x2, p2);
        spin = 0.25 * math.sin(math.pi * p2) * (i.isEven ? -1 : 1);
      } else {
        // Everyone sorts back home.
        final from = x2;
        final home = box.center.dx;
        final dd = home - from;
        final lift = (18 + 0.12 * dd.abs()).clamp(14.0, 56.0);
        final q = p3.clamp(0.0, 1.0);
        pos = Offset(from + dd * p3, -dd.sign * lift * math.sin(math.pi * q));
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

  /// Little strike lines where each letter hits line two: it took the hit.
  void _impacts(Canvas canvas, double ms) {
    for (final MapEntry(key: i, value: drop) in _drops.entries) {
      final hit = drop + _fallMs;
      final k = _ramp(ms, hit, hit + 360);
      if (k <= 0 || k >= 1) continue;
      final x = l.first[i] + (l.second[i] - l.first[i]) * 0.25;
      final y = l.floor - 4;
      final e = Curves.easeOut.transform(k);
      final paint = Paint()
        ..color = Palette.warn.withValues(alpha: 1 - k)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      for (final a in [-2.4, -1.9, -1.25, -0.7]) {
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(
          Offset(x, y) + dir * (34 + 22 * e),
          Offset(x, y) + dir * (52 + 34 * e),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ShufflePainter old) => old.t != t || old.l != l;
}
