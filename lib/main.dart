import 'package:flutter/material.dart';

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'deck.dart';
import 'layouts.dart';
import 'materialize.dart' show preloadHelmet;
import 'shatter.dart';
import 'snap_web.dart' if (dart.library.io) 'snap_io.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  preloadHelmet();
  runApp(const KeynoteApp());
}

class KeynoteApp extends StatelessWidget {
  const KeynoteApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Why AI Makes Flutter More Important, Not Less', // the browser tab
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: const Presenter(),
  );
}

/// Keys: → / space / PageDown next, ← / PageUp back, Home / End,
/// N toggles speaker notes. Touch: the left third back, the rest next.
class Presenter extends StatefulWidget {
  const Presenter({super.key, this.initial = 0});
  final int initial;

  @override
  State<Presenter> createState() => _PresenterState();
}

class _PresenterState extends State<Presenter> {
  late int index = const int.fromEnvironment('SLIDE', defaultValue: 1) - 1;
  int step = 0; // builds revealed on the current slide
  bool showNotes = false;
  final focus = FocusNode();
  final boundary = GlobalKey();
  ui.Image? shatter; // outgoing slide, while its glass flies off
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    // Global handler: works whatever has focus (the Focus widget missed keys
    // when the window opened without focus).
    HardwareKeyboard.instance.addHandler(_onKey);
    // --dart-define=SNAP=name.png captures the slide and quits; used to check
    // the live 3D slides without a human. SNAP_MS is a comma list of capture
    // times (name_0.png, name_1.png, ... when there are several), and
    // SHATTER_T an optional matching list of frozen shatter clocks.
    const snap = String.fromEnvironment('SNAP');
    if (snap.isNotEmpty) _snapAll(snap);
  }

  Future<void> _snapAll(String snap) async {
    const melt = int.fromEnvironment('SNAP_STEP_MS');
    if (melt > 0) {
      Future.delayed(const Duration(milliseconds: melt), next);
    }
    const atList = String.fromEnvironment('SNAP_MS', defaultValue: '10000');
    const clocks = String.fromEnvironment('SHATTER_T');
    final ats = atList.split(',').map(int.parse).toList();
    final ts = clocks.isEmpty
        ? <double>[]
        : clocks.split(',').map(double.parse).toList();
    // Freeze the shatter from its first frame, so a late first capture
    // still sees the glass rather than the slide after it.
    if (ts.isNotEmpty) shatterClock.value = ts.first;
    final start = DateTime.now();
    for (var i = 0; i < ats.length; i++) {
      final wait =
          Duration(milliseconds: ats[i]) - DateTime.now().difference(start);
      if (wait > Duration.zero) await Future.delayed(wait);
      if (i < ts.length) shatterClock.value = ts[i];
      // A ticking 3D scene keeps the boundary dirty; capture between frames.
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      final image = await _capture();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final name = ats.length == 1
          ? snap
          : snap.replaceFirst(RegExp(r'\.png$'), '_$i.png');
      final path = writeSnap(name, bytes!.buffer.asUint8List());
      debugPrint('SNAP_WRITTEN $path');
    }
    quit();
  }

  Future<ui.Image> _capture() async {
    final ro =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    if (kDebugMode && ro.debugNeedsPaint) {
      await WidgetsBinding.instance.endOfFrame;
    }
    return ro.toImage();
  }

  void go(int i, {bool atEnd = false}) => setState(() {
    index = i.clamp(0, deck.length - 1);
    step = atEnd ? deck[index].builds : 0;
  });

  /// While the glass is falling (or being captured), navigation waits: a
  /// second press on the black would skip the next slide unseen.
  bool get _transitioning => shatter != null || _capturing;

  void next() {
    if (_transitioning) return;
    if (step < deck[index].builds) return setState(() => step++);
    if (deck[index].shatterOut && index < deck.length - 1) {
      _shatterTo(index + 1);
    } else {
      go(index + 1);
    }
  }

  /// Snapshots the current slide, cuts to the next one underneath, and
  /// lays the snapshot over it as glass that shatters away.
  Future<void> _shatterTo(int i) async {
    if (_capturing) return;
    _capturing = true;
    final ui.Image image;
    try {
      image = await _capture();
    } catch (_) {
      // No snapshot, no glass: just cut to the next slide.
      _capturing = false;
      if (mounted) go(i);
      return;
    }
    _capturing = false;
    if (!mounted) return;
    setState(() {
      shatter?.dispose();
      shatter = image;
      index = i;
      step = 0;
    });
  }

  void back() => _transitioning
      ? null
      : step > 0
      ? setState(() => step--)
      : go(index - 1, atEnd: true);

  /// A click advances. A touch on the left third of the screen goes back and
  /// anywhere else advances: on a phone there are no arrow keys.
  void _onTap(TapUpDetails d) {
    final width = context.size?.width ?? 0;
    if (d.kind == ui.PointerDeviceKind.touch &&
        d.localPosition.dx < width / 3) {
      back();
    } else {
      next();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent e) => onKey(focus, e) == KeyEventResult.handled;

  KeyEventResult onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.pageDown) {
      next();
    } else if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.pageUp) {
      back();
    } else if (k == LogicalKeyboardKey.home) {
      go(0);
    } else if (k == LogicalKeyboardKey.end) {
      go(deck.length - 1);
    } else if (k == LogicalKeyboardKey.keyN) {
      setState(() => showNotes = !showNotes);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final slide = deck[index];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: focus,
        autofocus: true,
        child: GestureDetector(
          onTapUp: _onTap,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: canvasSize.aspectRatio,
                    child: FittedBox(
                      child: RepaintBoundary(
                        key: boundary,
                        child: SizedBox.fromSize(
                          size: canvasSize,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AnimatedSwitcher(
                                duration: shatter != null
                                    ? Duration.zero
                                    : const Duration(milliseconds: 250),
                                child: BuildStep(
                                  key: ValueKey(index),
                                  step: step,
                                  child: SlideFrame(
                                    slide: slide,
                                    number: index + 1,
                                  ),
                                ),
                              ),
                              if (shatter != null)
                                ShatterOverlay(
                                  key: ObjectKey(shatter),
                                  image: shatter!,
                                  onDone: () => setState(() {
                                    shatter?.dispose();
                                    shatter = null;
                                  }),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (showNotes)
                Container(
                  width: double.infinity,
                  color: const Color(0xFF161B22),
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    '${index + 1}/${deck.length}   ${slide.notes}',
                    style: const TextStyle(fontSize: 20, color: Colors.white70),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The master: background, logo, slide number, section tracker.
class SlideFrame extends StatelessWidget {
  const SlideFrame({super.key, required this.slide, required this.number});
  final Slide slide;
  final int number;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Palette.background),
        Image.asset(
          slide.cover
              ? 'assets/images/bg_cover.png'
              : 'assets/images/bg_dark.png',
          fit: BoxFit.cover,
        ),
        // The corner bird, except where the slide shows the full logo.
        if (!(slide.body is Cover && (slide.body as Cover).logo != null))
          Positioned(
            left: 25,
            top: 46,
            width: 36,
            child: Image.asset('assets/images/logo.png'),
          ),
        slide.body,
        if (!slide.cover) ...[
          Positioned(
            left: 28,
            bottom: 40,
            child: Text('$number', style: zalando(9, color: Palette.muted)),
          ),
          Positioned(right: 70, bottom: 36, child: _Tracker(slide.section)),
        ],
      ],
    ),
  );
}

class _Tracker extends StatelessWidget {
  const _Tracker(this.current);
  final Section? current;

  @override
  Widget build(BuildContext context) {
    if (current == null) return const SizedBox();
    const names = {
      Section.ai: 'AI',
      Section.flutter: 'Flutter',
      Section.us: 'Us',
    };
    final spans = <InlineSpan>[];
    for (final s in Section.values) {
      if (spans.isNotEmpty) {
        spans.add(
          TextSpan(
            text: '  ·  ',
            style: zalando(12, color: Palette.muted),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: names[s],
          style: s == current
              ? zalando(12, weight: 700, color: Palette.accent)
              : zalando(12, color: Palette.muted),
        ),
      );
    }
    return Text.rich(TextSpan(children: spans));
  }
}
