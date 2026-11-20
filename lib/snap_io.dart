// The SNAP capture hook's file output (see Presenter._snapAll): native only.
import 'dart:io';

/// Writes [bytes] to [name] in the system temp dir; returns the path.
String writeSnap(String name, List<int> bytes) {
  final out = File('${Directory.systemTemp.path}/$name');
  out.writeAsBytesSync(bytes);
  return out.path;
}

/// Quits the app once the snaps are written.
Never quit() => exit(0);
