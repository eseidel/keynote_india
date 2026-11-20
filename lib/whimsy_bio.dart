import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import 'theme.dart';

/// Bio, as a career told in order ("Browsers, then started Flutter, then
/// Shorebird"). The headshot drops onto the slide as a Polaroid, wobbles
/// to rest at a slight tilt, and develops: it starts as a milky, colorless
/// print, and contrast and color come up while the frame drifts out a
/// little (Ken Burns). Meanwhile a small shorebird hops down the career
/// lines in the order they happened, and each line slides in as it lands
/// beside it: 20 years of engineering, WebKit/Safari/Chrome, Flutter, leading
/// Flutter & Dart, then Shorebird. Its last hop is a flight up to perch on
/// the top of the Polaroid. Plays once and settles in about four seconds.
class BioTimeline extends StatefulWidget {
  const BioTimeline({
    super.key,
    required this.name,
    required this.lines,
    required this.photo,
    required this.order,
  });
  final String name;
  final List<String> lines;
  final String photo;

  /// Indexes into [lines], in the order they happened.
  final List<int> order;

  @override
  State<BioTimeline> createState() => _BioTimelineState();
}

const _totalMs = 4000;
const _total = _totalMs / 1000;

// The slide's geometry, on the 1920x1080 canvas (Bio's padding).
const _pad = EdgeInsets.fromLTRB(150, 180, 150, 140);
const _photo = 650.0; // the picture inside the Polaroid
const _border = 22.0, _chin = 78.0; // Polaroid paper
const _printW = _photo + 2 * _border, _printH = _photo + _border + _chin;
const _rest = 0.045; // radians: the print's tilt once it settles
const _lineGap = 6.0; // Bio's vertical padding around each line

/// When each hop lands (seconds); the line beside it slides in then.
const _hops = [0.7, 1.15, 1.55, 1.95, 2.35];
const _hopFor = 0.36;
const _flight = (2.65, 3.4); // the last hop, up onto the print

double _clamp01(double v) => v.clamp(0.0, 1.0);

class _BioTimelineState extends State<BioTimeline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  )..forward();

  double get _t => _clock.value * _total;

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nameStyle = headline(34);
    final lineStyle = zalando(16.5, color: Palette.soft);
    final scaler = MediaQuery.textScalerOf(context);
    final defaults = DefaultTextStyle.of(context).style;
    double heightOf(TextStyle s) {
      final tp = TextPainter(
        text: TextSpan(text: 'Hg', style: defaults.merge(s)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final h = tp.height;
      tp.dispose();
      return h;
    }

    // Where the lines are, so the bird can stand beside them: the column is
    // centered in the padded area, as in Bio.
    final nameH = heightOf(nameStyle),
        lineH = heightOf(lineStyle) + 2 * _lineGap;
    final n = widget.lines.length;
    final columnH = nameH + 36 + n * lineH;
    final top = _pad.top + (canvasSize.height - _pad.vertical - columnH) / 2;
    final lineMid = [
      for (var i = 0; i < n; i++) top + nameH + 36 + lineH * (i + 0.5),
    ];
    // The step at which each line arrives.
    final arrives = List.filled(n, 0);
    for (final (step, i) in widget.order.indexed) {
      arrives[i] = step;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: _pad,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name, style: nameStyle),
                    const SizedBox(height: 36),
                    for (final (i, line) in widget.lines.indexed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: _lineGap),
                        child: AnimatedBuilder(
                          animation: _clock,
                          builder: (_, child) {
                            final f = Curves.easeOutCubic.transform(
                              _clamp01((_t - _hops[arrives[i]] + 0.05) / 0.4),
                            );
                            if (f == 1) return child!;
                            return Opacity(
                              opacity: f,
                              child: Transform.translate(
                                offset: Offset((1 - f) * -40, 0),
                                child: child,
                              ),
                            );
                          },
                          child: Text(line, style: lineStyle),
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _clock,
                builder: (_, _) => _Polaroid(widget.photo, _t),
              ),
            ],
          ),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _BirdPainter(_clock, [
              for (final i in widget.order) lineMid[i],
            ]),
          ),
        ),
      ],
    );
  }
}

/// The print: drops in from above with a shadow that tightens as it lands,
/// wobbles to its resting tilt, and develops.
class _Polaroid extends StatelessWidget {
  const _Polaroid(this.photo, this.t);
  final String photo;
  final double t;

  /// Drop, wobble, and how high above the slide it is (0 when down).
  static ({double dy, double angle, double lift}) pose(double t) {
    final fall = Curves.easeInCubic.transform(_clamp01((t - 0.1) / 0.55));
    final s = t - 0.65; // since it landed
    final wobble = s < 0
        ? -0.16 * (1 - fall)
        : 0.05 * math.exp(-s * 4.5) * math.sin(s * 13);
    return (
      dy: (1 - fall) * -1100,
      angle: _rest + wobble,
      lift: s < 0 ? 1 - fall * 0.85 : 0.15 * math.exp(-s * 9),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = pose(t);
    // Develops from a milky, flat, colorless print to the real photo.
    final dev = Curves.easeInOut.transform(_clamp01((t - 0.5) / 2.7));
    // A slow drift out as it develops.
    final zoom =
        1 + 0.1 * (1 - Curves.easeOutCubic.transform(_clamp01(t / 3.8)));
    Widget picture = Image.asset(
      photo,
      width: _photo,
      height: _photo,
      fit: BoxFit.cover,
    );
    if (zoom != 1) picture = Transform.scale(scale: zoom, child: picture);
    if (dev < 1) {
      picture = ColorFiltered(colorFilter: _developing(dev), child: picture);
    }
    return Transform.translate(
      offset: Offset(0, p.dy),
      child: Transform.rotate(
        angle: p.angle,
        child: Container(
          width: _printW,
          height: _printH,
          padding: const EdgeInsets.fromLTRB(_border, _border, _border, _chin),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F1EB),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: const Color(0x8C000000),
                blurRadius: 24 + 70 * p.lift,
                offset: Offset(10 + 30 * p.lift, 16 + 60 * p.lift),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: picture,
          ),
        ),
      ),
    );
  }

  /// k = 0: a flat, milky blue-grey; k = 1: the photo as it is.
  static ColorFilter _developing(double k) {
    final s = k * k; // color comes in after contrast
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    // Saturation matrix rows, then scale by contrast k and add the milky base.
    List<double> row(int c) {
      final m = [
        lr * (1 - s) + (c == 0 ? s : 0),
        lg * (1 - s) + (c == 1 ? s : 0),
        lb * (1 - s) + (c == 2 ? s : 0),
      ];
      const base = [150.0, 160.0, 168.0];
      return [m[0] * k, m[1] * k, m[2] * k, 0, base[c] * (1 - k)];
    }

    return ColorFilter.matrix([...row(0), ...row(1), ...row(2), 0, 0, 0, 1, 0]);
  }
}

class _BirdPainter extends CustomPainter {
  _BirdPainter(this.clock, this.stops) : super(repaint: clock);
  final Animation<double> clock;
  final List<double> stops; // line middles, in the order the bird visits

  static const _x = 96.0; // where it stands, left of the lines
  static const _feet = 22.0; // feet below a line's middle

  /// The top of the print, a little right of center, where the bird ends up.
  static Offset get _perch {
    final c = Offset(
      canvasSize.width - _pad.right - _printW / 2,
      _pad.top + (canvasSize.height - _pad.vertical) / 2,
    );
    const local = Offset(_printW * 0.22, -_printH / 2);
    return c +
        Offset(
          local.dx * math.cos(_rest) - local.dy * math.sin(_rest),
          local.dx * math.sin(_rest) + local.dy * math.cos(_rest),
        );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * _total;
    final spots = [for (final y in stops) Offset(_x, y + _feet)];
    final perch = _perch;

    var at = Offset(-120, spots.first.dy);
    var facing = 1.0, squash = 0.0, flap = 0.0, angle = 0.0;
    // Hops: from off the left edge to the first line, then line to line.
    var from = at;
    for (final (i, land) in _hops.indexed) {
      final to = spots[i];
      final start = land - (i == 0 ? 0.5 : _hopFor);
      if (t >= start) {
        final u = _clamp01((t - start) / (land - start));
        final e = Curves.easeInOut.transform(u);
        final rise = (to - from).dy.abs() * 0.35 + 34;
        at = Offset.lerp(from, to, e)! - Offset(0, rise * 4 * e * (1 - e));
        squash = _squash(t, start, land);
      }
      from = to;
    }
    // The flight up to the print.
    if (t >= _flight.$1) {
      final u = _clamp01((t - _flight.$1) / (_flight.$2 - _flight.$1));
      final e = Curves.easeInOutCubic.transform(u);
      final mid = Offset(
        (from.dx + perch.dx) / 2,
        math.min(from.dy, perch.dy) - 170,
      );
      final a = 1 - e;
      at = from * (a * a) + mid * (2 * a * e) + perch * (e * e);
      flap = u < 1 ? math.sin(u * math.pi * 2 * 6) * math.sin(u * math.pi) : 0;
      squash = _squash(t, _flight.$1, _flight.$2);
      angle = _rest * _clamp01((t - _flight.$2) / 0.2);
      // A little look back at the slide, once it's settled.
      if (t > _flight.$2 + 0.25) facing = -1;
    }
    if (t < _hops.first - 0.5) return;

    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(angle)
      ..scale(facing * (1 + squash * 0.6), 1 - squash);
    _drawBird(canvas, flap);
    canvas.restore();
  }

  /// A crouch before take-off and on landing.
  static double _squash(double t, double start, double land) {
    double bump(double c) => math.max(0, 1 - ((t - c) / 0.08).abs());
    return 0.18 * (bump(start) + bump(land + 0.06));
  }

  static const _body = Color(0xFFF4EFE6);
  static const _wingC = Color(0xFFC3CCDA); // Palette.soft
  static const _beakC = Color(0xFFFFB259); // Palette.warn

  static final Path _tail = Path()
    ..moveTo(-14, -26)
    ..lineTo(-34, -36)
    ..lineTo(-31, -22)
    ..close();
  static final Path _beak = Path()
    ..moveTo(24, -41)
    ..lineTo(38, -37.5)
    ..lineTo(24, -34)
    ..close();

  /// A small shorebird facing right, feet at the origin.
  static void _drawBird(Canvas canvas, double flap) {
    final legs = Paint()
      ..color = _beakC
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(const Offset(-3, -11), const Offset(-5, 0), legs)
      ..drawLine(const Offset(4, -11), const Offset(6, 0), legs)
      ..drawPath(_tail, Paint()..color = _wingC)
      ..drawOval(
        Rect.fromCenter(center: const Offset(0, -23), width: 40, height: 27),
        Paint()..color = _body,
      )
      ..drawCircle(const Offset(15, -37), 11, Paint()..color = _body)
      ..drawPath(_beak, Paint()..color = _beakC)
      ..drawCircle(
        const Offset(18.5, -39),
        2.3,
        Paint()..color = Palette.background,
      );
    canvas
      ..save()
      ..translate(-2, -27)
      ..rotate(-0.25 - flap * 0.9)
      ..drawOval(
        Rect.fromCenter(center: const Offset(-6, 0), width: 26, height: 12),
        Paint()..color = _wingC,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_BirdPainter old) => !listEquals(old.stops, stops);
}
