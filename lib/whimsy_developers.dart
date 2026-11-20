import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// "A lot more developers": one person stands up at the front, tagged
/// "Flutter developer". Then the room fills: 10, 100, then a crowd of about
/// a thousand rising row by row back to the horizon, the far rows just dots.
/// Tags pop up over a few of them, and none of the new ones say Flutter:
/// designer, founder, PM, student... Pairs with the app icons on the slide
/// before. Runs once when the slide appears and settles in about four seconds.
class DevelopersSlide extends StatefulWidget {
  const DevelopersSlide(this.text, {super.key});
  final String text;

  @override
  State<DevelopersSlide> createState() => _DevelopersSlideState();
}

/// The crowd grows 1, 10, 100, everyone; each count reached at its time (ms)
/// after growing for [_grow] ms.
const _stages = [(1, 500), (10, 1300), (100, 2100)];
const _finalAt = 3000;
const _grow = 550;
const _rise = 520; // ms for one person to stand up
const _tagsFrom = 2300; // ms; the seed's tag comes first, at its own time
const _tagEvery = 120; // ms between the other tags
const _tagPop = 380;
const _total = _tagsFrom + 10 * _tagEvery + _tagPop + 100;

class _DevelopersSlideState extends State<DevelopersSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _total),
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
      IgnorePointer(child: CustomPaint(painter: _CrowdPainter(_clock))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 160),
        child: Center(
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: headline(50),
          ),
        ),
      ),
    ],
  );
}

class _Person {
  _Person(this.at, this.h, this.skin, this.shirt, this.hair, this.born);
  final Offset at; // middle of the shoulders' bottom edge
  final double h; // scale: about 0.8h tall above [at]
  final Color skin, shirt;
  final Color? hair;
  double born; // ms when they start to stand
}

/// Perspective rows: a ground plane seen from the front, horizon at y=250.
/// Back to front, so painting in order overlaps correctly.
final List<_Person> _crowd = _layout();

/// Index into [_crowd] of the first person, front and center.
late int _seedIndex;

/// Tags: who calls themselves what, near where on screen, and when (ms).
final List<(int person, String label, bool flutter, double at)> _tags =
    _tagLayout();

List<_Person> _layout() {
  final rnd = math.Random(53);
  final people = <_Person>[];
  final rows = <List<_Person>>[];
  var z = 1.0;
  for (var r = 0; z <= 10.01; r++, z *= 1.15) {
    final h = 150 / z;
    final y = 250 + 860 / z;
    final step = 0.8 * h;
    final row = <_Person>[];
    final offset = r.isOdd ? step / 2 : 0.0;
    for (
      var x = 960.0 + offset - step * ((960 + step) / step).ceil();
      x < 1920 + step;
      x += step
    ) {
      row.add(
        _Person(
          Offset(
            x + (rnd.nextDouble() - 0.5) * step * 0.35,
            y + (rnd.nextDouble() - 0.5) * h * 0.08,
          ),
          h * (0.9 + rnd.nextDouble() * 0.2),
          _skins[rnd.nextInt(_skins.length)],
          _shirts[rnd.nextInt(_shirts.length)],
          rnd.nextDouble() < 0.78 ? _hairs[rnd.nextInt(_hairs.length)] : null,
          0,
        ),
      );
    }
    rows.add(row);
  }
  for (final row in rows.reversed) {
    people.addAll(row);
  }
  // The seed: the front-row person nearest the center.
  final front = rows.first;
  var seed = front.first;
  for (final p in front) {
    if ((p.at.dx - 960).abs() < (seed.at.dx - 960).abs()) seed = p;
  }
  _seedIndex = people.indexOf(seed);
  // Rank by distance from the seed (rows count for more, so the crowd fills
  // outward along the front then back), jittered so the edge is ragged.
  final ranked = [
    for (final p in people)
      (
        p,
        p == seed
            ? -1.0
            : math.sqrt(
                    math.pow(p.at.dx - seed.at.dx, 2) +
                        math.pow((p.at.dy - seed.at.dy) * 2.2, 2),
                  ) +
                  rnd.nextDouble() * 140,
      ),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  for (final (rank, (p, _)) in ranked.indexed) {
    p.born = _bornAt(rank, people.length);
  }
  return people;
}

List<(int, String, bool, double)> _tagLayout() {
  final crowd = _crowd;
  int near(Offset head) {
    var best = 0;
    var bestD = double.infinity;
    for (final (i, p) in crowd.indexed) {
      final d = (_head(p) - head).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  const others = [
    ('designer', Offset(300, 905)),
    ('founder', Offset(1600, 920)),
    ('PM', Offset(640, 760)),
    ('student', Offset(1290, 775)),
    ('ops', Offset(150, 700)),
    ('data scientist', Offset(1740, 700)),
    ('teacher', Offset(420, 395)),
    ('sales', Offset(1500, 385)),
    ('support', Offset(960, 360)),
    ('doctor', Offset(990, 790)),
  ];
  return [
    (_seedIndex, 'Flutter developer', true, _stages.first.$2 + 150.0),
    for (final (i, (label, at)) in others.indexed)
      (near(at), label, false, _tagsFrom + i * _tagEvery.toDouble()),
  ];
}

Offset _head(_Person p) => p.at - Offset(0, p.h * 0.62);

/// When the visible count first exceeds [rank].
double _bornAt(int rank, int total) {
  if (rank == 0) return _stages.first.$2 - _grow * 0.6;
  final counts = [for (final s in _stages) s.$1.toDouble(), total.toDouble()];
  final ends = [for (final s in _stages) s.$2.toDouble(), _finalAt.toDouble()];
  for (var k = 1; k < counts.length; k++) {
    if (rank < counts[k]) {
      // count = from * (to/from)^e, e = easeOut(u); invert both.
      final e =
          math.log((rank + 1) / counts[k - 1]) /
          math.log(counts[k] / counts[k - 1]);
      final u = 1 - math.pow(1 - e.clamp(0.0, 1.0), 1 / 3);
      return ends[k] - _grow + u * _grow;
    }
  }
  return _finalAt.toDouble();
}

const _skins = [
  Color(0xFF8D5524),
  Color(0xFFA86B3C),
  Color(0xFFC68642),
  Color(0xFFD9A066),
  Color(0xFFE8BE8F),
  Color(0xFF6B3E1E),
];

const _shirts = [
  Color(0xFF27C4F5), // accent
  Color(0xFF4F7DF9),
  Color(0xFF7C5CF2),
  Color(0xFFE2559B),
  Color(0xFFF2545B),
  Color(0xFFFF8A3D),
  Color(0xFFFFB259), // warn
  Color(0xFF3CCB7F),
  Color(0xFF18B5A4),
  Color(0xFF8C9EB8), // muted
];

const _hairs = [
  Color(0xFF1B1410),
  Color(0xFF2E1F16),
  Color(0xFF4A3020),
  Color(0xFF111111),
  Color(0xFF7A7A80),
];

class _CrowdPainter extends CustomPainter {
  _CrowdPainter(this.clock) : super(repaint: clock);
  final Animation<double> clock;

  static final _labels = <String, TextPainter>{};

  @override
  void paint(Canvas canvas, Size size) {
    final ms = clock.value * _total;
    final body = Paint();
    final head = Paint();
    final hair = Paint();
    for (final p in _crowd) {
      final age = (ms - p.born) / _rise;
      if (age <= 0) continue;
      final t = age.clamp(0.0, 1.0);
      // Stand up from below with a little bounce; fade in quickly.
      final lift = (1 - _backOut(t)) * p.h * 0.5;
      final a = math.min(1.0, t * 3);
      // Far rows sink into the dark a little, like a room.
      final depth = (1 - (p.h - 15) / 135).clamp(0.0, 1.0);
      final dim = 1 - 0.45 * depth;
      _paintPerson(canvas, p, lift, a * dim, body, head, hair);
    }
    // Shade behind the headline so it reads over the crowd.
    if (ms > 1000) {
      final t = ((ms - 1000) / 1500).clamp(0.0, 1.0);
      _shade(canvas, Offset(size.width / 2, size.height / 2), 900, 0.3, t);
    }
    // And under the slide number and section tracker.
    if (ms > 1500) {
      final t = ((ms - 1500) / 800).clamp(0.0, 1.0);
      _shade(canvas, const Offset(42, 1026), 80, 1, t);
      _shade(canvas, const Offset(1725, 1026), 240, 0.35, t);
    }
    for (final (i, label, flutter, at) in _tags) {
      final age = (ms - at) / _tagPop;
      if (age <= 0) continue;
      _paintTag(canvas, _crowd[i], label, flutter, age.clamp(0.0, 1.0));
    }
  }

  static void _shade(Canvas c, Offset at, double r, double squash, double t) {
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(1, squash);
    c.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          r,
          [
            Palette.background.withValues(alpha: 0.95 * t),
            Palette.background.withValues(alpha: 0.88 * t),
            Palette.background.withValues(alpha: 0),
          ],
          [0, 0.55, 1],
        ),
    );
    c.restore();
  }

  static void _paintPerson(
    Canvas c,
    _Person p,
    double lift,
    double a,
    Paint body,
    Paint head,
    Paint hair,
  ) {
    final h = p.h;
    final base = p.at + Offset(0, lift);
    body.color = Color.lerp(
      Palette.background,
      p.shirt,
      0.85,
    )!.withValues(alpha: a);
    // Shoulders: a rounded-top block.
    c.drawRRect(
      RRect.fromLTRBAndCorners(
        base.dx - h * 0.3,
        base.dy - h * 0.42,
        base.dx + h * 0.3,
        base.dy + h * 0.4,
        topLeft: Radius.circular(h * 0.22),
        topRight: Radius.circular(h * 0.22),
      ),
      body,
    );
    final centre = base - Offset(0, h * 0.6);
    final r = h * 0.17;
    head.color = p.skin.withValues(alpha: a);
    c.drawCircle(centre, r, head);
    if (p.hair != null && h > 12) {
      hair.color = p.hair!.withValues(alpha: a);
      c.drawArc(
        Rect.fromCircle(center: centre, radius: r * 1.04),
        math.pi * 0.95,
        math.pi * 1.1,
        false,
        hair,
      );
    }
  }

  static void _paintTag(
    Canvas c,
    _Person p,
    String label,
    bool flutter,
    double t,
  ) {
    final tp = _labels.putIfAbsent(
      '$label$flutter',
      () => TextPainter(
        text: TextSpan(
          text: label,
          style: zalando(
            flutter ? 15 : 13,
            weight: 700,
            color: flutter ? Palette.background : Palette.text,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    final top = _head(p) - Offset(0, p.h * 0.17 + 14);
    final s = _backOut(t);
    final pad = flutter ? const Offset(16, 8) : const Offset(12, 6);
    final w = tp.width + pad.dx * 2, hh = tp.height + pad.dy * 2;
    c.save();
    c.translate(top.dx, top.dy);
    c.scale(s);
    final rect = Rect.fromLTWH(-w / 2, -hh - 8, w, hh);
    final fill = Paint()
      ..color = flutter ? Palette.accent : const Color(0xFF2A3342);
    c.drawRRect(
      RRect.fromRectAndRadius(
        rect.shift(const Offset(0, 3)),
        Radius.circular(hh / 2),
      ),
      Paint()..color = const Color(0x66000000),
    );
    c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(hh / 2)), fill);
    // A little pointer down to the head.
    c.drawPath(
      Path()
        ..moveTo(-7, -8.5)
        ..lineTo(7, -8.5)
        ..lineTo(0, 0)
        ..close(),
      fill,
    );
    tp.paint(c, Offset(-tp.width / 2, -hh - 8 + pad.dy));
    c.restore();
  }

  /// 0 to 1 with a small overshoot.
  static double _backOut(double t) {
    if (t >= 1) return 1;
    const k = 1.7;
    final x = t - 1;
    return 1 + (k + 1) * x * x * x + k * x * x;
  }

  @override
  bool shouldRepaint(_CrowdPainter old) => false;
}
