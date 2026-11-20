// The Flutter Scene "Materialize" showcase, ported from
// flutter_scene/examples/flutter_app/lib/example_materialize.dart (bdero),
// trimmed for a slide: no panels, bundled assets (no network), and driven by
// the slide's builds.
//
// Entrance: the DamagedHelmet phases in bottom to top: a glowing wireframe,
// then glass shards flying in, then the real PBR surface behind a hot seam.
// Exit (the slide's one build): the same sweep runs backwards, faster, and
// the helmet dissolves back into shards and wire.
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart' hide Material;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'layouts.dart' show BuildStep;

// The example's tuned look.
abstract final class _Look {
  static const wireThickness = 0.002;
  static final wireColor = vm.Vector3(0.16, 0.64, 1.0);
  static const wireAlpha = 0.85, wireGlow = 27.5;
  static final glassTint = vm.Vector3(0.5, 0.85, 1.0);
  static const glassAlpha = 0.2;
  static final glassGlowColor = vm.Vector3(1.0, 1.0, 0.6);
  static const glassGlowStrength = 1.9;
  static final flyDir = vm.Vector3(0.0, 1.0, 0.0);
  static const flyDistance = 0.0, centerDistance = 0.45, normalDistance = 1.5;
  static const jitter = 0.32, fadePortion = 0.64, coolSpan = 0.62;
  static const tumble = 2.3, glassBand = 0.84;
  static const seamWidth = 0.12;
  static final seamColor = vm.Vector3(0.3, 0.9, 1.0);
  static const seamStrength = 40.0;
  static final noiseScale = vm.Vector3(3.4, 0.5, 3.9);
  static const noiseAmp = 0.11;
  static const lagWireToGlass = 0.0, lagGlassToSolid = 1.5;
  static const sweepPad = 0.15;

  /// Seconds for the full materialize; the exit runs at [exitSpeed]x.
  static const duration = 7.0, exitSpeed = 2.2;
}

class MaterializeHelmet extends StatefulWidget {
  const MaterializeHelmet({super.key});

  @override
  State<MaterializeHelmet> createState() => _MaterializeHelmetState();
}

/// The loaded demo: one scene, built once at app start (see
/// [preloadHelmet]) so the slide starts the moment it appears.
class _Helmet {
  static final _Helmet instance = _Helmet();
  final Scene scene = Scene();
  late final Future<void> ready = _load();

  final List<PreprocessedMaterial> _shellMaterials = [];
  final List<(PreprocessedMaterial, LineSegmentsGeometry)> _wirePasses = [];
  final List<(Node, PreprocessedMaterial)> _glassPasses = [];
  final Node spin = Node(name: 'materialize_spin');

  double _minH = 0, _maxH = 1;
  final vm.Vector3 _center = vm.Vector3.zero();
  double get _range => math.max(_maxH - _minH, 1e-3);
  PerspectiveCamera camera = PerspectiveCamera(position: vm.Vector3(0, 0, -3));

  Future<void> _load() async {
    try {
      await Scene.initializeStaticResources();
      final data = await rootBundle.load('models/DamagedHelmet.glb');
      final helmet = await Node.fromGlbBytes(data.buffer.asUint8List());

      for (final meshNode in helmet.meshNodes.toList()) {
        final parts = <MeshData>[];
        for (final primitive in meshNode.mesh!.primitives) {
          parts.add(primitive.geometry.extractMeshData());
          final shell = await loadFmatMaterial('assets/materialize_shell.fmat');
          _bindShellInputs(shell, primitive.material);
          primitive.material = shell;
          _shellMaterials.add(shell);
        }
        final derived = await compute(_derive, MeshData.merge(parts));

        final wire = await loadFmatMaterial(
          'assets/materialize_wireframe.fmat',
        );
        final wireGeometry = LineSegmentsGeometry(
          derived.edges,
          normalOffset: 0.002,
        );
        meshNode.add(
          Node(name: 'materialize_wire', mesh: Mesh(wireGeometry, wire)),
        );
        _wirePasses.add((wire, wireGeometry));

        final glass = await loadFmatMaterial('assets/materialize_glass.fmat');
        final glassNode = Node(
          name: 'materialize_glass',
          mesh: Mesh(MeshGeometry.fromMeshData(derived.shards), glass),
        );
        meshNode.add(glassNode);
        _glassPasses.add((glassNode, glass));
      }

      final bounds =
          helmet.combinedWorldBounds ??
          (throw StateError('Model has no computable bounds.'));
      _minH = bounds.min.y;
      _maxH = bounds.max.y;
      _center.setFrom(bounds.center);
      spin.add(helmet);
      scene.add(spin);
      camera = PerspectiveCamera.framing(
        bounds,
        direction: vm.Vector3(0.4, 0.5, -2.6),
      );

      await scene.loadEnvironment(
        'models/helipad.hdr',
        showSkybox: false,
        exposure: 2.03,
        intensity: 1.36,
        rotationY: -80.7 * math.pi / 180,
        maxWidth: 2048,
      );
      scene.environmentSettings = EnvironmentSettings(
        toneMapping: ToneMappingMode.aces,
        exposure: 2.03,
        bloomEnabled: true,
        bloomThreshold: 1.0,
        bloomIntensity: 0.25,
        bloomScatter: 0.7,
        vignetteEnabled: true,
        vignetteIntensity: 0.3,
      );

      _applySettings();
      applyProgress(0, 0);
    } catch (e, st) {
      debugPrint('Materialize failed: $e\n$st');
      rethrow;
    }
  }

  void _bindShellInputs(PreprocessedMaterial shell, Material imported) {
    if (imported is! PhysicallyBasedMaterial) return;
    void bind(String name, TextureSource? source) {
      final texture = source?.sampledTexture;
      if (texture == null) return;
      shell.parameters.setTexture(
        name,
        texture,
        sampler: source!.sampledSampler,
      );
    }

    bind('base_color_texture', imported.baseColorTexture);
    bind('metallic_roughness_texture', imported.metallicRoughnessTexture);
    bind('normal_texture', imported.normalTexture);
    bind('occlusion_texture', imported.occlusionTexture);
    bind('emissive_texture', imported.emissiveTexture);
    shell.parameters
      ..setVec4('base_color_factor', imported.baseColorFactor)
      ..setFloat('metallic_factor', imported.metallicFactor)
      ..setFloat('roughness_factor', imported.roughnessFactor)
      ..setVec3('emissive_factor', imported.emissiveFactor.rgb)
      ..setFloat('normal_scale', imported.normalScale)
      ..setFloat('occlusion_strength', imported.occlusionStrength);
  }

  void _applySettings() {
    final range = _range;
    final noiseScale = _Look.noiseScale / range;
    const noiseAmpFrac = _Look.noiseAmp;
    final noiseAmp = noiseAmpFrac * range;
    for (final (wire, wireGeometry) in _wirePasses) {
      wireGeometry.width = range * _Look.wireThickness;
      wire.parameters
        ..setFloat('band', range * 0.06)
        ..setVec4(
          'wire_color',
          vm.Vector4(
            _Look.wireColor.x,
            _Look.wireColor.y,
            _Look.wireColor.z,
            _Look.wireAlpha,
          ),
        )
        ..setFloat('glow_strength', _Look.wireGlow)
        ..setVec3('noise_scale', noiseScale)
        ..setFloat('noise_amp', noiseAmp);
    }
    for (final (_, glass) in _glassPasses) {
      glass.parameters
        ..setFloat('band', range * _Look.glassBand)
        ..setVec3('fly_dir', _Look.flyDir)
        ..setFloat('fly_distance', range * _Look.flyDistance)
        ..setFloat('center_distance', range * _Look.centerDistance)
        ..setFloat('normal_distance', range * _Look.normalDistance)
        ..setFloat('jitter', range * _Look.jitter)
        ..setFloat('fade_portion', _Look.fadePortion)
        ..setFloat('cool_span', _Look.coolSpan)
        ..setFloat('tumble', _Look.tumble)
        ..setVec4(
          'glass_color',
          vm.Vector4(
            _Look.glassTint.x,
            _Look.glassTint.y,
            _Look.glassTint.z,
            _Look.glassAlpha,
          ),
        )
        ..setVec3('glow_color', _Look.glassGlowColor)
        ..setFloat('glow_strength', _Look.glassGlowStrength)
        ..setVec3('noise_scale', noiseScale)
        ..setFloat('noise_amp', noiseAmp);
    }
    for (final shell in _shellMaterials) {
      shell.parameters
        ..setFloat('seam_width', range * _Look.seamWidth)
        ..setVec4(
          'seam_color',
          vm.Vector4(
            _Look.seamColor.x,
            _Look.seamColor.y,
            _Look.seamColor.z,
            1,
          ),
        )
        ..setFloat('seam_strength', _Look.seamStrength)
        ..setVec3('noise_scale', noiseScale)
        ..setFloat('noise_amp', noiseAmp);
    }
  }

  void applyProgress(double progress, double elapsedSeconds) {
    final p = progress.clamp(0.0, 1.0);
    final eased = p * p * (3 - 2 * p);
    const pad = _Look.sweepPad + _Look.noiseAmp;
    const start = -pad;
    const end = 1.0 + _Look.lagWireToGlass + _Look.lagGlassToSolid + pad;
    final wireN = start + eased * (end - start);
    double front(double n) => _minH + n * _range;
    final wireFront = front(wireN);
    final glassFront = front(wireN - _Look.lagWireToGlass);
    final solidFront = front(
      wireN - _Look.lagWireToGlass - _Look.lagGlassToSolid,
    );
    final center = vm.Vector3.copy(_center);
    spin.globalTransform.transform3(center);
    for (final (wire, _) in _wirePasses) {
      wire.parameters
        ..setFloat('wire_front', wireFront)
        ..setFloat('solid_front', solidFront);
    }
    for (final (node, glass) in _glassPasses) {
      glass.parameters
        ..setFloat('glass_front', glassFront)
        ..setFloat('solid_front', solidFront)
        ..setFloat('time', elapsedSeconds)
        ..setVec3('model_center', center)
        ..setMat4('model_matrix', node.globalTransform);
    }
    for (final shell in _shellMaterials) {
      shell.parameters.setFloat('solid_front', solidFront);
    }
  }
}

/// Starts loading the helmet demo; call once at app start.
void preloadHelmet() => _Helmet.instance.ready.ignore();

class _MaterializeHelmetState extends State<MaterializeHelmet> {
  final _Helmet h = _Helmet.instance;
  bool _ready = false;
  Object? _error;

  // Progress 0 (nothing) to 1 (solid): it starts building on the first frame.
  double _progress = 0;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    h.applyProgress(0, 0);
    h.ready.then(
      (_) => mounted ? setState(() => _ready = true) : null,
      onError: (Object e) => mounted ? setState(() => _error = e) : null,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _exiting = BuildStep.of(context) >= 1;
  }

  void _tick(Duration elapsed, double dt) {
    final seconds = elapsed.inMicroseconds / 1e6;
    if (_exiting) {
      _progress = math.max(
        0,
        _progress - dt * _Look.exitSpeed / _Look.duration,
      );
    } else {
      _progress = math.min(1, _progress + dt / _Look.duration);
    }
    h.spin.localTransform = vm.Matrix4.rotationY(seconds * 0.25);
    h.applyProgress(_progress, seconds);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(
          '3D failed: $_error',
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
    if (!_ready) return const SizedBox.expand();
    return SceneView(h.scene, camera: h.camera, onTick: _tick);
  }
}

({MeshData shards, LineSegmentData edges}) _derive(MeshData source) => (
  shards: source.unweld(
    attributes: {UnweldAttribute.centroid, UnweldAttribute.seed},
  ),
  edges: source.extractEdges(),
);
