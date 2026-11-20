import 'package:flutter/widgets.dart';

import 'layouts.dart' show Statement;
import 'theme.dart';

/// "“Just prompt native”": the prompt goes out and two native apps print
/// themselves under the quote, scan line by scan line: an iOS one (Dynamic
/// Island, large title, tab bar) and an Android one (punch-hole, app bar,
/// cards, FAB). They lean in toward each other, bonk, and spring back:
/// two apps, and they stay separate. A shrug pops up between them. The
/// quote itself is the plain statement throughout.
class PromptNative extends StatefulWidget {
  const PromptNative(this.text, {super.key});
  final String text;

  @override
  State<PromptNative> createState() => _PromptNativeState();
}

const _totalMs = 4200;

class _PromptNativeState extends State<PromptNative>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  )..forward();
  final _labels = _Labels();

  @override
  void dispose() {
    _clock.dispose();
    _labels.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Statement(widget.text),
      Positioned.fill(
        child: RepaintBoundary(
          child: CustomPaint(painter: _PhonesPainter(_clock, _labels)),
        ),
      ),
    ],
  );
}

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0, 1);

/// "iOS", "Android" and the caption, laid out once, in a few alpha steps;
/// and the shrug.
class _Labels {
  final _cache = <(String, int), TextPainter>{};
  static const _steps = 12;

  TextPainter get(String s, double alpha) {
    final step = (alpha.clamp(0.0, 1.0) * _steps).round();
    return _cache[(s, step)] ??= TextPainter(
      text: TextSpan(
        text: s,
        style: zalando(
          12,
          weight: 700,
          color: Palette.muted.withValues(alpha: step / _steps),
        ).copyWith(letterSpacing: 2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  late final TextPainter shrug = TextPainter(
    text: TextSpan(
      text: '🤷',
      style: TextStyle(fontSize: pt(60)),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  void dispose() {
    shrug.dispose();
    for (final p in _cache.values) {
      p.dispose();
    }
  }
}

enum _Kind { ios, android, one }

class _PhonesPainter extends CustomPainter {
  _PhonesPainter(this.clock, this.labels) : super(repaint: clock);
  final Animation<double> clock;
  final _Labels labels;

  static const phone = Size(150, 300);
  static const apart = 270.0; // each phone's distance from center when two
  static const top = 680.0; // below the quote's descenders

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * _totalMs / 1000;
    final cx = size.width / 2;

    // Two sparks fall from the quote to where the phones will print.
    for (final side in [-1.0, 1.0]) {
      final start = side < 0 ? 0.25 : 0.4;
      final f = _seg(t, start, start + 0.35);
      if (f <= 0 || f >= 1) continue;
      final e = Curves.easeIn.transform(f);
      final from = Offset(cx + side * 120, 600);
      final to = Offset(cx + side * apart, top + 6);
      final p = Offset.lerp(from, to, e)!;
      final paint = Paint()..color = Palette.accent.withValues(alpha: 0.9);
      canvas.drawCircle(p, 5, paint);
      canvas.drawCircle(
        p,
        13,
        paint..color = Palette.accent.withValues(alpha: 0.18),
      );
    }

    // They lean in toward each other, bonk, and spring back apart.
    final approach = Curves.easeIn.transform(_seg(t, 2.0, 2.4));
    final recoil = const ElasticOutCurve(0.4).transform(_seg(t, 2.4, 3.4));
    final nudge = 70 * approach * (1 - recoil);
    final labelAlpha = _seg(t, 1.4, 1.8);

    for (final (side, kind, start) in [
      (-1.0, _Kind.ios, 0.6),
      (1.0, _Kind.android, 0.75),
    ]) {
      final print = _seg(t, start, start + 0.8);
      if (print <= 0) continue;
      // A slight lean in toward each other as they slide, upright on arrival.
      final x = cx + side * (apart - nudge);
      final lean = -side * 0.08 * nudge / 70;
      final rect = Rect.fromLTWH(
        x - phone.width / 2,
        top,
        phone.width,
        phone.height,
      );
      canvas.save();
      canvas.translate(rect.center.dx, rect.bottom);
      canvas.rotate(lean);
      canvas.translate(-rect.center.dx, -rect.bottom);
      // Printing: revealed top-down behind a glowing scan line.
      final scanY =
          rect.top + (rect.height + 8) * Curves.easeInOut.transform(print);
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(rect.left - 4, rect.top - 4, rect.right + 4, scanY),
      );
      _phone(canvas, rect, kind, 1);
      canvas.restore();
      if (print < 1) {
        final glow = Paint()
          ..shader =
              LinearGradient(
                colors: [
                  Palette.accent.withValues(alpha: 0),
                  Palette.accent.withValues(alpha: 0.9),
                  Palette.accent.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromLTWH(rect.left - 20, scanY, rect.width + 40, 1),
              );
        canvas.drawRect(
          Rect.fromLTWH(rect.left - 20, scanY - 2, rect.width + 40, 4),
          glow,
        );
      }
      canvas.restore();

      if (labelAlpha > 0) {
        final label = labels.get(
          kind == _Kind.ios ? 'iOS' : 'ANDROID',
          labelAlpha,
        );
        final ly = rect.center.dy - label.height / 2;
        final lx = side < 0 ? rect.left - 28 - label.width : rect.right + 28;
        label.paint(canvas, Offset(lx, ly));
      }
    }

    // A shrug between them, popping up after the bonk.
    final shrug = _seg(t, 2.9, 3.5);
    if (shrug > 0) {
      final pop = const ElasticOutCurve(0.5).transform(shrug);
      final c = Offset(cx, top + phone.height * 0.42);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(pop);
      final e = labels.shrug;
      e.paint(canvas, Offset(-e.width / 2, -e.height / 2));
      canvas.restore();
      final cap = labels.get('STAY SEPARATE', _seg(t, 3.2, 3.6));
      cap.paint(canvas, Offset(cx - cap.width / 2, c.dy + 70));
    }
  }

  static const _frame = Color(0xFF273142);
  static const _bezel = Color(0xFF3A4658);
  static const _screen = Color(0xFF0E131A);
  static const _row = Color(0xFF1C2430);
  static const _ink = Color(0xFF5B6B82);
  static const _iosBlue = Color(0xFF0A84FF);
  static const _androidGreen = Color(0xFF3DDC84);

  /// One phone in [r], its app drawn in [kind]'s idiom at [alpha]; the
  /// phone itself is opaque, and skipped when [frame] is false.
  void _phone(
    Canvas canvas,
    Rect r,
    _Kind kind,
    double alpha, {
    bool frame = true,
  }) {
    Color a(Color c) => c.withValues(alpha: c.a * alpha);
    final fill = Paint();
    final s = r.deflate(7);
    if (frame) {
      final body = RRect.fromRectAndRadius(r, const Radius.circular(24));
      canvas.drawRRect(body, fill..color = _frame);
      canvas.drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = _bezel,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(s, const Radius.circular(18)),
        fill..color = _screen,
      );
    }
    final w = s.width;
    Rect box(double x, double y, double bw, double bh) =>
        Rect.fromLTWH(s.left + x, s.top + y, bw, bh);
    void bar(double x, double y, double bw, double bh, Color c) =>
        canvas.drawRRect(
          RRect.fromRectAndRadius(box(x, y, bw, bh), Radius.circular(bh / 2)),
          fill..color = a(c),
        );

    switch (kind) {
      case _Kind.ios:
        bar(w / 2 - 20, 8, 40, 11, const Color(0xFF000000)); // Dynamic Island
        bar(12, 34, 74, 13, Palette.soft); // large title, left
        bar(10, 56, w - 20, 15, _row); // search field
        for (var i = 0; i < 5; i++) {
          final y = 84.0 + i * 30;
          canvas.drawCircle(
            Offset(s.left + 22, s.top + y + 8),
            8,
            fill..color = a(i == 0 ? _iosBlue : _ink),
          );
          bar(
            38,
            y + 2,
            56 - (i * 7 % 18),
            6,
            Palette.soft.withValues(alpha: 0.7),
          );
          bar(38, y + 11, 40, 4, _ink);
          // Chevron.
          final c = Offset(s.right - 14, s.top + y + 8);
          canvas.drawPath(
            Path()
              ..moveTo(c.dx - 3, c.dy - 5)
              ..lineTo(c.dx + 2, c.dy)
              ..lineTo(c.dx - 3, c.dy + 5),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round
              ..color = a(_ink),
          );
          if (i < 4) {
            canvas.drawRect(box(38, y + 23, w - 46, 1), fill..color = a(_row));
          }
        }
        // Tab bar and home indicator.
        canvas.drawRect(box(0, s.height - 42, w, 1), fill..color = a(_row));
        for (var i = 0; i < 4; i++) {
          final x = w * (i + 0.5) / 4;
          bar(x - 7, s.height - 34, 14, 14, i == 0 ? _iosBlue : _ink);
        }
        bar(w / 2 - 24, s.height - 9, 48, 4, Palette.soft);
      case _Kind.android:
        canvas.drawCircle(
          Offset(s.center.dx, s.top + 13),
          4.5,
          fill..color = a(const Color(0xFF000000)),
        ); // punch-hole
        // Top app bar: hamburger and title.
        for (var i = 0; i < 3; i++) {
          bar(12, 33 + i * 5.0, 14, 2.5, Palette.soft);
        }
        bar(36, 33, 54, 10, Palette.soft);
        bar(w - 22, 33, 10, 10, _ink);
        for (var i = 0; i < 3; i++) {
          final y = 60.0 + i * 54;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              box(10, y, w - 20, 46),
              const Radius.circular(10),
            ),
            fill..color = a(_row),
          );
          bar(
            20,
            y + 10,
            50 + (i * 13 % 26),
            7,
            Palette.soft.withValues(alpha: 0.7),
          );
          bar(20, y + 24, w - 50, 4, _ink);
          bar(20, y + 32, w - 70, 4, _ink);
        }
        // FAB.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            box(w - 46, s.height - 64, 34, 34),
            const Radius.circular(11),
          ),
          fill..color = a(_androidGreen),
        );
        final plus = box(w - 46, s.height - 64, 34, 34).center;
        final p = Paint()
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = a(_screen);
        canvas.drawLine(
          plus - const Offset(7, 0),
          plus + const Offset(7, 0),
          p,
        );
        canvas.drawLine(
          plus - const Offset(0, 7),
          plus + const Offset(0, 7),
          p,
        );
        bar(w / 2 - 22, s.height - 9, 44, 3.5, Palette.soft); // gesture bar
      case _Kind.one:
        // One app: its own look, the same on every phone.
        bar(w / 2 - 20, 8, 40, 11, const Color(0xFF000000));
        bar(12, 34, 64, 12, Palette.text);
        canvas.drawCircle(
          Offset(s.right - 18, s.top + 40),
          8,
          fill..color = a(Palette.accent),
        );
        // A hero card in the accent color, then rows.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            box(10, 58, w - 20, 64),
            const Radius.circular(12),
          ),
          fill..color = a(Palette.accent.withValues(alpha: 0.85)),
        );
        bar(20, 72, 60, 8, _screen);
        bar(20, 88, 40, 5, _screen.withValues(alpha: 0.6));
        bar(20, 104, 30, 9, Palette.text);
        for (var i = 0; i < 3; i++) {
          final y = 134.0 + i * 34;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              box(10, y, w - 20, 28),
              const Radius.circular(8),
            ),
            fill..color = a(_row),
          );
          canvas.drawCircle(
            Offset(s.left + 24, s.top + y + 14),
            7,
            fill..color = a(i == 0 ? Palette.statBlue : _ink),
          );
          bar(38, y + 9, 50 - i * 8, 5, Palette.soft.withValues(alpha: 0.7));
          bar(38, y + 17, 30, 4, _ink);
        }
        for (var i = 0; i < 3; i++) {
          final x = w * (i + 0.5) / 3;
          bar(x - 7, s.height - 32, 14, 14, i == 0 ? Palette.accent : _ink);
        }
        bar(w / 2 - 24, s.height - 9, 48, 4, Palette.soft);
    }
  }

  @override
  bool shouldRepaint(_PhonesPainter old) => old.clock != clock;
}
