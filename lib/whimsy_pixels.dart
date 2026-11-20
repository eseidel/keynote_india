import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

/// "You own every pixel", made literal: the headline is cut into square
/// pixels that assemble on entry, scatter away from the mouse cursor and
/// spring back. At rest it paints as the ordinary crisp headline. The only
/// slide in the deck that reacts to the mouse; it never handles taps, so a
/// click still advances.
class PixelStatement extends StatefulWidget {
  const PixelStatement(this.text, {super.key, this.size = 50});
  final String text;
  final double size;

  @override
  State<PixelStatement> createState() => _PixelStatementState();
}

class _PixelStatementState extends State<PixelStatement>
    with SingleTickerProviderStateMixin {
  static const cell = 8.0; // pixel size on the 1920x1080 canvas
  static const pad = cell; // atlas margin for glyph overhang
  static const atlasScale = 2.0; // crisp when the canvas is scaled up
  static const reach = 160.0; // cursor's radius of influence
  static const push = 30000.0; // cursor's push at its center (px/s²)
  static const k = 120.0; // spring back home
  static final damping = 2 * math.sqrt(k) * 0.55;

  late final TextPainter _tp;
  late final ui.Image _atlas;
  late final Float32List _home; // x, y per pixel (text-local, top-left)
  late final Float32List _off; // displacement from home
  late final Float32List _vel;
  late final Float32List _give; // per-pixel push, so they don't form a ring
  late final Float32List _rects; // atlas source rects
  late final Float32List _xforms; // RSTransforms
  late final Ticker _ticker;
  final _repaint = ValueNotifier(0);
  Offset? _mouse; // text-local
  bool _settled = false;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tp = TextPainter(
      text: TextSpan(text: widget.text, style: headline(widget.size)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: canvasSize.width - 320);
    final w = _tp.width + 2 * pad, h = _tp.height + 2 * pad;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)
      ..scale(atlasScale)
      ..translate(pad, pad);
    _tp.paint(c, Offset.zero);
    final pic = rec.endRecording();
    _atlas = pic.toImageSync((w * atlasScale).ceil(), (h * atlasScale).ceil());
    pic.dispose();

    final cols = (w / cell).ceil(), rows = (h / cell).ceil();
    final n = cols * rows;
    _home = Float32List(n * 2);
    _off = Float32List(n * 2);
    _vel = Float32List(n * 2);
    _give = Float32List(n);
    _rects = Float32List(n * 4);
    _xforms = Float32List(n * 4);
    final rnd = math.Random(7);
    for (var r = 0, i = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++, i++) {
        final x = c * cell - pad, y = r * cell - pad;
        _home[i * 2] = x;
        _home[i * 2 + 1] = y;
        final s = cell * atlasScale;
        _rects
          ..[i * 4] = c * s
          ..[i * 4 + 1] = r * s
          ..[i * 4 + 2] = c * s + s
          ..[i * 4 + 3] = r * s + s;
        _give[i] = 0.5 + rnd.nextDouble();
        // Entry: start scattered, assemble into the headline.
        final a = rnd.nextDouble() * 2 * math.pi;
        final d = 120 + rnd.nextDouble() * 380;
        _off[i * 2] = math.cos(a) * d;
        _off[i * 2 + 1] = math.sin(a) * d;
      }
    }
    _ticker = createTicker(_tick)..start();
  }

  void _wake() {
    if (_settled) setState(() => _settled = false);
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = math.min((elapsed - _last).inMicroseconds / 1e6, 1 / 30);
    _last = elapsed;
    if (dt <= 0) return;
    final m = _mouse;
    var moving = false;
    final half = cell / 2;
    for (var i = 0; i < _off.length; i += 2) {
      var ax = -k * _off[i] - damping * _vel[i];
      var ay = -k * _off[i + 1] - damping * _vel[i + 1];
      if (m != null) {
        final dx = _home[i] + _off[i] + half - m.dx;
        final dy = _home[i + 1] + _off[i + 1] + half - m.dy;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < reach) {
          moving = true; // held off home while the cursor is near
          final f = push * _give[i >> 1] * (1 - d / reach) / math.max(d, 1);
          ax += dx * f;
          ay += dy * f;
        }
      }
      _vel[i] += ax * dt;
      _vel[i + 1] += ay * dt;
      _off[i] += _vel[i] * dt;
      _off[i + 1] += _vel[i + 1] * dt;
      if (!moving &&
          (_off[i].abs() > 0.3 ||
              _off[i + 1].abs() > 0.3 ||
              _vel[i].abs() > 3 ||
              _vel[i + 1].abs() > 3)) {
        moving = true;
      }
    }
    if (!moving) {
      _off.fillRange(0, _off.length, 0);
      _vel.fillRange(0, _vel.length, 0);
      _ticker.stop();
      setState(() => _settled = true);
      return;
    }
    _repaint.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _atlas.dispose();
    _tp.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final origin = Offset(
        (box.maxWidth - _tp.width) / 2,
        (box.maxHeight - _tp.height) / 2,
      );
      return MouseRegion(
        onHover: (e) {
          _mouse = e.localPosition - origin;
          _wake();
        },
        onExit: (_) => _mouse = null,
        child: SizedBox.expand(
          child: CustomPaint(painter: _PixelPainter(this, origin)),
        ),
      );
    },
  );
}

class _PixelPainter extends CustomPainter {
  _PixelPainter(this.s, this.origin) : super(repaint: s._repaint);
  final _PixelStatementState s;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(origin.dx, origin.dy);
    if (s._settled) {
      s._tp.paint(canvas, Offset.zero);
      return;
    }
    const inv = 1 / _PixelStatementState.atlasScale;
    final x = s._xforms, h = s._home, o = s._off;
    for (var i = 0, j = 0; j < x.length; i += 2, j += 4) {
      x
        ..[j] = inv
        ..[j + 1] = 0
        ..[j + 2] = h[i] + o[i]
        ..[j + 3] = h[i + 1] + o[i + 1];
    }
    canvas.drawRawAtlas(
      s._atlas,
      x,
      s._rects,
      null,
      null,
      null,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_PixelPainter old) => true; // rebuilt only on settle
}
