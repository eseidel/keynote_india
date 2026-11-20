import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// "The engineer's job changed": under the line, a split-flap nameplate
/// reads JOB TITLE: ENGINEER. Then it starts clattering. Every flap flips
/// through letters and odd glyphs, slowing down, as if it's hunting for the
/// new word, but it never finds one: the flaps run out to blank one by one,
/// and the last one lands on a "?". We don't have the words yet. Runs once,
/// settles in about three and a half seconds.
class JobTitleStatement extends StatefulWidget {
  const JobTitleStatement(this.text, {super.key, this.size = 50});
  final String text;
  final double size;

  @override
  State<JobTitleStatement> createState() => _JobTitleStatementState();
}

const _totalMs = 3800;
const _cells = 9;
const _start = 'ENGINEER '; // one char per cell
const _askCell = 4; // the one that ends on '?'
const _cellW = 84.0, _cellH = 116.0, _gap = 10.0;
const _boardW = _cells * _cellW + (_cells - 1) * _gap;

class _JobTitleStatementState extends State<JobTitleStatement>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  )..forward();

  final _Flaps _flaps = _Flaps();

  @override
  void dispose() {
    _clock.dispose();
    _flaps.dispose();
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
        const SizedBox(height: 64),
        Text(
          'JOB TITLE',
          style: zalando(
            12,
            weight: 600,
            color: Palette.muted,
          ).copyWith(letterSpacing: 6),
        ),
        const SizedBox(height: 16),
        CustomPaint(
          size: const Size(_boardW, _cellH),
          painter: _BoardPainter(_clock, _flaps),
        ),
      ],
    ),
  );
}

/// One cell's schedule: the characters it shows, in order, and when each
/// flip to the next one starts and how long it takes (ms).
class _Track {
  _Track(this.chars, this.starts, this.durs);
  final List<String> chars; // chars[0] shows first
  final List<double> starts; // starts[j]: flip from chars[j] to chars[j+1]
  final List<double> durs;
}

/// Glyph painters (laid out once) and every cell's flip schedule (seeded).
class _Flaps {
  _Flaps() {
    final style = headline(27);
    final accent = headline(27, color: Palette.accent);
    for (final ch in '$_alphabet?'.split('')) {
      glyphs[ch] = TextPainter(
        text: TextSpan(text: ch, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    ask = TextPainter(
      text: TextSpan(text: '?', style: accent),
      textDirection: TextDirection.ltr,
    )..layout();
    final m = glyphs['E']!.computeLineMetrics().first;
    baseline = m.baseline;
    capHeight = m.ascent * 0.72;

    final r = math.Random(50);
    // Blanks land from the outside in; the '?' cell flips longest.
    const landOrder = [0, 8, 1, 7, 2, 6, 3, 5, 4];
    for (var i = 0; i < _cells; i++) {
      final rank = landOrder.indexOf(i);
      final flips = i == _askCell ? 18 : 12 + rank + r.nextInt(3);
      final chars = <String>[_start[i]];
      for (var j = 0; j < flips - 1; j++) {
        String c;
        do {
          c = _alphabet[r.nextInt(_alphabet.length)];
        } while (c == chars.last);
        chars.add(c);
      }
      chars.add(i == _askCell ? '?' : ' ');
      final starts = <double>[];
      final durs = <double>[];
      var at = 520.0 + i * 45 + r.nextDouble() * 30;
      for (var j = 0; j < flips; j++) {
        // Quick clatter that slows down toward the end, like a real board
        // running out of momentum.
        final f = j / flips;
        final gap = 62 + 150 * f * f * f + (i == _askCell ? 90 * f * f : 0);
        final dur = math.min(gap * 0.92, 150.0);
        starts.add(at);
        durs.add(dur);
        at += gap;
      }
      tracks.add(_Track(chars, starts, durs));
    }
  }

  // Letters plus a few symbols: the board hunts but never spells anything.
  static const _alphabet = 'ABCDEFGHIJKLMNOPRSTUVWXYZ#&%*@';

  final glyphs = <String, TextPainter>{};
  late final TextPainter ask;
  late final double baseline, capHeight;
  final tracks = <_Track>[];

  double get endMs {
    final t = tracks[_askCell];
    return t.starts.last + t.durs.last;
  }

  void dispose() {
    for (final g in glyphs.values) {
      g.dispose();
    }
    ask.dispose();
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.t, this.f) : super(repaint: t);
  final Animation<double> t;
  final _Flaps f;

  static const _top = Color(0xFF1F2733);
  static const _bottom = Color(0xFF19202A);
  static const _radius = Radius.circular(9);

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _totalMs;
    // The housing behind the flaps.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-14, -12, size.width + 28, size.height + 24),
        const Radius.circular(16),
      ),
      Paint()..color = const Color(0xFF0A0D12),
    );
    for (var i = 0; i < _cells; i++) {
      _cell(canvas, Offset(i * (_cellW + _gap), 0), f.tracks[i], ms, i);
    }
  }

  void _cell(Canvas canvas, Offset o, _Track tr, double ms, int i) {
    // Which flip is under way (or last finished).
    var k = 0; // chars[k] is fully showing, or flipping away
    var p = 1.0; // progress of the flip from chars[k-1] to chars[k]
    for (var j = 0; j < tr.starts.length; j++) {
      if (ms < tr.starts[j]) break;
      k = j + 1;
      p = ((ms - tr.starts[j]) / tr.durs[j]).clamp(0.0, 1.0);
    }
    final now = tr.chars[k];
    final before = k > 0 ? tr.chars[k - 1] : now;
    final rect = o & const Size(_cellW, _cellH);
    final hinge = rect.center.dy;
    final topHalf = Rect.fromLTRB(rect.left, rect.top, rect.right, hinge);
    final botHalf = Rect.fromLTRB(rect.left, hinge, rect.right, rect.bottom);
    final isAsk = i == _askCell && k == tr.chars.length - 1;

    // Behind the flap: new char on top, old char below until the flap
    // passes halfway.
    _half(canvas, rect, topHalf, now, _top, isAsk);
    _half(canvas, rect, botHalf, p < 0.5 ? before : now, _bottom, isAsk);

    if (p < 1) {
      // The flap: the old top half folding down to edge-on, then the new
      // bottom half falling from edge-on to flat.
      final fold = p < 0.5
          ? math.cos(p * math.pi)
          : -math.cos(p * math.pi); // 1 -> 0, then 0 -> 1
      canvas.save();
      canvas.translate(0, hinge);
      canvas.scale(1, math.max(fold, 0.001));
      canvas.translate(0, -hinge);
      if (p < 0.5) {
        _half(canvas, rect, topHalf, before, _top, false);
      } else {
        _half(canvas, rect, botHalf, now, _bottom, isAsk);
      }
      // Shade it as it turns away from the light.
      canvas.drawRect(
        p < 0.5 ? topHalf : botHalf,
        Paint()..color = Colors.black.withValues(alpha: 0.45 * (1 - fold)),
      );
      canvas.restore();
    }

    // The hinge line and its pins.
    canvas.drawRect(
      Rect.fromLTRB(rect.left, hinge - 1.5, rect.right, hinge + 1.5),
      Paint()..color = const Color(0xFF07090C),
    );
    final pin = Paint()..color = const Color(0xFF3A4452);
    canvas.drawRect(Rect.fromLTWH(rect.left - 2, hinge - 5, 4, 10), pin);
    canvas.drawRect(Rect.fromLTWH(rect.right - 2, hinge - 5, 4, 10), pin);

    // A soft glow under the '?' as it lands.
    if (isAsk && ms >= f.endMs) {
      final glow = ((ms - f.endMs) / 700).clamp(0.0, 1.0);
      if (glow < 1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(4 + 6 * glow), _radius),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Palette.accent.withValues(alpha: 0.6 * (1 - glow)),
        );
      }
    }
  }

  /// One half of a cell: its card and the part of [ch] that falls in it.
  void _half(
    Canvas canvas,
    Rect cell,
    Rect half,
    String ch,
    Color color,
    bool isAsk,
  ) {
    final top = half.top == cell.top;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        half,
        topLeft: top ? _radius : Radius.zero,
        topRight: top ? _radius : Radius.zero,
        bottomLeft: top ? Radius.zero : _radius,
        bottomRight: top ? Radius.zero : _radius,
      ),
      Paint()..color = color,
    );
    if (ch == ' ') return;
    final g = isAsk ? f.ask : f.glyphs[ch]!;
    canvas.save();
    canvas.clipRect(half);
    // Caps centered on the hinge.
    final y = cell.center.dy + f.capHeight / 2 - f.baseline;
    g.paint(canvas, Offset(cell.center.dx - g.width / 2, y));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BoardPainter old) => old.t != t || old.f != f;
}
