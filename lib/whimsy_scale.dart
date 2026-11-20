import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// "Proven at scale": laid out like ListSlide, but the first item's number
/// races up through every order of magnitude (1, 10, 100, 1K ... 1M+) while
/// a field of tiny app tiles blooms across the slide behind the text, faster
/// and faster, one for every few hundred apps. Then the other items rise in
/// one after another. At rest it's the plain list over a faint field of apps.
class ScaleList extends StatefulWidget {
  const ScaleList({
    super.key,
    required this.title,
    required this.items,
    this.size = 40,
  });
  final String title;

  /// The first item may lead with a count like "1M+"; that's the one that
  /// races up.
  final List<String> items;
  final double size;

  @override
  State<ScaleList> createState() => _ScaleListState();
}

class _ScaleListState extends State<ScaleList>
    with SingleTickerProviderStateMixin {
  // Seconds.
  static const countStart = 0.35, countEnd = 2.25;
  static const firstItem = 0.15, nextItems = 2.35, itemGap = 0.4;
  static const rise = 0.5;

  late final double _total =
      nextItems + (widget.items.length - 2) * itemGap + rise + 0.05;
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_total * 1000).round()),
  )..forward();

  static final _count = RegExp(r'^(\d+)([KM])\+');

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  /// How far the count has climbed, 0 to 1, in orders of magnitude.
  double _climb(double t) =>
      ((t - countStart) / (countEnd - countStart)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) {
      final t = _clock.value * _total;
      return Stack(
        fit: StackFit.expand,
        children: [
          // Kept clear of the logo, slide number and section tracker.
          Positioned.fill(
            left: 90,
            right: 90,
            top: 30,
            bottom: 90,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _AppField(
                  _climb(t),
                  ((t - countEnd) / 0.6).clamp(0.0, 1.0),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 160, vertical: 90),
            child: Column(
              children: [
                Text(widget.title, style: headline(36, color: Palette.accent)),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (i, item) in widget.items.indexed)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: pt(widget.size) * 0.25,
                            ),
                            child: _arrive(
                              t -
                                  (i == 0
                                      ? firstItem
                                      : nextItems + (i - 1) * itemGap),
                              i == 0 ? _counting(item, t) : _text(item),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _text(String s) =>
      Text(s, textAlign: TextAlign.center, style: headline(widget.size));

  /// Rises into place and fades in over [rise] seconds from local time 0.
  Widget _arrive(double local, Widget child) {
    final f = Curves.easeOutCubic.transform((local / rise).clamp(0.0, 1.0));
    if (f >= 1) return child;
    return Opacity(
      opacity: f,
      child: Transform.translate(offset: Offset(0, (1 - f) * 40), child: child),
    );
  }

  /// The item with its leading count racing up to the real figure. The rest
  /// of the line sits where it'll end up; the count grows leftward from
  /// where its final text ends, so nothing jitters.
  Widget _counting(String item, double t) {
    final m = _count.firstMatch(item);
    final c = _climb(t);
    if (m == null || (c >= 1 && t > countEnd + 0.3)) return _text(item);
    final prefix = m.group(0)!;
    final target =
        int.parse(m.group(1)!) * (m.group(2) == 'M' ? 1000000 : 1000);
    final value = c >= 1
        ? target
        : math.pow(target, c).floor().clamp(0, target).toInt();
    final style = headline(widget.size);
    // Accent while racing, settling to the list's white.
    final settle = ((t - countEnd) / 0.3).clamp(0.0, 1.0);
    final countStyle = style.copyWith(
      color: Color.lerp(Palette.accent, Palette.text, settle),
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final measure = TextPainter(
      text: TextSpan(text: prefix, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final prefixWidth = measure.width;
    measure.dispose();
    final shown = value >= target ? prefix : '${_compact(value)}+';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: prefix,
                style: style.copyWith(color: const Color(0x00000000)),
              ),
              TextSpan(text: item.substring(prefix.length)),
            ],
          ),
          textAlign: TextAlign.center,
          style: style,
        ),
        Positioned(
          left: prefixWidth - 600,
          width: 600,
          top: 0,
          child: Text(
            shown,
            textAlign: TextAlign.right,
            maxLines: 1,
            softWrap: false,
            style: countStyle,
          ),
        ),
      ],
    );
  }

  static String _compact(int v) {
    if (v >= 1000000) return '${v ~/ 1000000}M';
    if (v >= 1000) return '${v ~/ 1000}K';
    return '$v';
  }
}

/// A faint field of app tiles across the slide, [climb] of the way grown in.
/// Tiles appear in a fixed random order, accelerating as the count climbs,
/// each flashing bright as it lands; the field thins out toward its edges
/// and, once full, dims by [settle] so the list reads cleanly over it.
class _AppField extends CustomPainter {
  _AppField(this.climb, this.settle);
  final double climb;
  final double settle;

  static const cell = 18.0, tile = 10.0;
  static const fill = 0.6; // share of the grid that ends up with a tile
  static List<int>? _order;
  static List<double>? _tone;

  @override
  void paint(Canvas canvas, Size size) {
    if (climb <= 0) return;
    final cols = (size.width / cell).floor(),
        rows = (size.height / cell).floor();
    final n = cols * rows;
    if (_order == null || _order!.length != n) {
      final rng = math.Random(42);
      _order = List.generate(n, (i) => i)..shuffle(rng);
      _tone = List.generate(n, (_) => rng.nextDouble());
    }
    final order = _order!, tone = _tone!;
    // Most tiles arrive late, like the count's last orders of magnitude.
    const pop = 80.0; // tiles over which one grows to full size
    final total = (n * fill).floor();
    // Overshoots by [pop] so that at the end every tile is fully grown.
    final shown = (total + pop) * math.pow(climb, 2.2);
    final ox = (size.width - cols * cell) / 2 + (cell - tile) / 2;
    final oy = (size.height - rows * cell) / 2 + (cell - tile) / 2;
    final c = size.center(Offset.zero);
    const hues = [Palette.accent, Palette.statBlue, Palette.soft];
    const alphas = [0.2, 0.15, 0.1];
    final dim = 1 - 0.35 * settle;
    final paint = Paint();
    for (var k = 0; k < shown.ceil() && k < total; k++) {
      final i = order[k];
      final x = ox + (i % cols) * cell + tile / 2;
      final y = oy + (i ~/ cols) * cell + tile / 2;
      // Elliptical falloff: full in the middle, gone at the edges.
      final ex = (x - c.dx) / (size.width / 2),
          ey = (y - c.dy) / (size.height / 2);
      final r = math.sqrt(ex * ex + ey * ey);
      final edge = 1 - ((r - 0.5) / 0.5).clamp(0.0, 1.0);
      if (edge <= 0) continue;
      final grow = ((shown - k) / pop).clamp(0.0, 1.0);
      final s = tile * Curves.easeOutBack.transform(grow);
      final h = tone[i] < 0.5 ? 0 : (tone[i] < 0.8 ? 1 : 2);
      final a = alphas[h] * edge * dim;
      // Fresh tiles flash bright, then settle to their faint tone.
      paint.color = Color.lerp(
        Palette.text.withValues(alpha: 0.7 * edge),
        hues[h].withValues(alpha: a),
        grow,
      )!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: s, height: s),
          Radius.circular(s * 0.28),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AppField old) =>
      old.climb != climb || old.settle != settle;
}
