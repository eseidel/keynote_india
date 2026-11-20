import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Material;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Freezes the shatter at this many seconds, for checking frames (set by
/// the SNAP harness in main.dart); null runs on the real clock.
final shatterClock = ValueNotifier<double?>(null);

/// A slide transition: a snapshot of the outgoing slide, cut into glass
/// shards in a Flutter Scene, cracks outward from an impact point and blows
/// toward the audience, revealing the next slide underneath.
class ShatterOverlay extends StatefulWidget {
  const ShatterOverlay({super.key, required this.image, required this.onDone});

  /// The outgoing slide, captured at canvas size.
  final ui.Image image;
  final VoidCallback onDone;

  @override
  State<ShatterOverlay> createState() => _ShatterOverlayState();
}

class _Shard {
  _Shard(this.node, this.home, this.delay, this.velocity, this.axis, this.spin);
  final Node node;
  final vm.Vector3 home;
  final double delay;
  final vm.Vector3 velocity;
  final vm.Vector3 axis;
  final double spin;
}

class _ShatterOverlayState extends State<ShatterOverlay> {
  final Scene scene = Scene();
  final List<_Shard> shards = [];
  bool ready = false;
  bool done = false;

  // The glass pane is 16 x 9 world units, framed to fill the view exactly.
  static const w = 16.0, h = 9.0, cols = 18, rows = 10;
  static const fov = 30 * math.pi / 180;
  static const duration = 2.0;

  /// Half of g, in world units (the pane is 9 tall) per second squared.
  static const gravity = 8.0;

  /// The black behind the glass fades over this window, so the next slide
  /// comes up under the last falling shards.
  static const revealStart = 1.2, revealEnd = 1.8;
  final reveal = ValueNotifier<double>(0);
  static final impact = vm.Vector2(1.5, 0.6); // a little right of center

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    await Scene.initializeStaticResources();
    final texture = await Texture2D.fromImage(widget.image, opaque: true);
    final material = UnlitMaterial(colorTexture: texture)..doubleSided = true;
    final rng = math.Random(38);

    // A jittered grid of points (edges kept straight), each cell split
    // into two triangles along a random diagonal.
    final pts = List.generate(rows + 1, (r) {
      return List.generate(cols + 1, (c) {
        var x = -w / 2 + w * c / cols, y = h / 2 - h * r / rows;
        if (c > 0 && c < cols) x += (rng.nextDouble() - 0.5) * w / cols * 0.8;
        if (r > 0 && r < rows) y += (rng.nextDouble() - 0.5) * h / rows * 0.8;
        return vm.Vector2(x, y);
      });
    });
    const maxDist = 11.0;
    void shard(vm.Vector2 a, vm.Vector2 b, vm.Vector2 c) {
      final centroid = (a + b + c) / 3;
      final g = GeometryBuilder();
      for (final p in [a, b, c]) {
        g.texCoord(vm.Vector2((p.x + w / 2) / w, (h / 2 - p.y) / h));
        g.normal(vm.Vector3(0, 0, -1));
        g.addVertex(vm.Vector3(p.x - centroid.x, p.y - centroid.y, 0));
      }
      g.addTriangle(0, 1, 2);
      final home = vm.Vector3(centroid.x, centroid.y, 0);
      final node = Node(
        mesh: Mesh(g.build(), material),
        localTransform: vm.Matrix4.translation(home),
      );
      scene.add(node);
      final away = centroid - impact;
      final d = away.length;
      final out = d < 1e-3 ? vm.Vector2(0, 1) : away / d;
      final near = math.max(0.0, 1 - d / maxDist);
      final burst = 0.4 + rng.nextDouble() * 1.0 + near * 2.0;
      shards.add(
        _Shard(
          node,
          home,
          // The crack runs out from the impact, so the far edges hold a
          // beat longer and the title visibly breaks before it drops.
          (d / maxDist) * 0.6 + rng.nextDouble() * 0.08,
          // Outward, a small kick up, and toward the camera: hard near the
          // impact, gently elsewhere, so most glass stays in view and falls.
          vm.Vector3(
            out.x * burst,
            out.y * burst + 1,
            -(0.5 + rng.nextDouble() * 2.5 + near * near * 9),
          ),
          vm.Vector3(
            rng.nextDouble() - 0.5,
            rng.nextDouble() - 0.5,
            rng.nextDouble() - 0.5,
          ).normalized(),
          1.5 + rng.nextDouble() * 4,
        ),
      );
    }

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final p00 = pts[r][c], p10 = pts[r][c + 1];
        final p01 = pts[r + 1][c], p11 = pts[r + 1][c + 1];
        if (rng.nextBool()) {
          shard(p00, p10, p11);
          shard(p00, p11, p01);
        } else {
          shard(p00, p10, p01);
          shard(p10, p11, p01);
        }
      }
    }
    scene.toneMapping = ToneMappingMode.linear;
    scene.exposure = 1.0;
    if (mounted) setState(() => ready = true);
  }

  double? _t0;

  void _tick(Duration elapsed, double dt) {
    // SceneView's clock doesn't start at this overlay; measure from our
    // first frame.
    final now = elapsed.inMicroseconds / 1e6;
    var t = now - (_t0 ??= now);
    final frozen = shatterClock.value;
    if (frozen != null) t = frozen;
    for (final s in shards) {
      final local = math.max(0.0, t - s.delay);
      // A hairline crack first: shards barely move for a beat.
      final crack = math.min(local, 0.08);
      final fly = math.max(0.0, local - 0.08);
      final pos =
          s.home +
          s.velocity * (crack * 0.15 + fly) +
          vm.Vector3(0, -gravity * fly * fly, 0);
      final rot = vm.Quaternion.axisAngle(s.axis, s.spin * fly);
      // A fresh matrix per node: the setter keeps the reference.
      s.node.localTransform = vm.Matrix4.compose(pos, rot, vm.Vector3.all(1));
    }
    reveal.value = ((t - revealStart) / (revealEnd - revealStart)).clamp(
      0.0,
      1.0,
    );
    if (t > duration && !done && frozen == null) {
      done = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
    }
  }

  @override
  void dispose() {
    scene.removeAll();
    reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Until the shards are built, hold the outgoing slide on screen.
    if (!ready) return RawImage(image: widget.image, fit: BoxFit.fill);
    final d = (h / 2) / math.tan(fov / 2);
    return Stack(
      fit: StackFit.expand,
      children: [
        ValueListenableBuilder(
          valueListenable: reveal,
          builder: (_, r, _) =>
              ColoredBox(color: Colors.black.withValues(alpha: 1 - r)),
        ),
        SceneView(
          scene,
          camera: PerspectiveCamera(
            fovRadiansY: fov,
            position: vm.Vector3(0, 0, -d),
            target: vm.Vector3.zero(),
          ),
          onTick: _tick,
        ),
      ],
    );
  }
}
