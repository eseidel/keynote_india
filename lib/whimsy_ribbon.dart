import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// "It codes better than I do": a blue first-place rosette swings down
/// from above, gets pinned to the end of the line, and sways to rest, as
/// if the judges just walked by. A glint crosses its gold center.
class RibbonStatement extends StatefulWidget {
  const RibbonStatement(this.text, {super.key, this.size = 50});
  final String text;
  final double size;

  @override
  State<RibbonStatement> createState() => _RibbonStatementState();
}

class _RibbonStatementState extends State<RibbonStatement>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = headline(widget.size);
    // The line shifts left so line and rosette center together.
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: _Rosette.width),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text(widget.text, style: style),
            Positioned(
              right: -_Rosette.width - 16,
              top: -_Rosette.pin.dy - 40,
              child: AnimatedBuilder(
                animation: _clock,
                builder: (_, _) => _Rosette(_clock.value * 3.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rosette extends StatelessWidget {
  const _Rosette(this.t);
  final double t; // seconds since the slide appeared

  static const width = 190.0, height = 330.0;
  static const pin = Offset(width / 2, 14);

  @override
  Widget build(BuildContext context) {
    // 0.5s beat, then a 0.45s drop from above the slide with an overshoot.
    final drop = Curves.easeOutBack.transform(((t - 0.5) / 0.45).clamp(0, 1));
    // Pinned at 0.95s; it swings about the pin and settles.
    final s = math.max(0.0, t - 0.95);
    final swing = 0.32 * math.exp(-s * 1.6) * math.cos(s * 7.5);
    final rest = 0.18; // hangs a little tilted, like it was pinned in a hurry
    final glint = ((t - 1.6) / 0.7).clamp(0.0, 1.0);
    return Opacity(
      opacity: t < 0.5 ? 0 : 1,
      child: Transform.translate(
        offset: Offset(0, (1 - drop) * -700),
        child: Transform.rotate(
          angle: rest + swing,
          origin: pin - const Offset(width / 2, height / 2),
          child: CustomPaint(
            size: const Size(width, height),
            painter: _RosettePainter(glint),
          ),
        ),
      ),
    );
  }
}

class _RosettePainter extends CustomPainter {
  _RosettePainter(this.glint);
  final double glint;

  static const blue = Color(0xFF1F6FE0);
  static const blueDark = Color(0xFF134C9E);
  static const blueLight = Color(0xFF4F95F5);
  static const gold = Color(0xFFF5C542);
  static const goldDark = Color(0xFFC9951E);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, 108);
    const outer = 92.0;

    // Tails, behind the rosette, each with a V notch.
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(side * 0.2);
      const w = 52.0, len = 215.0;
      final tail = Path()
        ..moveTo(-w / 2, 0)
        ..lineTo(w / 2, 0)
        ..lineTo(w / 2, len)
        ..lineTo(0, len - 30)
        ..lineTo(-w / 2, len)
        ..close();
      canvas.drawPath(tail, Paint()..color = side < 0 ? blueDark : blue);
      canvas.drawLine(
        const Offset(0, 40),
        const Offset(0, len - 36),
        Paint()
          ..color = blueLight.withValues(alpha: 0.5)
          ..strokeWidth = 3,
      );
      canvas.restore();
    }

    // Pleated ruffle: two rings of scallops.
    void ruffle(double r, int n, Color color, double phase) {
      final p = Path();
      for (var i = 0; i < n; i++) {
        final a = (i + phase) / n * 2 * math.pi;
        p.addOval(
          Rect.fromCircle(
            center: c + Offset(math.cos(a), math.sin(a)) * (r - 13),
            radius: 2 * math.pi * r / n * 0.62,
          ),
        );
      }
      p.addOval(Rect.fromCircle(center: c, radius: r - 12));
      canvas.drawPath(p, Paint()..color = color);
    }

    ruffle(outer, 26, blueDark, 0);
    ruffle(outer - 12, 26, blue, 0.5);

    // The gold center button.
    const inner = 52.0;
    final rect = Rect.fromCircle(center: c, radius: inner);
    canvas.drawCircle(
      c,
      inner + 4,
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      c,
      inner,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFFFFE89A), gold, goldDark],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      inner - 7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = goldDark.withValues(alpha: 0.8),
    );

    // "1st"
    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '1',
            style: headline(30, color: blueDark),
          ),
          TextSpan(
            text: 'st',
            style: headline(15, color: blueDark),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));

    // A glint sweeping across the button once.
    if (glint > 0 && glint < 1) {
      canvas.save();
      canvas.clipPath(Path()..addOval(rect));
      final x = c.dx - inner * 1.6 + glint * inner * 3.2;
      canvas.drawRect(
        Rect.fromLTWH(x - 14, c.dy - inner, 28, inner * 2),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.7),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(x - 14, 0, 28, 1))
          ..blendMode = BlendMode.plus,
      );
      canvas.restore();
    }

    // The pin.
    canvas.drawCircle(
      const Offset(95, 14),
      7,
      Paint()..color = const Color(0xFFD9DEE6),
    );
    canvas.drawCircle(const Offset(93, 12), 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_RosettePainter old) => old.glint != glint;
}
