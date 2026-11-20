import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// "Code captures intent": under the statement, two sides argue about
/// retrying failed payments in speech bubbles, left and right, one after
/// another. When the argument is over, the bubbles collapse into the middle
/// and resolve into the one line of code that captures what was decided,
/// with the decisions from the bubbles (3, keepCart) highlighted in it.
/// Argue once, build once. Plays once and settles in about six seconds.
class IntentStatement extends StatefulWidget {
  const IntentStatement(this.text, {super.key});
  final String text;

  @override
  State<IntentStatement> createState() => _IntentStatementState();
}

/// The argument: (from the right?, words, the decided part).
const _argument = [
  (false, 'Retry failed payments?', ''),
  (true, 'Sure, but not forever. ', 'Three tries.'),
  (false, 'And if all three fail?', ''),
  (true, 'Never lose their ', 'cart.'),
];

const _total = 5800; // ms
const _firstBubble = 350, _perBubble = 720, _pop = 380;
// The last bubble lands at ~2.9s; let the punchline sit before collapsing.
const _collapse = 3750, _collapseLen = 550;
const _code = 4200, _codeLen = 600;

class _IntentStatementState extends State<IntentStatement>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _total),
  )..forward();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 160),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.text, textAlign: TextAlign.center, style: headline(50)),
          const SizedBox(height: 70),
          SizedBox(
            width: 1240,
            height: 440,
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, _) => _Stage(ms: _clock.value * _total),
            ),
          ),
        ],
      ),
    ),
  );
}

double _phase(double ms, int start, int length) =>
    ((ms - start) / length).clamp(0.0, 1.0);

class _Stage extends StatelessWidget {
  const _Stage({required this.ms});
  final double ms;

  @override
  Widget build(BuildContext context) {
    final collapse = Curves.easeInCubic.transform(
      _phase(ms, _collapse, _collapseLen),
    );
    final code = _phase(ms, _code, _codeLen);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (collapse < 1)
          for (final (i, (right, words, decided)) in _argument.indexed)
            _bubble(i, right, words, decided, collapse),
        if (code > 0) _CodeLine(t: code, glow: _phase(ms, _code, 1500)),
      ],
    );
  }

  Widget _bubble(
    int i,
    bool right,
    String words,
    String decided,
    double collapse,
  ) {
    final pop = _phase(ms, _firstBubble + i * _perBubble, _pop);
    if (pop <= 0) return const SizedBox.shrink();
    final grow = Curves.easeOutBack.transform(pop);
    // Rows down the stage, each side toward its own edge; the collapse pulls
    // every bubble into the middle, where the code appears.
    final y = -0.85 + i * 0.57;
    final x = right ? 0.5 : -0.5;
    return Align(
      alignment: Alignment(x * (1 - collapse), y * (1 - collapse)),
      child: Transform.rotate(
        // Each side leans in a little as it makes its point.
        angle: (right ? 1.5 : -1.5) * math.pi / 180 * (1 - collapse),
        child: Transform.scale(
          scale: grow * (1 - 0.7 * collapse),
          alignment: right ? Alignment.bottomRight : Alignment.bottomLeft,
          child: Opacity(
            opacity: pop * (1 - collapse) * (1 - collapse),
            child: _Bubble(right: right, words: words, decided: decided),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.right,
    required this.words,
    required this.decided,
  });
  final bool right;
  final String words;
  final String decided;

  @override
  Widget build(BuildContext context) {
    final fill = right
        ? Palette.accent.withValues(alpha: 0.16)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.07);
    final edge = right
        ? Palette.accent.withValues(alpha: 0.55)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.16);
    return CustomPaint(
      painter: _BubblePainter(right: right, fill: fill, edge: edge),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: words),
              if (decided.isNotEmpty)
                TextSpan(
                  text: decided,
                  style: zalando(
                    15,
                    weight: 700,
                    color: right ? Palette.warn : Palette.accent,
                  ),
                ),
            ],
          ),
          style: zalando(15, weight: 500),
        ),
      ),
    );
  }
}

/// A rounded bubble with a little tail at its bottom corner, pointing at
/// whoever said it.
class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.right, required this.fill, required this.edge});
  final bool right;
  final Color fill;
  final Color edge;

  /// The outline depends only on the side and the bubble's (fixed) layout
  /// size, so build it once instead of re-running the path union every frame
  /// while the bubbles pop and collapse.
  static final _shapes = <(bool, Size), Path>{};

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _shapes[(right, size)] ??= _shape(size);
    canvas.drawPath(shape, Paint()..color = Palette.background);
    canvas.drawPath(shape, Paint()..color = fill);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = edge,
    );
  }

  Path _shape(Size size) {
    final body = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    final tail = Path();
    final h = size.height;
    if (right) {
      tail
        ..moveTo(size.width - 46, h - 10)
        ..quadraticBezierTo(size.width - 8, h + 4, size.width + 10, h + 14)
        ..quadraticBezierTo(size.width - 4, h - 6, size.width - 14, h - 26)
        ..close();
    } else {
      tail
        ..moveTo(46, h - 10)
        ..quadraticBezierTo(8, h + 4, -10, h + 14)
        ..quadraticBezierTo(4, h - 6, 14, h - 26)
        ..close();
    }
    return Path.combine(PathOperation.union, Path()..addRRect(body), tail);
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.right != right || old.fill != fill || old.edge != edge;
}

/// The decision, as code: `retry(max: 3, onFail: keepCart)` on an editor
/// card that pops in with a flash of glow that fades as it settles.
class _CodeLine extends StatelessWidget {
  const _CodeLine({required this.t, required this.glow});
  final double t; // 0..1 pop
  final double glow; // 0..1 over the glow's life

  @override
  Widget build(BuildContext context) {
    final pop = Curves.easeOutBack.transform(t);
    // A flash as the bubbles land, easing to a steady soft glow.
    final burst = math.pow(1 - glow, 2).toDouble();
    final flash = 0.35 + 0.65 * burst;
    TextSpan s(String text, Color color, {double weight = 600}) => TextSpan(
      text: text,
      style: zalando(24, weight: weight, color: color),
    );
    return Transform.scale(
      scale: 0.6 + 0.4 * pop,
      child: Opacity(
        opacity: t,
        child: Container(
          padding: const EdgeInsets.fromLTRB(54, 34, 64, 38),
          decoration: BoxDecoration(
            color: const Color(0xFF161D27),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Palette.accent.withValues(alpha: 0.5 + 0.5 * flash),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                // Settles at 0.3 so the steady glow still reads at rest.
                color: Palette.accent.withValues(alpha: 0.3 + 0.2 * burst),
                blurRadius: 40 + 50 * flash,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '// argued once',
                style: zalando(13, color: Palette.muted, italic: true),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    s('retry', Palette.accent, weight: 700),
                    s('(', Palette.soft),
                    s('max: ', Palette.muted, weight: 500),
                    s('3', Palette.warn, weight: 700),
                    s(', ', Palette.soft),
                    s('onFail: ', Palette.muted, weight: 500),
                    s('keepCart', Palette.warn, weight: 700),
                    s(')', Palette.soft),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
