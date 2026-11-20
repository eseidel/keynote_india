// Web stand-in for snap_io.dart: there is no file system or exit on the web,
// and SNAP is only ever used against the macOS app.

String writeSnap(String name, List<int> bytes) =>
    throw UnsupportedError('SNAP is not supported on the web');

Never quit() => throw UnsupportedError('SNAP is not supported on the web');
