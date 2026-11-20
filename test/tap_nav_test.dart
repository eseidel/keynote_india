import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keynote_india/deck.dart';
import 'package:keynote_india/main.dart';

// A touch on the left third goes back; anywhere else advances.
void main() {
  int shown(WidgetTester tester) =>
      tester.widget<SlideFrame>(find.byType(SlideFrame).last).number;

  Future<void> tap(
    WidgetTester tester,
    double x,
    PointerDeviceKind kind,
  ) async {
    await tester.tapAt(Offset(x, 400), kind: kind);
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('touch: left third back, the rest forward', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Presenter()));
    expect(shown(tester), 1);
    // Past slide 1's builds, onto slide 2.
    for (var i = 0; i <= deck[0].builds; i++) {
      await tap(tester, 300, PointerDeviceKind.touch);
    }
    expect(shown(tester), 2);
    await tap(tester, 60, PointerDeviceKind.touch);
    expect(shown(tester), 1);
    // A mouse click advances wherever it lands.
    await tap(tester, 60, PointerDeviceKind.mouse);
    expect(shown(tester), 2); // back landed past its builds
  });
}
