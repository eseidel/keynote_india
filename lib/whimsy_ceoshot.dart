import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// "This is how I work", over the real ceo app. Two other windows slide in
/// behind; the app drops onto the stack in perspective and settles with a
/// slow drift. A mic pill pops up in the corner and its waveform talks: the
/// words appear in the app's own command bar as they're spoken, and then
/// the app acts on them, the LGTM button on the first review pulsing as it
/// gets pressed. No mouse, no keyboard: he just talks to it. Plays once
/// when the slide appears and settles in about four seconds.
class CeoShotSlide extends StatefulWidget {
  const CeoShotSlide({super.key, required this.title, required this.image});
  final String title;
  final String image;

  @override
  State<CeoShotSlide> createState() => _CeoShotSlideState();
}

const _totalMs = 4200;
const _said = 'Put some whimsy on every slide of my FlutterCon India keynote.';

// The app window, in canvas pixels, before the tilt.
const _win = Rect.fromLTWH(440, 215, 1150, 723);

// Where the window sits inside the screenshot (the rest is its shadow).
// (The window's bottom edge is at 0.931 of the image height, so the visible
// height, 723, is 0.895 of the full image height.)
const _crop = (left: 0.035, top: 0.036, width: 0.93);

double _phase(double ms, double from, double to) =>
    ((ms - from) / (to - from)).clamp(0.0, 1.0);

class _CeoShotSlideState extends State<CeoShotSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  )..forward();

  final _words = TextPainter(
    text: TextSpan(
      text: _said,
      // About the app's own 11px UI text.
      style: zalando(4.2, weight: 450, color: const Color(0xFFE8E8EC)),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  /// Where each word of [_said] ends, so the dictation can land a whole
  /// word at a time.
  late final List<double> _wordEnds = [
    for (var i = 0; i <= _said.length; i++)
      if (i == _said.length || _said[i] == ' ')
        _words.getOffsetForCaret(TextPosition(offset: i), Rect.zero).dx,
  ];

  @override
  void dispose() {
    _clock.dispose();
    _words.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const fullW = 1150 / 0.93, fullH = fullW * 1338 / 2048;
    final window = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 60,
            offset: const Offset(0, 30),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: -_crop.left * fullW,
              top: -_crop.top * fullH,
              width: fullW,
              height: fullH,
              child: Image.asset(
                widget.image,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _AppPainter(_clock, _words, _wordEnds),
              ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 56,
          child: Text(
            widget.title,
            textAlign: TextAlign.center,
            style: headline(32),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _PanelsPainter(_clock))),
        Positioned.fromRect(
          rect: _win,
          child: AnimatedBuilder(
            animation: _clock,
            child: window,
            builder: (context, child) {
              final ms = _clock.value * _totalMs;
              // Drops in tipped back, then settles; a slow drift after.
              final p = _phase(ms, 200, 1150);
              final s = math.max(0.0, ms - 1150) / 1000;
              final wobble = ms < 1150
                  ? 0.0
                  : 0.03 * math.exp(-s * 5) * math.sin(s * 14);
              final fall = 1 - Curves.easeOutCubic.transform(p);
              final drift = Curves.easeInOut.transform(_phase(ms, 1150, 4200));
              final m = Matrix4.identity()
                ..setEntry(3, 2, 0.0007)
                ..translateByDouble(0, 80 * fall, 0, 1)
                ..rotateX(0.04 + 0.35 * fall + wobble)
                ..rotateY(0.11 - 0.025 * drift)
                ..scaleByDouble(
                  1.05 * fall + (1 - fall) * (0.985 + 0.015 * drift),
                  1.05 * fall + (1 - fall) * (0.985 + 0.015 * drift),
                  1,
                  1,
                );
              final o = _phase(ms, 200, 500);
              final tilted = Transform(
                transform: m,
                alignment: Alignment.center,
                child: child,
              );
              return o < 1 ? Opacity(opacity: o, child: tilted) : tilted;
            },
          ),
        ),
        Positioned(
          left: 150,
          top: 860,
          width: 400,
          height: 130,
          child: CustomPaint(painter: _MicPainter(_clock)),
        ),
      ],
    );
  }
}

/// Two other windows that slide in behind the app, as if it sits on a
/// busy desk: an agent log and a PR list, in skeleton.
class _PanelsPainter extends CustomPainter {
  _PanelsPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  static final _fill = Paint()..color = const Color(0xFF1A212C);
  static final _edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = Colors.white.withValues(alpha: 0.10);
  static final _line = Paint()..color = Colors.white.withValues(alpha: 0.10);

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _totalMs;
    for (final (i, (rect, angle, from)) in [
      (const Rect.fromLTWH(250, 250, 700, 560), -0.05, -900.0),
      (const Rect.fromLTWH(1180, 175, 620, 480), 0.04, 900.0),
    ].indexed) {
      final p = Curves.easeOutCubic.transform(
        _phase(ms, i * 120.0, 700 + i * 120.0),
      );
      if (p <= 0) continue;
      canvas.save();
      canvas.translate(rect.center.dx + (1 - p) * from, rect.center.dy);
      canvas.rotate(angle);
      final r = Rect.fromCenter(
        center: Offset.zero,
        width: rect.width,
        height: rect.height,
      );
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(14));
      canvas.drawRRect(rr, _fill);
      canvas.drawRRect(rr, _edge);
      // Traffic lights and skeleton rows.
      for (var k = 0; k < 3; k++) {
        canvas.drawCircle(
          r.topLeft + Offset(22.0 + k * 18, 20),
          5,
          Paint()
            ..color = const [
              Color(0xFFFF5F57),
              Color(0xFFFEBC2E),
              Color(0xFF28C840),
            ][k].withValues(alpha: 0.6),
        );
      }
      final rnd = math.Random(7 + i);
      for (var y = r.top + 56; y < r.bottom - 24; y += 30) {
        final w = (0.35 + 0.55 * rnd.nextDouble()) * (r.width - 60);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(r.left + 30, y, w, 10),
            const Radius.circular(5),
          ),
          _line,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PanelsPainter old) => old.t != t;
}

/// Drawn over the screenshot, in the window's own coordinates: the spoken
/// words landing in the command bar, then LGTM getting pressed.
class _AppPainter extends CustomPainter {
  _AppPainter(this.t, this.words, this.wordEnds) : super(repaint: t);
  final Animation<double> t;
  final TextPainter words;
  final List<double> wordEnds;

  // In fractions of the window, measured off ceo_shot.png: the command bar,
  // where its placeholder text starts (after the ⌘ glyph), and the #325
  // LGTM button.
  static const _field = Rect.fromLTRB(0.0699, 0.1607, 0.8925, 0.2018);
  static const _textLeft = 0.0994;
  static const _lgtm = Rect.fromLTRB(0.7333, 0.5318, 0.7909, 0.5643);

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _totalMs;
    final typed = _phase(ms, 1350, 3250);
    if (typed > 0) {
      final f = Rect.fromLTRB(
        _field.left * size.width,
        _field.top * size.height,
        _field.right * size.width,
        _field.bottom * size.height,
      );
      final rr = RRect.fromRectAndRadius(f, const Radius.circular(5));
      final x = _textLeft * size.width;
      // The bar, focused: the placeholder (after the ⌘ glyph, which stays)
      // gives way to what he's saying.
      canvas.drawRect(
        Rect.fromLTRB(x - 3, f.top + 3, f.right - 3, f.bottom - 3),
        Paint()..color = const Color(0xFF1B1B1F),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Palette.accent.withValues(alpha: 0.85),
      );
      final y = f.center.dy - words.height / 2;
      // Words arrive whole, one at a time, like dictation.
      final n = (Curves.easeInOut.transform(typed) * wordEnds.length).ceil();
      final shown = n == 0 ? 0.0 : wordEnds[n - 1];
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(x, f.top, x + shown, f.bottom));
      words.paint(canvas, Offset(x, y));
      canvas.restore();
      // A blinking caret while it listens.
      final caretOn = typed < 1 || ((ms - 3250) / 400).floor().isEven;
      if (ms < 3900 && caretOn) {
        canvas.drawRect(
          Rect.fromLTWH(x + shown + 2, y + 2, 2, words.height - 4),
          Paint()..color = Palette.accent,
        );
      }
    }
    // Then it acts: LGTM gets pressed (the button dips and darkens), and a
    // ring goes out from it.
    final b = Rect.fromLTRB(
      _lgtm.left * size.width,
      _lgtm.top * size.height,
      _lgtm.right * size.width,
      _lgtm.bottom * size.height,
    );
    final dip = math.sin(math.pi * _phase(ms, 3400, 3650));
    if (dip > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(b, Radius.circular(b.height / 2)),
        Paint()..color = Colors.black.withValues(alpha: 0.4 * dip),
      );
    }
    final press = _phase(ms, 3500, 4100);
    if (press > 0 && press < 1) {
      final c = b.center;
      final e = Curves.easeOut.transform(press);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c,
            width: b.width + 50 * e,
            height: b.height + 30 * e,
          ),
          const Radius.circular(30),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Palette.accent.withValues(alpha: 0.9 * (1 - press)),
      );
    }
  }

  @override
  bool shouldRepaint(_AppPainter old) => old.t != t;
}

/// The mic pill: pops up, pulses and shows a live waveform while he talks,
/// then rests.
class _MicPainter extends CustomPainter {
  _MicPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  static const _bars = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _totalMs;
    final pop = _phase(ms, 900, 1250);
    if (pop <= 0) return;
    final scale = Curves.easeOutBack.transform(pop);
    canvas.save();
    const mic = Offset(70, 65);
    canvas.translate(mic.dx, mic.dy);
    canvas.scale(scale);
    canvas.translate(-mic.dx, -mic.dy);

    final pill = RRect.fromRectAndRadius(
      const Rect.fromLTWH(10, 15, 380, 100),
      const Radius.circular(50),
    );
    canvas.drawRRect(
      pill.shift(const Offset(0, 10)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawRRect(pill, Paint()..color = const Color(0xFF222B38));
    canvas.drawRRect(
      pill,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.14),
    );

    // How hard he's talking right now: on while the words arrive, with a
    // syllable-ish flutter.
    final talk = _phase(ms, 1250, 1450) * (1 - _phase(ms, 3150, 3450));
    // Rings off the mic while it's hearing him.
    for (var k = 0; k < 2; k++) {
      final r = ((ms - 1250 - k * 450) % 900) / 900;
      if (talk <= 0 || ms < 1250 + k * 450) continue;
      canvas.drawCircle(
        mic,
        36 + 22 * r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Palette.accent.withValues(alpha: 0.5 * (1 - r) * talk),
      );
    }
    canvas.drawCircle(mic, 36, Paint()..color = Palette.accent);
    // The mic glyph.
    final ink = Paint()
      ..color = Palette.background
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: mic - const Offset(0, 6),
          width: 16,
          height: 28,
        ),
        const Radius.circular(8),
      ),
      Paint()..color = Palette.background,
    );
    canvas.drawArc(
      Rect.fromCenter(center: mic - const Offset(0, 4), width: 30, height: 30),
      0.15,
      math.pi - 0.3,
      false,
      ink,
    );
    canvas.drawLine(mic + const Offset(0, 11), mic + const Offset(0, 19), ink);

    // Waveform.
    final s = ms / 1000;
    final bar = Paint()
      ..color = Palette.accent
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < _bars; i++) {
      final x = 132.0 + i * 11.5;
      final phase = i * 1.7;
      final syllable = 0.55 + 0.45 * math.sin(s * 9 + i * 0.25).abs();
      final live = (0.35 + 0.65 * math.sin(s * 13 + phase).abs()) * syllable;
      // At rest a low, gentle shape stays.
      final rest = 0.1 + 0.08 * math.sin(i * 0.9).abs();
      final h = 6 + 56 * (rest + (live - rest) * talk);
      canvas.drawLine(
        Offset(x, mic.dy - h / 2),
        Offset(x, mic.dy + h / 2),
        bar..color = Palette.accent.withValues(alpha: 0.55 + 0.45 * talk),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MicPainter old) => old.t != t;
}
