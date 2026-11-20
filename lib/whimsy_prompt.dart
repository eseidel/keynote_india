import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// The opening question, being prompted: a chat composer box where the
/// question types itself in at a human pace (quicker within words, a beat
/// at the spaces) behind a blinking caret, and the send button lights up
/// once there's something to send. Settles in about five seconds with the
/// whole question in the box, caret resting at the end.
class PromptBox extends StatefulWidget {
  const PromptBox(this.text, {super.key, this.placeholder = 'Ask anything'});
  final String text;
  final String placeholder;

  @override
  State<PromptBox> createState() => _PromptBoxState();
}

const _typeStart = 700; // ms: the empty box shows first
const _blinkAfter = 1300; // ms of caret blinking once typed
const _caretGap = 4.0; // px between the last character and the caret
const _caretWidth = 5.0;

class _PromptBoxState extends State<PromptBox>
    with SingleTickerProviderStateMixin {
  /// When (ms) each character appears: a typist's rhythm, deterministic.
  late final List<int> _at = () {
    final rng = math.Random(2);
    final at = <int>[];
    var t = _typeStart.toDouble();
    for (var i = 0; i < widget.text.length; i++) {
      at.add(t.round());
      final c = widget.text[i];
      t += 38 + rng.nextDouble() * 34;
      if (c == ' ') t += 40 + rng.nextDouble() * 70;
    }
    return at;
  }();

  late final int _total = _at.last + _blinkAfter;

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _total),
  )..forward();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = headline(40);
    return Center(
      child: Container(
        width: 1500,
        padding: const EdgeInsets.fromLTRB(64, 52, 36, 36),
        decoration: BoxDecoration(
          color: const Color(0x10FFFFFF),
          borderRadius: BorderRadius.circular(48),
          border: Border.all(color: const Color(0x24FFFFFF), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 60,
              offset: Offset(0, 24),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final ms = _clock.value * _total;
            var typed = 0;
            while (typed < _at.length && ms >= _at[typed]) {
              typed++;
            }
            final done = typed == widget.text.length;
            // Solid while typing; blinking while waiting; resting on at
            // the end.
            final caretOn =
                !_clock.isAnimating ||
                (typed > 0 && !done) ||
                // Blink phase counts from the last keystroke, so the caret
                // stays lit for a beat after the question is complete.
                math.cos((done ? ms - _at.last : ms) / 1060 * 2 * math.pi) >
                    -0.3;
            final ready = ((ms - _at.first) / 180).clamp(0.0, 1.0);
            // The send button bounces once when the question is complete.
            final pop = done ? ((ms - _at.last) / 450).clamp(0.0, 1.0) : 0.0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 28),
                  child: CustomPaint(
                    painter: _TypedPainter(
                      text: widget.text,
                      typed: typed,
                      style: style,
                      placeholder: typed == 0 ? widget.placeholder : null,
                      caret: caretOn,
                    ),
                    child: Text(
                      widget.text,
                      style: style.copyWith(color: const Color(0x00000000)),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    _RoundIcon(
                      size: 64,
                      fill: const Color(0x00000000),
                      border: const Color(0x30FFFFFF),
                      painter: _PlusPainter(Palette.muted),
                    ),
                    const Spacer(),
                    Transform.scale(
                      scale: 1 + 0.16 * math.sin(pop * math.pi) * (1 - pop),
                      child: _RoundIcon(
                        size: 80,
                        fill: Color.lerp(
                          const Color(0x1FFFFFFF),
                          Palette.accent,
                          ready,
                        )!,
                        painter: _ArrowPainter(
                          Color.lerp(Palette.muted, Palette.background, ready)!,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The question so far, the rest held invisibly in place so lines don't
/// reflow as it types, and the caret after the last typed character.
class _TypedPainter extends CustomPainter {
  _TypedPainter({
    required this.text,
    required this.typed,
    required this.style,
    required this.placeholder,
    required this.caret,
  });
  final String text;
  final int typed;
  final TextStyle style;
  final String? placeholder;
  final bool caret;

  @override
  void paint(Canvas canvas, Size size) {
    final hidden = style.copyWith(color: const Color(0x00000000));
    final tp = TextPainter(
      text: TextSpan(
        style: hidden,
        children: [
          TextSpan(text: text.substring(0, typed), style: style),
          TextSpan(text: text.substring(typed), style: hidden),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width + 1);
    if (placeholder != null) {
      final ph = TextPainter(
        text: TextSpan(
          text: placeholder,
          style: zalando(40, weight: 500, color: Palette.muted.withAlpha(150)),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      // Like a real composer: the caret sits at the start, the
      // placeholder just after it, not under it.
      ph.paint(canvas, const Offset(_caretGap + _caretWidth + 10, 0));
      ph.dispose();
    } else {
      tp.paint(canvas, Offset.zero);
    }
    if (caret) {
      final at = tp.getOffsetForCaret(TextPosition(offset: typed), Rect.zero);
      final line = tp.preferredLineHeight;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            at.dx + _caretGap,
            at.dy + line * 0.12,
            _caretWidth,
            line * 0.78,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = Palette.accent,
      );
    }
    tp.dispose();
  }

  @override
  bool shouldRepaint(_TypedPainter old) =>
      old.typed != typed ||
      old.caret != caret ||
      old.placeholder != placeholder ||
      old.text != text;
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.size,
    required this.fill,
    required this.painter,
    this.border,
  });
  final double size;
  final Color fill;
  final Color? border;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: fill,
      shape: BoxShape.circle,
      border: border == null ? null : Border.all(color: border!, width: 2),
    ),
    child: CustomPaint(painter: painter),
  );
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final s = size.width * 0.22;
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(c + Offset(0, s), c - Offset(0, s), paint);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - s * 0.85, c.dy - s * 0.15)
        ..lineTo(c.dx, c.dy - s)
        ..lineTo(c.dx + s * 0.85, c.dy - s * 0.15),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color;
}

class _PlusPainter extends CustomPainter {
  _PlusPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final s = size.width * 0.2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c - Offset(s, 0), c + Offset(s, 0), paint);
    canvas.drawLine(c - Offset(0, s), c + Offset(0, s), paint);
  }

  @override
  bool shouldRepaint(_PlusPainter old) => old.color != color;
}
