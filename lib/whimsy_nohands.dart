import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// "Producing code is no longer a human job": behind the headline, a dim
/// code editor writes a Flutter widget by itself, far faster than anyone
/// types, with a ghost caret and nobody at the keyboard. The status bar
/// keeps count: the agent's keystrokes climb, yours stay at 0. Runs once
/// when the slide appears and settles in about three seconds, the file
/// written and saved.
class NoHandsStatement extends StatefulWidget {
  const NoHandsStatement(this.text, {super.key, this.size = 50});
  final String text;
  final double size;

  @override
  State<NoHandsStatement> createState() => _NoHandsStatementState();
}

const _code = '''// Written by an agent. No hands.
class Checkout extends StatelessWidget {
  const Checkout({super.key, required this.cart});
  final Cart cart;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in cart.items)
          LineItem(item: item),
        Total(amount: cart.total),
        PayButton(
          onPressed: () => cart.pay(),
        ),
      ],
    );
  }
}''';

const _startMs = 350;
const _typeMs = 2300; // the whole file, ~190 characters a second
const _recedeDelayMs = 200;
const _recedeMs = 600;

/// When (ms) each character of [_code] appears: steady but bursty, the way
/// a model streams tokens, and deterministic so frames repeat.
final List<double> _charTimes = () {
  final rnd = math.Random(13);
  final gaps = <double>[];
  for (var i = 0; i < _code.length; i++) {
    // Whole words arrive together; a pause now and then between tokens.
    final c = _code[i];
    final boundary = c == ' ' || c == '\n' || c == '(' || c == '.';
    gaps.add(boundary ? 2 + rnd.nextDouble() * 10 : rnd.nextDouble() * 1.2);
  }
  final sum = gaps.fold(0.0, (a, b) => a + b);
  var t = _startMs.toDouble();
  return [for (final g in gaps) t += g / sum * _typeMs];
}();

/// The clock runs until the editor has fully receded (the last thing to
/// move), so it settles at its resting opacity rather than mid-fade.
final int _totalMs = (_charTimes.last + _recedeDelayMs + _recedeMs).ceil();

class _NoHandsStatementState extends State<NoHandsStatement>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _totalMs),
  )..forward();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Positioned(
        left: 300,
        right: 300,
        top: 130,
        bottom: 150,
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) => _Editor(ms: _clock.value * _totalMs),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 160),
        child: Center(
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: headline(widget.size).copyWith(
              shadows: [
                const Shadow(color: Palette.background, blurRadius: 40),
                const Shadow(color: Palette.background, blurRadius: 18),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _Editor extends StatelessWidget {
  const _Editor({required this.ms});
  final double ms;

  static const _keywords = {
    'class',
    'extends',
    'const',
    'final',
    'required',
    'super',
    'this',
    'return',
    'for',
    'in',
  };

  @override
  Widget build(BuildContext context) {
    var typed = 0;
    while (typed < _charTimes.length && _charTimes[typed] <= ms) {
      typed++;
    }
    final done = typed == _code.length;
    // The caret fades once the file is written; nothing blinks forever.
    final caretAlpha = done
        ? (1 - (ms - _charTimes.last) / 400).clamp(0.0, 1.0)
        : 1.0;
    final shown = _code.substring(0, typed);
    final lines = shown.split('\n');
    final all = _code.split('\n');
    final codeStyle = zalando(8.4, color: Palette.soft, height: 1.55);
    final gutter = zalando(8.4, color: Palette.muted, height: 1.55);

    // Once saved, the editor steps back behind the headline.
    final recede = done
        ? Curves.easeInOut.transform(
            ((ms - _charTimes.last - _recedeDelayMs) / _recedeMs).clamp(
              0.0,
              1.0,
            ),
          )
        : 0.0;
    return Opacity(
      opacity: 0.42 - 0.12 * recede,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title bar: traffic lights and the file's tab.
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
              child: Row(
                children: [
                  for (final c in const [
                    Color(0xFFFF5F57),
                    Color(0xFFFEBC2E),
                    Color(0xFF28C840),
                  ])
                    Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 20),
                  Text('checkout.dart', style: zalando(8, color: Palette.soft)),
                  // The unsaved dot, until the agent saves.
                  if (!done) const _Dot(Palette.soft, left: 14),
                ],
              ),
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < all.length; i++)
                      Row(
                        children: [
                          SizedBox(
                            width: 56,
                            child: Text(
                              '${i + 1}',
                              textAlign: TextAlign.right,
                              style: gutter.copyWith(
                                color: i < lines.length
                                    ? Palette.muted
                                    : Palette.muted.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                          const SizedBox(width: 28),
                          Text.rich(
                            TextSpan(
                              children: [
                                if (i < lines.length)
                                  ..._highlight(lines[i], codeStyle),
                                if (i == lines.length - 1)
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: _Caret(
                                      height: codeStyle.fontSize! * 1.2,
                                      alpha: caretAlpha,
                                    ),
                                  ),
                              ],
                            ),
                            style: codeStyle,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            // Status bar: who's typing.
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
              child: Row(
                children: [
                  _Dot(done ? Palette.accent : Palette.warn, right: 12),
                  Text(
                    done ? 'Agent: saved' : 'Agent: writing',
                    style: zalando(
                      7.5,
                      weight: 700,
                      color: done ? Palette.accent : Palette.warn,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Agent keystrokes: $typed',
                    style: zalando(7.5, color: Palette.soft),
                  ),
                  const SizedBox(width: 36),
                  Text(
                    'Human keystrokes: 0',
                    style: zalando(7.5, weight: 700, color: Palette.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A small Dart highlighter: comments, keywords, Types, annotations.
  static final _token = RegExp(r'@?\w+|\W+');
  static final _type = RegExp(r'^[A-Z]');
  static final _indent = RegExp(r'^ +');

  /// Zalando Sans is proportional, so a space is too narrow to read as
  /// indentation; leading spaces get a fixed, editor-like width instead.
  static List<InlineSpan> _highlight(String line, TextStyle base) {
    final lead = _indent.firstMatch(line)?[0]?.length ?? 0;
    return [
      if (lead > 0)
        WidgetSpan(child: SizedBox(width: lead * base.fontSize! * 0.6)),
      ..._highlightCode(line.substring(lead), base),
    ];
  }

  static List<InlineSpan> _highlightCode(String line, TextStyle base) {
    final comment = line.indexOf('//');
    if (comment >= 0) {
      return [
        TextSpan(text: line.substring(0, comment)),
        TextSpan(
          text: line.substring(comment),
          style: base.copyWith(
            color: Palette.muted,
            fontStyle: FontStyle.italic,
          ),
        ),
      ];
    }
    final spans = <InlineSpan>[];
    for (final m in _token.allMatches(line)) {
      final w = m[0]!;
      Color? color;
      if (_keywords.contains(w)) {
        color = const Color(0xFFC792EA);
      } else if (w.startsWith('@')) {
        color = Palette.warn;
      } else if (_type.hasMatch(w)) {
        color = Palette.accent;
      }
      spans.add(
        TextSpan(
          text: w,
          style: color == null ? null : base.copyWith(color: color),
        ),
      );
    }
    return spans;
  }
}

/// The ghost caret: a glowing bar with no one behind it.
class _Caret extends StatelessWidget {
  const _Caret({required this.height, required this.alpha});
  final double height;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
    width: 4,
    height: height,
    margin: const EdgeInsets.only(left: 2),
    decoration: BoxDecoration(
      color: Palette.accent.withValues(alpha: alpha),
      boxShadow: [
        BoxShadow(
          color: Palette.accent.withValues(alpha: 0.9 * alpha),
          blurRadius: 14,
          spreadRadius: 2,
        ),
      ],
    ),
  );
}

/// A small status dot (drawn, not a glyph, so it renders on every font).
class _Dot extends StatelessWidget {
  const _Dot(this.color, {this.left = 0, this.right = 0});
  final Color color;
  final double left;
  final double right;

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    margin: EdgeInsets.only(left: left, right: right),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
