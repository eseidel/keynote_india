import 'package:flutter/material.dart';

import 'theme.dart';

/// "Mary had a little …" types itself, then the next token flickers through
/// candidates before the model lands on "lamb": token prediction, live.
/// Runs once when the slide appears and settles in about three seconds.
class TokenPrediction extends StatefulWidget {
  const TokenPrediction({super.key});

  @override
  State<TokenPrediction> createState() => _TokenPredictionState();
}

const _prompt = 'Mary had a little ';

/// Candidates shown while the model "thinks", each with its probability and
/// when (ms) it appears. The last one is the answer.
const _candidates = [
  (1550, 'dog', 0.04),
  (1680, 'problem', 0.02),
  (1810, 'while', 0.06),
  (1960, 'cat', 0.03),
  (2140, 'bit', 0.08),
  (2360, 'goat', 0.01),
  (2620, 'lamb', 0.97),
];

const _typeStart = 250; // ms
const _perChar = 65; // ms
const _total = 3000; // ms

class _TokenPredictionState extends State<TokenPrediction>
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
  Widget build(BuildContext context) {
    final style = zalando(26, color: Palette.muted);
    final hidden = style.copyWith(color: Colors.transparent);
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final ms = _clock.value * _total;
        final typed = ((ms - _typeStart) / _perChar).floor().clamp(
          0,
          _prompt.length,
        );
        (int, String, double)? candidate;
        for (final c in _candidates) {
          if (ms >= c.$1) candidate = c;
        }
        final landed = candidate == _candidates.last;
        final caret = WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Container(
            width: 4,
            height: style.fontSize! * 0.85,
            color: landed
                ? Colors.transparent
                : Palette.accent.withValues(alpha: 0.8),
          ),
        );
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: _prompt.substring(0, typed), style: style),
                if (candidate == null) caret,
                // The rest of the prompt and the token slot keep their space so
                // nothing moves while it types.
                TextSpan(text: _prompt.substring(typed), style: hidden),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: SizedBox(
                    width: 440,
                    child: candidate == null
                        ? const SizedBox()
                        : Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: candidate.$2,
                                  style: landed
                                      ? zalando(
                                          26,
                                          weight: 700,
                                          color: Palette.accent,
                                        )
                                      : style.copyWith(
                                          color: Palette.muted.withValues(
                                            alpha: 0.55,
                                          ),
                                          fontStyle: FontStyle.italic,
                                        ),
                                ),
                                caret, // transparent once landed
                                TextSpan(
                                  text: '  ${(candidate.$3 * 100).round()}%',
                                  style: zalando(
                                    14,
                                    color: landed
                                        ? Palette.accent.withValues(alpha: 0.7)
                                        : Palette.muted.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
