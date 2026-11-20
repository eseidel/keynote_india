import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'layouts.dart';
import 'theme.dart';

/// The opening cover, while Eric is introduced ("Every tool is up in the
/// air"): the title's words are up in the air. A breeze of accent petals
/// blows across the slide, and the words flutter in on it like leaves, each
/// bobbing and tilting on its own path, settling one by one into the title.
/// Then the byline card rises into place. Plays once and settles in about three seconds;
/// at rest it is the same picture as [Cover] (layouts.dart).
class FlutteringCover extends StatefulWidget {
  const FlutteringCover({super.key, required this.title, required this.byline});
  final String title;
  final List<String> byline;

  @override
  State<FlutteringCover> createState() => _FlutteringCoverState();
}

const _totalMs = 3200;
const _bylineAt = 2.35, _bylineFor = 0.8; // seconds

class _FlutteringCoverState extends State<FlutteringCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  )..forward();

  _Words? _laidOut;

  /// The words, laid out with the same text scaler the settled Text uses.
  _Words get _words {
    // Resolve the style the way Text does: merged into the ambient
    // DefaultTextStyle (Material 3's spreads leading evenly) and scaled.
    final scaler = MediaQuery.textScalerOf(context);
    final style = DefaultTextStyle.of(context).style.merge(headline(40));
    final words = _laidOut;
    if (words != null && words.scaler == scaler && words.style == style) {
      return words;
    }
    words?.dispose();
    return _laidOut = _Words(widget.title, style, scaler);
  }

  @override
  void dispose() {
    _clock.dispose();
    _laidOut?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = headline(40);
    return ClipRect(
      child: Padding(
        padding: const EdgeInsets.only(left: 288, right: 288),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedBuilder(
              animation: _clock,
              // Once everything has landed, the title is plain text again.
              builder: (_, _) => _clock.isCompleted
                  ? Text(widget.title, style: style)
                  : CustomPaint(
                      size: _words.size,
                      painter: _FlightPainter(_clock, _words),
                    ),
            ),
            const SizedBox(height: 48),
            AnimatedBuilder(
              animation: _clock,
              builder: (_, child) {
                final t = _clock.value * _totalMs / 1000;
                final f = Curves.easeOutCubic.transform(
                  ((t - _bylineAt) / _bylineFor).clamp(0.0, 1.0),
                );
                return Opacity(
                  opacity: f,
                  child: Transform.translate(
                    offset: Offset(0, (1 - f) * 60),
                    child: child,
                  ),
                );
              },
              child: BylineCard(widget.byline),
            ),
          ],
        ),
      ),
    );
  }
}

/// One word in the breeze: its painter, where the title's layout puts it,
/// and its flight (all seeded, so every run and every golden is the same).
class _Word {
  _Word(this.painter, this.home, this.land, this.reach, this.bob, this.phase);
  final TextPainter painter;
  final Offset
  home; // where its painter's origin goes, in the title's coordinates
  final double land; // seconds: when it settles
  final double reach; // how far right of home it starts (off the slide)
  final double bob; // up-and-down amplitude
  final double phase;
}

class _Petal {
  _Petal(this.y, this.start, this.speed, this.bob, this.phase, this.size);
  final double y, start, speed, bob, phase, size;
}

/// The slide's right edge, in the title's coordinates (the title starts
/// 288 px in from the left of the 1920 px canvas).
const _rightEdge = 1920.0 - 288;

class _Words {
  _Words(String text, this.style, this.scaler) {
    final line = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    size = line.size;
    final rng = math.Random(7);
    var i = 0;
    for (final m in RegExp(r'\S+').allMatches(text)) {
      final box = line
          .getBoxesForSelection(
            TextSelection(baseOffset: m.start, extentOffset: m.end),
          )
          .first;
      final word = m.group(0)!;
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      // The word's own painter has its own leading (the box can start above
      // its origin), so line its glyphs up with the paragraph's, not its
      // origin with the paragraph's box: the hand-off to Text is then exact.
      final own = painter
          .getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: word.length),
          )
          .first;
      words.add(
        _Word(
          painter,
          Offset(box.left - own.left, box.top - own.top),
          // In reading order, with a little jitter so it isn't mechanical.
          // Each word blows in from the right and lands left of the words
          // still in the air, so a flying word never crosses a landed one.
          1.35 + i * 0.16 + rng.nextDouble() * 0.08,
          _rightEdge - box.left + 60 + rng.nextDouble() * 260,
          16 + rng.nextDouble() * 18, // small: each line keeps to its lane
          rng.nextDouble() * 2 * math.pi,
        ),
      );
      i++;
    }
    line.dispose();
    for (var k = 0; k < 28; k++) {
      petals.add(
        _Petal(
          -260 + rng.nextDouble() * 980,
          rng.nextDouble() * 1.4,
          650 + rng.nextDouble() * 500,
          20 + rng.nextDouble() * 50,
          rng.nextDouble() * 2 * math.pi,
          9 + rng.nextDouble() * 10,
        ),
      );
    }
  }

  final TextStyle style;
  final TextScaler scaler;
  late final Size size;
  final words = <_Word>[];
  final petals = <_Petal>[];

  void dispose() {
    for (final w in words) {
      w.painter.dispose();
    }
  }
}

class _FlightPainter extends CustomPainter {
  _FlightPainter(this.clock, this.words) : super(repaint: clock);
  final Animation<double> clock;
  final _Words words;

  static const _flight = 1.3; // seconds each word spends in the air

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * _totalMs / 1000;

    // Petals first, behind the words: accent flecks on the same breeze,
    // tumbling across and fading out.
    final petal = Paint();
    for (final p in words.petals) {
      final age = t - p.start;
      if (age <= 0) continue;
      final fade = (1 - age / 1.8).clamp(0.0, 1.0);
      if (fade <= 0) continue;
      final w = 2 * math.pi * 0.8 * age + p.phase;
      final x = _rightEdge + 30 - age * p.speed;
      final y = p.y + math.sin(w) * p.bob + age * 40; // and sinking a little
      petal.color = Palette.accent.withValues(alpha: 0.8 * fade);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(math.cos(w) * 1.2 + p.phase)
        // A petal flips as it tumbles: squash it on one axis.
        ..scale(1, 0.3 + 0.7 * math.cos(w * 1.3).abs());
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          Radius.circular(p.size * 0.3),
        ),
        petal,
      );
      canvas.restore();
    }

    for (final word in words.words) {
      final p = ((t - (word.land - _flight)) / _flight).clamp(0.0, 1.0);
      if (p == 0) continue; // still off the slide
      // Like a leaf on a breeze: it slows as it nears its spot, and the
      // bob and tilt die out as it lands, so it arrives level.
      final e = Curves.easeOutCubic.transform(p);
      final left = 1 - e;
      final w = 2 * math.pi * 1.1 * p * _flight + word.phase;
      final dx = word.reach * left;
      final dy = math.sin(w) * word.bob * left;
      final tilt = math.cos(w) * 0.28 * left;
      final s = word.painter.size;
      canvas
        ..save()
        ..translate(
          word.home.dx + dx + s.width / 2,
          word.home.dy + dy + s.height / 2,
        )
        ..rotate(tilt);
      word.painter.paint(canvas, Offset(-s.width / 2, -s.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FlightPainter old) => old.words != words;
}
