import 'dart:math' as math;
import 'dart:typed_data';
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
  late final _CrowdPainter _painter = _CrowdPainter(_clock);

  @override
  void dispose() {
    _clock.dispose();
    _painter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      IgnorePointer(child: CustomPaint(painter: _painter)),
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
  const _Person(this.at, this.h, this.skin, this.shirt, this.hair, this.born);
  final Offset at; // middle of the shoulders' bottom edge
  final double h; // scale: about 0.8h tall above [at]
  final Color skin, shirt;
  final Color? hair;
  final double born; // ms when they start to stand
}

/// The room, computed once: perspective rows of people on a ground plane seen
/// from the front (horizon at y=250), back to front so painting in order
/// overlaps correctly; which one is the seed; and the tags.
class _Crowd {
  _Crowd._(this.people, this.seed, this.tags);
  final List<_Person> people;
  final int seed; // index of the first person, front and center
  /// Who calls themselves what, and when (ms).
  final List<(int person, String label, bool flutter, double at)> tags;

  static final _Crowd instance = _build();

  static _Crowd _build() {
    final rnd = math.Random(53);
    final rows = <List<(Offset, double, Color, Color, Color?)>>[];
    var z = 1.0;
    for (var r = 0; z <= 10.01; r++, z *= 1.15) {
      final h = 150 / z;
      final y = 250 + 860 / z;
      final step = 0.8 * h;
      final row = <(Offset, double, Color, Color, Color?)>[];
      final offset = r.isOdd ? step / 2 : 0.0;
      for (
        var x = 960.0 + offset - step * ((960 + step) / step).ceil();
        x < 1920 + step;
        x += step
      ) {
        row.add((
          Offset(
            x + (rnd.nextDouble() - 0.5) * step * 0.35,
            y + (rnd.nextDouble() - 0.5) * h * 0.08,
          ),
          h * (0.9 + rnd.nextDouble() * 0.2),
          _skins[rnd.nextInt(_skins.length)],
          _shirts[rnd.nextInt(_shirts.length)],
          rnd.nextDouble() < 0.78 ? _hairs[rnd.nextInt(_hairs.length)] : null,
        ));
      }
      rows.add(row);
    }
    final raw = [for (final row in rows.reversed) ...row];
    // The seed: the front-row person nearest the center.
    final front = rows.first;
    var seed = front.first;
    for (final p in front) {
      if ((p.$1.dx - 960).abs() < (seed.$1.dx - 960).abs()) seed = p;
    }
    final seedIndex = raw.indexOf(seed);
    // Rank by distance from the seed (rows count for more, so the crowd fills
    // outward along the front then back), jittered so the edge is ragged.
    final ranked = [
      for (final (i, p) in raw.indexed)
        (
          i,
          i == seedIndex
              ? -1.0
              : math.sqrt(
                      math.pow(p.$1.dx - seed.$1.dx, 2) +
                          math.pow((p.$1.dy - seed.$1.dy) * 2.2, 2),
                    ) +
                    rnd.nextDouble() * 140,
        ),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final born = List.filled(raw.length, 0.0);
    for (final (rank, (i, _)) in ranked.indexed) {
      born[i] = _bornAt(rank, raw.length);
    }
    final people = [
      for (final (i, (at, h, skin, shirt, hair)) in raw.indexed)
        _Person(at, h, skin, shirt, hair, born[i]),
    ];

    int near(Offset head) {
      var best = 0;
      var bestD = double.infinity;
      for (final (i, p) in people.indexed) {
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
    return _Crowd._(people, seedIndex, [
      (seedIndex, 'Flutter developer', true, _stages.first.$2 + 150.0),
      for (final (i, (label, at)) in others.indexed)
        (near(at), label, false, _tagsFrom + i * _tagEvery.toDouble()),
    ]);
  }
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

/// Paints the whole crowd in one drawRawAtlas call: every body, then every
/// head, then every hair cap, each a tinted white sprite. Bodies never reach
/// the heads behind them, so the three passes overlap like painting each
/// person in turn. The sprites are drawn at a few sizes (like mipmaps) so the
/// far rows stay smooth; per frame only the transforms and colors change.
class _CrowdPainter extends CustomPainter {
  _CrowdPainter(this.clock) : super(repaint: clock) {
    final people = _Crowd.instance.people;
    final hairy = [
      for (final (i, p) in people.indexed)
        if (p.hair != null && p.h > 12) i,
    ];
    _hairy = hairy;
    final n = people.length * 2 + hairy.length;
    _xforms = Float32List(n * 4);
    _colors = Int32List(n);
    _rects = Float32List(n * 4);
    _atlas = _sprites();
    // Static: which sprite (part and size) each quad uses.
    var q = 0;
    void rect(int part, int level) {
      final r = _cells[level][part];
      _rects
        ..[q * 4] = r.left
        ..[q * 4 + 1] = r.top
        ..[q * 4 + 2] = r.right
        ..[q * 4 + 3] = r.bottom;
      q++;
    }

    _levels = [for (final p in people) _levelFor(p.h)];
    for (final l in _levels) {
      rect(0, l);
    }
    for (final l in _levels) {
      rect(1, l);
    }
    for (final i in hairy) {
      rect(2, _levels[i]);
    }
    // Each quad's opaque RGB; alpha is applied per frame.
    _rgb = Int32List(n);
    q = 0;
    for (final p in people) {
      _rgb[q++] = _opaque(Color.lerp(Palette.background, p.shirt, 0.85)!);
    }
    for (final p in people) {
      _rgb[q++] = _opaque(p.skin);
    }
    for (final i in hairy) {
      _rgb[q++] = _opaque(people[i].hair!);
    }
  }

  final Animation<double> clock;

  late final List<int> _hairy;
  late final List<int> _levels;
  late final Float32List _xforms, _rects;
  late final Int32List _colors, _rgb;
  late final ui.Image _atlas;
  final _atlasPaint = Paint()..filterQuality = FilterQuality.medium;
  final _shadePaint = Paint()
    ..shader = ui.Gradient.radial(
      Offset.zero,
      900,
      [
        Palette.background.withValues(alpha: 0.95),
        Palette.background.withValues(alpha: 0.88),
        Palette.background.withValues(alpha: 0),
      ],
      [0, 0.55, 1],
    );
  final _cornerPaint = Paint()
    ..shader = ui.Gradient.radial(
      Offset.zero,
      900,
      [
        Palette.background.withValues(alpha: 0.97),
        Palette.background.withValues(alpha: 0.9),
        Palette.background.withValues(alpha: 0),
      ],
      [0, 0.6, 1],
    );
  final _labels = <String, TextPainter>{};

  void dispose() {
    _atlas.dispose();
    for (final tp in _labels.values) {
      tp.dispose();
    }
  }

  static int _opaque(Color c) => c.toARGB32() & 0xFFFFFF;

  /// Sprite sizes: the reference h each level is drawn at. A person uses the
  /// smallest level at least their size, so sprites only shrink, by <= 2x.
  static const _sizes = [200.0, 100.0, 50.0, 25.0, 12.5];
  static const _pad = 2.0; // atlas px around each sprite

  /// Each part's bounds in units of h, relative to the person's base point.
  static const _bounds = [
    Rect.fromLTRB(-0.3, -0.42, 0.3, 0.4), // body
    Rect.fromLTRB(-0.17, -0.77, 0.17, -0.43), // head
    Rect.fromLTRB(-0.1768, -0.7768, 0.1768, -0.4232), // hair cap
  ];

  /// Atlas source rects, [level][part], including padding.
  static final List<List<Rect>> _cells = () {
    var y = 0.0;
    return [
      for (final s in _sizes)
        () {
          var x = 0.0;
          final row = <Rect>[];
          for (final b in _bounds) {
            final r = Rect.fromLTWH(
              x,
              y,
              b.width * s + 2 * _pad,
              b.height * s + 2 * _pad,
            );
            row.add(r);
            x = r.right.ceilToDouble() + 1;
          }
          y += (_bounds[0].height * s + 2 * _pad).ceilToDouble() + 1;
          return row;
        }(),
    ];
  }();

  static int _levelFor(double h) {
    var l = 0;
    while (l + 1 < _sizes.length && _sizes[l + 1] >= h) {
      l++;
    }
    return l;
  }

  static ui.Image _sprites() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final white = Paint()..color = const Color(0xFFFFFFFF);
    for (final (l, h) in _sizes.indexed) {
      for (final (part, b) in _bounds.indexed) {
        final cell = _cells[l][part];
        c.save();
        // Local point (lx, ly), in units of h, lands at this atlas pixel.
        c.translate(cell.left + _pad - b.left * h, cell.top + _pad - b.top * h);
        final centre = Offset(0, -h * 0.6);
        final r = h * 0.17;
        switch (part) {
          case 0:
            c.drawRRect(
              RRect.fromLTRBAndCorners(
                -h * 0.3,
                -h * 0.42,
                h * 0.3,
                h * 0.4,
                topLeft: Radius.circular(h * 0.22),
                topRight: Radius.circular(h * 0.22),
              ),
              white,
            );
          case 1:
            c.drawCircle(centre, r, white);
          case 2:
            c.drawArc(
              Rect.fromCircle(center: centre, radius: r * 1.04),
              math.pi * 0.95,
              math.pi * 1.1,
              false,
              white,
            );
        }
        c.restore();
      }
    }
    final pic = rec.endRecording();
    final image = pic.toImageSync(
      _cells.first.last.right.ceil() + 1, // the biggest level is the widest
      _cells.last.first.bottom.ceil() + 1,
    );
    pic.dispose();
    return image;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ms = clock.value * _total;
    final crowd = _Crowd.instance;
    final people = crowd.people;
    final n = people.length;
    final x = _xforms, col = _colors, rgb = _rgb;
    var hq = 2 * n; // next hair quad
    var hairIndex = 0;
    for (var i = 0; i < n; i++) {
      final p = people[i];
      final hasHair = hairIndex < _hairy.length && _hairy[hairIndex] == i;
      final age = (ms - p.born) / _rise;
      var alpha = 0;
      var s = 0.0, lift = 0.0;
      if (age > 0) {
        final t = age.clamp(0.0, 1.0);
        // Stand up from below with a little bounce; fade in quickly.
        lift = (1 - _backOut(t)) * p.h * 0.5;
        final a = math.min(1.0, t * 3);
        // Far rows sink into the dark a little, like a room.
        final depth = (1 - (p.h - 15) / 135).clamp(0.0, 1.0);
        alpha = (255 * a * (1 - 0.45 * depth)).round();
        s = p.h / _sizes[_levels[i]];
      }
      final bx = p.at.dx, by = p.at.dy + lift;
      void put(int q, int part) {
        final b = _bounds[part];
        x
          ..[q * 4] = s
          ..[q * 4 + 1] = 0
          ..[q * 4 + 2] = bx + b.left * p.h - s * _pad
          ..[q * 4 + 3] = by + b.top * p.h - s * _pad;
        col[q] = (alpha << 24) | rgb[q];
      }

      put(i, 0);
      put(n + i, 1);
      if (hasHair) {
        put(hq++, 2);
        hairIndex++;
      }
    }
    canvas.drawRawAtlas(
      _atlas,
      x,
      _rects,
      col,
      BlendMode.modulate,
      null,
      _atlasPaint,
    );
    // Shade behind the headline so it reads over the crowd.
    if (ms > 1000) {
      final t = ((ms - 1000) / 1500).clamp(0.0, 1.0);
      canvas
        ..save()
        ..translate(size.width / 2, size.height / 2)
        ..scale(1, 0.3);
      _shadePaint.color = Color.fromRGBO(0, 0, 0, t);
      canvas
        ..drawCircle(Offset.zero, 900, _shadePaint)
        ..restore();
    }
    // Darken the bottom corners, like a vignette, so the slide number and
    // section tracker read over the front row.
    if (ms > 1500) {
      _cornerPaint.color = Color.fromRGBO(
        0,
        0,
        0,
        ((ms - 1500) / 800).clamp(0.0, 1.0),
      );
      for (final (at, r) in [
        (Offset(0, size.height), 260.0),
        (Offset(size.width, size.height), 620.0),
      ]) {
        canvas
          ..save()
          ..translate(at.dx, at.dy)
          ..scale(r / 900, r / 900 * 0.32)
          ..drawCircle(Offset.zero, 900, _cornerPaint)
          ..restore();
      }
    }
    for (final (i, label, flutter, at) in crowd.tags) {
      final age = (ms - at) / _tagPop;
      if (age <= 0) continue;
      _paintTag(canvas, people[i], label, flutter, age.clamp(0.0, 1.0));
    }
  }

  void _paintTag(
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
