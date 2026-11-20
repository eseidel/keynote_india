import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// "A Cambrian explosion" of portable efforts. The four real ones burst out
/// of the middle of the slide as cards, spinning and lifted high (big, with
/// a long soft shadow), and land scattered across the slide, overlapping a
/// little, each at its own tilt in perspective, with an accent flash that
/// drains on landing. Around and behind them a dozen ghost apps (bare
/// skeleton screens) fly out of the same burst, flicker, hold for a moment
/// and blink out like old CRTs: most new efforts don't survive. After
/// about three seconds only the four cards remain, each picture and
/// caption square enough on to read.
class CambrianWall extends StatefulWidget {
  const CambrianWall({super.key, required this.items});
  final List<(String image, String caption)> items;

  @override
  State<CambrianWall> createState() => _CambrianWallState();
}

/// The last ghost blinks out at 3000ms (2350 + 650); stop ticking then.
const _totalMs = 3000;

/// Where everything bursts out from (canvas px).
const _origin = Offset(960, 560);

/// One card at rest: its center on the canvas, the picture's size, and its
/// tilt (roll in the slide's plane; yaw and pitch in perspective), plus
/// when it bursts out (ms).
typedef _Place = ({
  Offset center,
  Size picture,
  double roll,
  double yaw,
  double pitch,
  int startMs,
});

/// Laid out for the four pictures in deck order (Exact 800x620, DartNative
/// 2048x960, Discord 894x400, Skip 943x2048): the wide ones get width, the
/// tall phone leans on Exact's corner, corners overlapping.
const _places = <_Place>[
  (
    center: Offset(650, 350),
    picture: Size(493, 382),
    roll: -0.09,
    yaw: 0.14,
    pitch: 0.0,
    startMs: 150,
  ),
  (
    center: Offset(1320, 300),
    picture: Size(651, 305),
    roll: 0.045,
    yaw: -0.12,
    pitch: 0.06,
    startMs: 260,
  ),
  (
    center: Offset(1210, 780),
    picture: Size(634, 283),
    roll: 0.05,
    yaw: -0.12,
    pitch: -0.05,
    startMs: 370,
  ),
  (
    center: Offset(345, 770),
    picture: Size(190, 413),
    roll: 0.1,
    yaw: 0.1,
    pitch: 0.0,
    startMs: 480,
  ),
];

/// Card chrome around the picture: padding, gap, caption line height.
const _pad = 14.0;
const _gap = 10.0;
const _captionH = 50.0;

const _flyMs = 900.0;

double _ramp(double ms, double start, double length) =>
    ((ms - start) / length).clamp(0.0, 1.0);

class _CambrianWallState extends State<CambrianWall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  )..forward();

  @override
  void initState() {
    super.initState();
    // _places is hand-laid-out for exactly these four pictures; a fifth
    // would silently never appear.
    assert(
      widget.items.length == _places.length,
      'CambrianWall lays out exactly ${_places.length} items',
    );
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // Ghosts sit behind the cards, so they never cover a real one.
      CustomPaint(painter: _GhostPainter(_clock)),
      for (final (i, (image, caption)) in widget.items.indexed)
        if (i < _places.length) _card(i, image, caption),
    ],
  );

  Widget _card(int i, String image, String caption) {
    final place = _places[i];
    final w = place.picture.width + 2 * _pad;
    final h = place.picture.height + 2 * _pad + _gap + _captionH;
    // Built once; only the transform, opacity, shadow and flash change.
    final face = Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            image,
            width: place.picture.width,
            height: place.picture.height,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        const SizedBox(height: _gap),
        SizedBox(
          height: _captionH,
          child: Center(
            child: Text(
              caption,
              maxLines: 1,
              style: zalando(16, color: Palette.soft),
            ),
          ),
        ),
      ],
    );
    return Positioned(
      left: place.center.dx - w / 2,
      top: place.center.dy - h / 2,
      width: w,
      height: h,
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, child) =>
            _burst(i, _clock.value * _totalMs - place.startMs, child!),
        child: face,
      ),
    );
  }

  /// Card [i] [ms] after it starts bursting out: from a speck at the
  /// origin, spinning, lifted high, to its resting place and tilt.
  Widget _burst(int i, double ms, Widget face) {
    final place = _places[i];
    // One tree shape for the card's whole life (identity-ish values at
    // rest), so the Image is never unmounted mid-flight.
    final p = _ramp(ms, 0, _flyMs);
    final travel = 1 - Curves.easeOutBack.transform(p); // overshoots a bit
    final lift = 1 - Curves.easeOutCubic.transform(p); // 1 in the air
    final grow = Curves.easeOutCubic.transform(_ramp(ms, 0, _flyMs * 0.3));
    // Held high (25% bigger, long shadow) through the first part of the
    // flight, then set down onto the slide.
    final hover =
        1 -
        Curves.easeInOutCubic.transform(
          _ramp(ms, _flyMs * 0.25, _flyMs * 0.75),
        );
    final opacity = ms <= 0 ? 0.0 : _ramp(ms, 0, 120);
    // The flash peaks as it lands and drains away.
    final flash = 0.75 * math.pow(1 - _ramp(ms, _flyMs * 0.45, 650), 2);

    final from = _origin - place.center;
    final spin = (i.isEven ? 1 : -1) * 1.4;
    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0009)
      ..translateByDouble(from.dx * travel, from.dy * travel, 0, 1)
      ..rotateY(place.yaw + 0.8 * lift * (i.isEven ? -1 : 1))
      ..rotateX(place.pitch + 0.5 * lift)
      ..rotateZ(place.roll + spin * lift)
      // Grows from a speck to a lifted 1.25x, then is set down at 1x.
      ..scaleByDouble(
        (0.15 + 0.85 * grow) * (1 + 0.25 * hover),
        (0.15 + 0.85 * grow) * (1 + 0.25 * hover),
        1,
        1,
      );

    return Opacity(
      opacity: opacity,
      child: Transform(
        alignment: Alignment.center,
        transform: transform,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF1C2431),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x1FFFFFFF)),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.55 - 0.2 * hover),
                blurRadius: 18 + 50 * hover,
                offset: Offset(0, 14 + 60 * hover),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(_pad),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Palette.accent.withValues(alpha: flash.toDouble()),
                BlendMode.srcATop,
              ),
              child: face,
            ),
          ),
        ),
      ),
    );
  }
}

/// Flicker pattern for the ghosts: on/off from a deterministic hash of the
/// frame bucket, so captures are repeatable.
bool _flickerOn(int seed, double ms) {
  final bucket = (ms / 45).floor();
  final h = math.Random(seed * 7919 + bucket).nextDouble();
  return h > 0.38;
}

/// One would-be effort: where it appears (canvas px), when (ms), how long
/// it lives (ms) and its color.
typedef _Ghost = (Rect rect, int start, int life, Color color);

const _a = Palette.accent;
const _b = Palette.statBlue;
const _s = Palette.soft;
const _w = Palette.warn;

// Placed in the gaps the cards leave (and partly behind their edges).
final List<_Ghost> _ghosts = [
  (const Rect.fromLTWH(140, 130, 120, 215), 120, 760, _a),
  (const Rect.fromLTWH(1720, 140, 130, 220), 480, 820, _b),
  (const Rect.fromLTWH(590, 640, 225, 150), 700, 900, _s),
  (const Rect.fromLTWH(1690, 590, 190, 140), 1050, 780, _a),
  (const Rect.fromLTWH(660, 820, 130, 170), 1450, 820, _w),
  (const Rect.fromLTWH(50, 450, 175, 130), 1700, 700, _b),
  (const Rect.fromLTWH(40, 700, 110, 190), 900, 900, _s),
  (const Rect.fromLTWH(1760, 770, 120, 180), 1250, 900, _a),
  (const Rect.fromLTWH(560, 15, 260, 80), 1550, 800, _b),
  (const Rect.fromLTWH(520, 975, 230, 75), 1900, 750, _a),
  (const Rect.fromLTWH(1730, 400, 110, 150), 2050, 650, _w),
  (const Rect.fromLTWH(1060, 12, 240, 70), 300, 700, _s),
  (const Rect.fromLTWH(180, 900, 170, 90), 2200, 650, _b),
  (const Rect.fromLTWH(860, 560, 90, 150), 2350, 650, _a),
];

class _GhostPainter extends CustomPainter {
  _GhostPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  static const _inMs = 90.0; // flicker on
  static const _outMs = 170.0; // CRT collapse
  static const _flyOutMs = 380.0; // out of the burst

  @override
  void paint(Canvas canvas, Size size) {
    final now = t.value * _totalMs;
    for (final (i, (rect, start, life, color)) in _ghosts.indexed) {
      final ms = now - start;
      if (ms <= 0 || ms >= life) continue;
      // Flickers while alive, steadier in the middle of its life.
      final edge = ms < 260 || ms > life - _outMs - 120;
      var alpha = edge ? (_flickerOn(i, ms) ? 1.0 : 0.15) : 0.9;
      if (ms < _inMs) alpha *= ms / _inMs;
      // Dying: squashes to a bright line, then to a dot, like a CRT off.
      var sx = 1.0, sy = 1.0;
      final dying = ms - (life - _outMs);
      if (dying > 0) {
        final d = dying / _outMs;
        sy = math.max(0.02, 1 - Curves.easeIn.transform(math.min(1, d * 1.6)));
        sx = d < 0.6 ? 1 : 1 - Curves.easeIn.transform((d - 0.6) / 0.4);
      }
      // A little sideways jitter while unstable.
      final jitter = edge
          ? (math.Random(i * 31 + (ms / 45).floor()).nextDouble() - 0.5) * 10
          : 0.0;
      // Thrown out of the same burst as the cards.
      final out = Curves.easeOutCubic.transform(math.min(1, ms / _flyOutMs));
      final at = Offset.lerp(_origin, rect.center, out)!;
      final grow = 0.2 + 0.8 * out;
      canvas.save();
      canvas.translate(at.dx + jitter, at.dy);
      canvas.scale(sx * grow, sy * grow);
      _ghost(canvas, rect.size, color, alpha, collapsing: dying > 0);
      canvas.restore();
    }
  }

  /// A skeleton app screen centered on the origin.
  void _ghost(
    Canvas canvas,
    Size size,
    Color color,
    double alpha, {
    required bool collapsing,
  }) {
    final r = Rect.fromCenter(
      center: Offset.zero,
      width: size.width,
      height: size.height,
    );
    final body = RRect.fromRectAndRadius(r, const Radius.circular(14));
    canvas.drawRRect(
      body.inflate(6),
      Paint()
        ..color = color.withValues(alpha: 0.22 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = color.withValues(alpha: (collapsing ? 0.5 : 0.08) * alpha),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color.withValues(alpha: 0.75 * alpha),
    );
    if (collapsing) return;
    // Skeleton UI: a header bar, a few lines, a button.
    final fill = Paint()..color = color.withValues(alpha: 0.4 * alpha);
    final pad = math.min(size.width, size.height) * 0.12;
    final inner = r.deflate(pad);
    final rowH = math.max(6.0, inner.height * 0.09);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(inner.left, inner.top, inner.width, rowH * 1.4),
        Radius.circular(rowH),
      ),
      fill,
    );
    final lines = inner.height > 120 ? 4 : 2;
    for (var k = 0; k < lines; k++) {
      final y = inner.top + rowH * 2.6 + k * rowH * 1.8;
      if (y + rowH > inner.bottom - rowH * 2) break;
      final w = inner.width * (k.isEven ? 0.85 : 0.6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(inner.left, y, w, rowH * 0.8),
          Radius.circular(rowH),
        ),
        Paint()..color = color.withValues(alpha: 0.25 * alpha),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          inner.left + inner.width * 0.2,
          inner.bottom - rowH * 1.6,
          inner.width * 0.6,
          rowH * 1.6,
        ),
        Radius.circular(rowH),
      ),
      fill,
    );
  }

  @override
  bool shouldRepaint(_GhostPainter old) => false; // repaints via t
}
