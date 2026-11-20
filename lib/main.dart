import 'package:flutter/material.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'deck.dart';
import 'layouts.dart';
import 'theme.dart';

void main() => runApp(const KeynoteApp());

class KeynoteApp extends StatelessWidget {
  const KeynoteApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FlutterCon India 2026',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: const Presenter(),
  );
}

/// Keys: → / space / PageDown next, ← / PageUp back, Home / End,
/// N toggles speaker notes.
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

  @override
  void initState() {
    super.initState();
    // Global handler: works whatever has focus (the Focus widget missed keys
    // when the window opened without focus).
    HardwareKeyboard.instance.addHandler(_onKey);
    // --dart-define=SNAP=/path.png captures the slide after a few seconds
    // and quits; used to check the live 3D slide without a human.
    const snap = String.fromEnvironment('SNAP');
    if (snap.isNotEmpty) {
      const melt = int.fromEnvironment('SNAP_STEP_MS');
      if (melt > 0) {
        Future.delayed(const Duration(milliseconds: melt), next);
      }
      const at = int.fromEnvironment('SNAP_MS', defaultValue: 10000);
      Future.delayed(const Duration(milliseconds: at), () async {
        final ro =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await ro.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final out = File('${Directory.systemTemp.path}/$snap');
        out.writeAsBytesSync(bytes!.buffer.asUint8List());
        debugPrint('SNAP_WRITTEN ${out.path}');
        exit(0);
      });
    }
  }

  void go(int i, {bool atEnd = false}) => setState(() {
    index = i.clamp(0, deck.length - 1);
    step = atEnd ? deck[index].builds : 0;
  });

  void next() =>
      step < deck[index].builds ? setState(() => step++) : go(index + 1);

  void back() => step > 0 ? setState(() => step--) : go(index - 1, atEnd: true);

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
          onTap: next,
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
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: BuildStep(
                              key: ValueKey(index),
                              step: step,
                              child: SlideFrame(
                                slide: slide,
                                number: index + 1,
                              ),
                            ),
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
