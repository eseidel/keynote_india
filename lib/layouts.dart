import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

/// How many builds of the current slide are showing. Without one (e.g. in
/// renders), everything shows.
class BuildStep extends InheritedWidget {
  const BuildStep({super.key, required this.step, required super.child});
  final int step;

  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BuildStep>()?.step ?? 1 << 20;

  @override
  bool updateShouldNotify(BuildStep old) => old.step != step;
}

/// Big centered statement, one idea per slide. Each '\n' starts a line;
/// lines get generous spacing, and with [reveal] they appear one per click
/// (give the Slide `builds: lines - 1`). A blank line is a spacer.
/// Text where *words* between asterisks are italic.
Widget _rich(String text, TextStyle style) {
  final parts = text.split('*');
  return Text.rich(
    TextSpan(
      children: [
        for (final (i, part) in parts.indexed)
          TextSpan(
            text: part,
            style: i.isOdd ? style.copyWith(fontStyle: FontStyle.italic) : null,
          ),
      ],
    ),
    textAlign: TextAlign.center,
    style: style,
  );
}

class Statement extends StatelessWidget {
  const Statement(
    this.text, {
    super.key,
    this.size = 50,
    this.color,
    this.reveal = false,
    this.below = const {},
  });
  final String text;
  final double size;
  final Color? color;
  final bool reveal;

  /// Extra widgets shown under a line (by index), fading with it.
  final Map<int, Widget> below;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final style = headline(size, color: color ?? Palette.text);
    if (lines.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 160),
        child: Center(child: _rich(text, style)),
      );
    }
    final shown = reveal ? BuildStep.of(context) : lines.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 160),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, line) in lines.indexed)
              Padding(
                padding: EdgeInsets.symmetric(vertical: pt(size) * 0.3),
                child: AnimatedOpacity(
                  opacity: i <= shown ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    children: [
                      _rich(line, style),
                      ?below[i],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opening and closing cover: title plus a byline card.
class Cover extends StatelessWidget {
  const Cover({
    super.key,
    required this.title,
    this.byline,
    this.logo,
    this.logoOverlay,
  });
  final String title;
  final List<String>? byline;
  final String? logo;

  /// Painted over the logo, unclipped, in the logo's coordinates (the
  /// Thank you slide's bird flies in and lands on it).
  final Widget? logoOverlay;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 288, right: 288),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (logo != null) ...[
          if (logoOverlay == null)
            Image.asset(logo!, height: 82)
          else
            Stack(
              clipBehavior: Clip.none,
              children: [Image.asset(logo!, height: 82), logoOverlay!],
            ),
          const SizedBox(height: 24),
        ],
        Text(title, style: headline(logo == null ? 40 : 80)),
        if (byline != null) ...[
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(byline!.first, style: zalando(17, weight: 700)),
                for (final line in byline!.skip(1))
                  Text(line, style: zalando(16, color: Palette.soft)),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

/// Section divider: small accent eyebrow, a short rule, a big title.
class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key, required this.eyebrow, required this.title});
  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 242, right: 160),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: zalando(
            16,
            weight: 700,
            color: Palette.accent,
          ).copyWith(letterSpacing: 4),
        ),
        const SizedBox(height: 12),
        Container(width: 147, height: 4, color: Palette.accent),
        const SizedBox(height: 28),
        Text(title, style: headline(54)),
      ],
    ),
  );
}

/// A title over a list of lines (agenda, numbered reasons, approaches).
class ListSlide extends StatelessWidget {
  const ListSlide({
    super.key,
    this.title,
    required this.items,
    this.size = 40,
    this.itemColor = Palette.text,
  });
  final String? title;
  final List<String> items;
  final double size;
  final Color itemColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 160, vertical: 90),
    child: Column(
      children: [
        if (title != null)
          Text(title!, style: headline(36, color: Palette.accent)),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in items)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: pt(size) * 0.25),
                    child: Text(
                      item,
                      textAlign: TextAlign.center,
                      style: headline(size, color: itemColor),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Text on the left, picture on the right.
class SplitImage extends StatelessWidget {
  const SplitImage({
    super.key,
    required this.text,
    required this.image,
    this.size = 50,
  });
  final String text;
  final String image;
  final double size;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(200, 40, 40, 40),
    child: Row(
      children: [
        Expanded(
          flex: 5,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(text, style: headline(size)),
          ),
        ),
        const SizedBox(width: 60),
        Expanded(
          flex: 5,
          child: Center(child: Image.asset(image, fit: BoxFit.contain)),
        ),
      ],
    ),
  );
}

/// Title across the top, one large visual underneath.
class TitleOver extends StatelessWidget {
  const TitleOver({
    super.key,
    required this.title,
    required this.child,
    this.size = 36,
  });
  final String title;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(120, 56, 120, 110),
    child: Column(
      children: [
        Text(title, style: headline(size)),
        const SizedBox(height: 36),
        Expanded(child: child),
      ],
    ),
  );
}

/// A rounded, softly shadowed picture.
class Picture extends StatelessWidget {
  const Picture(this.asset, {super.key, this.fit = BoxFit.contain});
  final String asset;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Image.asset(asset, fit: fit),
  );
}

/// Pictures in a row, each with a caption.
class Gallery extends StatelessWidget {
  const Gallery({super.key, required this.items});
  final List<(String image, String caption)> items;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (image, caption) in items)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                Expanded(child: Center(child: Picture(image))),
                const SizedBox(height: 20),
                Text(caption, style: zalando(16, color: Palette.muted)),
              ],
            ),
          ),
        ),
    ],
  );
}

/// Labeled 2x2 wall of logos/screens.
class LogoWall extends StatelessWidget {
  const LogoWall({super.key, required this.items});
  final List<(String image, String caption)> items;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(140, 75, 140, 75),
    child: Center(
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 2,
        childAspectRatio: 2.0,
        mainAxisSpacing: 30,
        crossAxisSpacing: 60,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final (image, caption) in items)
            Column(
              children: [
                Expanded(child: Picture(image)),
                const SizedBox(height: 12),
                Text(caption, style: zalando(16, color: Palette.muted)),
              ],
            ),
        ],
      ),
    ),
  );
}

/// One big number and what it means.
class Stat extends StatelessWidget {
  const Stat({super.key, required this.value, required this.caption});
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: zalando(100, weight: 800, color: Palette.statBlue)),
        const SizedBox(height: 12),
        Text(
          caption,
          style: zalando(24, color: const Color.fromRGBO(224, 241, 255, 1)),
        ),
      ],
    ),
  );
}

enum VerdictKind { good, bad }

/// "GOOD AT / Trivia" style verdicts, stacked with a rule between.
class Verdicts extends StatelessWidget {
  const Verdicts({super.key, required this.items});
  final List<(VerdictKind, String)> items;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 250),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, (kind, word)) in items.indexed) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Container(
                width: 1250,
                height: 4,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          Text(
            kind == VerdictKind.good ? 'GOOD AT' : 'BAD AT',
            style: zalando(
              20,
              weight: 700,
              color: kind == VerdictKind.good ? Palette.accent : Palette.warn,
            ).copyWith(letterSpacing: 3),
          ),
          Text(word, style: zalando(56, weight: 500)),
        ],
      ],
    ),
  );
}

class Quote extends StatelessWidget {
  const Quote({super.key, required this.text, required this.by});
  final String text;
  final String by;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 200),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: zalando(28, weight: 700, italic: true, height: 1.35),
        ),
        const SizedBox(height: 40),
        Text('— $by', style: zalando(24, color: Palette.muted)),
      ],
    ),
  );
}

/// Bio slide: name, lines, headshot.
class Bio extends StatelessWidget {
  const Bio({
    super.key,
    required this.name,
    required this.lines,
    required this.photo,
  });
  final String name;
  final List<String> lines;
  final String photo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(150, 180, 150, 140),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: headline(34)),
              const SizedBox(height: 36),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(line, style: zalando(16.5, color: Palette.soft)),
                ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(photo, width: 740, height: 740, fit: BoxFit.cover),
        ),
      ],
    ),
  );
}

/// The opening question, answered in three lines.
class Callback extends StatelessWidget {
  const Callback({super.key, required this.question, required this.answers});
  final String question;
  final List<String> answers;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(question, style: headline(32)),
        const SizedBox(height: 70),
        for (final a in answers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(a, style: headline(40, color: Palette.accent)),
          ),
      ],
    ),
  );
}

/// "Two codebases: 3x the bill": every copy must stay in sync with every
/// other, so links grow as n(n-1)/2. When the slide appears, 2, 3 and 5
/// copies get their links drawn one at a time, each with a running count
/// (1 link, 3 links, 10 links), so the cost of copies is something you count.
class SyncGraph extends StatefulWidget {
  const SyncGraph({super.key, required this.text});
  final String text;

  static const copies = [2, 3, 5];

  @override
  State<SyncGraph> createState() => _SyncGraphState();
}

class _SyncGraphState extends State<SyncGraph>
    with SingleTickerProviderStateMixin {
  // Links are drawn back to back across the graphs; the clock counts links.
  static const _perLink = Duration(milliseconds: 260);
  static const _pause = 2; // links' worth of pause before each next graph

  static final _starts = () {
    final starts = <int>[];
    var t = 2; // a beat after the slide appears
    for (final n in SyncGraph.copies) {
      starts.add(t);
      t += n * (n - 1) ~/ 2 + _pause;
    }
    return starts..add(t);
  }();

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: _perLink * _starts.last,
  )..forward();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(160, 60, 100, 60),
    child: Row(
      children: [
        Expanded(flex: 5, child: Text(widget.text, style: headline(44))),
        Expanded(
          flex: 7,
          child: AnimatedBuilder(
            animation: _clock,
            builder: (context, _) {
              final links = _clock.value * _starts.last; // in links
              return Row(
                children: [
                  for (final (i, n) in SyncGraph.copies.indexed)
                    Expanded(
                      child: _Graph(n: n, drawn: links - _starts[i]),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

/// One graph of [n] copies with [drawn] of its links drawn (fractional: the
/// last one is partway), its copies fading in just before its first link.
class _Graph extends StatelessWidget {
  const _Graph({required this.n, required this.drawn});
  final int n;
  final double drawn;

  @override
  Widget build(BuildContext context) {
    final total = n * (n - 1) ~/ 2;
    final done = drawn.floor().clamp(0, total);
    final shown = (drawn + 1).clamp(0.0, 1.0); // copies fade in a link early
    return Opacity(
      opacity: shown,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 300,
            child: CustomPaint(
              painter: _GraphPainter(n, drawn.clamp(0, total).toDouble()),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '$n copies',
            style: zalando(16, color: Palette.muted),
          ),
          const SizedBox(height: 8),
          Text(
            '$done ${done == 1 ? 'link' : 'links'}',
            style: zalando(
              24,
              weight: 700,
              color: done == total ? Palette.warn : Palette.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter(this.n, this.drawn);
  final int n;
  final double drawn;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) * 0.4;
    final pts = [
      for (var i = 0; i < n; i++)
        c +
            Offset.fromDirection(
              // Two copies sit side by side; more go round a polygon.
              n == 2 ? math.pi * i : -math.pi / 2 + i * 2 * math.pi / n,
              r,
            ),
    ];
    final line = Paint()
      ..color = Palette.muted
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    var k = 0;
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++, k++) {
        final f = (drawn - k).clamp(0.0, 1.0);
        if (f == 0) continue;
        canvas.drawLine(pts[i], Offset.lerp(pts[i], pts[j], f)!, line);
      }
    }
    final dot = Paint()..color = Palette.accent;
    for (final p in pts) {
      canvas.drawCircle(p, 16, dot);
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) => old.n != n || old.drawn != drawn;
}

/// A live 3D scene filling the whole slide, title over the top and an
/// optional link in the bottom-left corner.
class FullBleed3D extends StatelessWidget {
  const FullBleed3D({
    super.key,
    required this.title,
    required this.child,
    this.link,
  });
  final String title;
  final Widget child;
  final String? link;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      Positioned(
        top: 56,
        left: 0,
        right: 0,
        child: Text(title, textAlign: TextAlign.center, style: headline(36)),
      ),
      if (link != null)
        Positioned(
          left: 100,
          bottom: 34,
          child: GestureDetector(
            onTap: () => launchUrl(Uri.https(link!)),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                link!,
                style: zalando(14, weight: 600, color: Palette.accent),
              ),
            ),
          ),
        ),
    ],
  );
}

/// One approach: what it is, an example or two, its upside and downside.
class ProsCons extends StatelessWidget {
  const ProsCons({
    super.key,
    required this.title,
    required this.examples,
    required this.upside,
    required this.downside,
  });
  final String title;
  final String examples;
  final String upside;
  final String downside;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, Color color, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 380,
            child: Text(
              label,
              style: zalando(
                20,
                weight: 700,
                color: color,
              ).copyWith(letterSpacing: 3),
            ),
          ),
          Expanded(child: Text(text, style: zalando(26, weight: 500))),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 180),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: headline(44)),
          const SizedBox(height: 12),
          Text(examples, style: zalando(22, color: Palette.muted)),
          const SizedBox(height: 50),
          row('UPSIDE', Palette.accent, upside),
          row('DOWNSIDE', Palette.warn, downside),
        ],
      ),
    );
  }
}

/// A brick foundation that lays itself, course by course from the bottom,
/// each brick dropping into place. Drawn by Flutter, no image.
class BrickFoundation extends StatefulWidget {
  const BrickFoundation({super.key});

  @override
  State<BrickFoundation> createState() => _BrickFoundationState();
}

class _BrickFoundationState extends State<BrickFoundation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) =>
        CustomPaint(painter: _BrickPainter(_c.value), size: Size.infinite),
  );
}

class _BrickPainter extends CustomPainter {
  _BrickPainter(this.t);
  final double t;

  static const rows = 9, cols = 7, gap = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(9);
    final bh = (size.height - gap * (rows - 1)) / rows;
    final bw = (size.width - gap * (cols - 1)) / cols;
    final total = rows * cols;
    var n = 0;
    for (var r = 0; r < rows; r++) {
      // Bottom course first; odd courses offset by half a brick.
      final y = size.height - (r + 1) * bh - r * gap;
      final offset = r.isOdd ? -(bw + gap) / 2 : 0.0;
      // The lowest two courses are the foundation: heavier, darker stone.
      final footing = r < 2;
      for (var c = 0; c <= cols; c++) {
        var x = offset + c * (bw + gap);
        var w = bw;
        if (x < 0) {
          w += x;
          x = 0;
        }
        if (x + w > size.width) w = size.width - x;
        if (w <= 4) continue;
        // Each brick lands in turn; the drop eases out.
        final start = (n / total) * 0.94;
        n++;
        final local = ((t - start) / 0.05).clamp(0.0, 1.0);
        if (local <= 0) continue;
        final e = 1 - math.pow(1 - local, 3).toDouble();
        final dy = (1 - e) * -140;
        final shade = 0.85 + rng.nextDouble() * 0.3;
        final base = footing
            ? const Color(0xFF5B6675)
            : Color.lerp(
                const Color(0xFFB4532A),
                const Color(0xFFD9733F),
                rng.nextDouble(),
              )!;
        final color = Color.from(
          alpha: e,
          red: (base.r * shade).clamp(0, 1),
          green: (base.g * shade).clamp(0, 1),
          blue: (base.b * shade).clamp(0, 1),
        );
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y + dy, w, bh),
          const Radius.circular(4),
        );
        canvas.drawRRect(rect, Paint()..color = color);
        // A lit top edge so each brick reads in 3D.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y + dy, w, bh * 0.16),
            const Radius.circular(4),
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.18 * e),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BrickPainter old) => old.t != t;
}

/// Text on the left, any visual on the right.
class SplitVisual extends StatelessWidget {
  const SplitVisual({
    super.key,
    required this.text,
    required this.visual,
    this.size = 60,
  });
  final String text;
  final Widget visual;
  final double size;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(200, 140, 160, 160),
    child: Row(
      children: [
        Expanded(
          flex: 5,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(text, style: headline(size)),
          ),
        ),
        const SizedBox(width: 60),
        Expanded(flex: 6, child: visual),
      ],
    ),
  );
}
