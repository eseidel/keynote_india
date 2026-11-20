import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// "Single source of truth": two copies slide together and merge into one
/// glowing file, then the people and agents who read it connect one by one.
/// Plays once when the slide appears and settles.
class SingleSource extends StatefulWidget {
  const SingleSource({super.key});

  @override
  State<SingleSource> createState() => _SingleSourceState();
}

class _SingleSourceState extends State<SingleSource>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _SourcePainter(_t), child: const SizedBox.expand());
}

/// Readers around the file: (angle in turns from 12 o'clock, is an agent).
const _readers = [
  (0.00, true),
  (0.09, false),
  (0.18, true),
  (0.27, false),
  (0.36, true),
  (0.45, false),
  (0.55, true),
  (0.64, false),
  (0.73, true),
  (0.82, false),
  (0.91, true),
];

class _SourcePainter extends CustomPainter {
  _SourcePainter(this.t) : super(repaint: t);
  final Animation<double> t;

  static const _fileSize = Size(250, 310);
  static const _mergeEnd = 0.3; // fraction of the timeline spent merging

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    final c = size.center(Offset.zero);
    final merge = Curves.easeInOutCubic.transform(
      (v / _mergeEnd).clamp(0.0, 1.0),
    );
    final rx = size.width * 0.40;
    final ry = size.height * 0.40;

    // Readers: lines first so the file and glyphs sit on top.
    final readerT = ((v - _mergeEnd) / (1 - _mergeEnd)).clamp(0.0, 1.0);
    final positions = <Offset>[];
    for (final (turn, _) in _readers) {
      final a = -math.pi / 2 + turn * 2 * math.pi;
      positions.add(c + Offset(math.cos(a) * rx, math.sin(a) * ry));
    }
    final appear = <double>[];
    for (var i = 0; i < _readers.length; i++) {
      final start = i / _readers.length * 0.75;
      appear.add(
        Curves.easeOutBack.transform(
          ((readerT - start) / 0.25).clamp(0.0, 1.0),
        ),
      );
    }
    for (var i = 0; i < _readers.length; i++) {
      final k = appear[i].clamp(0.0, 1.0);
      if (k <= 0) continue;
      final from = positions[i];
      final to = Offset.lerp(from, c, 0.78)!;
      final end = Offset.lerp(from, to, k)!;
      canvas.drawLine(
        from,
        end,
        Paint()
          ..color = Palette.accent.withValues(alpha: 0.45 * k)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // Two copies sliding in from the sides, fading as they merge.
    if (merge < 1) {
      final spread = size.width * 0.30 * (1 - merge);
      final copyAlpha = 1 - merge;
      _file(
        canvas,
        c - Offset(spread, 0),
        alpha: copyAlpha,
        color: Palette.muted,
        glow: 0,
        tilt: -0.06 * (1 - merge),
      );
      _file(
        canvas,
        c + Offset(spread, 0),
        alpha: copyAlpha,
        color: Palette.muted,
        glow: 0,
        tilt: 0.06 * (1 - merge),
      );
    }
    // The one file, glowing once the copies have merged into it.
    _file(canvas, c, alpha: merge, color: Palette.accent, glow: merge, tilt: 0);

    for (var i = 0; i < _readers.length; i++) {
      final k = appear[i];
      if (k <= 0) continue;
      canvas.save();
      canvas.translate(positions[i].dx, positions[i].dy);
      canvas.scale(k * 1.3);
      if (_readers[i].$2) {
        _agent(canvas);
      } else {
        _person(canvas);
      }
      canvas.restore();
    }
  }

  void _file(
    Canvas canvas,
    Offset center, {
    required double alpha,
    required Color color,
    required double glow,
    required double tilt,
  }) {
    if (alpha <= 0) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: _fileSize.width,
      height: _fileSize.height,
    );
    final body = RRect.fromRectAndRadius(rect, const Radius.circular(22));
    if (glow > 0) {
      canvas.drawRRect(
        body.inflate(10),
        Paint()
          ..color = Palette.accent.withValues(alpha: 0.55 * glow * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50),
      );
    }
    canvas.drawRRect(
      body,
      Paint()..color = const Color(0xFF161D27).withValues(alpha: alpha),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = color.withValues(alpha: alpha),
    );
    // Code lines, indented like a real file.
    const lines = [
      (0, 0.70),
      (1, 0.55),
      (2, 0.45),
      (2, 0.35),
      (1, 0.20),
      (0, 0.10),
      (0, 0.0),
      (0, 0.62),
      (1, 0.50),
      (0, 0.10),
    ];
    final line = Paint()
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    var y = rect.top + 44;
    for (final (indent, w) in lines) {
      if (w > 0) {
        final x0 = rect.left + 36 + indent * 26.0;
        final x1 = x0 + (rect.width - 80) * w;
        line.color = (indent == 0 ? color : Palette.soft).withValues(
          alpha: alpha * (indent == 0 ? 0.9 : 0.5),
        );
        canvas.drawLine(Offset(x0, y), Offset(x1, y), line);
      }
      y += 24;
    }
    canvas.restore();
  }

  void _person(Canvas canvas) {
    final p = Paint()..color = Palette.text;
    canvas.drawCircle(const Offset(0, -22), 17, p);
    canvas.drawPath(
      Path()
        ..moveTo(-32, 30)
        ..quadraticBezierTo(-32, -2, 0, -2)
        ..quadraticBezierTo(32, -2, 32, 30)
        ..close(),
      p,
    );
  }

  void _agent(Canvas canvas) {
    final p = Paint()..color = Palette.accent;
    // Antenna.
    canvas.drawLine(
      const Offset(0, -26),
      const Offset(0, -40),
      Paint()
        ..color = Palette.accent
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(0, -42), 6, p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 0), width: 64, height: 52),
        const Radius.circular(14),
      ),
      p,
    );
    final eye = Paint()..color = Palette.background;
    canvas.drawCircle(const Offset(-13, -2), 6, eye);
    canvas.drawCircle(const Offset(13, -2), 6, eye);
  }

  @override
  bool shouldRepaint(_SourcePainter old) => old.t != t;
}
