import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// "Your skills still matter", as an RPG character sheet: under the line,
/// three skill bars (Taste, Scars, Judgment) fill up one after another.
/// Each one tops out, flashes, throws a little burst of sparkles, bumps its
/// level and starts the next level with a sliver of XP, the way a game
/// does. Last, a fresh skill shows up at level 1: HyperLogLog, learned
/// last week from an agent. Runs once and settles in about four seconds.
/// The line itself stays exactly where a plain Statement puts it.
class SkillsStatement extends StatefulWidget {
  const SkillsStatement(this.text, {super.key, this.size = 50});
  final String text;
  final double size;

  @override
  State<SkillsStatement> createState() => _SkillsStatementState();
}

const _totalMs = 4000;

class _SkillsStatementState extends State<SkillsStatement>
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
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 160),
        child: Center(
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: headline(widget.size),
          ),
        ),
      ),
      // The sheet hangs under the line without moving it.
      Align(
        alignment: const Alignment(0, 0.62),
        child: RepaintBoundary(
          child: CustomPaint(
            size: _SheetPainter.size,
            painter: _SheetPainter(_clock),
          ),
        ),
      ),
    ],
  );
}

class _Skill {
  const _Skill(this.name, this.level, this.from, this.rest, this.startMs);
  final String name;
  final int level; // level before the level-up
  final double from; // XP fraction when the bar starts filling
  final double rest; // XP fraction into the next level, at rest
  final double startMs;
}

class _SheetPainter extends CustomPainter {
  _SheetPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  static const size = Size(760, 250);
  static const _rowH = 48.0;
  static const _barX = 250.0, _barW = 380.0, _barH = 14.0;
  static const _fillMs = 750.0; // filling to the top
  static const _holdMs = 180.0; // full, a beat
  static const _resetMs = 600.0; // then XP carries into the next level

  static const _skills = [
    _Skill('Taste', 11, 0.35, 0.62, 300),
    _Skill('Scars', 23, 0.45, 0.74, 750),
    _Skill('Judgment', 16, 0.30, 0.55, 1200),
  ];
  static const _newMs = 2750.0; // HyperLogLog unlocks

  static const _fillA = Color(0xFF1E9BE0);
  static const _fillB = Palette.accent;
  static const _gold = Color(0xFFFFD36B);

  // Text is laid out once; only position, opacity and scale change.
  static final _names = [
    for (final s in _skills) _tp(s.name.toUpperCase(), 11.5, Palette.soft, 600),
  ];
  static final _levels = [
    for (final s in _skills)
      for (final l in [s.level, s.level + 1])
        _tp('Lv $l', 12, Palette.text, 700),
  ];
  static final _levelsGold = [
    for (final s in _skills) _tp('Lv ${s.level + 1}', 12, _gold, 700),
  ];
  static final _levelUp = _tp('LEVEL UP!', 10, _gold, 800);
  static final _hllName = _tp('HYPERLOGLOG', 11.5, Palette.muted, 600);
  static final _hllLevel = _tp('Lv 1', 12, Palette.muted, 700);
  static final _newTag = _tp('NEW', 8.5, Palette.background, 800);

  static TextPainter _tp(String s, double points, Color c, double weight) =>
      TextPainter(
        text: TextSpan(
          text: s,
          style: zalando(points, weight: weight, color: c, height: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  static double _ease(double x) => Curves.easeInOutCubic.transform(x);

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _totalMs;
    for (final (i, s) in _skills.indexed) {
      final y = i * _rowH;
      final appear = ((ms - s.startMs + 250) / 250).clamp(0.0, 1.0);
      if (appear == 0) continue;
      _row(canvas, i, s, y, ms - s.startMs, appear);
    }
    _hyperLogLog(canvas, 3 * _rowH + 14, ms - _newMs);
  }

  void _row(
    Canvas canvas,
    int i,
    _Skill s,
    double y,
    double local,
    double appear,
  ) {
    final cy = y + _rowH / 2;
    final alpha = appear;

    // Name, right-aligned against the bar.
    final name = _names[i];
    _paintText(canvas, name, Offset(_barX - 24 - name.width, cy), alpha);

    // Track.
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(_barX, cy - _barH / 2, _barW, _barH),
      const Radius.circular(_barH / 2),
    );
    canvas.drawRRect(
      track,
      Paint()..color = Colors.white.withValues(alpha: 0.08 * alpha),
    );

    // XP: fills to the top, holds a beat, then the next level's sliver.
    final up = local - _fillMs; // ms since the bar topped out
    final fill = (local / _fillMs).clamp(0.0, 1.0);
    final after = ((up - _holdMs) / _resetMs).clamp(0.0, 1.0);
    final leveled = up >= _holdMs;
    final xp = leveled
        ? s.rest * Curves.easeOut.transform(after)
        : s.from + (1 - s.from) * _ease(fill);
    if (xp > 0.001) {
      final w = math.max(_barH, _barW * xp);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(_barX, cy - _barH / 2, w, _barH),
        const Radius.circular(_barH / 2),
      );
      // Full, it burns gold for the beat.
      final full = up >= 0 && !leveled;
      canvas.drawRRect(
        r,
        Paint()
          ..shader = LinearGradient(
            colors: full
                ? const [_gold, Color(0xFFFFF1C2)]
                : const [_fillA, _fillB],
          ).createShader(r.outerRect)
          ..color = Colors.white.withValues(alpha: alpha),
      );
      // A highlight along the top, like a game's glossy bar.
      canvas.drawLine(
        Offset(_barX + _barH / 2, cy - _barH / 2 + 3.5),
        Offset(_barX + w - _barH / 2, cy - _barH / 2 + 3.5),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35 * alpha)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    // Segment ticks over the track.
    final ticks = Paint()
      ..color = Palette.background.withValues(alpha: 0.55 * alpha)
      ..strokeWidth = 2;
    for (var k = 1; k < 10; k++) {
      final x = _barX + _barW * k / 10;
      canvas.drawLine(
        Offset(x, cy - _barH / 2 + 2),
        Offset(x, cy + _barH / 2 - 2),
        ticks,
      );
    }

    // A ring flashes out from the track when it tops out.
    final flashT = up / 450;
    if (flashT > 0 && flashT < 1) {
      final a = 1 - flashT;
      canvas.drawRRect(
        track.inflate(2 + 10 * Curves.easeOut.transform(flashT)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = _gold.withValues(alpha: 0.7 * a),
      );
    }

    // Level number: pops (by scale, never font size) and glows gold.
    final lvX = _barX + _barW + 26;
    final lv = _levels[i * 2 + (leveled ? 1 : 0)];
    final pop = leveled ? math.sin(after * math.pi) : 0.0;
    canvas.save();
    canvas.translate(lvX, cy);
    canvas.scale(1 + 0.22 * pop);
    _paintText(canvas, lv, Offset.zero, alpha);
    final goldA = leveled ? 1 - (up - _holdMs - 300) / 700 : 0.0;
    if (goldA > 0) {
      _paintText(canvas, _levelsGold[i], Offset.zero, goldA.clamp(0.0, 1.0));
    }
    canvas.restore();

    // "LEVEL UP!" pops up beside the level, drifts up and fades.
    final upT = (up - _holdMs) / 1000;
    if (upT > 0 && upT < 1) {
      final a = upT < 0.15 ? upT / 0.15 : 1 - math.pow((upT - 0.15) / 0.85, 2);
      final s0 = 0.6 + 0.4 * Curves.easeOutBack.transform(math.min(1, upT * 4));
      canvas.save();
      canvas.translate(
        lvX + lv.width + 36,
        cy - 14 * Curves.easeOut.transform(upT),
      );
      canvas.scale(s0);
      _paintText(canvas, _levelUp, Offset.zero, a.toDouble());
      canvas.restore();
    }

    // Sparkles burst from the end of the bar.
    final spT = up / 800;
    if (spT > 0 && spT < 1) {
      final rnd = math.Random(17 + i);
      final origin = Offset(_barX + _barW - _barH / 2, cy);
      final e = Curves.easeOutCubic.transform(spT);
      final fade = 1 - spT * spT;
      for (var k = 0; k < 12; k++) {
        final a = k / 12 * 2 * math.pi + rnd.nextDouble() * 0.4;
        final d = 22 + 30 * rnd.nextDouble();
        // Flattened, so the burst stays inside its own row.
        final p =
            origin + Offset(math.cos(a) * d * 1.3, math.sin(a) * d * 0.6) * e;
        final r = (5 + 5 * rnd.nextDouble()) * (1 - 0.6 * spT);
        _sparkle(
          canvas,
          p,
          r,
          (k.isEven ? _gold : Colors.white).withValues(alpha: fade),
        );
      }
    }
  }

  void _hyperLogLog(Canvas canvas, double y, double local) {
    if (local <= 0) return;
    final a = (local / 400).clamp(0.0, 1.0);
    final slide = (1 - Curves.easeOutCubic.transform(a)) * 14;
    final cy = y + _rowH / 2 + slide;
    _paintText(canvas, _hllName, Offset(_barX - 24 - _hllName.width, cy), a);
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(_barX, cy - _barH / 2, _barW, _barH),
      const Radius.circular(_barH / 2),
    );
    canvas.drawRRect(
      track,
      Paint()..color = Colors.white.withValues(alpha: 0.06 * a),
    );
    final xp =
        0.06 * Curves.easeOut.transform(((local - 300) / 500).clamp(0, 1));
    if (xp > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            _barX,
            cy - _barH / 2,
            math.max(_barH, _barW * xp),
            _barH,
          ),
          const Radius.circular(_barH / 2),
        ),
        Paint()..color = Palette.muted.withValues(alpha: 0.8 * a),
      );
    }
    final lvX = _barX + _barW + 26;
    _paintText(canvas, _hllLevel, Offset(lvX, cy), a);

    // A "NEW" tag pops on after the label, the way games flag a fresh skill.
    final tagT = ((local - 450) / 350).clamp(0.0, 1.0);
    if (tagT > 0) {
      final s = Curves.easeOutBack.transform(tagT);
      final c = Offset(lvX + _hllLevel.width + 22 + _newTag.width / 2 + 8, cy);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(s);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: _newTag.width + 16,
            height: _newTag.height + 8,
          ),
          const Radius.circular(6),
        ),
        Paint()..color = Palette.warn.withValues(alpha: tagT),
      );
      _paintText(canvas, _newTag, Offset(-_newTag.width / 2, 0), tagT);
      canvas.restore();
    }
  }

  // A four-point star.
  static void _sparkle(Canvas canvas, Offset c, double r, Color color) {
    final w = r * 0.28;
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + w, c.dy - w, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + w, c.dy + w, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - w, c.dy + w, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - w, c.dy - w, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  // Paints [tp] vertically centered on [at].dy, with an opacity.
  static void _paintText(Canvas canvas, TextPainter tp, Offset at, double a) {
    if (a <= 0) return;
    final o = Offset(at.dx, at.dy - tp.height / 2);
    if (a >= 1) {
      tp.paint(canvas, o);
      return;
    }
    // One small layer per label while it fades; labels are few.
    canvas.saveLayer(
      Rect.fromLTWH(o.dx - 2, o.dy - 2, tp.width + 4, tp.height + 4),
      Paint()..color = Colors.white.withValues(alpha: a),
    );
    tp.paint(canvas, o);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SheetPainter old) => false;
}
