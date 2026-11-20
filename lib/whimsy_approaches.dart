import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// The three approaches to cross-platform (ProsCons slides), each with a
/// small diagram under the text that plays once when the slide appears:
///
/// - [ShareLogicDiagram]: two native UIs and a shared core. The core lights
///   up and sends the same update to both, then the seams between core and
///   UIs (the API you now own) start to flicker.
/// - [PuppetDiagram]: your code is a puppeteer's control bar, strings down to
///   three platforms' native switches. One pull, and each switch does its
///   own thing; the third bounces back off, and you can't check why from
///   here.
/// - [CarryStackDiagram]: your whole stack, copied into a phone, a tablet, a
///   laptop and a TV, landing identical in each; then each gets a check
///   (test anywhere), and the stack stays with you (you carry it).
///
/// Each settles in about five seconds on a finished diagram.
class Approach extends StatelessWidget {
  const Approach(this.text, {super.key, required this.diagram});

  /// The ProsCons slide.
  final Widget text;
  final Widget diagram;

  static const _band = 250.0; // diagram height
  static const _bottom = 80.0; // clear of the slide number and tracker

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(bottom: _bottom + _band + 10, child: text),
      Positioned(
        left: 180,
        right: 180,
        bottom: _bottom,
        height: _band,
        child: IgnorePointer(child: diagram),
      ),
    ],
  );
}

double _span(double t, double begin, double end, [Curve? curve]) {
  final f = ((t - begin) / (end - begin)).clamp(0.0, 1.0);
  return curve == null ? f : curve.transform(f);
}

/// Laid-out labels, by text and style. They never change except for alpha,
/// so each is laid out once and faded with a small layer only while fading.
final _labels = <(String, TextStyle), TextPainter>{};

void _label(
  Canvas canvas,
  String text,
  Offset center,
  TextStyle style, {
  double alpha = 1,
}) {
  if (alpha <= 0) return;
  final tp = _labels.putIfAbsent(
    (text, style),
    () => TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(),
  );
  final topLeft = center - Offset(tp.width / 2, tp.height / 2);
  if (alpha >= 1) {
    tp.paint(canvas, topLeft);
    return;
  }
  canvas.saveLayer(
    (topLeft & tp.size).inflate(2),
    Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
  );
  tp.paint(canvas, topLeft);
  canvas.restore();
}

TextStyle get _caption =>
    zalando(13, weight: 700, color: Palette.muted).copyWith(letterSpacing: 2);

const _panel = Color(0xFF161D27);

/// Runs [paint] once over [seconds] from when it appears.
class _Clocked extends StatefulWidget {
  const _Clocked({required this.seconds, required this.painter});
  final double seconds;
  final CustomPainter Function(Animation<double> seconds) painter;

  @override
  State<_Clocked> createState() => _ClockedState();
}

class _ClockedState extends State<_Clocked>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    upperBound: widget.seconds,
    duration: Duration(milliseconds: (widget.seconds * 1000).round()),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: widget.painter(_c), child: const SizedBox.expand());
}

// ---------------------------------------------------------------------------
// Share some logic

class ShareLogicDiagram extends StatelessWidget {
  const ShareLogicDiagram({super.key});

  @override
  Widget build(BuildContext context) =>
      _Clocked(seconds: 4.6, painter: _SharePainter.new);
}

class _SharePainter extends CustomPainter {
  _SharePainter(this.clock) : super(repaint: clock);
  final Animation<double> clock;

  static const _waves = [1.5, 2.0, 2.9]; // packets leave the core
  static const _travel = 0.6; // seconds core to UI
  static const _flicker = (2.6, 4.1); // the seams act up

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final cx = size.width / 2;
    const cy = 92.0;
    const coreW = 250.0, coreH = 150.0, cardW = 210.0, cardH = 170.0;
    const reach = 520.0; // core center to card center

    final coreIn = _span(t, 0, 0.5, Curves.easeOutBack);
    final cardsIn = _span(t, 0.25, 0.8, Curves.easeOutBack);
    final wire = _span(t, 0.8, 1.3, Curves.easeOut);
    final lit = _span(t, 1.3, 1.8, Curves.easeOut);

    for (final side in [-1.0, 1.0]) {
      final from = cx + side * coreW / 2;
      final to = cx + side * (reach - cardW / 2);
      final seam = (from + to) / 2;
      _wire(canvas, from, to, seam, cy, wire, t, side);
    }

    // Packets: the same update leaves the core for both UIs.
    for (final (w, start) in _waves.indexed) {
      for (final side in [-1.0, 1.0]) {
        final f = (t - start) / _travel;
        // The last wave hits the seams while they're flickering: the iOS side
        // gets through singed, the Android side gets stuck just short of the
        // seam and stays there.
        final late = w == _waves.length - 1;
        final blocked = late && side > 0;
        if (f <= 0 || (f >= 1 && !blocked)) continue;
        final from = cx + side * coreW / 2;
        final to = cx + side * (reach - cardW / 2);
        final stop = (from + to) / 2 - side * 28;
        final x = blocked
            ? math.min(from + (to - from) * f, stop)
            : from + (to - from) * f;
        final stuck = blocked && x >= stop;
        final burnt = late && (f > 0.5 || stuck);
        final color = burnt ? Palette.warn : Palette.accent;
        // It rattles against the seam, then gives up.
        final jitter = stuck
            ? math.sin(t * 80) * 4 * (1 - _span(t, start + _travel / 2, 4.3))
            : 0.0;
        canvas.drawCircle(
          Offset(x + jitter, cy),
          14,
          Paint()
            ..color = color.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
        canvas.drawCircle(Offset(x + jitter, cy), 8, Paint()..color = color);
      }
    }

    _core(canvas, Offset(cx, cy), Size(coreW, coreH), coreIn, lit);

    for (final (side, platform) in [(-1.0, 'iOS'), (1.0, 'Android')]) {
      final center = Offset(cx + side * reach, cy);
      // Flash the UI's button when a packet lands.
      var flash = 0.0;
      for (final (w, start) in _waves.indexed) {
        if (w == _waves.length - 1 && side > 0) continue; // never arrived
        final dt = t - start - _travel;
        if (dt >= 0 && dt < 0.45) flash = math.max(flash, 1 - dt / 0.45);
      }
      _card(
        canvas,
        center,
        const Size(cardW, cardH),
        cardsIn,
        flash,
        ios: platform == 'iOS',
      );
      _label(
        canvas,
        '$platform UI',
        center + const Offset(0, cardH / 2 + 30),
        _caption,
        alpha: cardsIn.clamp(0.0, 1.0),
      );
    }
    _label(
      canvas,
      'SHARED LOGIC',
      Offset(cx, cy + cardH / 2 + 30),
      // Quantized so the label cache holds at most 11 versions.
      _caption.copyWith(
        color: Color.lerp(
          Palette.muted,
          Palette.accent,
          (lit.clamp(0.0, 1.0) * 10).round() / 10,
        ),
      ),
      alpha: coreIn.clamp(0.0, 1.0),
    );
  }

  /// A wire from core to UI with a seam (the API) in the middle.
  void _wire(
    Canvas canvas,
    double from,
    double to,
    double seam,
    double cy,
    double drawn,
    double t,
    double side,
  ) {
    if (drawn <= 0) return;
    const gap = 14.0;
    final line = Paint()
      ..color = Palette.muted.withValues(alpha: 0.7)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final end = from + (to - from) * drawn;
    // Core half, then UI half, leaving the seam open.
    final seamNear = seam - side * gap / 2, seamFar = seam + side * gap / 2;
    final firstEnd = side > 0
        ? math.min(end, seamNear)
        : math.max(end, seamNear);
    canvas.drawLine(Offset(from, cy), Offset(firstEnd, cy), line);
    final pastSeam = side > 0 ? end > seamFar : end < seamFar;
    if (pastSeam) {
      canvas.drawLine(Offset(seamFar, cy), Offset(end, cy), line);
    }
    if (drawn < 1) return;

    // The seam: two plug ends facing each other. Calm, then flickering, then
    // steadily warning.
    final (f0, f1) = _flicker;
    var heat = 0.0;
    if (t >= f1) {
      heat = 1;
    } else if (t >= f0) {
      final frame = (t * 12).floor() + (side > 0 ? 7 : 0);
      final r = math.Random(frame);
      final progress = (t - f0) / (f1 - f0);
      heat = r.nextDouble() < 0.35 + 0.5 * progress ? 1 : 0.15;
      if (heat == 1 && r.nextDouble() < 0.5) {
        // Sparks.
        final spark = Paint()
          ..color = Palette.warn
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 3; i++) {
          final a = r.nextDouble() * 2 * math.pi;
          final d0 = 12 + r.nextDouble() * 6,
              d1 = d0 + 10 + r.nextDouble() * 14;
          canvas.drawLine(
            Offset(seam, cy) + Offset.fromDirection(a, d0),
            Offset(seam, cy) + Offset.fromDirection(a, d1),
            spark,
          );
        }
      }
    }
    final color = Color.lerp(Palette.muted, Palette.warn, heat)!;
    if (heat > 0.5) {
      canvas.drawCircle(
        Offset(seam, cy),
        26,
        Paint()
          ..color = Palette.warn.withValues(alpha: 0.35 * heat)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    final plug = Paint()..color = color;
    // While it flickers, the two ends rattle apart.
    final rattle = t >= f0 && t < f1
        ? math.Random((t * 15).floor() + (side > 0 ? 3 : 0)).nextDouble() * 6
        : 0.0;
    for (final s in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(seam + s * (gap / 2 + 5 + rattle), cy),
            width: 10,
            height: 30,
          ),
          const Radius.circular(3),
        ),
        plug,
      );
    }
    _label(
      canvas,
      'API',
      Offset(seam, cy + 40),
      _caption.copyWith(color: Palette.warn),
      alpha: t >= f0 ? heat.clamp(0.4, 1.0) : 0,
    );
  }

  void _core(Canvas canvas, Offset c, Size s, double k, double lit) {
    if (k <= 0) return;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(k);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: s.width, height: s.height),
      const Radius.circular(24),
    );
    if (lit > 0) {
      canvas.drawRRect(
        body.inflate(8),
        Paint()
          ..color = Palette.accent.withValues(alpha: 0.5 * lit)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36),
      );
    }
    canvas.drawRRect(body, Paint()..color = _panel);
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Color.lerp(Palette.muted, Palette.accent, lit)!,
    );
    // Code lines.
    const lines = [(0, 0.7), (1, 0.55), (1, 0.4), (0, 0.25), (0, 0.6)];
    final p = Paint()
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    var y = -s.height / 2 + 32;
    for (final (indent, w) in lines) {
      final x0 = -s.width / 2 + 34 + indent * 24.0;
      p.color =
          (indent == 0
                  ? Color.lerp(Palette.muted, Palette.accent, lit)!
                  : Palette.soft)
              .withValues(alpha: indent == 0 ? 0.9 : 0.5);
      canvas.drawLine(Offset(x0, y), Offset(x0 + (s.width - 80) * w, y), p);
      y += 22;
    }
    canvas.restore();
  }

  /// A small app screen, drawn the iOS way or the Android way.
  void _card(
    Canvas canvas,
    Offset c,
    Size s,
    double k,
    double flash, {
    required bool ios,
  }) {
    if (k <= 0) return;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(k);
    final r = Rect.fromCenter(
      center: Offset.zero,
      width: s.width,
      height: s.height,
    );
    final body = RRect.fromRectAndRadius(r, Radius.circular(ios ? 30 : 10));
    canvas.drawRRect(body, Paint()..color = _panel);
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Palette.soft.withValues(alpha: 0.6),
    );
    final ink = Paint()..color = Palette.soft.withValues(alpha: 0.45);
    if (ios) {
      // Large title, a grouped list, a pill button.
      canvas.drawRRect(
        RRect.fromLTRBR(
          r.left + 22,
          r.top + 22,
          r.left + 110,
          r.top + 36,
          const Radius.circular(7),
        ),
        Paint()..color = Palette.text.withValues(alpha: 0.8),
      );
      canvas.drawRRect(
        RRect.fromLTRBR(
          r.left + 18,
          r.top + 50,
          r.right - 18,
          r.top + 100,
          const Radius.circular(12),
        ),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.07),
      );
      for (final y in [r.top + 64, r.top + 86]) {
        canvas.drawLine(
          Offset(r.left + 32, y),
          Offset(r.right - 60, y),
          ink
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round,
        );
      }
    } else {
      // Filled top app bar, rows with leading circles, a squarer button.
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          r.left,
          r.top,
          r.right,
          r.top + 40,
          topLeft: const Radius.circular(10),
          topRight: const Radius.circular(10),
        ),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.10),
      );
      canvas.drawRRect(
        RRect.fromLTRBR(
          r.left + 18,
          r.top + 14,
          r.left + 100,
          r.top + 26,
          const Radius.circular(3),
        ),
        Paint()..color = Palette.text.withValues(alpha: 0.8),
      );
      for (final y in [r.top + 62, r.top + 88]) {
        canvas.drawCircle(Offset(r.left + 28, y), 8, ink);
        canvas.drawLine(
          Offset(r.left + 48, y),
          Offset(r.right - 50, y),
          ink
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    final button = Rect.fromLTRB(
      r.left + 22,
      r.bottom - 50,
      r.right - 22,
      r.bottom - 16,
    );
    final color = Color.lerp(
      Palette.accent.withValues(alpha: 0.75),
      const Color(0xFFFFFFFF),
      flash * 0.7,
    )!;
    if (flash > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(button.inflate(6), const Radius.circular(20)),
        Paint()
          ..color = Palette.accent.withValues(alpha: 0.6 * flash)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(button, Radius.circular(ios ? 17 : 6)),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SharePainter old) => old.clock != clock;
}

// ---------------------------------------------------------------------------
// Orchestrate native widgets

class PuppetDiagram extends StatelessWidget {
  const PuppetDiagram({super.key});

  @override
  Widget build(BuildContext context) =>
      _Clocked(seconds: 4.8, painter: _PuppetPainter.new);
}

enum _Os { ios, android, windows }

class _PuppetPainter extends CustomPainter {
  _PuppetPainter(this.clock) : super(repaint: clock);
  final Animation<double> clock;

  static const _end = 4.8;
  static const _pull = 1.5; // the bar jerks up

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final cx = size.width / 2;
    final calm = math.pow(1 - _span(t, 0, _end), 2).toDouble();
    final appear = _span(t, 0, 0.6, Curves.easeOut);

    // The control bar sways, then jerks up once.
    final lift =
        -22 * _span(t, _pull, _pull + 0.15, Curves.easeOut) +
        22 * _span(t, _pull + 0.35, _pull + 0.9, Curves.easeInOut);
    final barY = 26.0 + lift;
    final tilt = 0.07 * math.sin(t * 3.4) * calm;
    const barHalf = 360.0;
    Offset onBar(double u) => // u in -1..1 along the bar
        Offset(cx, barY) +
        Offset(math.cos(tilt), math.sin(tilt)) * (u * barHalf);

    const hangY = 150.0;
    const spread = 470.0;
    const oses = [
      (_Os.ios, 'iOS', -1.0, 0.0),
      (_Os.android, 'ANDROID', 0.0, 1.3),
      (_Os.windows, 'WINDOWS', 1.0, 2.6),
    ];
    final string = Paint()
      ..color = Palette.soft.withValues(alpha: 0.55 * appear)
      ..strokeWidth = 2;
    final widgets = <(Offset, _Os, String, double)>[];
    for (final (os, name, u, phase) in oses) {
      // Each dangles in its own way; Windows swings widest.
      final amp = os == _Os.windows ? 26.0 : 12.0;
      final freq = os == _Os.ios ? 2.6 : (os == _Os.android ? 3.1 : 2.2);
      final sway = amp * math.sin(t * freq + phase) * calm;
      final pos = Offset(cx + u * spread + sway, hangY + lift * 0.8);
      final attach = onBar(u * 0.92);
      canvas.drawLine(attach, pos - const Offset(0, 34), string);
      // A second string to each widget's far end, like a marionette.
      canvas.drawLine(
        onBar(u * 0.92 + 0.08),
        pos + const Offset(44, -30),
        string,
      );
      widgets.add((pos, os, name, sway / 300));
    }

    // Bar on top of the strings.
    final bar = Paint()
      ..color = Palette.accent.withValues(alpha: appear)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(onBar(-1), onBar(1), bar);
    canvas.drawLine(
      onBar(0) - const Offset(0, 22),
      onBar(0) + const Offset(0, 22),
      bar,
    );
    _label(
      canvas,
      'YOUR CODE',
      onBar(1) + const Offset(140, 0),
      _caption.copyWith(color: Palette.accent),
      alpha: appear,
    );

    for (final (pos, os, name, angle) in widgets) {
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle);
      final k = appear;
      switch (os) {
        case _Os.ios:
          _iosSwitch(
            canvas,
            _span(t, _pull + 0.1, _pull + 0.45, Curves.easeInOut),
            k,
          );
        case _Os.android:
          _androidSwitch(canvas, t - _pull - 0.2, k);
        case _Os.windows:
          _windowsSwitch(canvas, t, k);
      }
      canvas.restore();
      _label(canvas, name, Offset(pos.dx, hangY + 66), _caption, alpha: appear);
    }
  }

  void _iosSwitch(Canvas canvas, double on, double k) {
    const w = 112.0, h = 64.0;
    final track = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      const Radius.circular(h / 2),
    );
    canvas.drawRRect(
      track,
      Paint()
        ..color = Color.lerp(
          const Color(0xFF3A3A3F),
          const Color(0xFF34C759),
          on,
        )!.withValues(alpha: k),
    );
    final x = -w / 2 + h / 2 + (w - h) * on;
    canvas.drawCircle(
      Offset(x, 3),
      27,
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: 0.3 * k)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      Offset(x, 0),
      27,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: k),
    );
  }

  /// Material: the thumb grows as it travels, with an ink ripple.
  void _androidSwitch(Canvas canvas, double since, double k) {
    const w = 108.0, h = 60.0;
    final on = _span(since, 0, 0.2, Curves.easeOutCubic);
    final ripple = _span(since, 0, 0.55);
    final track = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      const Radius.circular(h / 2),
    );
    canvas.drawRRect(
      track,
      Paint()
        ..color = Color.lerp(
          const Color(0xFF1E252E),
          Palette.statBlue,
          on,
        )!.withValues(alpha: k),
    );
    if (on < 1) {
      canvas.drawRRect(
        track.deflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Palette.muted.withValues(alpha: k * (1 - on)),
      );
    }
    final x = -w / 2 + h / 2 + (w - h) * on;
    if (ripple > 0 && ripple < 1) {
      canvas.drawCircle(
        Offset(x, 0),
        20 + 40 * ripple,
        Paint()
          ..color = Palette.statBlue.withValues(alpha: 0.35 * (1 - ripple)),
      );
    }
    canvas.drawCircle(
      Offset(x, 0),
      12 + 12 * on,
      Paint()
        ..color = Color.lerp(
          Palette.muted,
          const Color(0xFF0B2E4F),
          on,
        )!.withValues(alpha: k),
    );
  }

  /// Fluent: flips late, overshoots, then bounces back off. Behavior you
  /// can't see from the machine you're on.
  void _windowsSwitch(Canvas canvas, double t, double k) {
    const w = 104.0, h = 52.0;
    final start = _pull + 0.55;
    final out = _span(t, start, start + 0.18, Curves.easeOut);
    final back = _span(t, start + 0.55, start + 0.8, Curves.bounceOut);
    final on = (out * 1.12 - back * 1.12).clamp(0.0, 1.12);
    final wrong = _span(t, start + 0.7, start + 1.0);
    final track = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      const Radius.circular(h / 2),
    );
    final filled = on.clamp(0.0, 1.0);
    canvas.drawRRect(
      track,
      Paint()
        ..color = Color.lerp(
          const Color(0xFF1E252E),
          const Color(0xFF0078D4),
          filled,
        )!.withValues(alpha: k),
    );
    canvas.drawRRect(
      track.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Color.lerp(
          Palette.soft,
          Palette.warn,
          wrong,
        )!.withValues(alpha: k * (1 - filled * (1 - wrong))),
    );
    final x = -w / 2 + h / 2 + (w - h) * on;
    canvas.drawCircle(
      Offset(x, 0),
      11,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: k),
    );
    if (wrong > 0) {
      final pop = Curves.easeOutBack.transform(wrong);
      canvas.save();
      canvas.translate(w / 2 + 30, -h / 2 - 16);
      canvas.scale(pop);
      canvas.drawCircle(Offset.zero, 20, Paint()..color = Palette.warn);
      _label(
        canvas,
        '?',
        const Offset(0, -1),
        zalando(14, weight: 800, color: Palette.background),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PuppetPainter old) => old.clock != clock;
}

// ---------------------------------------------------------------------------
// Bring your whole stack

class CarryStackDiagram extends StatelessWidget {
  const CarryStackDiagram({super.key});

  @override
  Widget build(BuildContext context) =>
      _Clocked(seconds: 4.4, painter: _StackPainter.new);
}

enum _Device { phone, tablet, laptop, tv }

class _StackPainter extends CustomPainter {
  _StackPainter(this.clock) : super(repaint: clock);
  final Animation<double> clock;

  static const _layers = [
    Color(0xFF6FD3FB),
    Color(0xFF27C4F5),
    Color(0xFF0175C2),
    Color(0xFF02569B),
  ];
  static const _floor = 176.0; // devices and the stack stand here
  static const _fly = 0.7; // seconds per copy in flight
  static const _firstFlight = 0.7;
  static const _stagger = 0.35;

  /// A stack of [_layers], [w] wide, bottom center at [at].
  void _stack(Canvas canvas, Offset at, double w, {double alpha = 1}) {
    final slab = w * 0.16, gap = w * 0.05;
    var y = at.dy;
    for (final color in _layers.reversed) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(at.dx - w / 2, y - slab, at.dx + w / 2, y),
          Radius.circular(slab * 0.35),
        ),
        Paint()..color = color.withValues(alpha: alpha),
      );
      y -= slab + gap;
    }
  }

  static double _stackHeight(double w) => w * (0.16 * 4 + 0.05 * 3);

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final cx = size.width / 2;
    final appear = _span(t, 0, 0.5, Curves.easeOutBack);

    // Your stack, on the left.
    final home = Offset(cx - 640, _floor);
    const homeW = 150.0;
    // It hefts each copy off: a little squash as each one leaves.
    var heft = 0.0;
    for (var i = 0; i < 4; i++) {
      final dt = t - (_firstFlight + i * _stagger);
      if (dt > 0 && dt < 0.25) {
        heft = math.max(heft, math.sin(dt / 0.25 * math.pi));
      }
    }
    canvas.save();
    canvas.translate(home.dx, home.dy);
    canvas.scale(appear * (1 + 0.04 * heft), appear * (1 - 0.08 * heft));
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(0, -_stackHeight(homeW) / 2),
        width: homeW * 1.4,
        height: _stackHeight(homeW) * 1.2,
      ),
      Paint()
        ..color = Palette.accent.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
    );
    _stack(canvas, Offset.zero, homeW);
    canvas.restore();
    _label(
      canvas,
      'YOUR STACK',
      home + const Offset(0, 40),
      _caption.copyWith(color: Palette.accent),
      alpha: appear.clamp(0.0, 1.0),
    );

    final devices = [
      (_Device.phone, cx - 300, const Size(76, 136)),
      (_Device.tablet, cx - 60, const Size(196, 140)),
      (_Device.laptop, cx + 230, const Size(220, 132)),
      (_Device.tv, cx + 540, const Size(250, 150)),
    ];
    for (final (i, (kind, x, s)) in devices.indexed) {
      final launch = _firstFlight + i * _stagger;
      final arrive = launch + _fly;
      final landed = _span(t, arrive, arrive + 0.3, Curves.easeOut);
      final check = _span(t, arrive + 0.35, arrive + 0.7, Curves.easeOutBack);
      final screen = _device(canvas, kind, x, s, appear, landed);

      // The copy in the device, at rest.
      final fit = math.min(screen.width * 0.62, screen.height * 0.62 / 0.79);
      final rest = Offset(
        screen.center.dx,
        screen.center.dy + _stackHeight(fit) / 2,
      );
      if (t >= arrive) {
        // A little settle as it lands.
        final bounce = 1 + 0.12 * math.sin(landed * math.pi) * (1 - landed);
        canvas.save();
        canvas.translate(rest.dx, rest.dy);
        canvas.scale(1 / bounce, bounce);
        _stack(canvas, Offset.zero, fit);
        canvas.restore();
      } else if (t > launch) {
        // In flight: an arc from the stack to the screen, shrinking.
        final f = Curves.easeInOutCubic.transform((t - launch) / _fly);
        final from = home - Offset(0, _stackHeight(homeW) * 0.3);
        final p =
            Offset.lerp(from, rest, f)! -
            Offset(0, math.sin(f * math.pi) * (110 + 20 * i));
        final w = homeW + (fit - homeW) * f;
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(math.sin(f * math.pi) * -0.25);
        _stack(canvas, Offset.zero, w, alpha: 0.95);
        canvas.restore();
      }

      if (check > 0) {
        final c = Offset(x, _floor + 40);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.scale(check);
        canvas.drawCircle(Offset.zero, 17, Paint()..color = Palette.accent);
        canvas.drawPath(
          Path()
            ..moveTo(-8, 0)
            ..lineTo(-2, 6)
            ..lineTo(9, -6),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = Palette.background,
        );
        canvas.restore();
      }
    }
  }

  /// Draws a device standing on the floor at [x]; returns its screen rect.
  Rect _device(
    Canvas canvas,
    _Device kind,
    double x,
    Size s,
    double k,
    double lit,
  ) {
    final frame = Paint()..color = const Color(0xFF2A3340).withValues(alpha: k);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Palette.soft.withValues(alpha: 0.5 * k);
    final glass = Paint()
      ..color = Color.lerp(
        const Color(0xFF0B0F14),
        const Color(0xFF14283A),
        lit,
      )!.withValues(alpha: k);
    late Rect screen;
    switch (kind) {
      case _Device.phone || _Device.tablet:
        final body = Rect.fromLTWH(
          x - s.width / 2,
          _floor - s.height,
          s.width,
          s.height,
        );
        final rr = RRect.fromRectAndRadius(
          body,
          Radius.circular(kind == _Device.phone ? 14 : 12),
        );
        canvas.drawRRect(rr, frame);
        canvas.drawRRect(rr, edge);
        screen = body.deflate(kind == _Device.phone ? 7 : 10);
      case _Device.laptop:
        final lid = Rect.fromLTWH(
          x - s.width / 2 + 16,
          _floor - s.height,
          s.width - 32,
          s.height - 12,
        );
        final rr = RRect.fromRectAndRadius(lid, const Radius.circular(8));
        canvas.drawRRect(rr, frame);
        canvas.drawRRect(rr, edge);
        final base = RRect.fromRectAndRadius(
          Rect.fromLTWH(x - s.width / 2, _floor - 12, s.width, 12),
          const Radius.circular(6),
        );
        canvas.drawRRect(base, frame);
        canvas.drawRRect(base, edge);
        screen = lid.deflate(8);
      case _Device.tv:
        final panel = Rect.fromLTWH(
          x - s.width / 2,
          _floor - s.height,
          s.width,
          s.height - 22,
        );
        final rr = RRect.fromRectAndRadius(panel, const Radius.circular(6));
        canvas.drawRRect(rr, frame);
        canvas.drawRRect(rr, edge);
        final stand = Path()
          ..moveTo(x - 14, panel.bottom)
          ..lineTo(x + 14, panel.bottom)
          ..lineTo(x + 30, _floor)
          ..lineTo(x - 30, _floor)
          ..close();
        canvas.drawPath(stand, frame);
        screen = panel.deflate(8);
    }
    final rs = RRect.fromRectAndRadius(screen, const Radius.circular(5));
    canvas.drawRRect(rs, glass);
    if (lit > 0) {
      canvas.save();
      canvas.clipRRect(rs);
      canvas.drawCircle(
        screen.center,
        screen.longestSide * 0.6 * lit,
        Paint()
          ..color = Palette.accent.withValues(alpha: 0.22 * (1 - lit * 0.5))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
      canvas.restore();
    }
    return screen;
  }

  @override
  bool shouldRepaint(_StackPainter old) => old.clock != clock;
}
