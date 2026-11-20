import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// "Build for people, not platforms", as a park bench drawn by Flutter.
/// Two friends sit side by side, each looking down at the same app on their
/// phone, each wearing a name-tag sticker: "iOS" and "android". The
/// stickers peel off their shirts and flutter away, since they never
/// mattered. Then the two lean in toward each other, say so in speech
/// bubbles, and a heart rises between them and stays. Runs once and
/// settles in about four seconds. The text column is laid out exactly as
/// the plain SplitImage did.
class PeopleSplit extends StatefulWidget {
  const PeopleSplit({super.key, required this.text, this.size = 56});
  final String text;
  final double size;

  @override
  State<PeopleSplit> createState() => _PeopleSplitState();
}

const _totalMs = 4000;

class _PeopleSplitState extends State<PeopleSplit>
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

  // Same padding, flex and gap as SplitImage, so the words don't move.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(200, 40, 40, 40),
    child: Row(
      children: [
        Expanded(
          flex: 5,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(widget.text, style: headline(widget.size)),
          ),
        ),
        const SizedBox(width: 60),
        Expanded(
          flex: 5,
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: RepaintBoundary(
                child: CustomPaint(painter: _BenchPainter(_clock)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// One of the two friends, drawn around the middle of the seat under them.
class _Person {
  const _Person({
    required this.x,
    required this.side,
    required this.skin,
    required this.shirt,
    required this.pants,
    required this.hair,
    required this.label,
    required this.peelMs,
  });
  final double x; // seat position, scene coordinates
  final double side; // -1 on the left, 1 on the right
  final Color skin, shirt, pants, hair;
  final String label;
  final double peelMs; // when the sticker starts to lift
}

class _BenchPainter extends CustomPainter {
  _BenchPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  // The scene is drawn in an 800x800 box and scaled to fit.
  static const _box = 800.0;
  static const _seatY = 600.0;
  static const _groundY = 708.0;

  static const _a = _Person(
    x: 288,
    side: -1,
    skin: Color(0xFFC98E68),
    shirt: Color(0xFFEB6F67),
    pants: Color(0xFF3D5A8A),
    hair: Color(0xFF3B2419),
    label: 'iOS',
    peelMs: 500,
  );
  static const _b = _Person(
    x: 512,
    side: 1,
    skin: Color(0xFF9A6649),
    shirt: Color(0xFF45B3B5),
    pants: Color(0xFF2E3A52),
    hair: Color(0xFF261A14),
    label: 'android',
    peelMs: 720,
  );

  // Timeline (ms).
  static const _peelLen = 420.0; // the corner lifts
  static const _flyLen = 1500.0; // then it flutters up and away
  static const _lean = (1500.0, 2300.0);
  static const _bubbleA = 1900.0, _bubbleB = 2350.0, _bubbleLen = 380.0;
  static const _heart = (2700.0, 3700.0);

  static const _wood = Color(0xFF9C6A45);
  static const _woodDark = Color(0xFF7A4F32);
  static const _woodLight = Color(0xFFB98559);
  static const _metal = Color(0xFF4E5562);
  static const _ink = Color(0xFF2A2320);
  static const _heartColor = Color(0xFFFF6F7D);

  // Face and hair shapes, around the head's center; built once.
  static const _c = Offset(0, -288);
  static final _bangs = Path()
    ..moveTo(_c.dx - 60, _c.dy + 4)
    ..quadraticBezierTo(_c.dx - 64, _c.dy - 66, _c.dx, _c.dy - 68)
    ..quadraticBezierTo(_c.dx + 64, _c.dy - 66, _c.dx + 60, _c.dy + 2)
    ..quadraticBezierTo(_c.dx + 40, _c.dy - 34, _c.dx - 6, _c.dy - 30)
    ..quadraticBezierTo(_c.dx - 40, _c.dy - 26, _c.dx - 60, _c.dy + 4)
    ..close();
  static final _shortHair = Path()
    ..moveTo(_c.dx - 58, _c.dy - 2)
    ..quadraticBezierTo(_c.dx - 64, _c.dy - 74, _c.dx + 4, _c.dy - 72)
    ..quadraticBezierTo(_c.dx + 66, _c.dy - 70, _c.dx + 58, _c.dy - 2)
    ..lineTo(_c.dx + 50, _c.dy - 20)
    ..quadraticBezierTo(_c.dx + 20, _c.dy - 44, _c.dx - 30, _c.dy - 36)
    ..lineTo(_c.dx - 50, _c.dy - 18)
    ..close();
  static final _beard = Path()
    ..moveTo(_c.dx - 56, _c.dy + 2)
    ..quadraticBezierTo(_c.dx - 54, _c.dy + 70, _c.dx, _c.dy + 72)
    ..quadraticBezierTo(_c.dx + 54, _c.dy + 70, _c.dx + 56, _c.dy + 2)
    ..lineTo(_c.dx + 46, _c.dy + 8)
    ..quadraticBezierTo(_c.dx + 36, _c.dy + 30, _c.dx, _c.dy + 30)
    ..quadraticBezierTo(_c.dx - 36, _c.dy + 30, _c.dx - 46, _c.dy + 8)
    ..close();
  static final _mouth = Path()
    ..moveTo(_c.dx - 15, _c.dy + 30)
    ..quadraticBezierTo(_c.dx, _c.dy + 33, _c.dx + 15, _c.dy + 30)
    ..quadraticBezierTo(_c.dx + 13, _c.dy + 48, _c.dx, _c.dy + 48)
    ..quadraticBezierTo(_c.dx - 13, _c.dy + 48, _c.dx - 15, _c.dy + 30)
    ..close();

  static TextPainter _tp(String s, double points, Color c, double weight) =>
      TextPainter(
        text: TextSpan(
          text: s,
          style: zalando(points, weight: weight, color: c, height: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  // Laid out once. Stickers and bubbles move by transform only.
  static final _labelA = _tp(_a.label, 11, const Color(0xFFB8433C), 800);
  static final _labelB = _tp(_b.label, 11, const Color(0xFF237C7E), 800);
  static final _sayA = _tp('Love this app!', 10.5, _ink, 700);
  static final _sayB = _tp('Me too!', 10.5, _ink, 700);

  static double _step(double v, double by) => (v / by).roundToDouble() * by;

  static double _span(double ms, double from, double len) =>
      ((ms - from) / len).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _totalMs;
    canvas.save();
    canvas.scale(size.width / _box);

    _backdrop(canvas);
    _benchBack(canvas);
    _benchSeat(canvas);

    final lean = Curves.easeInOutCubic.transform(
      _span(ms, _lean.$1, _lean.$2 - _lean.$1),
    );
    for (final p in [_a, _b]) {
      _person(canvas, p, lean, ms);
    }
    _stickerAway(canvas, _a, _labelA, ms);
    _stickerAway(canvas, _b, _labelB, ms);

    _bubble(canvas, _sayA, const Offset(206, 168), -1, ms, _bubbleA);
    _bubble(canvas, _sayB, const Offset(586, 170), 1, ms, _bubbleB);
    _heartRise(canvas, ms);
    canvas.restore();
  }

  void _backdrop(Canvas canvas) {
    // A soft park glow and a little sun, behind it all.
    const c = Offset(400, 430);
    canvas.drawCircle(
      c,
      390,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF3E8F6A).withValues(alpha: 0.30),
            const Color(0xFF3E8F6A).withValues(alpha: 0.10),
            const Color(0xFF3E8F6A).withValues(alpha: 0),
          ],
          stops: const [0, 0.7, 1],
        ).createShader(Rect.fromCircle(center: c, radius: 390)),
    );
    // The sun, with a warm halo so it doesn't read as a moon.
    const sun = Offset(724, 74);
    canvas.drawCircle(
      sun,
      90,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFF5C85A).withValues(alpha: 0.30),
            const Color(0xFFF5C85A).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: 90)),
    );
    canvas.drawCircle(sun, 34, Paint()..color = const Color(0xFFF5C85A));
    // Grass under the bench, and its shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(400, _groundY),
        width: 700,
        height: 54,
      ),
      Paint()..color = const Color(0xFF3E8F6A).withValues(alpha: 0.35),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(400, _groundY),
        width: 560,
        height: 26,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.30),
    );
  }

  void _benchBack(Canvas canvas) {
    final metal = Paint()..color = _metal;
    // Back posts and legs.
    for (final x in [150.0, 650.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 9, 410, 18, _groundY - 410),
          const Radius.circular(5),
        ),
        metal,
      );
    }
    for (final y in [420.0, 478.0]) {
      _plank(canvas, Rect.fromLTWH(110, y, 580, 40));
    }
  }

  void _benchSeat(Canvas canvas) {
    // The seat's top, seen a little from above, so there's somewhere to
    // sit; then its front edge, which the thighs come forward over.
    canvas.drawPath(
      Path()
        ..moveTo(122, _seatY - 22)
        ..lineTo(678, _seatY - 22)
        ..lineTo(704, _seatY)
        ..lineTo(96, _seatY)
        ..close(),
      Paint()..color = _woodLight,
    );
    _plank(canvas, const Rect.fromLTWH(96, _seatY - 4, 608, 28));
  }

  void _plank(Canvas canvas, Rect r) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(8));
    canvas.drawRRect(rr, Paint()..color = _wood);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r.left, r.bottom - 7, r.width, 7),
        const Radius.circular(6),
      ),
      Paint()..color = _woodDark,
    );
    canvas.drawLine(
      Offset(r.left + 12, r.top + 5),
      Offset(r.right - 12, r.top + 5),
      Paint()
        ..color = _woodLight
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _person(Canvas canvas, _Person p, double lean, double ms) {
    final skin = Paint()..color = p.skin;
    final shirt = Paint()..color = p.shirt;
    final pants = Paint()..color = p.pants;

    // Shins and shoes hang down in front of the seat; they don't lean.
    for (final dx in [-30.0, 30.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(p.x + dx, _seatY + 64),
            width: 40,
            height: 88,
          ),
          const Radius.circular(14),
        ),
        pants,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(p.x + dx * 1.15, _groundY - 6),
          width: 54,
          height: 24,
        ),
        Paint()..color = _ink,
      );
    }

    canvas.save();
    // Lean toward the other one, pivoting at the seat.
    canvas.translate(p.x, _seatY);
    canvas.rotate(-p.side * 0.07 * lean);

    // Torso.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTRB(-76, -208, 76, 4),
        topLeft: const Radius.circular(44),
        topRight: const Radius.circular(44),
        bottomLeft: const Radius.circular(16),
        bottomRight: const Radius.circular(16),
      ),
      shirt,
    );
    // Neck.
    canvas.drawRect(
      const Rect.fromLTRB(-15, -232, 15, -200),
      Paint()..color = Color.lerp(p.skin, Colors.black, 0.18)!,
    );
    // Collar.
    canvas.drawArc(
      const Rect.fromLTRB(-24, -224, 24, -188),
      0,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Color.lerp(p.shirt, Colors.black, 0.2)!,
    );

    _sticker(canvas, p, p.side < 0 ? _labelA : _labelB, ms);

    // Arms: sleeve, upper arm out to the elbow, forearm in to the phone.
    for (final s in [-1.0, 1.0]) {
      final shoulder = Offset(s * 66, -182);
      final elbow = Offset(s * 86, -88);
      final hand = Offset(s * 34, -112);
      final arm = Paint()
        ..color = p.skin
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(
        Path()
          ..moveTo(shoulder.dx, shoulder.dy)
          ..lineTo(elbow.dx, elbow.dy)
          ..lineTo(hand.dx, hand.dy),
        arm,
      );
      canvas.drawLine(
        shoulder,
        Offset.lerp(shoulder, elbow, 0.42)!,
        Paint()
          ..color = p.shirt
          ..strokeWidth = 40
          ..strokeCap = StrokeCap.round,
      );
    }

    _phone(canvas, ms);
    for (final s in [-1.0, 1.0]) {
      canvas.drawCircle(Offset(s * 33, -112), 15, skin);
    }

    _head(canvas, p, lean);
    canvas.restore();

    // Sitting: the thighs come forward over the seat's edge toward us and
    // end in bent knees, over the bottom of the shirt. They don't lean.
    for (final s in [-1.0, 1.0]) {
      final k = Offset(p.x + s * 37, _seatY + 16);
      canvas.drawOval(Rect.fromCenter(center: k, width: 80, height: 62), pants);
      // Light on the kneecap.
      canvas.drawOval(
        Rect.fromCenter(center: k + const Offset(0, 12), width: 40, height: 20),
        Paint()..color = Color.lerp(p.pants, Colors.white, 0.07)!,
      );
    }
    // The crease between the knees.
    canvas.drawLine(
      Offset(p.x, _seatY - 6),
      Offset(p.x, _seatY + 36),
      Paint()
        ..color = Color.lerp(p.pants, Colors.black, 0.3)!
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _phone(Canvas canvas, double ms) {
    // Both phones run the same app.
    const body = Rect.fromLTRB(-30, -172, 30, -68);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(10)),
      Paint()..color = const Color(0xFF1E2229),
    );
    final screen = body.deflate(5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(screen, const Radius.circular(6)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.accent, Color(0xFF1B7FD1)],
        ).createShader(screen),
    );
    final white = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(screen.left + 6, screen.top + 10, screen.width - 12, 34),
        const Radius.circular(5),
      ),
      white,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            screen.left + 6,
            screen.top + 52 + i * 11,
            (screen.width - 12) * (i == 2 ? 0.6 : 1),
            5,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.6),
      );
    }
  }

  void _head(Canvas canvas, _Person p, double lean) {
    final skin = Paint()..color = p.skin;
    final hair = Paint()..color = p.hair;
    const c = _c;

    canvas.save();
    // The head tilts a little more than the body, toward the friend.
    canvas.translate(0, -226);
    canvas.rotate(-p.side * 0.06 * lean);
    canvas.translate(0, 226);

    if (p.side < 0) {
      // A bob, behind the face.
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromCenter(
            center: c + const Offset(0, 6),
            width: 144,
            height: 146,
          ),
          topLeft: const Radius.circular(72),
          topRight: const Radius.circular(72),
          bottomLeft: const Radius.circular(22),
          bottomRight: const Radius.circular(22),
        ),
        hair,
      );
    }
    // Ears and face.
    for (final s in [-1.0, 1.0]) {
      canvas.drawCircle(c + Offset(s * 57, 6), 12, skin);
    }
    canvas.drawOval(Rect.fromCenter(center: c, width: 114, height: 124), skin);

    if (p.side < 0) {
      // Bangs swept to one side.
      canvas.drawPath(_bangs, hair);
      // Earrings.
      for (final s in [-1.0, 1.0]) {
        canvas.drawCircle(
          c + Offset(s * 58, 22),
          4,
          Paint()..color = const Color(0xFFF5C85A),
        );
      }
    } else {
      // Short hair, and a beard.
      canvas.drawPath(_shortHair, hair);
      canvas.drawPath(_beard, hair);
    }

    // Eyes look down at the phone, then over at the friend.
    final look = Offset(-p.side * 5 * lean, 4 - 4 * lean);
    for (final s in [-1.0, 1.0]) {
      final e = c + Offset(s * 21, 2) + look;
      canvas.drawOval(
        Rect.fromCenter(center: e, width: 11, height: 13),
        Paint()..color = _ink,
      );
      canvas.drawCircle(
        e + const Offset(-2, -3),
        2.2,
        Paint()..color = Colors.white,
      );
      // Brows.
      canvas.drawLine(
        c + Offset(s * 21 - 9, -20),
        c + Offset(s * 21 + 9, -22 + s * 1.5),
        Paint()
          ..color = p.hair
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round,
      );
    }
    // Cheeks.
    for (final s in [-1.0, 1.0]) {
      canvas.drawCircle(
        c + Offset(s * 34, 22),
        10,
        Paint()..color = const Color(0xFFFF7F7F).withValues(alpha: 0.28),
      );
    }
    // An open smile.
    canvas.drawPath(_mouth, Paint()..color = const Color(0xFF7A2E2E));
    canvas.save();
    canvas.clipPath(_mouth);
    canvas.drawRect(
      Rect.fromLTWH(c.dx - 16, c.dy + 28, 32, 7),
      Paint()..color = Colors.white,
    );
    canvas.restore();

    canvas.restore();
  }

  static Rect _stickerRect(TextPainter label) => Rect.fromCenter(
    center: const Offset(0, -40),
    width: label.width + 26,
    height: label.height + 18,
  );

  // The sticker while it's still on the shirt: flat, then its corner lifts.
  void _sticker(Canvas canvas, _Person p, TextPainter label, double ms) {
    final lift = _span(ms, p.peelMs, _peelLen);
    if (ms >= p.peelMs + _peelLen) return; // it's off; see _stickerAway
    final r = _stickerRect(label);
    canvas.save();
    // Peel from the outer bottom corner: rotate about the inner top corner.
    final pivot = p.side < 0 ? r.topRight : r.topLeft;
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(p.side * 0.35 * Curves.easeIn.transform(lift));
    // Stepped, so the label's glyphs come in a few sizes, not one a frame.
    canvas.scale(1 + _step(0.08 * lift, 0.04));
    canvas.translate(-pivot.dx, -pivot.dy);
    _stickerBody(canvas, r, label, lift);
    canvas.restore();
  }

  // After it lets go: a flutter down and away, turning over, fading out.
  void _stickerAway(Canvas canvas, _Person p, TextPainter label, double ms) {
    final f = _span(ms, p.peelMs + _peelLen, _flyLen);
    if (f <= 0 || f >= 1) return;
    final r = _stickerRect(label);
    final pivot = p.side < 0 ? r.topRight : r.topLeft;
    // Fully there for most of the trip; gone by the end.
    final a = 1 - math.pow(f, 4).toDouble();
    final e = Curves.easeOut.transform(f);
    // Starts exactly where the peel left it (the bodies don't lean yet),
    // then catches the breeze: up and out past the person's shoulder,
    // swaying and tumbling like a leaf.
    canvas.save();
    canvas.translate(
      p.x + pivot.dx + p.side * 290 * e + 22 * math.sin(f * 8),
      _seatY + pivot.dy - 400 * e + 40 * f * f,
    );
    canvas.rotate(p.side * (0.35 + 1.8 * f) + 0.3 * math.sin(f * 10));
    // The tumble squashes it edge-on and back. Stepped, like the peel.
    final squash = _step(math.cos(f * 7).abs(), 0.25).clamp(0.25, 1.0);
    canvas.scale(1.08, 1.08 * squash);
    canvas.translate(-pivot.dx, -pivot.dy);
    _stickerBody(canvas, r, label, 1, alpha: a);
    canvas.restore();
  }

  void _stickerBody(
    Canvas canvas,
    Rect r,
    TextPainter label,
    double lift, {
    double alpha = 1,
  }) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(9));
    if (lift > 0) {
      canvas.drawRRect(
        rr.shift(Offset(0, 4 + 6 * lift)),
        Paint()..color = Colors.black.withValues(alpha: 0.22 * lift * alpha),
      );
    }
    canvas.drawRRect(
      rr,
      Paint()..color = const Color(0xFFFDFDFB).withValues(alpha: alpha),
    );
    final o = r.center - Offset(label.width / 2, label.height / 2);
    if (alpha >= 1) {
      label.paint(canvas, o);
    } else {
      // One layer for the one label while it fades.
      canvas.saveLayer(
        r.inflate(2),
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
      label.paint(canvas, o);
      canvas.restore();
    }
  }

  void _bubble(
    Canvas canvas,
    TextPainter say,
    Offset c,
    double side,
    double ms,
    double from,
  ) {
    final k = _span(ms, from, _bubbleLen);
    if (k <= 0) return;
    final s = Curves.easeOutBack.transform(k);
    final body = Rect.fromCenter(
      center: Offset.zero,
      width: say.width + 44,
      height: say.height + 34,
    );
    canvas.save();
    // Pops out from the tail, toward the speaker.
    final tail = Offset(-side * body.width * 0.18, body.bottom + 26);
    canvas.translate(c.dx + tail.dx, c.dy + tail.dy);
    canvas.scale(s);
    canvas.translate(-tail.dx, -tail.dy);
    final fill = Paint()..color = Colors.white;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = _ink;
    final round = RRect.fromRectAndRadius(body, const Radius.circular(26));
    final tip = Path()
      ..moveTo(tail.dx + side * 6, body.bottom - 4)
      ..lineTo(tail.dx, tail.dy)
      ..lineTo(tail.dx - side * 22, body.bottom - 4)
      ..close();
    // Outline both, then fill both, so the seam between them disappears.
    canvas.drawRRect(round, outline);
    canvas.drawPath(tip, outline);
    canvas.drawRRect(round, fill);
    canvas.drawPath(tip, fill);
    // The bubble pops smoothly; its words snap between a few sizes (and
    // wait until it's half grown), so Impeller doesn't rasterize a new
    // glyph size every frame.
    if (s >= 0.5) {
      canvas.scale(_step(s, 0.1) / s);
      say.paint(canvas, Offset(-say.width / 2, -say.height / 2));
    }
    canvas.restore();
  }

  void _heartRise(Canvas canvas, double ms) {
    final k = _span(ms, _heart.$1, _heart.$2 - _heart.$1);
    if (k <= 0) return;
    final e = Curves.easeOutCubic.transform(k);
    final c = Offset.lerp(const Offset(400, 440), const Offset(400, 222), e)!;
    final pop = Curves.easeOutBack.transform(math.min(1, k * 2.2));
    final r = 26 * pop;
    // A warm glow behind it.
    canvas.drawCircle(
      c,
      r * 2.2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _heartColor.withValues(alpha: 0.35),
            _heartColor.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 2.2)),
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(r);
    canvas.drawPath(_heartPath, Paint()..color = _heartColor);
    canvas.restore();
  }

  // A heart about 2 wide, centered on the origin.
  static final _heartPath = Path()
    ..moveTo(0, 0.95)
    ..cubicTo(-0.6, 0.45, -1.1, 0.05, -1.05, -0.4)
    ..cubicTo(-1.0, -0.95, -0.25, -1.1, 0, -0.55)
    ..cubicTo(0.25, -1.1, 1.0, -0.95, 1.05, -0.4)
    ..cubicTo(1.1, 0.05, 0.6, 0.45, 0, 0.95)
    ..close();

  @override
  bool shouldRepaint(_BenchPainter old) => false;
}
