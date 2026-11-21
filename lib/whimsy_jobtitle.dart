import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// "The engineer's job changed": under the line, a split-flap nameplate
/// reads JOB TITLE: ENGINEER. Then it starts clattering, hunting for the
/// new word, and tries one on: WIZARD. It holds a beat, then clatters on
/// to the next: ARCHITECT, CONDUCTOR, INVENTOR... and round again for as
/// long as the slide is up. We don't have the word yet, but they're all
/// good ones.
class JobTitleStatement extends StatefulWidget {
  const JobTitleStatement(this.text, {super.key, this.size = 50});
  final String text;
  final double size;

  @override
  State<JobTitleStatement> createState() => _JobTitleStatementState();
}

const _cells = 9;

/// The board's words, in order. After the last it goes round again from
/// the second (the first is where it starts, and the last repeats the
/// second, so the wrap is seamless).
const _words = [
  'ENGINEER',
  'WIZARD',
  'ARCHITECT',
  'CONDUCTOR',
  'INVENTOR',
  'MAESTRO',
  'CAPTAIN',
  'CREATOR',
  'WIZARD',
];
const _introMs = 900.0; // ENGINEER, before the first clatter
const _clatterMs = 850.0; // from a leg's start until every cell has landed
const _holdMs = 800.0; // each word, on show
const _cellW = 84.0, _cellH = 116.0, _gap = 10.0;
const _boardW = _cells * _cellW + (_cells - 1) * _gap;

class _JobTitleStatementState extends State<JobTitleStatement>
    with SingleTickerProviderStateMixin {
  final _Flaps _flaps = _Flaps();
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _flaps.totalMs.ceil()),
  );
  Timer? _hold;
  int _word = 1; // the word the board is heading for

  @override
  void initState() {
    super.initState();
    _go();
  }

  /// Clatter to [_word], hold it, then on to the next.
  void _go() {
    _clock.animateTo(_flaps.landedAt(_word) / _flaps.totalMs).then((_) {
      if (!mounted) return;
      _hold = Timer(Duration(milliseconds: _holdMs.round()), () {
        if (!mounted) return;
        if (_word == _words.length - 1) {
          // The last word repeats the second: jump back to it, unseen.
          _word = 1;
          _clock.value = _flaps.landedAt(1) / _flaps.totalMs;
        }
        _word++;
        _go();
      });
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    _clock.dispose();
    _flaps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 160),
    child: Center(
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
            painter: _BoardPainter(_clock, _flaps, _flaps.totalMs),
          ),
        ],
      ),
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
    for (final ch in _alphabet.split('')) {
      glyphs[ch] = TextPainter(
        text: TextSpan(text: ch, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    final m = glyphs['E']!.computeLineMetrics().first;
    baseline = m.baseline;
    capHeight = m.ascent * 0.72;

    final r = math.Random(50);
    String cellOf(String word, int i) {
      final left = (_cells - word.length) ~/ 2;
      final j = i - left;
      return j >= 0 && j < word.length ? word[j] : ' ';
    }

    final chars = [
      for (var i = 0; i < _cells; i++) [cellOf(_words.first, i)],
    ];
    final starts = [for (var i = 0; i < _cells; i++) <double>[]];
    final durs = [for (var i = 0; i < _cells; i++) <double>[]];
    var legStart = _introMs;
    for (var w = 1; w < _words.length; w++) {
      var landed = legStart;
      for (var i = 0; i < _cells; i++) {
        final target = cellOf(_words[w], i);
        // A cell with nothing to change still clatters a little, now and
        // then, like a real board settling; most just flip their way there.
        final flips = target == chars[i].last && r.nextBool()
            ? 0
            : 5 + r.nextInt(4);
        if (flips == 0) continue;
        for (var j = 0; j < flips - 1; j++) {
          String c;
          do {
            c = _alphabet[r.nextInt(_alphabet.length)];
          } while (c == chars[i].last || c == target);
          chars[i].add(c);
        }
        chars[i].add(target);
        // Quick clatter that slows toward the end, landing left to right.
        final gaps = [
          for (var j = 0; j < flips; j++) 60 + 140 * math.pow(j / flips, 3),
        ];
        final start = legStart + r.nextDouble() * 60;
        final land = legStart + 420 + i * 40 + r.nextDouble() * 30;
        final raw = gaps.fold(0.0, (a, b) => a + b);
        final stretch = (land - start) / raw;
        var at = start;
        for (final g in gaps) {
          starts[i].add(at);
          durs[i].add(math.min(g * stretch * 0.92, 150.0));
          at += g * stretch;
        }
        landed = math.max(landed, at);
      }
      _landed.add(landed);
      legStart += _clatterMs + _holdMs;
    }
    totalMs = _landed.last;
    for (var i = 0; i < _cells; i++) {
      tracks.add(_Track(chars[i], starts[i], durs[i]));
    }
  }

  // Letters plus a few symbols: the board hunts but never spells anything.
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ#&%*@';

  final glyphs = <String, TextPainter>{};
  late final double baseline, capHeight;
  final tracks = <_Track>[];
  final _landed = <double>[_introMs]; // when each word is fully showing
  late final double totalMs;

  /// When word [w] has fully landed (ms).
  double landedAt(int w) => _landed[w];

  void dispose() {
    for (final g in glyphs.values) {
      g.dispose();
    }
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.t, this.f, this.totalMs) : super(repaint: t);
  final Animation<double> t;
  final _Flaps f;
  final double totalMs;

  static const _top = Color(0xFF1F2733);
  static const _bottom = Color(0xFF19202A);
  static const _radius = Radius.circular(9);

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * totalMs;
    // The housing behind the flaps.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-14, -12, size.width + 28, size.height + 24),
        const Radius.circular(16),
      ),
      Paint()..color = const Color(0xFF0A0D12),
    );
    for (var i = 0; i < _cells; i++) {
      _cell(canvas, Offset(i * (_cellW + _gap), 0), f.tracks[i], ms);
    }
  }

  void _cell(Canvas canvas, Offset o, _Track tr, double ms) {
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

    // Behind the flap: new char on top, old char below until the flap
    // passes halfway.
    _half(canvas, rect, topHalf, now, _top);
    _half(canvas, rect, botHalf, p < 0.5 ? before : now, _bottom);

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
        _half(canvas, rect, topHalf, before, _top);
      } else {
        _half(canvas, rect, botHalf, now, _bottom);
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
  }

  /// One half of a cell: its card and the part of [ch] that falls in it.
  void _half(Canvas canvas, Rect cell, Rect half, String ch, Color color) {
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
    final g = f.glyphs[ch]!;
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
