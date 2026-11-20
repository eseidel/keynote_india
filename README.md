# FlutterCon India 2026 keynote

The keynote deck as a Flutter app. Content is in `lib/deck.dart`, layouts in `lib/layouts.dart`, the live 3D slide in `lib/voxel_island.dart`.

    flutter run -d macos --enable-flutter-gpu --release            # present
    flutter run -d macos --enable-flutter-gpu --dart-define=SLIDE=38  # start at a slide
    flutter test --update-goldens test/render_slides_test.dart     # render every slide to test/goldens/

Keys: → / space / click advance (including builds), ← back, Home/End, N shows speaker notes.
