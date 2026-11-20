import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'layouts.dart' show verdictWord;
import 'theme.dart';

/// Slide 10's two verdicts, live. "Squishy inputs" plops in letter by
/// letter and wobbles like jelly (hover it to poke it again): squishy is
/// fine. "Determinism" is a slot machine: pulled three times, it lands on
/// three different answers ("Determinant", "Detergent", "Determinism")
/// before it settles: ask three times, get three answers. At rest both are
/// the ordinary verdict words.

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

  /// A painter for [char] alone, in [color] (default: the style's).
  TextPainter glyph(String char, [Color? color]) {
    final key = '$char${color?.toARGB32()}';
    return _painters[key] ??= TextPainter(
      text: TextSpan(
        text: char,
        style: style.copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void dispose() {
    for (final p in _painters.values) {
      p.dispose();
    }
  }
}

/// A word that drops in letter by letter and wobbles like jelly, then rests
/// as plain text. Pointing at it pokes it, sending a wobble out from there.
class JellyWord extends StatefulWidget {
  const JellyWord(this.word, {super.key});
  final String word;

  @override
  State<JellyWord> createState() => _JellyWordState();
}

class _JellyWordState extends State<JellyWord>
    with SingleTickerProviderStateMixin {
  static const _total = 2400; // ms; the entry drop plus wobble fits in this

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _total),
  )..forward();
  _Glyphs? _glyphs;

  /// Where the last poke landed (x in the word), or null for the entry drop.
  double? _pokeX;

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

  void _poke(PointerEvent e) {
    if (_clock.isAnimating) return;
    _pokeX = e.localPosition.dx;
    _clock.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: _poke,
    child: AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        if (!_clock.isAnimating) {
          return Text(widget.word, style: verdictWord);
        }
        final g = _glyphs!;
        return CustomPaint(
          size: g.size,
          painter: _JellyPainter(g, _clock.value * _total, _pokeX),
        );
      },
    ),
  );
}

class _JellyPainter extends CustomPainter {
  _JellyPainter(this.g, this.ms, this.pokeX);
  final _Glyphs g;
  final double ms;
  final double? pokeX;

  static const _fall = 0.26; // s from above to the line

  @override
  void paint(Canvas canvas, Size size) {
    final drop = pokeX == null;
    for (final (k, box) in g.boxes.indexed) {
      final char = g.text[k];
      if (char == ' ') continue;
      final cx = box.center.dx;
      // Entry: letters fall in turn. Poke: the wobble spreads from the
      // pointer at about 1.6 px/ms.
      final delay = drop ? 120 + k * 45.0 : (cx - pokeX!).abs() / 1.6;
      var tau = (ms - delay) / 1000; // s since this letter's start
      var dy = 0.0, sx = 1.0, sy = 1.0, skew = 0.0, alpha = 1.0;
      if (drop && tau < 0) continue;
      if (drop && tau < _fall) {
        // Falling: accelerating, a little stretched.
        final f = tau / _fall;
        dy = -150 * (1 - f * f);
        sy = 1.14;
        sx = 0.92;
        alpha = (f * 3).clamp(0.0, 1.0);
      } else if (tau > 0) {
        if (drop) tau -= _fall;
        // Landed: squash and stretch around the baseline, keeping volume,
        // with a sideways sway a beat out of phase.
        final amp = drop ? 0.34 : 0.2;
        final s =
            amp * math.exp(-4.2 * tau) * math.cos(2 * math.pi * 3.3 * tau);
        sy = 1 - s;
        sx = 1 + 0.6 * s;
        skew =
            (drop ? 0.16 : 0.12) *
            math.exp(-3.8 * tau) *
            math.sin(2 * math.pi * 2.2 * tau + k * 0.45);
      }
      final tp = g.glyph(
        char,
        alpha < 1 ? g.style.color!.withValues(alpha: alpha) : null,
      );
      canvas.save();
      canvas.translate(cx, g.baseline + dy);
      canvas.transform(
        Matrix4.identity().storage
          ..[4] = -skew, // x shifts with height: the top sways
      );
      canvas.scale(sx, sy);
      tp.paint(canvas, Offset(box.left - cx, -g.baseline));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_JellyPainter old) =>
      old.ms != ms || old.pokeX != pokeX || old.g != g;
}

/// A word on slot-machine reels, one per letter, pulled once per answer in
/// [tries] (each the word's length, padded with spaces) and then once more
/// to land on [word]. Letters that differ from [word] land in warn orange.
class SlotWord extends StatefulWidget {
  const SlotWord(this.word, {super.key, this.tries = const []});
  final String word;
  final List<String> tries;

  @override
  State<SlotWord> createState() => _SlotWordState();
}

class _SlotWordState extends State<SlotWord>
    with SingleTickerProviderStateMixin {
  static const _firstSpin = 1000; // ms of spin before the first reel stops
  static const _spin = 380; // ms on later pulls
  static const _stagger = 40; // ms between reels stopping, left to right
  static const _hold = 420; // ms to read an answer before the next pull
  static const _fade = 500; // ms for the try counter to fade at the end

  late final List<String> _answers = [...widget.tries, widget.word];

  /// When each pull starts, and when its first reel stops (ms).
  late final List<(int, int)> _pulls = () {
    final pulls = <(int, int)>[];
    var t = 0;
    for (var j = 0; j < _answers.length; j++) {
      final stop = t + (j == 0 ? _firstSpin : _spin);
      pulls.add((t, stop));
      t = stop + (widget.word.length - 1) * _stagger + _hold;
    }
    return pulls;
  }();

  late final int _total =
      _pulls.last.$2 + (widget.word.length - 1) * _stagger + _fade;

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _total),
  )..forward();
  List<_Glyphs>? _glyphs; // one layout per answer

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disposeGlyphs();
    final style = DefaultTextStyle.of(context).style.merge(verdictWord);
    _glyphs = [for (final a in _answers) _Glyphs(a, style)];
  }

  void _disposeGlyphs() {
    for (final g in _glyphs ?? const <_Glyphs>[]) {
      g.dispose();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _disposeGlyphs();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) {
      if (!_clock.isAnimating) return Text(widget.word, style: verdictWord);
      return CustomPaint(
        size: _glyphs!.last.size,
        painter: _SlotPainter(
          glyphs: _glyphs!,
          pulls: _pulls,
          ms: _clock.value * _total,
          stagger: _stagger,
          fadeFrom: _total - _fade,
        ),
      );
    },
  );
}

class _SlotPainter extends CustomPainter {
  _SlotPainter({
    required this.glyphs,
    required this.pulls,
    required this.ms,
    required this.stagger,
    required this.fadeFrom,
  });
  final List<_Glyphs> glyphs;
  final List<(int, int)> pulls;
  final double ms;
  final int stagger;
  final int fadeFrom;

  static const _alphabet = 'abcdefghijklmnopqrstuvwxyz';

  @override
  void paint(Canvas canvas, Size size) {
    final word = glyphs.last;
    final h = word.size.height;
    // The reel window: the line's box (a little more for descenders), fading
    // out at top and bottom so letters roll over a drum out of sight.
    final window = Rect.fromLTRB(-60, 0, size.width + 600, 1.15 * h);
    canvas.saveLayer(window, Paint());
    // The current pull: the last one started.
    var j = 0;
    while (j + 1 < pulls.length && ms >= pulls[j + 1].$1) {
      j++;
    }
    final (start, firstStop) = pulls[j];
    final answer = glyphs[j];
    final last = j == pulls.length - 1;
    for (var k = 0; k < word.text.length; k++) {
      final stop = firstStop + k * stagger;
      final target = answer.text[k];
      // A reel's strip: the letter it showed before, some random letters,
      // then this pull's letter, N rows down.
      final n = 9 + k ~/ 2 + (j == 0 ? 8 : 0);
      final rng = math.Random(j * 131 + k * 7 + 3);
      String row(int i) {
        if (i == n) return target;
        if (i == 0 && j > 0) return glyphs[j - 1].text[k];
        final c = _alphabet[rng.nextInt(_alphabet.length)];
        return k == 0 ? c.toUpperCase() : c;
      }

      final strip = [for (var i = 0; i <= n; i++) row(i)];
      // Position in rows: decelerating to the target, then a little clunk.
      double p, speed; // rows, rows/s
      if (ms < stop) {
        final dur = (stop - start).toDouble();
        final u = ((ms - start) / dur).clamp(0.0, 1.0);
        p = n * (1 - math.pow(1 - u, 3).toDouble());
        speed = 3 * n * math.pow(1 - u, 2).toDouble() / (dur / 1000);
      } else {
        final w = (ms - stop) / 1000;
        p = n + 0.14 * math.exp(-11 * w) * math.sin(2 * math.pi * 4.5 * w);
        speed = 0;
      }
      // Rolling letters sit in this pull's column; landed ones exactly where
      // the answer lays them out.
      final box = answer.boxes[k];
      final blur = (speed * h / 260).clamp(0.0, 22.0);
      if (blur > 0.5) {
        canvas.saveLayer(
          null,
          Paint()
            ..imageFilter = ui.ImageFilter.blur(
              sigmaX: 0,
              sigmaY: blur,
              tileMode: TileMode.decal,
            ),
        );
      }
      for (var i = p.floor() - 1; i <= p.ceil() + 1; i++) {
        if (i < 0 || i > n) continue;
        final char = strip[i];
        if (char == ' ') continue;
        final d = p - i; // rows from the window's middle
        if (d.abs() >= 1.4) continue;
        // The letter shown before this pull sits in the old answer's place.
        final from = i == 0 && j > 0 ? glyphs[j - 1] : answer;
        final b = i == 0 && j > 0 ? from.boxes[k] : box;
        final wrong = i == n && !last && target != word.text[k];
        final wasWrong = i == 0 && j > 0 && char != word.text[k];
        final tp = from.glyph(char, wrong || wasWrong ? Palette.warn : null);
        // Round the drum: rows off the middle are nearer and squashed.
        final squash = math.cos(d * 1.1).clamp(0.0, 1.0);
        canvas.save();
        canvas.translate(0, h / 2 + d * h * 0.85);
        canvas.scale(1, squash);
        tp.paint(canvas, Offset(b.center.dx - tp.width / 2, -h / 2));
        canvas.restore();
      }
      if (blur > 0.5) canvas.restore();
    }
    canvas.drawRect(
      window,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          window.topCenter,
          window.bottomCenter,
          const [
            Color(0x00FFFFFF),
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
          ],
          const [0, 0.09, 0.85, 1],
        ),
    );
    canvas.restore();
    // Which try this is, beside the word, fading once the last one lands.
    final fade = ((ms - fadeFrom) / 500).clamp(0.0, 1.0);
    final label = TextPainter(
      text: TextSpan(
        text: 'ASK #${j + 1}',
        style: zalando(
          16,
          weight: 700,
          color: Palette.muted.withValues(alpha: 1 - fade),
        ).copyWith(letterSpacing: 3),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(
        glyphs.map((g) => g.size.width).reduce(math.max) + 48,
        word.baseline -
            label.computeDistanceToActualBaseline(TextBaseline.alphabetic),
      ),
    );
    label.dispose();
  }

  @override
  bool shouldRepaint(_SlotPainter old) => old.ms != ms || old.glyphs != glyphs;
}
