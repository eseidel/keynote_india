import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'theme.dart';

/// "Verify one thing, not two": under the statement, two copies of the app,
/// iOS and Android, each run their own checklist, the same four checks
/// ticking off twice. Then the two slide together and merge into one, which
/// gathers itself into a single badge, and one big check mark draws in it.
/// Settles in under four seconds on the one check.
class VerifySlide extends StatefulWidget {
  const VerifySlide(this.text, {super.key});
  final String text;

  @override
  State<VerifySlide> createState() => _VerifySlideState();
}

const _checks = ['Checkout', 'Sign in', 'Payments', 'Offline'];

// Timeline, ms.
const _runStart = 250, _runEach = 330, _spin = 280, _skew = 170;
const _mergeStart = 2000, _mergeMs = 650;
const _morphStart = 2550, _morphMs = 500;
const _checkStart = 3000, _checkMs = 450;
const _total = 3600;

const _cardW = 540.0, _cardH = 392.0, _gap = 150.0, _badge = 270.0;

double _phase(double ms, int start, int length) =>
    ((ms - start) / length).clamp(0.0, 1.0);

class _VerifySlideState extends State<VerifySlide>
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
          const SizedBox(height: 90),
          SizedBox(
            width: 2 * _cardW + _gap,
            height: _cardH,
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, _) => _Stage(_clock.value * _total),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Everything under the statement at time [ms].
class _Stage extends StatelessWidget {
  const _Stage(this.ms);
  final double ms;

  @override
  Widget build(BuildContext context) {
    final merge = Curves.easeInOutCubic.transform(
      _phase(ms, _mergeStart, _mergeMs),
    );
    final morph = Curves.easeInOutCubic.transform(
      _phase(ms, _morphStart, _morphMs),
    );
    final dx = (_cardW + _gap) / 2 * (1 - merge);
    // The two copies fade out as the merged one fades in over them.
    final twoAlpha = 1 - _phase(ms, _mergeStart + 400, 250);
    // Their checklists fade before the cards overlap, leaving two shells
    // that slide into one.
    final content =
        1 - Curves.easeOut.transform(_phase(ms, _mergeStart, _mergeMs ~/ 3));
    final check = _phase(ms, _checkStart, _checkMs);
    return Stack(
      alignment: Alignment.center,
      children: [
        if (twoAlpha > 0)
          // Labels in caps, except iOS keeps its own case.
          for (final (i, label) in ['iOS', 'ANDROID'].indexed)
            Transform.translate(
              offset: Offset(i == 0 ? -dx : dx, 0),
              child: Opacity(
                opacity: twoAlpha,
                child: _Card(
                  label: label,
                  ms: ms - (i == 0 ? 0 : _skew),
                  content: content,
                ),
              ),
            ),
        if (twoAlpha < 1) _Merged(ms: ms, morph: morph, alpha: 1 - twoAlpha),
        // One run covers both.
        if (check > 0)
          Positioned(
            bottom: 0,
            child: Opacity(
              opacity: Curves.easeOut.transform(check),
              child: Text(
                'iOS + ANDROID',
                style: zalando(
                  14,
                  weight: 700,
                  color: Palette.muted,
                ).copyWith(letterSpacing: 3),
              ),
            ),
          ),
      ],
    );
  }
}

/// The merged copy: a card shell that gathers into a round badge, then the
/// check draws in it.
class _Merged extends StatelessWidget {
  const _Merged({required this.ms, required this.morph, required this.alpha});
  final double ms;
  final double morph;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    final w = _lerp(_cardW, _badge, morph);
    final h = _lerp(_cardH, _badge, morph);
    final check = _phase(ms, _checkStart, _checkMs);
    // A little pop as the check lands.
    final pop = check <= 0
        ? 1.0
        : 1 + 0.08 * math.sin(math.pi * Curves.easeOut.transform(check));
    return Opacity(
      opacity: alpha,
      child: Transform.scale(
        scale: pop,
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Color.lerp(
              Colors.white.withValues(alpha: 0.07),
              Palette.accent,
              morph,
            ),
            borderRadius: BorderRadius.circular(_lerp(28, _badge / 2, morph)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14 * (1 - morph)),
            ),
            boxShadow: [
              BoxShadow(
                color: Palette.accent.withValues(alpha: 0.35 * morph),
                blurRadius: 60 * morph,
              ),
            ],
          ),
          child: check > 0
              ? CustomPaint(
                  painter: _BigCheck(Curves.easeInOutCubic.transform(check)),
                )
              : null,
        ),
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// One copy's checklist: its platform, a pass count, and four checks that
/// run one after another.
class _Card extends StatelessWidget {
  const _Card({required this.label, required this.ms, required this.content});
  final String label;
  final double ms; // this copy's clock
  final double content; // opacity of the checklist inside the card

  @override
  Widget build(BuildContext context) {
    final states = [
      for (var k = 0; k < _checks.length; k++)
        (ms - _runStart - k * _runEach) / _spin, // <0 queued, 0..1 running
    ];
    final passed = states.where((s) => s >= 1).length;
    return Container(
      width: _cardW,
      height: _cardH,
      padding: const EdgeInsets.fromLTRB(40, 34, 40, 30),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: content <= 0
          ? null
          : Opacity(
              opacity: content,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: zalando(
                          14,
                          weight: 700,
                          color: Palette.muted,
                        ).copyWith(letterSpacing: 3),
                      ),
                      const Spacer(),
                      Text(
                        '$passed/${_checks.length} passed',
                        style: zalando(
                          14,
                          weight: 600,
                          color: passed == _checks.length
                              ? Palette.accent
                              : Palette.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  for (final (k, name) in _checks.indexed)
                    SizedBox(
                      height: 66,
                      child: Row(
                        children: [
                          SizedBox.square(
                            dimension: 36,
                            child: CustomPaint(
                              painter: _Status(states[k], spin: ms / 1000),
                            ),
                          ),
                          const SizedBox(width: 22),
                          Text(
                            name,
                            style: zalando(
                              22,
                              weight: 500,
                              color: states[k] >= 1
                                  ? Palette.text
                                  : Palette.soft,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// A check's status: a faint ring while queued, a spinner while running,
/// a filled tick once it passes.
class _Status extends CustomPainter {
  _Status(this.state, {required this.spin});
  final double state; // <0 queued, 0..1 running, >=1 passed
  final double spin; // seconds, for the spinner's turn

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    if (state < 0) {
      canvas.drawCircle(
        c,
        r,
        ring..color = Palette.muted.withValues(alpha: .4),
      );
    } else if (state < 1) {
      canvas.drawCircle(
        c,
        r,
        ring..color = Palette.muted.withValues(alpha: .2),
      );
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        spin * 2 * math.pi * 1.6,
        math.pi * 0.9,
        false,
        ring..color = Palette.accent,
      );
    } else {
      // Pops in slightly larger, then settles.
      final pop = ((state - 1) * _spin / 160).clamp(0.0, 1.0);
      final s = 1 + 0.18 * math.sin(math.pi * pop);
      canvas.drawCircle(c, r * s, Paint()..color = Palette.accent);
      final tick = Path()
        ..moveTo(c.dx - r * 0.42, c.dy + r * 0.02)
        ..lineTo(c.dx - r * 0.1, c.dy + r * 0.34)
        ..lineTo(c.dx + r * 0.46, c.dy - r * 0.3);
      canvas.drawPath(
        tick,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Palette.background,
      );
    }
  }

  @override
  bool shouldRepaint(_Status old) => old.state != state || old.spin != spin;
}

/// The one big check, drawn stroke by stroke as [t] goes 0..1.
class _BigCheck extends CustomPainter {
  _BigCheck(this.t);
  final double t;

  static Size? _size;
  static PathMetric? _metric;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    // The check's shape only depends on the size; measure it once.
    if (size != _size) {
      final c = size.center(Offset.zero);
      final path = Path()
        ..moveTo(c.dx - s * 0.24, c.dy + s * 0.01)
        ..lineTo(c.dx - s * 0.06, c.dy + s * 0.19)
        ..lineTo(c.dx + s * 0.26, c.dy - s * 0.17);
      _size = size;
      _metric = path.computeMetrics().first;
    }
    final metric = _metric!;
    canvas.drawPath(
      metric.extractPath(0, metric.length * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Palette.background,
    );
  }

  @override
  bool shouldRepaint(_BigCheck old) => old.t != t;
}
