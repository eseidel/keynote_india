import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'layouts.dart' show Picture;
import 'theme.dart';

/// "A Cambrian explosion" of portable efforts: the logo wall spawns. The
/// four real efforts flicker into existence one after another and pop into
/// place with a flash; around and behind them a dozen ghost apps (bare
/// skeleton screens) flicker in too, hold for a moment, and blink out like
/// old CRTs: most new efforts don't survive. After about three seconds only
/// the four remain, laid out exactly like LogoWall.
class CambrianWall extends StatefulWidget {
  const CambrianWall({super.key, required this.items});
  final List<(String image, String caption)> items;

  @override
  State<CambrianWall> createState() => _CambrianWallState();
}

/// The last ghost blinks out at 3000ms (2350 + 650); stop ticking then.
const _totalMs = 3000;

/// When each real tile starts to spawn (ms).
const _tileStarts = [250, 600, 950, 1300];
const _tileSpawnMs = 650;
int _tileStart(int i) =>
    i < _tileStarts.length ? _tileStarts[i] : 1300 + 350 * (i - 3);

class _CambrianWallState extends State<CambrianWall>
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

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // Ghosts sit behind the wall, so they never cover a real tile.
      CustomPaint(painter: _GhostPainter(_clock)),
      Padding(
        padding: const EdgeInsets.fromLTRB(140, 75, 140, 75),
        child: Center(
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            childAspectRatio: 2.0,
            mainAxisSpacing: 30,
            crossAxisSpacing: 60,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final (i, (image, caption)) in widget.items.indexed)
                AnimatedBuilder(
                  animation: _clock,
                  builder: (context, child) => _Spawn(
                    ms: _clock.value * _totalMs - _tileStart(i),
                    seed: i,
                    child: child!,
                  ),
                  child: Column(
                    children: [
                      Expanded(child: Picture(image)),
                      const SizedBox(height: 12),
                      Text(caption, style: zalando(16, color: Palette.muted)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Flicker pattern shared by tiles and ghosts: on/off from a deterministic
/// hash of the frame bucket, so captures are repeatable.
bool _flickerOn(int seed, double ms) {
  final bucket = (ms / 45).floor();
  final h = math.Random(seed * 7919 + bucket).nextDouble();
  return h > 0.38;
}

/// A real tile coming into existence [ms] after its start: two or three
/// stuttering flickers, then a springy pop to full size with an accent
/// flash that drains back to the real picture.
class _Spawn extends StatelessWidget {
  const _Spawn({required this.ms, required this.seed, required this.child});
  final double ms;
  final int seed;
  final Widget child;

  static const _flickerMs = 220.0;

  @override
  Widget build(BuildContext context) {
    // One tree shape for the whole life of the tile (identity values at
    // rest), so the tile's Image is never unmounted mid-pop.
    double opacity;
    double scale;
    double flash;
    if (ms <= 0) {
      opacity = 0;
      scale = 0.9;
      flash = 0;
    } else if (ms >= _tileSpawnMs) {
      opacity = 1;
      scale = 1;
      flash = 0;
    } else if (ms < _flickerMs) {
      // Stuttering: a faint, slightly small tile blinking on and off.
      opacity = _flickerOn(seed + 100, ms) ? 0.55 : 0.08;
      scale = 0.9;
      flash = 0.85;
    } else {
      final u = ((ms - _flickerMs) / (_tileSpawnMs - _flickerMs)).clamp(
        0.0,
        1.0,
      );
      opacity = 1;
      scale = 0.9 + 0.1 * Curves.elasticOut.transform(u);
      // The flash peaks as it pops and drains away.
      flash = 0.85 * (1 - u) * (1 - u);
    }
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            Palette.accent.withValues(alpha: flash),
            BlendMode.srcATop,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// One would-be effort: where it appears (canvas px), when (ms), how long
/// it lives (ms) and its color.
typedef _Ghost = (Rect rect, int start, int life, Color color);

const _a = Palette.accent;
const _b = Palette.statBlue;
const _s = Palette.soft;
const _w = Palette.warn;

final List<_Ghost> _ghosts = [
  (const Rect.fromLTWH(180, 175, 120, 215), 120, 760, _a),
  (const Rect.fromLTWH(780, 205, 125, 225), 480, 820, _b),
  (const Rect.fromLTWH(1040, 600, 225, 150), 700, 900, _s),
  (const Rect.fromLTWH(1525, 585, 225, 140), 1050, 780, _a),
  (const Rect.fromLTWH(1580, 765, 120, 175), 1450, 820, _w),
  (const Rect.fromLTWH(1055, 790, 175, 130), 1700, 700, _b),
  (const Rect.fromLTWH(20, 420, 100, 175), 900, 900, _s),
  (const Rect.fromLTWH(1795, 250, 105, 185), 1250, 900, _a),
  (const Rect.fromLTWH(590, 18, 260, 95), 1550, 800, _b),
  (const Rect.fromLTWH(1110, 965, 250, 85), 1900, 750, _a),
  (const Rect.fromLTWH(938, 340, 50, 150), 2050, 650, _w),
  (const Rect.fromLTWH(1320, 30, 240, 90), 300, 700, _s),
  (const Rect.fromLTWH(560, 955, 230, 90), 2200, 650, _b),
  (const Rect.fromLTWH(1365, 610, 115, 200), 2350, 650, _a),
];

class _GhostPainter extends CustomPainter {
  _GhostPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  static const _inMs = 90.0; // flicker on
  static const _outMs = 170.0; // CRT collapse

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
      canvas.save();
      canvas.translate(rect.center.dx + jitter, rect.center.dy);
      canvas.scale(sx, sy);
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
