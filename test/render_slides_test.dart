// Renders every slide to test/goldens/slide_NN.png for review:
//   flutter test --update-goldens test/render_slides_test.dart
// The live 3D slide is skipped (it needs Flutter GPU).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keynote_india/deck.dart';
import 'package:keynote_india/layouts.dart';
import 'package:keynote_india/main.dart';
import 'package:keynote_india/theme.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Zalando Sans')
      ..addFont(rootBundle.load('assets/fonts/ZalandoSans.ttf'));
    await font.load();
  });

  for (final (i, slide) in deck.indexed) {
    final n = (i + 1).toString().padLeft(2, '0');
    testWidgets('slide $n', (tester) async {
      tester.view.physicalSize = canvasSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            child: SlideFrame(slide: slide, number: i + 1),
          ),
        ),
      );
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('goldens/slide_$n.png'),
      );
    }, skip: slide.body is FullBleed3D);
  }
  test(
    'font file exists',
    () => expect(File('assets/fonts/ZalandoSans.ttf').existsSync(), isTrue),
  );
}
