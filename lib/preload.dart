import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'materialize.dart' show helmetReady;
import 'theme.dart';

/// On the web, every image is a network fetch the first time a slide shows
/// it. This holds the deck behind a progress bar until every image is
/// fetched and decoded and the 3D helmet is loaded, so no slide pops in.
class Preloader extends StatefulWidget {
  const Preloader({super.key, required this.child});
  final Widget child;

  @override
  State<Preloader> createState() => _PreloaderState();
}

class _PreloaderState extends State<Preloader> {
  int _done = 0, _total = 1;
  bool _ready = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    // Keep every slide's images decoded: the default cache could evict some.
    PaintingBinding.instance.imageCache.maximumSizeBytes = 1 << 30;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final images = manifest
        .listAssets()
        .where((a) => a.startsWith('assets/images/'))
        .toList();
    if (!mounted) return;
    setState(() => _total = images.length + 1);
    void tick() {
      if (mounted) setState(() => _done++);
    }

    await Future.wait([
      for (final a in images)
        precacheImage(
          AssetImage(a),
          context,
          onError: (_, _) {},
        ).whenComplete(tick),
      helmetReady().whenComplete(tick),
    ]).timeout(
      // A stuck fetch shouldn't hold the talk hostage: start anyway.
      const Duration(seconds: 45),
      onTimeout: () => [],
    );
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    final p = _done / _total;
    return Material(
      color: Palette.background,
      child: Center(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', width: 56),
              const SizedBox(height: 24),
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.centerLeft,
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 200),
                  widthFactor: p,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Palette.accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Loading slides  $_done / $_total',
                style: zalando(10, color: Palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
