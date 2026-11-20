import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The 60% stat as a cut you can watch: a code listing (an editor minimap
/// of syntax-colored lines) sits beside the number. When the slide appears,
/// 60% of its lines get struck out one after another and collapse away, the
/// lines below closing up, while the number counts up from 0% to 60% as they
/// go. It settles on the shorter listing next to "60%" and the caption.
class SixtyStat extends StatefulWidget {
  const SixtyStat({super.key, required this.caption});
  final String caption;

  @override
  State<SixtyStat> createState() => _SixtyStatState();
}

/// The clock runs through the end of the landing pop, so the number comes
/// back to rest at its normal size.
final int _total = _landMs + _popMs; // ms
const _popMs = 350;

class _SixtyStatState extends State<SixtyStat>
    with SingleTickerProviderStateMixin {
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
  Widget build(BuildContext context) => Center(
    child: AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final ms = _clock.value * _total;
        final cut = _Listing.cutAt(ms);
        final percent = (60 * cut).round();
        // A small pop as the count lands.
        final popT = (ms - _landMs) / _popMs;
        final pop = popT <= 0 || popT >= 1 ? 0.0 : math.sin(math.pi * popT);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Listing(ms),
            const SizedBox(width: 110),
            SizedBox(
              width: 1000, // the caption breaks after "cut"
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.scale(
                    scale: 1 + 0.06 * pop,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$percent%',
                      style: zalando(100, weight: 800, color: Palette.statBlue),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.caption,
                    style: zalando(
                      24,
                      color: const Color.fromRGBO(224, 241, 255, 1),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// One line of the listing: its indent level, token bar widths, and whether
/// it gets cut.
typedef _Line = (int indent, List<double> tokens, bool cut);

const _rows = 30;
const _rowH = 14.0, _rowGap = 9.0, _pad = 40.0, _width = 560.0;
const _strikeStart = 350, _strikeEach = 170, _strikeStagger = 62;
const _collapseStart = 1250, _collapseEach = 420, _collapseStagger = 85;

/// When the last line has closed up and the count reaches 60%.
final _landMs =
    _collapseStart + (_cutCount - 1) * _collapseStagger + _collapseEach;

final _cutCount = _lines.where((l) => l.$3).length; // 18 of 30: 60%

/// A deterministic, code-shaped listing: blocks that indent and close, with
/// 18 of the 30 lines marked to cut, spread through the file.
final List<_Line> _lines = () {
  final rng = math.Random(60);
  const cut = {
    2, 3, 4, 5, 7, 8, 9, 13, 14, 15, 16, 19, 20, 21, 24, 25, 26, 27, //
  };
  final lines = <_Line>[];
  var indent = 0;
  for (var i = 0; i < _rows; i++) {
    final closing = indent > 0 && rng.nextDouble() < 0.28;
    if (closing) indent--;
    final n = closing ? 1 : 1 + rng.nextInt(4);
    final room = _width - 2 * _pad - indent * 34 - 40;
    final tokens = <double>[];
    var used = 0.0;
    for (var k = 0; k < n; k++) {
      final w = closing ? 14.0 : 26 + rng.nextDouble() * 120;
      if (used + w > room) break;
      tokens.add(w);
      used += w + 12;
    }
    lines.add((indent, tokens, cut.contains(i)));
    if (!closing && indent < 3 && rng.nextDouble() < 0.4) indent++;
  }
  return lines;
}();

/// The listing card at time [ms]: struck lines dim, then their rows shrink
/// to nothing so the rest close up.
class _Listing extends StatelessWidget {
  const _Listing(this.ms);
  final double ms;

  static double _ease(double t) =>
      Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));

  /// How far line number [k] (k-th cut line) has struck through, 0..1.
  static double strike(double ms, int k) =>
      _ease((ms - _strikeStart - k * _strikeStagger) / _strikeEach);

  /// How far the k-th cut line has collapsed, 0..1.
  static double collapse(double ms, int k) =>
      _ease((ms - _collapseStart - k * _collapseStagger) / _collapseEach);

  /// The fraction of the cut that's done (rows closed up), 0..1.
  static double cutAt(double ms) {
    var sum = 0.0;
    for (var k = 0; k < _cutCount; k++) {
      sum += collapse(ms, k);
    }
    return sum / _cutCount;
  }

  @override
  Widget build(BuildContext context) {
    var h = 0.0;
    var k = 0;
    for (final line in _lines) {
      final f = line.$3 ? 1 - collapse(ms, k++) : 1.0;
      h += (_rowH + _rowGap) * f;
    }
    return Container(
      width: _width,
      height: h - _rowGap + 2 * _pad + 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CustomPaint(painter: _ListingPainter(ms)),
      ),
    );
  }
}

class _ListingPainter extends CustomPainter {
  _ListingPainter(this.ms);
  final double ms;

  static const _palette = [
    Palette.accent,
    Palette.statBlue,
    Palette.soft,
    Palette.muted,
    Color(0xFFC792EA), // a keyword purple, as editors do
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Editor window dots.
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(_pad + i * 24, _pad - 8),
        7,
        Paint()..color = Colors.white.withValues(alpha: 0.16),
      );
    }
    final rng = math.Random(19);
    var y = _pad + 26;
    var k = 0;
    for (final (indent, tokens, cut) in _lines) {
      final strike = cut ? _Listing.strike(ms, k) : 0.0;
      final keep = cut ? 1 - _Listing.collapse(ms, k) : 1.0;
      if (cut) k++;
      final rowH = (_rowH + _rowGap) * keep;
      final colors = [
        for (final _ in tokens) _palette[rng.nextInt(_palette.length)],
      ];
      if (keep > 0.001) {
        canvas.save();
        // Collapsing rows squash toward their middle and fade.
        final mid = y + rowH / 2 - _rowGap * keep / 2;
        canvas.translate(0, mid);
        canvas.scale(1, keep);
        final alpha = 0.75 * (1 - 0.6 * strike) * keep;
        var x = _pad + indent * 34.0;
        final start = x;
        for (final (i, w) in tokens.indexed) {
          final c = Color.lerp(colors[i], Palette.warn, strike * 0.6)!;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, -_rowH / 2, w, _rowH),
              const Radius.circular(7),
            ),
            Paint()..color = c.withValues(alpha: alpha),
          );
          x += w + 12;
        }
        if (strike > 0) {
          // The strike runs left to right, past the ends of the line.
          final from = start - 14;
          final to = from + (x - 12 + 14 - from + 14) * strike;
          canvas.drawLine(
            Offset(from, 0),
            Offset(to, 0),
            Paint()
              ..color = Palette.warn.withValues(alpha: keep)
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round,
          );
        }
        canvas.restore();
      }
      y += rowH;
    }
  }

  @override
  bool shouldRepaint(_ListingPainter old) => old.ms != ms;
}
