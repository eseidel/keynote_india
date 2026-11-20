import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'layouts.dart' show verdictWord;
import 'theme.dart';

/// Slide 9's "BAD AT / Learning": the word types itself in, letter by
/// letter, as if it's being learned. Then it forgets: the letters evaporate
/// and a new session starts from nothing, typing it in again at exactly the
/// same pace. They wake up fresh every time. At rest it's the plain word.
class ForgetfulWord extends StatefulWidget {
  const ForgetfulWord(this.word, {super.key});
  final String word;

  @override
  State<ForgetfulWord> createState() => _ForgetfulWordState();
}

// Timeline, ms from when the slide appears.
const _perLetter = 110;
const _sessions = [250, 2450]; // when each session starts typing
const _forgetAt = 1650; // the first session's letters start to evaporate
const _forgetEach = 420; // each letter's fade
const _forgetStagger = 45;
const _total = 4300;

class _ForgetfulWordState extends State<ForgetfulWord>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _total),
  )..forward();
  _Glyphs? _glyphs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _glyphs?.dispose();
    _glyphs = _Glyphs(
      widget.word,
      DefaultTextStyle.of(context).style.merge(verdictWord),
    );
  }

  @override
  void dispose() {
    _clock.dispose();
    _glyphs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) {
      if (!_clock.isAnimating) return Text(widget.word, style: verdictWord);
      return CustomPaint(
        size: _glyphs!.size,
        painter: _ForgetPainter(_glyphs!, _clock.value * _total),
      );
    },
  );
}

class _ForgetPainter extends CustomPainter {
  _ForgetPainter(this.g, this.ms);
  final _Glyphs g;
  final double ms;

  @override
  void paint(Canvas canvas, Size size) {
    final n = g.text.length;
    final session = ms < _sessions[1] ? 0 : 1;
    final typeStart = _sessions[session];
    final typed = ((ms - typeStart) / _perLetter).clamp(0.0, n.toDouble());
    final forgetting = session == 0 && ms >= _forgetAt;
    for (var k = 0; k < n; k++) {
      final box = g.boxes[k];
      // Typing: each letter pops up into place.
      final pop = (typed - k).clamp(0.0, 1.0);
      if (pop == 0) continue;
      var alpha = Curves.easeOut.transform(pop);
      var dy = 10 * (1 - alpha);
      var blur = 0.0;
      if (forgetting) {
        // Forgetting: letters drift up and blur away, last typed first.
        final f =
            ((ms - _forgetAt - (n - 1 - k) * _forgetStagger) / _forgetEach)
                .clamp(0.0, 1.0);
        final e = Curves.easeIn.transform(f);
        alpha *= 1 - e;
        dy -= 36 * e;
        blur = 10 * e;
      }
      if (alpha <= 0) continue;
      canvas.saveLayer(
        box.inflate(40).shift(Offset(0, dy)),
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, alpha)
          ..imageFilter = blur > 0.3
              ? ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur)
              : null,
      );
      g.glyph(g.text[k]).paint(canvas, Offset(box.left, dy));
      canvas.restore();
    }
    // The caret: after the last typed letter, blinking while it waits.
    final fadeOut = ((ms - (_total - 400)) / 400).clamp(0.0, 1.0);
    if (!forgetting || ms > _sessions[1] - 300) {
      // Once forgotten it waits back at the start for the next session.
      final shown = forgetting ? 0 : typed.ceil();
      final x = shown == 0 ? 0.0 : g.boxes[shown - 1].right + 6;
      final idle = forgetting || typed == 0 || typed == n;
      final blink = idle ? (math.cos(ms / 530 * math.pi * 2) > -0.2) : true;
      if (blink && fadeOut < 1) {
        canvas.drawRect(
          Rect.fromLTWH(x, g.size.height * 0.16, 5, g.size.height * 0.66),
          Paint()..color = Palette.accent.withValues(alpha: 1 - fadeOut),
        );
      }
    }
    // Which session this is, beside the word, fading at the end.
    final label = TextPainter(
      text: TextSpan(
        text: 'SESSION ${session + 1}',
        style: zalando(
          16,
          weight: 700,
          color: Palette.muted.withValues(alpha: 1 - fadeOut),
        ).copyWith(letterSpacing: 3),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(
        g.size.width + 60,
        g.baseline -
            label.computeDistanceToActualBaseline(TextBaseline.alphabetic),
      ),
    );
    label.dispose();
  }

  @override
  bool shouldRepaint(_ForgetPainter old) => old.ms != ms || old.g != g;
}

/// Each character's box in [text] laid out in [style], one painter per
/// character to draw it alone, and the whole line's size and baseline.
class _Glyphs {
  _Glyphs(this.text, this.style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    size = tp.size;
    baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    for (var k = 0; k < text.length; k++) {
      final b = tp.getBoxesForSelection(
        TextSelection(baseOffset: k, extentOffset: k + 1),
      );
      boxes.add(b.isEmpty ? Rect.zero : b.first.toRect());
    }
    tp.dispose();
  }

  final String text;
  final TextStyle style;
  late final Size size;
  late final double baseline;
  final boxes = <Rect>[];
  final _painters = <String, TextPainter>{};

  TextPainter glyph(String char) => _painters[char] ??= TextPainter(
    text: TextSpan(text: char, style: style),
    textDirection: TextDirection.ltr,
  )..layout();

  void dispose() {
    for (final p in _painters.values) {
      p.dispose();
    }
  }
}
