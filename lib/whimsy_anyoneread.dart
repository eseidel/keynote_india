import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'layouts.dart' show Statement;
import 'theme.dart';

/// "Anyone can read it": one by one, five people from around the company
/// (sales, ops, PM, design, support) pop up behind a ledge under the line,
/// Kilroy style, noses over the edge and fingers gripping it, each in tiny
/// reading glasses. Their eyes read along the line left to right together,
/// then each gives a small nod: got it. At rest they're still peeking up
/// at the words. The statement itself is the plain one throughout.
class AnyoneCanRead extends StatefulWidget {
  const AnyoneCanRead(this.text, {super.key});
  final String text;

  @override
  State<AnyoneCanRead> createState() => _AnyoneCanReadState();
}

const _totalMs = 3600;

class _AnyoneCanReadState extends State<AnyoneCanRead>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  )..forward();
  late final _cache = _Cache(widget.text);

  @override
  void dispose() {
    _clock.dispose();
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Statement(widget.text),
      Positioned.fill(
        child: RepaintBoundary(
          child: CustomPaint(painter: _ReadersPainter(_clock, _cache)),
        ),
      ),
    ],
  );
}

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0, 1);

/// The statement's width (to know where the line starts and ends) and the
/// role labels, laid out once, in a few alpha steps.
class _Cache {
  _Cache(String text) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: headline(50)),
      textDirection: TextDirection.ltr,
    )..layout();
    textWidth = tp.width;
    tp.dispose();
  }

  late final double textWidth;
  final _labels = <(String, int), TextPainter>{};
  static const _steps = 12;

  TextPainter label(String s, double alpha) {
    final step = (alpha.clamp(0.0, 1.0) * _steps).round();
    return _labels[(s, step)] ??= TextPainter(
      text: TextSpan(
        text: s,
        style: zalando(
          10.5,
          weight: 700,
          color: Palette.muted.withValues(alpha: step / _steps),
        ).copyWith(letterSpacing: 2.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void dispose() {
    for (final p in _labels.values) {
      p.dispose();
    }
  }
}

enum _Hair { parted, beanie, bun, curls, headset }

class _Person {
  const _Person(this.role, this.skin, this.hair, this.hairColor, this.square);
  final String role;
  final Color skin;
  final _Hair hair;
  final Color hairColor;
  final bool square; // square frames, else round
}

const _people = [
  _Person('SALES', Color(0xFFC98E62), _Hair.parted, Color(0xFF3B2A20), false),
  _Person('OPS', Color(0xFF7A5038), _Hair.beanie, Palette.warn, true),
  _Person('PM', Color(0xFFE2B48C), _Hair.bun, Color(0xFF1E1A1A), false),
  _Person('DESIGN', Color(0xFFF1C9A5), _Hair.curls, Color(0xFFC0522E), true),
  _Person(
    'SUPPORT',
    Color(0xFFA86E48),
    _Hair.headset,
    Color(0xFF2B2B33),
    false,
  ),
];

class _ReadersPainter extends CustomPainter {
  _ReadersPainter(this.clock, this.cache) : super(repaint: clock);
  final Animation<double> clock;
  final _Cache cache;

  static const ledgeY = 790.0;
  static const spacing = 210.0;
  static const r = 46.0; // head radius

  static const _glass = Color(0xFF0D1117);
  static const _white = Color(0xFFF4F7FB);
  static const _headsetGrey = Color(0xFF55606F);
  static final _headset = Paint()..color = _headsetGrey;
  static final _ledge = Paint()..color = _white.withValues(alpha: 0.12);
  static final _frames = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5
    ..color = _glass;
  static final _beanieBand = Paint()..color = const Color(0xFFD98F3E);

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * _totalMs / 1000;
    final cx = size.width / 2;
    final n = _people.length;

    // The ledge: a quiet rule, like the verdict slides' divider.
    final ledgeIn = Curves.easeOutCubic.transform(_seg(t, 0.15, 0.6));
    final half = (n - 1) / 2 * spacing + 110;
    canvas.drawRect(
      Rect.fromLTRB(
        cx - half * ledgeIn,
        ledgeY,
        cx + half * ledgeIn,
        ledgeY + 4,
      ),
      _ledge,
    );

    // Reading: a shared gaze target sweeps the line, left to right, then
    // comes back to rest near the middle.
    final textLeft = cx - cache.textWidth / 2,
        textRight = cx + cache.textWidth / 2;
    final read = Curves.easeInOut.transform(_seg(t, 1.45, 2.65));
    final back = Curves.easeInOut.transform(_seg(t, 2.75, 3.25));
    var gx = textLeft + 40 + (textRight - textLeft - 80) * read;
    gx += (cx + 60 - gx) * back;
    const gy = 540.0;

    for (var i = 0; i < n; i++) {
      final p = _people[i];
      final x = cx + (i - (n - 1) / 2) * spacing;
      final pop = _seg(t, 0.45 + i * 0.13, 0.95 + i * 0.13);
      if (pop <= 0) continue;
      // Rises from behind the ledge with a little overshoot.
      final rise = Curves.easeOutBack.transform(pop);
      // Nod, one after another, once they've read it.
      final nod = _seg(t, 2.7 + i * 0.09, 3.05 + i * 0.09);
      final bob = math.sin(nod * math.pi) * 9;
      final headC = Offset(x, ledgeY - 20 + (1 - rise) * (r * 2.4) + bob);

      // Everything above the ledge only: they're behind it.
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(x - 90, 0, x + 90, ledgeY));
      _head(canvas, p, headC, Offset(gx, gy), nod, t, i);
      canvas.restore();

      // Nose and fingers hang over the ledge once they're up.
      final grip = _seg(pop, 0.55, 1);
      if (grip > 0) _overLedge(canvas, p, x, headC, grip);

      // Role label under the ledge.
      final la = _seg(t, 0.9 + i * 0.13, 1.3 + i * 0.13);
      if (la > 0) {
        final lp = cache.label(p.role, la);
        lp.paint(canvas, Offset(x - lp.width / 2, ledgeY + 30));
      }
    }
  }

  void _head(
    Canvas canvas,
    _Person p,
    Offset c,
    Offset gaze,
    double nod,
    double t,
    int i,
  ) {
    final fill = Paint();
    final hair = Paint()..color = p.hairColor;
    // Hair behind the head.
    switch (p.hair) {
      case _Hair.bun:
        canvas.drawCircle(c + Offset(0, -r - 10), 17, hair);
      case _Hair.curls:
        for (var k = 0; k < 9; k++) {
          final a = math.pi + k / 8 * math.pi;
          canvas.drawCircle(
            c + Offset(math.cos(a), math.sin(a)) * (r + 2),
            13,
            hair,
          );
        }
      default:
    }
    canvas.drawCircle(c, r, fill..color = p.skin);
    // Ears.
    for (final s in [-1.0, 1.0]) {
      canvas.drawCircle(c + Offset(s * r, -2), 9, fill..color = p.skin);
    }
    // Hair on top of the head.
    final top = Rect.fromCircle(center: c, radius: r + 1);
    switch (p.hair) {
      case _Hair.parted:
        canvas.drawPath(
          Path()
            ..addArc(top, math.pi * 1.02, math.pi * 0.96)
            ..quadraticBezierTo(
              c.dx + 10,
              c.dy - r * 0.55,
              c.dx - 14,
              c.dy - r * 0.62,
            )
            ..quadraticBezierTo(c.dx - 30, c.dy - r * 0.45, c.dx - r, c.dy - 4)
            ..close(),
          hair,
        );
      case _Hair.beanie:
        // A knit cap that stops above the glasses: the band sits where the
        // brows would be, so the face below it still reads as a face.
        canvas.save();
        canvas.clipRect(
          Rect.fromLTRB(c.dx - r - 8, 0, c.dx + r + 8, c.dy - 34),
        );
        canvas.drawOval(
          Rect.fromLTRB(c.dx - r - 1, c.dy - r - 16, c.dx + r + 1, c.dy - 6),
          hair,
        );
        canvas.restore();
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(c.dx - r - 4, c.dy - 41, c.dx + r + 4, c.dy - 28),
            const Radius.circular(6),
          ),
          _beanieBand,
        );
        canvas.drawCircle(c + Offset(0, -r - 18), 9, _beanieBand);
      case _Hair.bun:
        canvas.drawPath(
          Path()
            ..addArc(top, math.pi * 1.05, math.pi * 0.9)
            ..quadraticBezierTo(
              c.dx,
              c.dy - r * 0.5,
              c.dx - r * 0.98,
              c.dy - 10,
            )
            ..close(),
          hair,
        );
      case _Hair.curls:
        canvas.drawPath(
          Path()
            ..addArc(top, math.pi * 1.08, math.pi * 0.84)
            ..quadraticBezierTo(
              c.dx,
              c.dy - r * 0.58,
              c.dx - r * 0.95,
              c.dy - 14,
            )
            ..close(),
          hair,
        );
      case _Hair.headset:
        // Spiky top, then the headset band over it.
        final spikes = Path()..moveTo(c.dx - r * 0.95, c.dy - 12);
        for (var k = 0; k <= 6; k++) {
          final a = math.pi * (1.05 + k / 6 * 0.9);
          final o =
              c + Offset(math.cos(a), math.sin(a)) * (r + (k.isEven ? 0 : 10));
          spikes.lineTo(o.dx, o.dy);
        }
        spikes.quadraticBezierTo(
          c.dx,
          c.dy - r * 0.5,
          c.dx - r * 0.95,
          c.dy - 12,
        );
        canvas.drawPath(spikes, hair);
        canvas.drawArc(
          top.inflate(5),
          math.pi * 1.0,
          math.pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = _headsetGrey,
        );
        for (final s in [-1.0, 1.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: c + Offset(s * (r + 4), -2),
                width: 16,
                height: 26,
              ),
              const Radius.circular(6),
            ),
            _headset,
          );
        }
    }

    // Eyes behind glasses, looking at the gaze point.
    final eyeY = c.dy - 12;
    final browLift = math.sin(nod * math.pi) * 5;
    final frame = _frames;
    for (final s in [-1.0, 1.0]) {
      final e = Offset(c.dx + s * 17, eyeY);
      canvas.drawCircle(e, 9, fill..color = _white);
      final d = gaze - e;
      final look = d / d.distance * 4.2;
      canvas.drawCircle(e + look, 4.6, fill..color = _glass);
      // Frames.
      if (p.square) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: e, width: 28, height: 22),
            const Radius.circular(5),
          ),
          frame,
        );
      } else {
        canvas.drawCircle(e, 13, frame);
      }
      // Brows, raised for the nod (under a beanie the band is the brow).
      if (p.hair != _Hair.beanie) {
        canvas.drawLine(
          e + Offset(-8, -20 - browLift),
          e + Offset(8, -21 - browLift),
          Paint()
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..color = p.hairColor,
        );
      }
    }
    // Bridge.
    canvas.drawLine(
      Offset(c.dx - (p.square ? 3 : 4), eyeY - 2),
      Offset(c.dx + (p.square ? 3 : 4), eyeY - 2),
      frame,
    );
    // A glint crosses the lenses, a little after each person reads.
    final g = _seg(t, 2.55 + i * 0.07, 2.95 + i * 0.07);
    if (g > 0 && g < 1) {
      final gp = Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = _white.withValues(alpha: 0.85 * math.sin(g * math.pi));
      for (final s in [-1.0, 1.0]) {
        final e = Offset(c.dx + s * 17, eyeY);
        final off = -12 + 24 * g;
        canvas.drawLine(e + Offset(off - 4, 5), e + Offset(off + 4, -5), gp);
      }
    }
  }

  /// The nose drooping over the ledge, and four fingers each side gripping.
  void _overLedge(
    Canvas canvas,
    _Person p,
    double x,
    Offset headC,
    double grip,
  ) {
    final skin = Paint()..color = p.skin;
    final shade = Paint()..color = Color.lerp(p.skin, _glass, 0.25)!;
    final e = Curves.easeOutBack.transform(grip);
    // Nose: an oval half over the ledge.
    final noseY = ledgeY + 6 * e;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, noseY), width: 18, height: 26 * e),
      skin,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x + 3, noseY + 6 * e),
        width: 6,
        height: 5 * e,
      ),
      shade,
    );
    for (final s in [-1.0, 1.0]) {
      for (var k = 0; k < 4; k++) {
        final fx = x + s * (r + 10 + k * 9);
        final f = RRect.fromRectAndRadius(
          Rect.fromLTWH(fx - 4, ledgeY - 7, 8, 7 + 12 * e),
          const Radius.circular(4),
        );
        canvas.drawRRect(f, skin);
      }
    }
  }

  @override
  bool shouldRepaint(_ReadersPainter old) => old.clock != clock;
}
