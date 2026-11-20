import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// "So which stack?", asked with blocks: under the question, three stacks
/// build themselves block by block. Two are badly made and wobble on
/// landing; the right one sways so far that its top block slides off and
/// tumbles to the floor, and both are left leaning. The middle one, square
/// and Flutter blue, never moves. Runs once and settles in about four
/// seconds on the three finished stacks. Drawn by Flutter, no image.
class WhichStack extends StatefulWidget {
  const WhichStack(this.text, {super.key, this.size = 50});
  final String text;
  final double size;

  @override
  State<WhichStack> createState() => _WhichStackState();
}

const _totalMs = 3900;

class _WhichStackState extends State<WhichStack>
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
        const SizedBox(height: 70),
        SizedBox(
          width: 1300,
          height: 420,
          child: CustomPaint(painter: _StacksPainter(_clock, _totalMs)),
        ),
      ],
    ),
  );
}

/// One block of a stack: its width, sideways offset from the block below,
/// and its tilt relative to the block below.
typedef _Block = ({double w, double dx, double tilt});

class _Stack {
  const _Stack({
    required this.x,
    required this.blocks,
    required this.colors,
    this.lean = 0,
    this.wobble = 0,
    this.drops = false,
  });

  /// Base centre, as a fraction of the width.
  final double x;
  final List<_Block> blocks;
  final List<Color> colors;

  /// Final lean of the whole stack (radians, + leans right).
  final double lean;

  /// Size of the wobble's first swing (radians).
  final double wobble;

  /// Whether the top block falls off.
  final bool drops;
}

const _grey = [Color(0xFF5B6675), Color(0xFF6F7A8A), Color(0xFF4E5866)];
const _rust = [Color(0xFF8A5A44), Color(0xFF9C6A50), Color(0xFF7A4E3B)];
// Flutter blue, dark at the footing to bright at the top: orderly.
const _blue = [
  Color(0xFF0B5FA8),
  Color(0xFF0D6EBF),
  Color(0xFF117FD0),
  Color(0xFF1592DE),
  Color(0xFF1EAAEA),
  Color(0xFF27C4F5),
];

const _stacks = [
  _Stack(
    x: 0.2,
    colors: _rust,
    lean: -0.06,
    wobble: 0.10,
    blocks: [
      (w: 190, dx: 0, tilt: 0),
      (w: 150, dx: -18, tilt: -0.02),
      (w: 200, dx: 14, tilt: 0.03),
      (w: 120, dx: -22, tilt: -0.04),
      (w: 170, dx: 10, tilt: 0.02),
      (w: 110, dx: -16, tilt: -0.05),
    ],
  ),
  _Stack(
    x: 0.5,
    colors: _blue,
    blocks: [
      (w: 230, dx: 0, tilt: 0),
      (w: 210, dx: 0, tilt: 0),
      (w: 190, dx: 0, tilt: 0),
      (w: 170, dx: 0, tilt: 0),
      (w: 150, dx: 0, tilt: 0),
      (w: 130, dx: 0, tilt: 0),
    ],
  ),
  _Stack(
    x: 0.8,
    colors: _grey,
    lean: 0.08,
    wobble: 0.16,
    drops: true,
    blocks: [
      (w: 160, dx: 0, tilt: 0),
      (w: 210, dx: 20, tilt: 0.04),
      (w: 130, dx: -12, tilt: -0.02),
      (w: 180, dx: 24, tilt: 0.05),
      (w: 140, dx: -8, tilt: 0.03),
      (w: 150, dx: 22, tilt: 0.04),
    ],
  ),
];

class _StacksPainter extends CustomPainter {
  _StacksPainter(this.t, this.totalMs) : super(repaint: t);
  final Animation<double> t;
  final int totalMs;

  static const _h = 54.0; // block height
  static const _drop = 220.0; // how far a block falls into place
  static const _floorOverhang = 60.0; // floor line past each side of the box

  // Timeline (ms): blocks land one course at a time across all stacks,
  // then the bad stacks wobble; the right one sheds its top block.
  static const _firstDrop = 150.0;
  static const _perCourse = 165.0;
  static const _fallMs = 260.0;
  static const _wobbleAt = _firstDrop + 5 * _perCourse + _fallMs; // ~1235
  static const _shedAt = 1650.0; // top block starts to slide
  static const _shedSlide = 220.0;
  static const _shedFly = 420.0;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * totalMs;
    final floor = size.height - 6;

    // The floor: a faint line the stacks stand on, a little wider than the
    // box so the shed block lands on it.
    canvas.drawLine(
      Offset(-_floorOverhang, floor),
      Offset(size.width + _floorOverhang, floor),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..strokeWidth = 2,
    );

    for (final s in _stacks) {
      final base = Offset(size.width * s.x, floor);
      final angle = _stackAngle(s, ms);
      // Walk up the stack: each block's base centre and angle in the world.
      var p = base;
      var a = 0.0;
      var below = double.infinity; // width of what this block stands on
      for (final (i, b) in s.blocks.indexed) {
        // Static crookedness grows in as the stack wobbles, and the whole
        // stack's sway is shared out up its height so it bends.
        final r = b.tilt * _settleIn(ms) + angle / s.blocks.length;
        // Tip about the edge it rests on (its own low corner, or the corner
        // of the block below if it overhangs), so corners never sink into
        // the block underneath.
        final q = (b.dx + r.sign * b.w / 2).clamp(-below / 2, below / 2);
        p += _rot(Offset(q, 0), a) + _rot(Offset(b.dx - q, 0), a + r);
        a += r;
        below = b.w;
        final top = i == s.blocks.length - 1;
        final color = s.colors[i % s.colors.length];
        if (top && s.drops && ms >= _shedAt) {
          _paintShed(canvas, p, a, b.w, base, floor, ms, color);
          continue;
        }
        final land = _firstDrop + i * _perCourse;
        final u = ((ms - land) / _fallMs).clamp(0.0, 1.0);
        if (u <= 0) continue;
        final fall = (1 - Curves.easeIn.transform(u)) * _drop;
        // A small squash as it lands, springing back.
        final since = ms - land - _fallMs;
        final squash = since >= 0 && since < 140
            ? math.sin(math.pi * since / 140) * 0.06
            : 0.0;
        _paintBlock(
          canvas,
          p + _rot(Offset(0, -fall), a),
          a,
          b.w * (1 + squash),
          _h * (1 - squash),
          color,
          alpha: (u * 3).clamp(0.0, 1.0),
        );
        p += _rot(const Offset(0, -_h), a);
      }
      // The good stack gets a soft glow once it's built.
      if (s.wobble == 0) {
        final g = ((ms - _wobbleAt - 600) / 900).clamp(0.0, 1.0);
        if (g > 0) {
          final height = s.blocks.length * _h;
          canvas.drawRect(
            Rect.fromCenter(
              center: base - Offset(0, height / 2),
              width: 300,
              height: height + 40,
            ),
            Paint()
              ..color = Palette.accent.withValues(alpha: 0.10 * g)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50),
          );
        }
      }
    }
  }

  /// How far into the wobble the static crookedness has grown (0..1): the
  /// bad stacks land square-ish, then sag into their crooked shapes.
  double _settleIn(double ms) =>
      Curves.easeOut.transform(((ms - _wobbleAt + 300) / 900).clamp(0.0, 1.0));

  /// The whole stack's sway: a damped swing settling to its lean, ending
  /// exactly at the lean on the last frame.
  double _stackAngle(_Stack s, double ms) {
    if (s.wobble == 0 || ms < _wobbleAt) return 0;
    final sec = (ms - _wobbleAt) / 1000;
    final end = (totalMs - _wobbleAt) / 1000;
    final window = 1 - math.pow(sec / end, 6).toDouble();
    final swing =
        s.wobble *
        math.sin(2 * math.pi * 1.5 * sec) *
        math.exp(-sec / 0.7) *
        window;
    final lean = s.lean * Curves.easeOut.transform((sec / 0.8).clamp(0.0, 1.0));
    return lean + swing;
  }

  /// The right stack's top block: slides off the tilted top, flies, lands
  /// on the floor beside the stack with a little bounce.
  void _paintShed(
    Canvas canvas,
    Offset p0,
    double a0,
    double w,
    Offset base,
    double floor,
    double ms,
    Color color,
  ) {
    final slide = ((ms - _shedAt) / _shedSlide).clamp(0.0, 1.0);
    // Slide down the slope by a third of its width.
    final slid =
        p0 + _rot(Offset(w * 0.4 * Curves.easeIn.transform(slide), 0), a0);
    final fly = ((ms - _shedAt - _shedSlide) / _shedFly).clamp(0.0, 1.0);
    if (fly <= 0) {
      _paintBlock(canvas, slid, a0 + 0.15 * slide, w, _h, color);
      return;
    }
    // Ballistic-looking arc to the floor, right of the stack.
    final land = Offset(base.dx + 230, floor);
    final x = slid.dx + (land.dx - slid.dx) * fly;
    final y = slid.dy + (land.dy - slid.dy) * fly * fly;
    var a = a0 + 0.15 + 1.3 * Curves.easeOut.transform(fly);
    var p = Offset(x, y);
    // On landing it tips flat with a small hop.
    final after = ms - _shedAt - _shedSlide - _shedFly;
    if (after >= 0) {
      final u = (after / 320).clamp(0.0, 1.0);
      a = (a0 + 1.45) * (1 - Curves.easeOutBack.transform(u));
      final hop = math.sin(math.pi * (after / 220).clamp(0.0, 1.0)) * 14;
      p = land - Offset(0, hop);
    }
    // Never let it pass through the floor: lift it so its lowest corner
    // rests on the floor line (it then tips flat about that corner).
    final c = math.cos(a), sn = math.sin(a);
    final lowest = math.max((w / 2 * sn).abs(), (w / 2 * sn).abs() - _h * c);
    if (p.dy + lowest > floor) p = Offset(p.dx, floor - lowest);
    _paintBlock(canvas, p, a, w, _h, color);
  }

  /// A block standing on [bottom] (centre of its bottom edge), rotated [a].
  static void _paintBlock(
    Canvas canvas,
    Offset bottom,
    double a,
    double w,
    double h,
    Color color, {
    double alpha = 1,
  }) {
    canvas.save();
    canvas.translate(bottom.dx, bottom.dy);
    canvas.rotate(a);
    final rect = Rect.fromLTWH(-w / 2, -h, w, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1.5), const Radius.circular(6)),
      Paint()..color = color.withValues(alpha: alpha),
    );
    // A lit top edge so each block reads as solid.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-w / 2 + 1.5, -h + 1.5, w - 3, h * 0.18),
        const Radius.circular(6),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.2 * alpha),
    );
    canvas.restore();
  }

  static Offset _rot(Offset v, double a) => Offset(
    v.dx * math.cos(a) - v.dy * math.sin(a),
    v.dx * math.sin(a) + v.dy * math.cos(a),
  );

  @override
  bool shouldRepaint(_StacksPainter old) => true;
}
