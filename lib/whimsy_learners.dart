import 'package:flutter/material.dart';

import 'theme.dart';

/// The Hoffer quote, marked up like a well-loved book: a blue highlighter
/// swipes across "learners inherit the earth", an amber one across "the
/// learned", and then "a world that no longer exists" quietly fades, as if
/// it were going away. Plays once and settles in about five seconds.
///
/// In [text], `[...]` is the learners' phrase (blue), `{...}` the learned
/// (amber), and `<...>` the world that fades.
class LearnersQuote extends StatefulWidget {
  const LearnersQuote({super.key, required this.text, required this.by});
  final String text;
  final String by;

  @override
  State<LearnersQuote> createState() => _LearnersQuoteState();
}

const _totalMs = 5200;

class _LearnersQuoteState extends State<LearnersQuote>
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

  static double _ramp(double ms, double a, double b) =>
      ((ms - a) / (b - a)).clamp(0.0, 1.0);

  List<InlineSpan> _spans(double ms) {
    final base = zalando(28, weight: 700, italic: true, height: 1.5);
    final spans = <InlineSpan>[];
    // Each marked phrase sweeps word by word over its window.
    void marked(String phrase, Color color, double start, double end) {
      final words = phrase.split(' ');
      final per = (end - start) / words.length;
      for (final (i, w) in words.indexed) {
        final p = Curves.easeInOut.transform(
          _ramp(ms, start + i * per, start + (i + 1) * per),
        );
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: CustomPaint(
              painter: _Marker(
                color,
                p,
                first: i == 0,
                last: i == words.length - 1,
              ),
              child: Text(
                // The space rides with its word, so strokes meet edge to edge.
                i < words.length - 1 ? '$w ' : w,
                style: base.copyWith(
                  color: Color.lerp(Palette.text, color, p * 0.25),
                ),
              ),
            ),
          ),
        );
      }
    }

    final re = RegExp(r'\[([^\]]+)\]|\{([^}]+)\}|<([^>]+)>');
    var at = 0;
    for (final m in re.allMatches(widget.text)) {
      spans.add(TextSpan(text: widget.text.substring(at, m.start)));
      if (m[1] != null) {
        marked(m[1]!, Palette.accent, 600, 1700);
      } else if (m[2] != null) {
        marked(m[2]!, Palette.warn, 2000, 2700);
      } else {
        final fade = Curves.easeInOut.transform(_ramp(ms, 3100, 5000));
        spans.add(
          TextSpan(
            text: m[3],
            style: TextStyle(
              color: Color.lerp(
                Palette.text,
                Palette.muted,
                fade,
              )!.withValues(alpha: 1 - fade * 0.55),
            ),
          ),
        );
      }
      at = m.end;
    }
    spans.add(TextSpan(text: widget.text.substring(at)));
    return spans;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 200),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _clock,
          builder: (_, _) => Text.rich(
            TextSpan(
              style: zalando(28, weight: 700, italic: true, height: 1.5),
              children: _spans(_clock.value * _totalMs),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 40),
        Text('— ${widget.by}', style: zalando(24, color: Palette.muted)),
      ],
    ),
  );
}

/// A highlighter stroke behind a word, drawn left to right to [progress].
class _Marker extends CustomPainter {
  _Marker(this.color, this.progress, {required this.first, required this.last});
  final Color color;
  final double progress;
  final bool first, last;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    // A little past the ends of the phrase, rounded only there.
    final left = first ? 9.0 : 0.0, right = last ? 9.0 : 0.0;
    final w = (size.width + left + right) * progress;
    final r = Rect.fromLTWH(-left, size.height * 0.38, w, size.height * 0.5);
    const round = Radius.circular(6);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        r,
        topLeft: first ? round : Radius.zero,
        bottomLeft: first ? round : Radius.zero,
        topRight: last || progress < 1 ? round : Radius.zero,
        bottomRight: last || progress < 1 ? round : Radius.zero,
      ),
      // Solid, pre-blended on the slide's ground, so overlapping word strokes
      // don't show seams.
      Paint()
        ..color = Color.alphaBlend(
          color.withValues(alpha: 0.38),
          Palette.background,
        ),
    );
  }

  @override
  bool shouldRepaint(_Marker old) =>
      old.progress != progress || old.color != color;
}
