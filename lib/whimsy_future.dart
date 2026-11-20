import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'layouts.dart';
import 'theme.dart';

/// "Let's go build the future": a skyline builds itself under the headline.
/// A horizon line draws out from the center, towers spring up out of the
/// ground one after another (each a column of widget-like window tiles), their
/// windows light up, and a sun rises in the gap between them: a warm disc
/// whose rays fly in one by one and click into place. Antenna lights come on
/// last and it holds, a city at sunrise. Plays once and settles in ~4.5s.
class FutureSkyline extends StatefulWidget {
  const FutureSkyline(this.text, {super.key});
  final String text;

  @override
  State<FutureSkyline> createState() => _FutureSkylineState();
}

class _FutureSkylineState extends State<FutureSkyline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4500),
  )..forward();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      CustomPaint(painter: _SkylinePainter(_t)),
      // Lifted clear of the skyline.
      Padding(
        padding: const EdgeInsets.only(bottom: 330),
        child: Statement(widget.text),
      ),
    ],
  );
}

/// One tower: left edge, width, height, rooftop kind.
enum _Roof { flat, dome, antenna, step }

class _Tower {
  const _Tower(this.x, this.w, this.h, this.roof, this.order);
  final double x, w, h;
  final _Roof roof;
  final int order; // rise order, center outward
}

const _ground = 950.0;
const _sunCenter = Offset(960, 850);
const _sunRadius = 138.0;

/// Skyline: low near the middle so the sun shows, taller toward the edges.
final List<_Tower> _towers = () {
  final rnd = math.Random(64);
  final raw = <(double, double, double, _Roof)>[];
  // Each side is laid out from the sun's gap toward its edge.
  for (final dir in [-1, 1]) {
    var edge = 960 + dir * 190.0; // the gap side of the next tower
    while (true) {
      final w = 84 + rnd.nextDouble() * 86;
      final x = dir > 0 ? edge : edge - w;
      if (x < 60 || x + w > 1860) break;
      final mid = (x + w / 2 - 960).abs() / 960; // 0 center, 1 edge
      final h = 120 + mid * 220 + rnd.nextDouble() * 130;
      final roof = _Roof.values[rnd.nextInt(_Roof.values.length)];
      raw.add((x, w, h, roof));
      edge += dir * (w + 14 + rnd.nextDouble() * 18);
    }
  }
  // Rise order: from the sun outward, alternating sides.
  final byDist = [for (var i = 0; i < raw.length; i++) i]
    ..sort(
      (a, b) => (raw[a].$1 + raw[a].$2 / 2 - 960).abs().compareTo(
        (raw[b].$1 + raw[b].$2 / 2 - 960).abs(),
      ),
    );
  final order = List.filled(raw.length, 0);
  for (final (k, i) in byDist.indexed) {
    order[i] = k;
  }
  return [
    for (final (i, (x, w, h, roof)) in raw.indexed)
      _Tower(x, w, h.clamp(120, 400), roof, order[i]),
  ];
}();

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0, 1);

class _SkylinePainter extends CustomPainter {
  _SkylinePainter(this.t) : super(repaint: t);
  final Animation<double> t;

  static const _warmTop = Color(0xFFFFD58A);

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    final sun = Curves.easeOutCubic.transform(_seg(v, 0.38, 0.8));

    // Warm haze over the horizon as the sun comes up.
    if (sun > 0) {
      final haze = Rect.fromLTRB(0, 560, size.width, _ground);
      canvas.drawRect(
        haze,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, 1),
            radius: 1.1,
            colors: [
              Palette.warn.withValues(alpha: 0.20 * sun),
              Palette.warn.withValues(alpha: 0),
            ],
          ).createShader(haze),
      );
    }

    _paintSun(canvas, v, sun);
    for (final tower in _towers) {
      _paintTower(canvas, tower, v);
    }

    // Horizon line, drawn out from the center.
    final g = Curves.easeOutCubic.transform(_seg(v, 0.0, 0.16));
    if (g > 0) {
      final half = 900 * g;
      final rect = Rect.fromLTRB(960 - half, _ground, 960 + half, _ground + 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Palette.accent.withValues(alpha: 0),
              Palette.accent,
              Color.lerp(Palette.accent, Palette.warn, sun)!,
              Palette.accent,
              Palette.accent.withValues(alpha: 0),
            ],
            stops: const [0, 0.3, 0.5, 0.7, 1],
          ).createShader(rect),
      );
    }
  }

  void _paintSun(Canvas canvas, double v, double sun) {
    if (sun <= 0) return;
    final c = Offset(
      _sunCenter.dx,
      _ground +
          _sunRadius +
          20 -
          (_ground + _sunRadius + 20 - _sunCenter.dy) * sun,
    );
    canvas.save();
    // The sun comes up from behind the horizon.
    canvas.clipRect(Rect.fromLTRB(0, 0, 1920, _ground));
    canvas.drawCircle(
      c,
      _sunRadius * 1.9,
      Paint()
        ..color = Palette.warn.withValues(alpha: 0.30 * sun)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90),
    );
    // Rays: rounded capsules that fly in and lock into a ring.
    const rays = 18;
    for (var i = 0; i < rays; i++) {
      final start = 0.62 + i / rays * 0.22;
      final k = _seg(v, start, start + 0.1);
      if (k <= 0) continue;
      final e = Curves.easeOutBack.transform(k);
      final a = -math.pi / 2 + (i - rays / 2) / rays * 2 * math.pi;
      final spin = (1 - e) * 0.9;
      final r = _sunRadius + 30 + (1 - e) * 140;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(a + spin);
      canvas.translate(r, 0);
      final long = i.isEven ? 46.0 : 30.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, -7, long, 14),
          const Radius.circular(7),
        ),
        Paint()
          ..color = Color.lerp(
            Palette.warn,
            _warmTop,
            i.isEven ? 0.6 : 0.0,
          )!.withValues(alpha: k),
      );
      canvas.restore();
    }
    final disc = Rect.fromCircle(center: c, radius: _sunRadius);
    canvas.drawCircle(
      c,
      _sunRadius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_warmTop, Palette.warn, Color(0xFFFF8A5B)],
        ).createShader(disc),
    );
    // Bands across the disc, like a retro sunrise, cut in background color.
    final band = Paint()..color = Palette.background.withValues(alpha: 0.55);
    for (var i = 0; i < 4; i++) {
      final y = c.dy + _sunRadius * (0.25 + i * 0.19);
      final hgt = 6.0 + i * 4;
      canvas.save();
      canvas.clipPath(Path()..addOval(disc));
      canvas.drawRect(Rect.fromLTRB(disc.left, y, disc.right, y + hgt), band);
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintTower(Canvas canvas, _Tower tw, double v) {
    final start = 0.06 + tw.order * 0.026;
    final k = _seg(v, start, start + 0.13);
    if (k <= 0) return;
    final e = Curves.easeOutBack.transform(k);
    final dy = (1 - e) * (tw.h + 40);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, 1920, _ground));
    canvas.translate(0, dy);
    final top = _ground - tw.h;
    final body = Rect.fromLTWH(tw.x, top, tw.w, tw.h + 8);
    final rr = RRect.fromRectAndCorners(
      body,
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
    );

    // Rooftops, behind the body so they join it cleanly.
    final roofPaint = Paint()..color = const Color(0xFF1E2C3D);
    final cx = tw.x + tw.w / 2;
    switch (tw.roof) {
      case _Roof.dome:
        canvas.drawCircle(Offset(cx, top + 4), tw.w * 0.3, roofPaint);
      case _Roof.step:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(tw.x + tw.w * 0.22, top - 34, tw.w * 0.56, 44),
            const Radius.circular(10),
          ),
          roofPaint,
        );
      case _Roof.antenna:
        canvas.drawLine(
          Offset(cx, top),
          Offset(cx, top - 56),
          Paint()
            ..color = const Color(0xFF3A4C63)
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
        // Its light comes on at the very end.
        final on = _seg(
          v,
          0.9 + (tw.order % 3) * 0.02,
          0.96 + (tw.order % 3) * 0.02,
        );
        canvas.drawCircle(
          Offset(cx, top - 60),
          7,
          Paint()
            ..color = Color.lerp(const Color(0xFF3A4C63), Palette.warn, on)!,
        );
        if (on > 0) {
          canvas.drawCircle(
            Offset(cx, top - 60),
            18,
            Paint()
              ..color = Palette.warn.withValues(alpha: 0.45 * on)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
          );
        }
      case _Roof.flat:
        break;
    }

    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF223246), Color(0xFF131C27)],
        ).createShader(body),
    );
    // Lit rim on the sun side.
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..shader = LinearGradient(
          begin: cx < 960 ? Alignment.centerRight : Alignment.centerLeft,
          end: cx < 960 ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            Palette.accent.withValues(alpha: 0.85),
            Palette.accent.withValues(alpha: 0.15),
          ],
        ).createShader(body),
    );

    // Windows: a grid of small rounded tiles, lit one by one.
    const ww = 16.0, wh = 20.0, gap = 10.0, margin = 16.0;
    final cols = ((tw.w - 2 * margin + gap) / (ww + gap)).floor();
    final rows = ((tw.h - 2 * margin - 10 + gap) / (wh + gap)).floor();
    if (cols > 0 && rows > 0) {
      final used = cols * ww + (cols - 1) * gap;
      final x0 = tw.x + (tw.w - used) / 2;
      final rnd = math.Random(tw.x.round());
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final h = rnd.nextDouble();
          final warm = rnd.nextDouble() < 0.22;
          final dark = rnd.nextDouble() < 0.28; // some stay dark
          final litAt = 0.3 + h * 0.5;
          final lit = dark ? 0.0 : _seg(v, litAt, litAt + 0.04);
          final rect = Rect.fromLTWH(
            x0 + c * (ww + gap),
            top + margin + 10 + r * (wh + gap),
            ww,
            wh,
          );
          final on = warm ? _warmTop : Palette.accent;
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            Paint()
              ..color = Color.lerp(
                const Color(0x0FFFFFFF),
                on.withValues(alpha: warm ? 0.85 : 0.7),
                lit,
              )!,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkylinePainter old) => old.t != t;
}
