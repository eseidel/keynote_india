import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// "Flutter goes everywhere": the three screens as a layered stage instead of a
/// flat row. Desktop swings in from the left and Embedded from the right,
/// each tilted in perspective with its outer edge leaning toward you and
/// bleeding off the slide; the phones drop in front, on top, last. Each one
/// arrives lifted (bigger, with a long soft shadow) and settles onto the
/// slide as its shadow tightens; the whole stage then drifts a little
/// (Ken Burns) while the car photo slowly zooms inside its frame. Once
/// they've landed, a tiny Dash drops onto the monitor and hops to the
/// phones, then to the car, ending perched there. The same app, wherever
/// there's a screen.
class HopGallery extends StatefulWidget {
  const HopGallery({super.key, required this.items});

  /// Each picture, its caption, and where Dash perches on it as a fraction
  /// of the picture (0,0 top left; 1,1 bottom right). Laid out as left,
  /// center (front) and right.
  final List<(String image, String caption, Offset perch)> items;

  @override
  State<HopGallery> createState() => _HopGalleryState();
}

/// Everything (cards, drift, Dash) is done by this point.
const _totalMs = 4400;

/// How each card sits at rest and arrives. [center] and [width] are
/// fractions of the stage (width of the stage for both x and width,
/// height of the stage for y); [yaw] / [pitch] / [roll] are the resting
/// tilt in radians; [from] is where it flies in from, as a fraction of the
/// stage size; [startMs] when it starts. [aspect] is the image's
/// width / height, so the card box is exactly the picture and Dash's perch
/// fractions land on the picture itself.
typedef _Place = ({
  Offset center,
  double width,
  double aspect,
  double yaw,
  double pitch,
  double roll,
  Offset from,
  double startMs,
  Offset caption,
});

const _places = <_Place>[
  // Desktop: back left, its left edge leaning out past the slide edge.
  (
    center: Offset(0.15, 0.495),
    width: 0.47,
    aspect: 1685 / 1372,
    yaw: -0.36,
    pitch: 0.0,
    roll: 0.0,
    from: Offset(-0.45, -0.12),
    startMs: 0,
    caption: Offset(0.15, 0.985),
  ),
  // Phones: front and center, nearly square on so they read best.
  (
    center: Offset(0.53, 0.54),
    width: 0.39,
    aspect: 1316 / 1072,
    yaw: 0.0,
    pitch: 0.07,
    roll: -0.03,
    from: Offset(0.0, 0.75),
    startMs: 380,
    caption: Offset(0.53, 0.985),
  ),
  // Embedded: back right, bleeding off the right edge.
  (
    center: Offset(0.87, 0.485),
    width: 0.42,
    aspect: 1200 / 900,
    yaw: 0.34,
    pitch: 0.0,
    roll: 0.0,
    from: Offset(0.45, -0.12),
    startMs: 160,
    caption: Offset(0.85, 0.985),
  ),
];

/// Back-to-front paint order: the phones go on top.
const _paintOrder = [0, 2, 1];

const _flyMs = 950.0;

/// 0..1 progress of [ms] through [start, start + length].
double _ramp(double ms, double start, double length) =>
    ((ms - start) / length).clamp(0.0, 1.0);

class _HopGalleryState extends State<HopGallery>
    with SingleTickerProviderStateMixin {
  final _stack = GlobalKey();
  late final _pictures = [for (final _ in widget.items) GlobalKey()];
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  )..forward();

  /// Each card's soft shadow, blurred once into a small padded image (see
  /// [_bakeShadow]); null until its picture has decoded.
  final List<ui.Image?> _shadows = [null, null, null];
  final List<(ImageStream, ImageStreamListener)> _streams = [];

  @override
  void initState() {
    super.initState();
    // The layout (_places, _paintOrder) is for exactly three screens. No
    // runtime guards: in release an extra item fails loudly (RangeError on
    // _places) rather than quietly dropping a picture.
    assert(widget.items.length == 3, 'HopGallery lays out exactly 3 items');
    // The car photo is an opaque rounded rect: no need to wait for it.
    _shadows[2] = _bakeShadow(null, _places[2].aspect, radius: 18);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_streams.isNotEmpty) return;
    // Desktop and phones are transparent around their backdrops, so their
    // shadows are their own silhouettes.
    for (final i in [0, 1]) {
      final stream = AssetImage(widget.items[i].$1)
          .resolve(createLocalImageConfiguration(context));
      final listener = ImageStreamListener((info, _) {
        if (!mounted || _shadows[i] != null) return;
        setState(
          () => _shadows[i] = _bakeShadow(info.image, _places[i].aspect),
        );
        info.dispose();
      });
      stream.addListener(listener);
      _streams.add((stream, listener));
    }
  }

  @override
  void dispose() {
    for (final (stream, listener) in _streams) {
      stream.removeListener(listener);
    }
    for (final image in _shadows) {
      image?.dispose();
    }
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final stage = box.biggest;
      return AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final ms = _clock.value * _totalMs;
          // Ken Burns: the whole stage eases in from a little right and
          // a touch bigger, coming to rest as Dash finishes.
          final drift = 1 - Curves.easeOutCubic.transform(ms / _totalMs);
          return Transform.translate(
            offset: Offset(28 * drift, 6 * drift),
            child: Transform.scale(
              scale: 1 + 0.025 * drift,
              child: Stack(
                key: _stack,
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  for (final i in _paintOrder) _card(i, stage, ms),
                  for (final (i, (_, caption, _)) in widget.items.indexed)
                    _caption(i, caption, stage, ms),
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _DashPainter(
                        ms,
                        perches: () => [
                          for (final (i, (_, _, perch)) in widget.items.indexed)
                            _perch(_pictures[i], perch),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  Widget _card(int i, Size stage, double ms) {
    final place = _places[i];
    final (image, _, _) = widget.items[i];
    final w = stage.width * place.width;
    final h = w / place.aspect;
    final c = Offset(
      stage.width * place.center.dx,
      stage.height * place.center.dy,
    );

    final p = _ramp(ms, place.startMs, _flyMs);
    final travel = 1 - Curves.easeOutBack.transform(p); // overshoots a bit
    final lift = 1 - Curves.easeOutCubic.transform(p); // 1 up high, 0 landed
    final fade = Curves.easeOut.transform(_ramp(ms, place.startMs, 240));

    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0011)
      ..translateByDouble(
        stage.width * place.from.dx * travel,
        stage.height * place.from.dy * travel,
        0,
        1,
      )
      ..rotateY(place.yaw + 0.9 * place.from.dx.sign * -lift)
      ..rotateX(place.pitch + (place.from.dx == 0 ? -0.5 * lift : 0))
      ..rotateZ(place.roll + 0.12 * lift * (i.isEven ? 1 : -1))
      ..scaleByDouble(1 + 0.22 * lift, 1 + 0.22 * lift, 1, 1);

    // Car photo: a slow zoom inside its frame.
    final zoom = i == 2
        ? 1 + 0.12 * (1 - Curves.easeOut.transform(ms / _totalMs))
        : 1.0;

    Widget picture = Image.asset(image, fit: BoxFit.fill);
    if (i == 2) {
      picture = ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Transform.scale(
          scale: zoom,
          alignment: const Alignment(0.3, 0.2),
          child: picture,
        ),
      );
    }

    // The shadow: a pre-blurred image with transparent padding, so every
    // edge is soft, just stretched over the card (no blur layer per frame).
    // It falls further, spreads and fades while the card is in the air.
    final bleed = _shadowPad * w / _shadowW;
    final shadow = Positioned(
      left: -bleed,
      top: -bleed,
      right: -bleed,
      bottom: -bleed,
      child: Transform.translate(
        offset: Offset(0, 16 + 70 * lift),
        child: Transform.scale(
          scale: 1 + 0.08 * lift,
          child: RawImage(
            image: _shadows[i],
            fit: BoxFit.fill,
            filterQuality: FilterQuality.low,
            color: Color.fromRGBO(0, 0, 0, 0.75 - 0.3 * lift),
            colorBlendMode: BlendMode.dstIn,
          ),
        ),
      ),
    );

    return Positioned(
      left: c.dx - w / 2,
      top: c.dy - h / 2,
      width: w,
      height: h,
      child: Opacity(
        opacity: fade,
        child: Transform(
          alignment: Alignment.center,
          transform: transform,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              shadow,
              SizedBox.expand(key: _pictures[i], child: picture),
            ],
          ),
        ),
      ),
    );
  }

  /// Upright and flat, so it reads; it rises in as its card lands.
  Widget _caption(int i, String caption, Size stage, double ms) {
    final place = _places[i];
    final u = Curves.easeOutCubic.transform(
      _ramp(ms, place.startMs + _flyMs * 0.55, 500),
    );
    return Positioned(
      left: stage.width * place.caption.dx - 300,
      width: 600,
      top: stage.height * place.caption.dy - 30,
      child: Opacity(
        opacity: u,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - u)),
          child: Text(
            caption,
            textAlign: TextAlign.center,
            style: zalando(16, color: Palette.muted),
          ),
        ),
      ),
    );
  }

  /// Where Dash's feet go on picture [key], in the stack's coordinates,
  /// through whatever perspective tilt the card has right now.
  Offset? _perch(GlobalKey key, Offset fraction) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.hasSize || box.size.isEmpty) {
      return null;
    }
    return box.localToGlobal(
      Offset(box.size.width * fraction.dx, box.size.height * fraction.dy),
      ancestor: stack,
    );
  }
}

/// Shadow images are baked this wide (plus padding), then stretched.
const _shadowW = 120.0;
const _shadowPad = 12.0;

/// One-time: a black silhouette of [src] (or a rounded rect when [src] is
/// null) blurred into a small image with [_shadowPad] of transparent margin
/// on every side, so the blur falls off to nothing at the image's edges.
ui.Image _bakeShadow(ui.Image? src, double aspect, {double radius = 0}) {
  const w = _shadowW;
  final h = w / aspect;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.saveLayer(
    null,
    Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
  );
  const black = Color(0xFF000000);
  final dst = Rect.fromLTWH(_shadowPad, _shadowPad, w, h);
  if (src == null) {
    // radius is in card px; the card is ~700px wide, the bake 120.
    canvas.drawRRect(
      RRect.fromRectAndRadius(dst, Radius.circular(radius * w / 700)),
      Paint()..color = black,
    );
  } else {
    canvas.drawImageRect(
      src,
      Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = const ColorFilter.mode(black, BlendMode.srcIn),
    );
  }
  canvas.restore();
  return recorder.endRecording().toImageSync(
    (w + 2 * _shadowPad).ceil(),
    (h + 2 * _shadowPad).ceil(),
  );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.ms, {required this.perches});
  final double ms;

  /// Read at paint time, after layout, so the pictures' real (tilted)
  /// positions are known.
  final List<Offset?> Function() perches;

  // Timeline (ms): drop in once the cards have landed, then each hop, each
  // followed by a squash on landing.
  static const _drop = (1250.0, 1800.0);
  static const _hops = [(2250.0, 3000.0), (3450.0, 4200.0)];
  static const _squash = 240.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (ms <= _drop.$1) return;
    final spots = perches();
    if (spots.any((p) => p == null)) return;
    final p = spots.cast<Offset>();
    final v = ms;

    var feet = p.first;
    var airborne = false;
    var landedAt = _drop.$2;
    var tilt = 0.0;
    if (v < _drop.$2) {
      final u = Curves.easeIn.transform((v - _drop.$1) / (_drop.$2 - _drop.$1));
      feet = p.first - Offset(0, 420 * (1 - u));
      airborne = true;
    }
    for (final (i, (start, end)) in _hops.indexed) {
      if (i + 1 >= p.length) break;
      if (v >= end) {
        feet = p[i + 1];
        landedAt = end;
      } else if (v > start) {
        final u = Curves.easeInOut.transform((v - start) / (end - start));
        final a = p[i];
        final b = p[i + 1];
        // Low arcs, so Dash stays under the title.
        final rise = 55 + (a.dy - b.dy).abs() * 0.3;
        feet = Offset.lerp(a, b, u)! - Offset(0, rise * math.sin(math.pi * u));
        airborne = true;
        // Nose up, then down, and level again at each end (no snap on landing).
        tilt = -0.3 * math.sin(2 * math.pi * u);
        break;
      }
    }
    // Squash on landing, springing back.
    final since = v - landedAt;
    final squash = !airborne && since >= 0 && since < _squash
        ? math.sin(math.pi * since / _squash)
        : 0.0;

    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.rotate(tilt);
    // A light squash: much more and Dash looks smeared.
    canvas.scale(1.25 * (1 + 0.06 * squash), 1.25 * (1 - 0.06 * squash));
    _paintDash(canvas, wingUp: airborne && (v / 57).floor().isEven);
    canvas.restore();
  }

  /// A small Dash-like hummingbird facing right, feet at the origin.
  static void _paintDash(Canvas canvas, {required bool wingUp}) {
    const blue = Color(0xFF42A5F5);
    const deep = Color(0xFF1565C0);
    const belly = Color(0xFFBBDEFB);
    const beak = Color(0xFFC8A27A);
    const r = 30.0;
    const c = Offset(0, -r - 8);

    // Shadow-free, flat: feet, tail, body, belly, wing, eye, beak, tuft.
    final stroke = Paint()
      ..color = beak
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-8, -9), const Offset(-10, 0), stroke);
    canvas.drawLine(const Offset(8, -9), const Offset(10, 0), stroke);

    final tail = Path()
      ..moveTo(c.dx - r * 0.7, c.dy + 6)
      ..lineTo(c.dx - r * 1.7, c.dy - 6)
      ..lineTo(c.dx - r * 1.5, c.dy + 18)
      ..close();
    canvas.drawPath(tail, Paint()..color = deep);

    canvas.drawCircle(c, r, Paint()..color = blue);
    canvas.drawOval(
      Rect.fromCenter(center: c + const Offset(6, 12), width: 34, height: 26),
      Paint()..color = belly,
    );

    canvas.save();
    canvas.translate(c.dx - 6, c.dy - 2);
    canvas.rotate(wingUp ? -0.9 : 0.25);
    canvas.drawOval(
      const Rect.fromLTWH(-30, -10, 34, 20),
      Paint()..color = deep,
    );
    canvas.restore();

    final eye = c + const Offset(12, -8);
    canvas.drawCircle(eye, 9, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(
      eye + const Offset(2, 0),
      4.5,
      Paint()..color = const Color(0xFF000000),
    );

    final bill = Path()
      ..moveTo(c.dx + r - 4, c.dy - 6)
      ..lineTo(c.dx + r + 26, c.dy + 1)
      ..lineTo(c.dx + r - 4, c.dy + 4)
      ..close();
    canvas.drawPath(bill, Paint()..color = beak);

    final tuft = Paint()
      ..color = deep
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      c + const Offset(-2, -r + 2),
      c + const Offset(-8, -r - 12),
      tuft,
    );
    canvas.drawLine(
      c + const Offset(4, -r + 1),
      c + const Offset(4, -r - 14),
      tuft,
    );
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.ms != ms;
}
