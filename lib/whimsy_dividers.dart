import 'package:flutter/widgets.dart';

import 'theme.dart';

/// The section divider's entrance: the accent rule draws across, the
/// eyebrow slides in after it, and the title rises letter by letter out of
/// its own baseline, like type being set. Under a second, the same on every
/// divider, then it rests as the plain divider (eyebrow, rule, title).
class DividerEntrance extends StatefulWidget {
  const DividerEntrance({
    super.key,
    required this.eyebrow,
    required this.title,
  });
  final String eyebrow;
  final String title;

  @override
  State<DividerEntrance> createState() => _DividerEntranceState();
}

// Timeline, in ms from the slide appearing.
const _ruleAt = (40, 420);
const _eyebrowAt = (140, 520);
const _lettersFrom = 220; // first letter starts rising
const _lettersSpread = 380; // last letter starts this much later
const _letterMs = 360;
const _totalMs = _lettersFrom + _lettersSpread + _letterMs; // 960

class _DividerEntranceState extends State<DividerEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  )..forward();

  late _Letters _letters = _Letters(widget.title, headline(54));

  @override
  void didUpdateWidget(DividerEntrance old) {
    super.didUpdateWidget(old);
    if (old.title != widget.title) {
      _letters.dispose();
      _letters = _Letters(widget.title, headline(54));
    }
  }

  @override
  void dispose() {
    _letters.dispose();
    _clock.dispose();
    super.dispose();
  }

  /// 0..1 progress through [span] at [ms], eased out.
  static double _phase(double ms, (int, int) span) => Curves.easeOutCubic
      .transform(((ms - span.$1) / (span.$2 - span.$1)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final titleStyle = headline(54);
    return Padding(
      padding: const EdgeInsets.only(left: 242, right: 160),
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final ms = _clock.value * _totalMs;
          final rule = _phase(ms, _ruleAt);
          final eyebrow = _phase(ms, _eyebrowAt);
          final done = _clock.isCompleted;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Opacity(
                opacity: eyebrow,
                child: Transform.translate(
                  offset: Offset(-36 * (1 - eyebrow), 0),
                  child: Text(
                    widget.eyebrow.toUpperCase(),
                    style: zalando(
                      16,
                      weight: 700,
                      color: Palette.accent,
                    ).copyWith(letterSpacing: 4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // The rule's slot keeps its width; the bar grows inside it.
              SizedBox(
                width: 147,
                height: 4,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 147 * rule,
                    height: 4,
                    color: Palette.accent,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // At rest it's the plain Text; while rising, a painter draws
              // the same layout letter by letter over an invisible copy.
              CustomPaint(
                foregroundPainter: done ? null : _RisingPainter(_letters, ms),
                child: Opacity(
                  opacity: done ? 1 : 0,
                  child: Text(widget.title, style: titleStyle),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The title, laid out once: where each letter sits, plus one small painter
/// per (letter, fade step), so a frame only clips and paints glyphs.
class _Letters {
  _Letters(this.text, this.style);
  final String text;
  final TextStyle style;
  double? _width;
  final _cells = <({String glyph, Rect cell, int k})>[];
  final _glyphs = <(String, int), (TextPainter, double)>{};
  int _total = 0;

  static const fadeSteps = 10;

  void _layout(double width) {
    if (_width == width) return;
    _width = width;
    _cells.clear();
    final whole = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width + 1);
    var at = 0;
    for (final g in text.characters) {
      final end = at + g.length;
      if (g.trim().isNotEmpty) {
        final boxes = whole.getBoxesForSelection(
          TextSelection(baseOffset: at, extentOffset: end),
        );
        if (boxes.isNotEmpty) {
          _cells.add((glyph: g, cell: boxes.first.toRect(), k: _cells.length));
        }
      }
      at = end;
    }
    _total = _cells.length;
    whole.dispose();
  }

  /// [glyph] at fade [step] (of [fadeSteps]), and where its cell starts
  /// inside its own painter.
  (TextPainter, double) _glyph(String glyph, int step) =>
      _glyphs.putIfAbsent((glyph, step), () {
        final base = style.color ?? Palette.text;
        final tp = TextPainter(
          text: TextSpan(
            text: glyph,
            style: style.copyWith(
              color: base.withValues(alpha: base.a * step / fadeSteps),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final boxes = tp.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: glyph.length),
        );
        return (tp, boxes.isEmpty ? 0.0 : boxes.first.left);
      });

  void paint(Canvas canvas, Size size, double ms) {
    _layout(size.width);
    final lineH = style.fontSize! * style.height!;
    for (final c in _cells) {
      final start =
          _lettersFrom + (_total < 2 ? 0 : _lettersSpread * c.k / (_total - 1));
      final u = ((ms - start) / _letterMs).clamp(0.0, 1.0);
      if (u == 0) continue;
      final e = Curves.easeOutCubic.transform(u);
      final step = ((u * 2).clamp(0.0, 1.0) * fadeSteps).ceil();
      final (tp, left) = _glyph(c.glyph, step);
      final dy = lineH * 0.7 * (1 - e);
      // Clip at the cell's bottom, so the letter rises out of its own
      // baseline; only this glyph is drawn, so the sides can be generous.
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(
          c.cell.left - lineH * 0.3,
          c.cell.top - lineH * 0.2,
          c.cell.right + lineH * 0.3,
          c.cell.bottom,
        ),
      );
      tp.paint(canvas, Offset(c.cell.left - left, c.cell.top + dy));
      canvas.restore();
    }
  }

  void dispose() {
    for (final (tp, _) in _glyphs.values) {
      tp.dispose();
    }
    _glyphs.clear();
  }
}

class _RisingPainter extends CustomPainter {
  _RisingPainter(this.letters, this.ms);
  final _Letters letters;
  final double ms;

  @override
  void paint(Canvas canvas, Size size) => letters.paint(canvas, size, ms);

  @override
  bool shouldRepaint(_RisingPainter old) =>
      old.ms != ms || old.letters != letters;
}
