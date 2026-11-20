import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Text sized in canvas pixels (zalando() takes Slides points).
TextStyle _px(double px, {double weight = 400, Color color = Palette.text}) =>
    zalando(px / pt(1), weight: weight, color: color);

/// "Everyone at Shorebird built their own": under the headline, four little
/// apps (Ops, PM, Sales, Support) assemble themselves one after another out
/// of flying widgets: a window lands, then its stat chips, chart, kanban
/// cards, funnel bars and chat bubbles snap into place. Each is different,
/// each has the Flutter logo in its title bar. Runs once when the slide
/// appears and settles in about three and a half seconds.
class BuiltOwnSlide extends StatefulWidget {
  const BuiltOwnSlide(this.text, {super.key});
  final String text;

  @override
  State<BuiltOwnSlide> createState() => _BuiltOwnSlideState();
}

const _total = 3500; // ms
const _firstWindow = 250; // ms
const _windowGap = 380; // ms between windows starting
const _pieceGap = 95; // ms between a window's pieces
const _fly = 620; // ms for a piece to land

const _ops = Color(0xFF3CCB7F);
const _pm = Color(0xFF9B7CF6);
const _sales = Palette.warn;
const _support = Palette.accent;
const _card = Color(0xFF222A37);
const _windowW = 370.0, _windowH = 310.0, _bar = 38.0;

class _BuiltOwnSlideState extends State<BuiltOwnSlide>
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 160),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.text, textAlign: TextAlign.center, style: headline(50)),
          const SizedBox(height: 80),
          AnimatedBuilder(
            animation: _clock,
            builder: (context, _) {
              final ms = _clock.value * _total;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final (i, app) in _apps.indexed)
                    _Window(
                      app: app,
                      ms: ms - _firstWindow - i * _windowGap,
                      seed: i,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

/// One app: its name, color, and pieces (rect in the window body, widget).
class _App {
  const _App(this.name, this.color, this.pieces);
  final String name;
  final Color color;
  final List<(Rect, Widget Function(double t))> pieces;
}

final _apps = [
  _App('Ops', _ops, [
    for (final (i, (big, small)) in [
      ('99.9%', 'uptime'),
      ('42', 'deploys'),
      ('0', 'pages'),
    ].indexed)
      (
        Rect.fromLTWH(16 + i * 115.0, 14, 107, 64),
        (t) => _Chip(big: big, small: small, color: _ops),
      ),
    (
      const Rect.fromLTWH(16, 90, 338, 96),
      (t) => _Panel(child: CustomPaint(painter: _Sparkline(_ops, t))),
    ),
    for (final (i, name) in ['api', 'builds'].indexed)
      (Rect.fromLTWH(16, 198 + i * 31.0, 338, 25), (t) => _Status(name, _ops)),
  ]),
  _App('PM', _pm, [
    for (final (c, col) in ['Todo', 'Doing', 'Done'].indexed)
      (
        Rect.fromLTWH(16 + c * 115.0, 14, 107, 22),
        (t) => Text(col, style: _px(12, weight: 700, color: Palette.muted)),
      ),
    for (final (c, n) in [3, 2, 2].indexed)
      for (var k = 0; k < n; k++)
        (
          Rect.fromLTWH(16 + c * 115.0, 42 + k * 74.0, 107, 64),
          (t) => _KanbanCard(
            color: c == 2 ? _ops : _pm,
            lines: 1 + (k + c) % 2,
            done: c == 2,
          ),
        ),
  ]),
  _App('Sales', _sales, [
    (
      const Rect.fromLTWH(16, 12, 338, 40),
      (t) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Pipeline', style: _px(15, weight: 700)),
          const Spacer(),
          Text('Q4', style: _px(12, color: Palette.muted)),
        ],
      ),
    ),
    for (final (i, (name, n)) in [
      ('Leads', 120),
      ('Demos', 48),
      ('Trials', 21),
      ('Won', 9),
    ].indexed)
      (
        Rect.fromLTWH(16, 62 + i * 52.0, 338, 40),
        (t) => _FunnelBar(
          name: name,
          n: n,
          fraction: n / 120,
          grow: t,
          won: name == 'Won',
        ),
      ),
  ]),
  _App('Support', _support, [
    (
      const Rect.fromLTWH(16, 14, 230, 40),
      (t) => const _Bubble('How do I patch iOS?', mine: false),
    ),
    (
      const Rect.fromLTWH(120, 64, 234, 40),
      (t) => const _Bubble('shorebird patch ios', mine: true),
    ),
    (
      const Rect.fromLTWH(16, 114, 170, 40),
      (t) => const _Bubble('Shipped. Thanks!', mine: false),
    ),
    (
      const Rect.fromLTWH(234, 164, 120, 40),
      (t) => const _Bubble('Love it', mine: true),
    ),
    (const Rect.fromLTWH(16, 222, 338, 36), (t) => const _Input()),
  ]),
];

class _Window extends StatelessWidget {
  const _Window({required this.app, required this.ms, required this.seed});
  final _App app;
  final double ms; // since this window started
  final int seed;

  @override
  Widget build(BuildContext context) {
    final frame = (ms / 500).clamp(0.0, 1.0);
    final rnd = math.Random(56 + seed);
    return Opacity(
      opacity: Curves.easeOut.transform(frame),
      child: Transform.translate(
        offset: Offset(0, 60 * (1 - Curves.easeOutCubic.transform(frame))),
        child: Transform.scale(
          scale: 0.9 + 0.1 * Curves.easeOutBack.transform(frame),
          child: Container(
            width: _windowW,
            height: _windowH,
            clipBehavior: Clip.none,
            decoration: BoxDecoration(
              color: const Color(0xFF161C26),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1FFFFFFF)),
              boxShadow: [
                BoxShadow(
                  color: app.color.withValues(alpha: 0.12),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
                const BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TitleBar(app),
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final (j, (rect, build)) in app.pieces.indexed)
                        _piece(
                          rect,
                          build,
                          (ms - 300 - j * _pieceGap) / _fly,
                          rnd,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A piece flying in from off to one side, tumbling, landing at [rect].
  Widget _piece(
    Rect rect,
    Widget Function(double t) build,
    double raw,
    math.Random rnd,
  ) {
    // Draw the random numbers whether or not it's visible, so each piece
    // keeps the same path from frame to frame.
    final angle = rnd.nextDouble() * 2 * math.pi;
    final dist = 160 + rnd.nextDouble() * 160;
    final spin = (rnd.nextDouble() - 0.5) * 0.9;
    final t = raw.clamp(0.0, 1.0);
    if (raw <= 0) return const SizedBox();
    final land = Curves.easeOutBack.transform(t);
    final away = 1 - land;
    return Positioned.fromRect(
      rect: rect,
      child: Opacity(
        opacity: math.min(1, t * 2.5),
        child: Transform.translate(
          offset: Offset(math.cos(angle), math.sin(angle)) * dist * away,
          child: Transform.rotate(
            angle: spin * away,
            child: build(
              Curves.easeOutCubic.transform(
                ((raw - 0.3) / 0.9).clamp(0.0, 1.0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar(this.app);
  final _App app;

  @override
  Widget build(BuildContext context) => Container(
    height: _bar,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0x14FFFFFF))),
    ),
    child: Row(
      children: [
        for (final c in const [
          Color(0xFFFF5F57),
          Color(0xFFFEBC2E),
          Color(0xFF28C840),
        ]) ...[
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
        ],
        const SizedBox(width: 8),
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: app.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(app.name, style: _px(15, weight: 700)),
        const Spacer(),
        const FlutterLogo(size: 18),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.big, required this.small, required this.color});
  final String big, small;
  final Color color;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(big, style: _px(21, weight: 700, color: color)),
        Text(small, style: _px(11, color: Palette.muted)),
      ],
    ),
  );
}

class _Sparkline extends CustomPainter {
  _Sparkline(this.color, this.t);
  final Color color;
  final double t; // how much of the line is drawn

  static const _points = [
    0.55,
    0.6,
    0.5,
    0.62,
    0.45,
    0.5,
    0.38,
    0.42,
    0.3,
    0.34,
    0.22,
    0.28,
    0.18,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final n = _points.length - 1;
    Offset at(int i) => Offset(size.width * i / n, size.height * _points[i]);
    final upto = t * n;
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    var end = at(0);
    for (var i = 1; i <= n; i++) {
      if (i <= upto) {
        end = at(i);
      } else {
        end = Offset.lerp(at(i - 1), at(i), upto - (i - 1))!;
        line.lineTo(end.dx, end.dy);
        break;
      }
      line.lineTo(end.dx, end.dy);
    }
    final fill = Path.from(line)
      ..lineTo(end.dx, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(end, 4.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Sparkline old) => old.t != t;
}

class _Status extends StatelessWidget {
  const _Status(this.name, this.color);
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 10),
      Text(name, style: _px(13, weight: 700)),
      const Spacer(),
      Text('healthy', style: _px(12, color: Palette.muted)),
    ],
  );
}

class _KanbanCard extends StatelessWidget {
  const _KanbanCard({
    required this.color,
    required this.lines,
    required this.done,
  });
  final Color color;
  final int lines;
  final bool done;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(8),
      border: Border(left: BorderSide(color: color, width: 3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines; i++) ...[
          Container(
            height: 6,
            width: i == 0 ? 70 : 46,
            decoration: BoxDecoration(
              color: Palette.soft.withValues(alpha: i == 0 ? 0.7 : 0.35),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 6),
        ],
        const Spacer(),
        Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
            ),
            const Spacer(),
            if (done)
              CustomPaint(
                size: const Size(14, 14),
                painter: _Glyph(color, check: true),
              ),
          ],
        ),
      ],
    ),
  );
}

class _FunnelBar extends StatelessWidget {
  const _FunnelBar({
    required this.name,
    required this.n,
    required this.fraction,
    required this.grow,
    required this.won,
  });
  final String name;
  final int n;
  final double fraction, grow;
  final bool won;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 56,
        child: Text(name, style: _px(12, color: Palette.muted)),
      ),
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: math.max(0.08, fraction * grow),
            child: Container(
              height: 26,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _sales.withValues(alpha: won ? 1 : 0.55),
                    _sales.withValues(alpha: won ? 0.85 : 0.35),
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${(n * grow).round()}',
                style: _px(
                  12,
                  weight: 700,
                  color: won ? Palette.background : Palette.text,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.text, {required this.mine});
  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: mine ? _support : _card,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
      ),
      child: Text(
        text,
        style: _px(
          14,
          weight: mine ? 700 : 400,
          color: mine ? Palette.background : Palette.text,
        ),
      ),
    ),
  );
}

class _Input extends StatelessWidget {
  const _Input();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(left: 14, right: 5),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x14FFFFFF)),
    ),
    child: Row(
      children: [
        Text('Reply…', style: _px(12, color: Palette.muted)),
        const Spacer(),
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: _support,
            shape: BoxShape.circle,
          ),
          child: const CustomPaint(
            painter: _Glyph(Palette.background, check: false),
          ),
        ),
      ],
    ),
  );
}

/// A check mark or an up arrow, drawn (no icon font needed).
class _Glyph extends CustomPainter {
  const _Glyph(this.color, {required this.check});
  final Color color;
  final bool check;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = check
        ? (Path()
            ..moveTo(w * 0.15, h * 0.55)
            ..lineTo(w * 0.42, h * 0.8)
            ..lineTo(w * 0.88, h * 0.22))
        : (Path()
            ..moveTo(w * 0.5, h * 0.75)
            ..lineTo(w * 0.5, h * 0.28)
            ..moveTo(w * 0.32, h * 0.45)
            ..lineTo(w * 0.5, h * 0.27)
            ..lineTo(w * 0.68, h * 0.45));
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_Glyph old) => false;
}
