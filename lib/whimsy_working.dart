import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// "We're working on it", as a building site: under the headline a tower
/// crane carries a block out along its jib, the block swings to a stop,
/// is lowered into its slot in a half-built wall and lands with a puff of
/// dust, and the empty hook winds back up. The courses still to build stay
/// as dashed outlines: progress, not done. Runs once and settles in about
/// three and a half seconds. Drawn by Flutter, no image.
class WorkingStatement extends StatefulWidget {
  const WorkingStatement(this.text, {super.key, this.size = 50});
  final String text;
  final double size;

  @override
  State<WorkingStatement> createState() => _WorkingStatementState();
}

const _totalMs = 3500;

class _WorkingStatementState extends State<WorkingStatement>
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
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.text,
          textAlign: TextAlign.center,
          style: headline(widget.size),
        ),
        const SizedBox(height: 60),
        SizedBox(
          width: 1100,
          height: 440,
          child: CustomPaint(painter: _SitePainter(_clock)),
        ),
      ],
    ),
  );
}

class _SitePainter extends CustomPainter {
  _SitePainter(this.t) : super(repaint: t);
  final Animation<double> t;

  // Geometry, in the 1100x440 box.
  static const _ground = 430.0;
  static const _mastX = 230.0;
  static const _mastW = 34.0;
  static const _jibY = 110.0; // underside of the jib
  static const _jibEnd = 960.0;
  static const _bw = 104.0, _bh = 44.0, _gap = 4.0; // blocks
  static const _wallX = 470.0; // left edge of the wall
  static const _cols = 4;
  static const _target = (course: 2, col: 2);

  // Timeline (ms).
  static const _carry = (250.0, 1250.0); // trolley runs out
  static const _lower = (1550.0, 2250.0);
  static const _landMs = 2250.0;
  static const _raise = (2450.0, 3100.0);

  static const _steel = Color(0xFFFFB259); // crane: Palette.warn
  static const _blues = [
    Color(0xFF0D6EBF),
    Color(0xFF117FD0),
    Color(0xFF1592DE),
    Color(0xFF1EAAEA),
  ];

  static double _phase(double ms, (double, double) span) =>
      ((ms - span.$1) / (span.$2 - span.$1)).clamp(0.0, 1.0);

  static Rect _slot(int course, int col) => Rect.fromLTWH(
    _wallX + col * (_bw + _gap),
    _ground - (course + 1) * (_bh + _gap) + _gap,
    _bw,
    _bh,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _totalMs;

    // Ground.
    canvas.drawLine(
      const Offset(0, _ground),
      Offset(size.width, _ground),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..strokeWidth = 2,
    );

    _paintWall(canvas, ms);
    _paintCrane(canvas, ms);
  }

  void _paintWall(Canvas canvas, double ms) {
    final ghost = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Palette.accent.withValues(alpha: 0.35);
    for (var course = 0; course < 4; course++) {
      for (var col = 0; col < _cols; col++) {
        final r = _slot(course, col);
        final built = course < 2 || (course == 2 && col < _target.col);
        if (built) {
          _block(canvas, r, _blues[(course + col) % _blues.length]);
        } else {
          // The plan: dashed outlines of what's still to build.
          _dashed(
            canvas,
            RRect.fromRectAndRadius(r, const Radius.circular(6)),
            ghost,
          );
        }
      }
    }
  }

  void _paintCrane(Canvas canvas, double ms) {
    final steel = Paint()
      ..color = _steel
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final thin = Paint()
      ..color = _steel.withValues(alpha: 0.75)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Mast: a lattice tower.
    const l = _mastX - _mastW / 2, r = _mastX + _mastW / 2;
    canvas.drawLine(const Offset(l, _ground), const Offset(l, _jibY), steel);
    canvas.drawLine(const Offset(r, _ground), const Offset(r, _jibY), steel);
    for (var y = _ground; y > _jibY + 10; y -= 34) {
      canvas.drawLine(Offset(l, y), Offset(r, y - 34), thin);
      canvas.drawLine(Offset(l, y - 34), Offset(r, y - 34), thin);
    }
    // Footing.
    canvas.drawRect(
      Rect.fromCenter(
        center: const Offset(_mastX, _ground - 6),
        width: 90,
        height: 12,
      ),
      Paint()..color = const Color(0xFF5B6675),
    );

    // Jib (right) and counter-jib (left), as trusses, with a peak and ties.
    const top = _jibY - 22;
    const back = _mastX - 170;
    canvas.drawLine(
      const Offset(back, _jibY),
      const Offset(_jibEnd, _jibY),
      steel,
    );
    canvas.drawLine(
      const Offset(back, top),
      const Offset(_jibEnd - 20, top),
      thin,
    );
    for (var x = back; x < _jibEnd - 30; x += 30) {
      canvas.drawLine(Offset(x, _jibY), Offset(x + 15, top), thin);
      canvas.drawLine(Offset(x + 15, top), Offset(x + 30, _jibY), thin);
    }
    canvas.drawLine(
      const Offset(_jibEnd - 20, top),
      const Offset(_jibEnd, _jibY),
      thin,
    );
    const peak = Offset(_mastX, _jibY - 70);
    canvas.drawLine(const Offset(l, top), peak, steel);
    canvas.drawLine(const Offset(r, top), peak, steel);
    canvas.drawLine(peak, const Offset(_jibEnd * 0.62, top), thin);
    canvas.drawLine(peak, const Offset(back + 10, top), thin);
    // Counterweight.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(back, _jibY, 70, 44),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF5B6675),
    );
    // Cab, with a lit window.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r - 2, _jibY, 46, 40),
        const Radius.circular(5),
      ),
      Paint()..color = _steel,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r + 18, _jibY + 8, 20, 16),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFBFEFFF),
    );
    // Beacon on the peak: blinks a few times while it works, then stays lit.
    final blink = ms > 2900 || ((ms / 280).floor().isEven);
    canvas.drawCircle(
      peak - const Offset(0, 6),
      7,
      Paint()
        ..color = (blink ? const Color(0xFFFF5F57) : const Color(0xFF5A2A28)),
    );
    if (blink) {
      canvas.drawCircle(
        peak - const Offset(0, 6),
        16,
        Paint()
          ..color = const Color(0xFFFF5F57).withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Trolley: runs out along the jib to over the slot, and back a little
    // once the block is placed.
    final slot = _slot(_target.course, _target.col);
    const startX = _mastX + 90;
    final outX = slot.center.dx;
    final carry = Curves.easeInOut.transform(_phase(ms, _carry));
    final home = Curves.easeInOut.transform(_phase(ms, _raise));
    final tx = startX + (outX - startX) * carry - 120 * home;

    // Cable length: short while carrying, paid out to set the block down,
    // wound back in empty.
    const carryLen = 30.0;
    final setLen = slot.top - 40 - (_jibY + 12); // block seated
    final lower = Curves.easeInOut.transform(_phase(ms, _lower));
    final raise = Curves.easeInOut.transform(_phase(ms, _raise));
    final len = ms < _landMs
        ? carryLen + (setLen - carryLen) * lower
        : setLen + (carryLen - 10 - setLen) * raise;

    // Swing: the load lags as the trolley accelerates, then swings to a
    // stop before it's lowered.
    var swing = 0.0;
    if (ms < _lower.$1) {
      final p = _phase(ms, _carry);
      // Lags back while moving (derivative of easeInOut), swings after.
      swing = -0.10 * math.sin(math.pi * p);
      if (ms > _carry.$2) {
        final s = (ms - _carry.$2) / 1000;
        swing = 0.09 * math.sin(2 * math.pi * 1.6 * s) * math.exp(-s / 0.18);
      }
    }

    // Trolley.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(tx, _jibY + 6), width: 36, height: 14),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF8C9EB8),
    );
    final pivot = Offset(tx, _jibY + 12);
    final hook = pivot + Offset(math.sin(swing) * len, math.cos(swing) * len);
    canvas.drawLine(
      pivot,
      hook,
      Paint()
        ..color = Palette.soft
        ..strokeWidth = 2,
    );
    // Hook block.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: hook + const Offset(0, 6),
          width: 20,
          height: 14,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = _steel,
    );

    // The load, hanging from slings until it lands.
    final placed = ms >= _landMs;
    if (!placed) {
      canvas.save();
      canvas.translate(hook.dx, hook.dy);
      canvas.rotate(-swing);
      final rect = Rect.fromLTWH(-_bw / 2, 40, _bw, _bh);
      final sling = Paint()
        ..color = Palette.soft.withValues(alpha: 0.8)
        ..strokeWidth = 2;
      canvas.drawLine(
        const Offset(0, 12),
        rect.topLeft + const Offset(8, 0),
        sling,
      );
      canvas.drawLine(
        const Offset(0, 12),
        rect.topRight - const Offset(8, 0),
        sling,
      );
      _block(canvas, rect, Palette.accent);
      canvas.restore();
    } else {
      _block(canvas, slot, Palette.accent);
      // Slings fall slack, then lift away with the hook.
      final lift = _phase(ms, (_landMs, _landMs + 250));
      if (lift < 1) {
        final sling = Paint()
          ..color = Palette.soft.withValues(alpha: 0.8 * (1 - lift))
          ..strokeWidth = 2;
        final h = hook + const Offset(0, 12);
        canvas.drawLine(h, slot.topLeft + const Offset(8, 0), sling);
        canvas.drawLine(h, slot.topRight - const Offset(8, 0), sling);
      }
      // A puff of dust either side as it seats.
      final puff = ((ms - _landMs) / 600).clamp(0.0, 1.0);
      if (puff < 1) {
        final e = Curves.easeOut.transform(puff);
        final dust = Paint()
          ..color = Palette.soft.withValues(alpha: 0.35 * (1 - puff));
        for (final side in [-1.0, 1.0]) {
          final base = Offset(slot.center.dx + side * (_bw / 2), slot.bottom);
          for (var k = 0; k < 3; k++) {
            canvas.drawCircle(
              base + Offset(side * (10 + 26 * e + k * 10), -6 - k * 7 * e),
              5 + 7 * e - k,
              dust,
            );
          }
        }
      }
      // A brief glow: it fits.
      final glow = (1 - ((ms - _landMs) / 700)).clamp(0.0, 1.0);
      if (glow > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(slot.inflate(6), const Radius.circular(9)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Palette.accent.withValues(alpha: 0.7 * glow),
        );
      }
    }
  }

  static void _block(Canvas canvas, Rect r, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(6)),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.18),
        const Radius.circular(6),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.2),
    );
  }

  static void _dashed(Canvas canvas, RRect rr, Paint paint) {
    final path = Path()..addRRect(rr);
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 16) {
        canvas.drawPath(m.extractPath(d, math.min(d + 9, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SitePainter old) => true;
}
