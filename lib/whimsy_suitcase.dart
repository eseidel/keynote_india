import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'layouts.dart';
import 'theme.dart';

/// "Portable matters more. Flutter is how.": a vintage suitcase skids in
/// under the two lines and rocks to a stop, platform stickers slap onto it
/// one by one (phone, web, desktop, TV, car, watch), and a Flutter-blue
/// luggage tag drops from the handle and swings to rest. Portable is the
/// suitcase; Flutter is the tag that goes everywhere with it. Plays once
/// when the slide appears and settles in about three and a half seconds.
class PortableStatement extends StatefulWidget {
  const PortableStatement(this.text, {super.key});
  final String text;

  @override
  State<PortableStatement> createState() => _PortableStatementState();
}

const _totalMs = 3600;

class _PortableStatementState extends State<PortableStatement>
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
      // The lines move up a little to make room for the suitcase.
      Padding(
        padding: const EdgeInsets.only(bottom: _lift * 2),
        child: Statement(widget.text),
      ),
      LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            Positioned(
              left: box.maxWidth / 2 - _SuitcasePainter.size.width / 2,
              top: box.maxHeight / 2 + 110,
              child: CustomPaint(
                size: _SuitcasePainter.size,
                painter: _SuitcasePainter(_clock),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

const _lift = 110.0;

typedef _Sticker = ({
  Offset c,
  double angle,
  Color color,
  bool round,
  Size size,
  void Function(Canvas, Paint) icon,
});

class _SuitcasePainter extends CustomPainter {
  _SuitcasePainter(this.t) : super(repaint: t);
  final Animation<double> t;

  static const _scale = 1.15;
  static const size = Size(560 * _scale, 300 * _scale);

  // The suitcase, in a 560x300 box (scaled up to [size]).
  static const _body = Rect.fromLTWH(130, 74, 300, 176);
  static const _floor = 250.0;

  // Timeline (ms).
  static const _slideEnd = 850.0;
  static const _stickerStart = 1000.0, _stickerGap = 190.0;
  static const _tagStart = 2250.0;

  static const _tan = Color(0xFFC98F55);
  static const _tanDark = Color(0xFF9A6638);
  static const _tanLight = Color(0xFFE0AD74);
  static const _brass = Color(0xFFF1C35A);
  static const _flutterBlue = Color(0xFF0468D7);

  static const _white = Colors.white;

  static final List<_Sticker> _stickers = [
    (
      c: const Offset(178, 124),
      angle: -0.18,
      color: Palette.accent,
      round: true,
      size: const Size(60, 60),
      icon: _phone,
    ),
    (
      c: const Offset(248, 120),
      angle: 0.12,
      color: const Color(0xFF7C5CFF),
      round: true,
      size: const Size(54, 54),
      icon: _globe,
    ),
    (
      c: const Offset(190, 202),
      angle: 0.08,
      color: Palette.warn,
      round: false,
      size: const Size(74, 52),
      icon: _desktop,
    ),
    (
      c: const Offset(268, 196),
      angle: -0.1,
      color: const Color(0xFFFF6B8B),
      round: false,
      size: const Size(66, 52),
      icon: _tv,
    ),
    (
      c: const Offset(400, 128),
      angle: 0.16,
      color: const Color(0xFF3DDC97),
      round: true,
      size: const Size(52, 52),
      icon: _car,
    ),
    (
      c: const Offset(398, 204),
      angle: -0.14,
      color: Palette.statBlue,
      round: true,
      size: const Size(48, 48),
      icon: _watch,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _totalMs;
    canvas.scale(_scale);

    // Skid in from the left, tipped back on its rear corner, then rock flat.
    final slide = Curves.easeOutCubic.transform((ms / _slideEnd).clamp(0, 1));
    final dx = (1 - slide) * -1150;
    final s = math.max(0.0, ms - _slideEnd) / 1000;
    final rock = ms < _slideEnd
        ? -0.07 * slide
        : -0.07 * math.exp(-s * 5) * math.cos(s * 16);
    // It pivots on the bottom corner that's on the floor.
    final pivot = rock < 0 ? _body.bottomLeft : _body.bottomRight;

    // Shadow on the floor, under the suitcase.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(_body.center.dx + dx, _floor + 4),
        width: _body.width * 1.05,
        height: 16,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );

    // Dust where it skids to a stop.
    final puff = ((ms - _slideEnd + 120) / 600).clamp(0.0, 1.0);
    if (puff > 0 && puff < 1) {
      final e = Curves.easeOut.transform(puff);
      final dust = Paint()
        ..color = Palette.soft.withValues(alpha: 0.35 * (1 - puff));
      for (var k = 0; k < 4; k++) {
        canvas.drawCircle(
          Offset(_body.left - 14 - 30 * e - k * 14, _floor - 6 - k * 8 * e),
          5 + 8 * e - k,
          dust,
        );
      }
    }

    canvas.save();
    canvas.translate(dx + pivot.dx, pivot.dy);
    canvas.rotate(rock);
    canvas.translate(-pivot.dx, -pivot.dy);
    _paintCase(canvas);
    for (var i = 0; i < _stickers.length; i++) {
      _paintSticker(canvas, _stickers[i], ms - _stickerStart - i * _stickerGap);
    }
    _paintTag(canvas, ms - _tagStart);
    canvas.restore();
  }

  void _paintCase(Canvas canvas) {
    final body = RRect.fromRectAndRadius(_body, const Radius.circular(22));
    // Handle.
    final handle = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        _body.center.dx - 46,
        _body.top - 34,
        _body.center.dx + 46,
        _body.top + 6,
      ),
      const Radius.circular(16),
    );
    canvas.drawRRect(
      handle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = _tanDark,
    );
    // Handle mounts.
    for (final x in [_body.center.dx - 46, _body.center.dx + 46]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, _body.top - 2),
            width: 26,
            height: 14,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = _brass,
      );
    }
    canvas.drawRRect(body, Paint()..color = _tan);
    // Lid: a lighter band and a seam.
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(
      Rect.fromLTWH(_body.left, _body.top, _body.width, 12),
      Paint()..color = _tanLight,
    );
    canvas.drawRect(
      Rect.fromLTWH(_body.left, _body.bottom - 14, _body.width, 14),
      Paint()..color = _tanDark.withValues(alpha: 0.55),
    );
    canvas.restore();
    canvas.drawRRect(
      body.deflate(7),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _tanDark.withValues(alpha: 0.6),
    );
    // Brass corners.
    final corner = Paint()..color = _brass;
    for (final (x, y, sx, sy) in [
      (_body.left, _body.top, 1.0, 1.0),
      (_body.right, _body.top, -1.0, 1.0),
      (_body.left, _body.bottom, 1.0, -1.0),
      (_body.right, _body.bottom, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + sy * 34)
          ..lineTo(x, y + sy * 18)
          ..quadraticBezierTo(x, y, x + sx * 18, y)
          ..lineTo(x + sx * 34, y)
          ..lineTo(x + sx * 34, y + sy * 8)
          ..lineTo(x + sx * 8, y + sy * 8)
          ..lineTo(x + sx * 8, y + sy * 34)
          ..close(),
        corner,
      );
    }
    // Latches.
    for (final x in [_body.left + 70, _body.right - 70]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, _body.top + 8),
            width: 30,
            height: 20,
          ),
          const Radius.circular(4),
        ),
        corner,
      );
      canvas.drawCircle(
        Offset(x, _body.top + 10),
        3,
        Paint()..color = _tanDark,
      );
    }
  }

  void _paintSticker(Canvas canvas, _Sticker k, double ms) {
    if (ms <= 0) return;
    // Slapped on: drops from big to flat with a little overshoot.
    final p = (ms / 230).clamp(0.0, 1.0);
    final scale = 1 + 0.9 * (1 - Curves.easeOutBack.transform(p));
    final spin = (1 - p) * 0.5;
    final alpha = (ms / 70).clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(k.c.dx, k.c.dy);
    canvas.rotate(k.angle + spin);
    canvas.scale(scale);
    final r = Rect.fromCenter(
      center: Offset.zero,
      width: k.size.width,
      height: k.size.height,
    );
    final shape = k.round
        ? RRect.fromRectAndRadius(r, Radius.circular(r.width / 2))
        : RRect.fromRectAndRadius(r, const Radius.circular(9));
    // A shadow that's longer while it's still in the air.
    canvas.drawRRect(
      shape.shift(Offset(2 + 8 * (1 - p), 3 + 10 * (1 - p))),
      Paint()..color = Colors.black.withValues(alpha: 0.22 * alpha),
    );
    canvas.drawRRect(shape, Paint()..color = _white.withValues(alpha: alpha));
    canvas.drawRRect(
      shape.deflate(4),
      Paint()..color = k.color.withValues(alpha: alpha),
    );
    final ink = Paint()
      ..color = _white.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    k.icon(canvas, ink);
    canvas.restore();
  }

  void _paintTag(Canvas canvas, double ms) {
    if (ms <= 0) return;
    // It drops on its string, then swings about the handle and settles.
    final s = ms / 1000;
    final drop = Curves.easeOutBack.transform((s / 0.3).clamp(0, 1));
    final swing = 0.75 * math.exp(-s * 2.6) * math.cos(s * 8.5 - 0.3);
    const rest = -0.12;
    const hook = Offset(_SuitcasePainter._hookX, _SuitcasePainter._hookY);
    canvas.save();
    canvas.translate(hook.dx, hook.dy);
    canvas.rotate(rest + swing * drop);
    final len = 34 * drop;
    // String.
    canvas.drawLine(
      Offset.zero,
      Offset(0, len + 6),
      Paint()
        ..color = const Color(0xFFEDE3D2)
        ..strokeWidth = 2.5,
    );
    canvas.translate(0, len);
    canvas.drawPath(
      _tag.shift(const Offset(3, 4)),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    canvas.drawPath(_tag, Paint()..color = _flutterBlue);
    // Eyelet.
    canvas.drawCircle(const Offset(0, 11), 5, Paint()..color = _white);
    canvas.drawCircle(const Offset(0, 11), 3, Paint()..color = _tanDark);
    // The Flutter logo, in white.
    canvas.save();
    canvas.translate(-21, 32);
    canvas.scale(0.42);
    canvas.drawPath(_logoLight, Paint()..color = _white);
    canvas.drawPath(_logoDark, Paint()..color = const Color(0xFFB9DEFF));
    canvas.restore();
    canvas.restore();
  }

  static final Path _tag = Path()
    ..moveTo(-12, 0)
    ..lineTo(12, 0)
    ..lineTo(30, 18)
    ..lineTo(30, 96)
    ..quadraticBezierTo(30, 104, 22, 104)
    ..lineTo(-22, 104)
    ..quadraticBezierTo(-30, 104, -30, 96)
    ..lineTo(-30, 18)
    ..close();

  // The tag hangs off the handle's right mount.
  static const _hookX = 320.0, _hookY = 58.0;

  // The Flutter logo in a ~100x124 box: the top bar and the chevron's upper
  // arm light, the lower arm a shade darker.
  static final Path _logoLight = Path()
    ..addPolygon(const [
      Offset(0, 62),
      Offset(62, 0),
      Offset(96, 0),
      Offset(17, 79),
    ], true)
    ..addPolygon(const [
      Offset(31, 90),
      Offset(64, 57),
      Offset(98, 57),
      Offset(48, 107),
    ], true);
  static final Path _logoDark = Path()
    ..addPolygon(const [
      Offset(48, 107),
      Offset(65, 90),
      Offset(99, 124),
      Offset(65, 124),
    ], true);

  // Sticker icons, drawn around the sticker's center.
  static void _phone(Canvas c, Paint p) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 20, height: 32),
        const Radius.circular(5),
      ),
      p,
    );
    c.drawLine(const Offset(-3, 11), const Offset(3, 11), p);
  }

  static void _globe(Canvas c, Paint p) {
    c.drawCircle(Offset.zero, 15, p);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 13, height: 30), p);
    c.drawLine(const Offset(-15, 0), const Offset(15, 0), p);
  }

  static void _desktop(Canvas c, Paint p) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, -4), width: 40, height: 24),
        const Radius.circular(3),
      ),
      p,
    );
    c.drawLine(const Offset(0, 8), const Offset(0, 13), p);
    c.drawLine(const Offset(-9, 14), const Offset(9, 14), p);
  }

  static void _tv(Canvas c, Paint p) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 3), width: 38, height: 24),
        const Radius.circular(5),
      ),
      p,
    );
    c.drawLine(const Offset(-8, -16), const Offset(0, -9), p);
    c.drawLine(const Offset(8, -16), const Offset(0, -9), p);
  }

  static void _car(Canvas c, Paint p) {
    c.drawPath(
      Path()
        ..moveTo(-17, 6)
        ..lineTo(-17, -1)
        ..lineTo(-11, -3)
        ..lineTo(-6, -10)
        ..lineTo(7, -10)
        ..lineTo(12, -3)
        ..lineTo(17, -1)
        ..lineTo(17, 6)
        ..close(),
      p,
    );
    final fill = Paint()..color = p.color;
    c.drawCircle(const Offset(-9, 8), 4, fill);
    c.drawCircle(const Offset(9, 8), 4, fill);
  }

  static void _watch(Canvas c, Paint p) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 18, height: 20),
        const Radius.circular(5),
      ),
      p,
    );
    c.drawLine(const Offset(-5, -10), const Offset(-4, -16), p);
    c.drawLine(const Offset(5, -10), const Offset(4, -16), p);
    c.drawLine(const Offset(-5, 10), const Offset(-4, 16), p);
    c.drawLine(const Offset(5, 10), const Offset(4, 16), p);
  }

  @override
  bool shouldRepaint(_SuitcasePainter old) => old.t != t;
}
