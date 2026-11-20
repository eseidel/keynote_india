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
class Statement extends StatelessWidget {
  const Statement(
    this.text, {
    super.key,
    this.size = 50,
    this.color,
    this.reveal = false,
  });
  final String text;
  final double size;
  final Color? color;
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final style = headline(size, color: color ?? Palette.text);
    if (lines.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 160),
        child: Center(
          child: Text(text, textAlign: TextAlign.center, style: style),
        ),
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
                  child: Text(line, textAlign: TextAlign.center, style: style),
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
  const Cover({super.key, required this.title, this.byline, this.logo});
  final String title;
  final List<String>? byline;
  final String? logo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 288, right: 288),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (logo != null) ...[
          Image.asset(logo!, height: 82),
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
        Expanded(flex: 5, child: Text(text, style: headline(size))),
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
    padding: const EdgeInsets.fromLTRB(140, 40, 140, 110),
    child: GridView.count(
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
/// other, so links grow as n(n-1)/2 (a triangle at 3, a pentagram at 5).
class SyncGraph extends StatelessWidget {
  const SyncGraph({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(160, 60, 120, 60),
    child: Row(
      children: [
        Expanded(flex: 5, child: Text(text, style: headline(44))),
        Expanded(
          flex: 6,
          child: Row(
            children: [
              Expanded(
                child: CustomPaint(
                  painter: _GraphPainter(3),
                  child: const SizedBox.expand(),
                ),
              ),
              Expanded(
                child: CustomPaint(
                  painter: _GraphPainter(5),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _GraphPainter extends CustomPainter {
  _GraphPainter(this.n);
  final int n;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) * 0.32;
    final pts = [
      for (var i = 0; i < n; i++)
        c + Offset.fromDirection(-math.pi / 2 + i * 2 * math.pi / n, r),
    ];
    final line = Paint()
      ..color = Palette.muted
      ..strokeWidth = 4;
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        canvas.drawLine(pts[i], pts[j], line);
      }
    }
    final dot = Paint()..color = Palette.accent;
    for (final p in pts) {
      canvas.drawCircle(p, 16, dot);
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) => old.n != n;
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
            width: 420,
            child: Text(
              label,
              style: zalando(
                20,
                weight: 700,
                color: color,
              ).copyWith(letterSpacing: 3),
            ),
          ),
          Expanded(child: Text(text, style: zalando(30, weight: 500))),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 220),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: headline(50)),
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
