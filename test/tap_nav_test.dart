import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keynote_india/deck.dart';
import 'package:keynote_india/layouts.dart';
import 'package:keynote_india/main.dart';

// A touch on the left third goes back (a build, then a slide); anywhere else
// advances; a mouse click always advances.
void main() {
  testWidgets('touch: left third back, the rest forward', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // A slide with builds, after one without, so back walks both.
    final i = deck.indexWhere((s) => s.builds > 0 && !s.shatterOut, 1);
    expect(deck[i - 1].shatterOut, isFalse);
    await tester.pumpWidget(MaterialApp(home: Presenter(initial: i)));
    final probe = _PresenterProbe(tester);
    expect(probe.slide, i + 1);

    await probe.tap(300); // right: reveals a build
    expect((probe.slide, probe.step), (i + 1, 1));
    await probe.tap(129); // just inside the left third: hides it
    expect((probe.slide, probe.step), (i + 1, 0));
    await probe.tap(131); // just past it: forward again
    expect((probe.slide, probe.step), (i + 1, 1));
    await probe.tap(60);
    await probe.tap(60); // past the first build: the slide before
    expect(probe.slide, i);

    await probe.tap(60, kind: PointerDeviceKind.mouse); // a click advances
    expect(probe.slide, i + 1);
    await probe.tap(60, kind: PointerDeviceKind.stylus); // a pen goes back
    expect(probe.slide, i);
  });
}

class _PresenterProbe {
  _PresenterProbe(this.tester);
  final WidgetTester tester;

  int get slide =>
      tester.widget<SlideFrame>(find.byType(SlideFrame).last).number;
  int get step => tester.widget<BuildStep>(find.byType(BuildStep).last).step;

  Future<void> tap(
    double x, {
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) async {
    await tester.tapAt(Offset(x, 400), kind: kind);
    await tester.pump(const Duration(seconds: 1));
  }
}
