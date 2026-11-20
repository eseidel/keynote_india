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

  @override
  void dispose() {
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
                foregroundPainter: done
                    ? null
                    : _RisingPainter(widget.title, titleStyle, ms),
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

class _RisingPainter extends CustomPainter {
  _RisingPainter(this.text, this.style, this.ms);
  final String text;
  final TextStyle style;
  final double ms;

  @override
  void paint(Canvas canvas, Size size) {
    // The whole title, for where each line sits; then each line on its own,
    // so a letter's clip never catches the line above it.
    final whole = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width + 1);
    final lineH = style.fontSize! * style.height!;
    final total = text.replaceAll(RegExp(r'\s'), '').length;
    var k = 0; // letters so far, across lines
    var at = 0; // index of this line's first character in [text]
    for (final line in text.split('\n')) {
      final top = line.isEmpty
          ? 0.0
          : whole
                .getBoxesForSelection(
                  TextSelection(baseOffset: at, extentOffset: at + 1),
                )
                .first
                .top;
      final tp = TextPainter(
        text: TextSpan(text: line, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width + 1);
      for (var i = 0; i < line.length; i++) {
        if (line[i].trim().isEmpty) continue;
        final start =
            _lettersFrom + (total < 2 ? 0 : _lettersSpread * k / (total - 1));
        k++;
        final u = ((ms - start) / _letterMs).clamp(0.0, 1.0);
        if (u == 0) continue;
        final e = Curves.easeOutCubic.transform(u);
        final boxes = tp.getBoxesForSelection(
          TextSelection(baseOffset: i, extentOffset: i + 1),
        );
        if (boxes.isEmpty) continue;
        // Clip to this letter's cell, so it rises out of its own baseline
        // (and neighbours, at their own heights, don't bleed into it).
        final clip = boxes.first.toRect().shift(Offset(0, top));
        final dy = lineH * 0.7 * (1 - e);
        canvas.save();
        canvas.clipRect(
          Rect.fromLTRB(
            clip.left,
            clip.top - lineH * 0.2,
            clip.right,
            clip.bottom,
          ),
        );
        if (u < 1) {
          canvas.saveLayer(
            clip.inflate(lineH),
            Paint()..color = Color.fromRGBO(0, 0, 0, (u * 2).clamp(0.0, 1.0)),
          );
          tp.paint(canvas, Offset(0, top + dy));
          canvas.restore();
        } else {
          tp.paint(canvas, Offset(0, top + dy));
        }
        canvas.restore();
      }
      tp.dispose();
      at += line.length + 1;
    }
    whole.dispose();
  }

  @override
  bool shouldRepaint(_RisingPainter old) =>
      old.ms != ms || old.text != text || old.style != style;
}
