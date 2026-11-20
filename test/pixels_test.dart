import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keynote_india/whimsy_pixels.dart';

void main() {
  testWidgets('hovering scatters, a tap still reaches the presenter', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GestureDetector(
          onTap: () => taps++,
          child: const PixelStatement('You own every pixel'),
        ),
      ),
    );
    await tester.pumpAndSettle(); // the entry assembly settles
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byType(PixelStatement)));
    await mouse.moveBy(const Offset(1, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue); // scattering
    await mouse.down(tester.getCenter(find.byType(PixelStatement)));
    await mouse.up();
    await tester.pump();
    expect(taps, 1, reason: 'mouse');
    await tester.tapAt(const Offset(5, 5));
    expect(taps, 2, reason: 'touch');
    await mouse.removePointer();
    await tester.pumpAndSettle(); // springs back and stops ticking
  });
}
