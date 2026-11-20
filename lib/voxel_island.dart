import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/noise.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// A live, procedurally generated voxel island in a lagoon, rendered with
/// Flutter Scene. The camera drifts slowly around it.
class VoxelIsland extends StatefulWidget {
  const VoxelIsland({super.key});

  @override
  State<VoxelIsland> createState() => _VoxelIslandState();
}

class _VoxelIslandState extends State<VoxelIsland> {
  final Scene scene = Scene();
  bool ready = false;

  static const size = 56; // blocks per side
  static const waterLevel = 3.0;

  @override
  void initState() {
    super.initState();
    Scene.initializeStaticResources().then((_) {
      _build();
      if (mounted) setState(() => ready = true);
    });
  }

  void _build() {
    final noise = FastNoiseLite(seed: 2026)
      ..noiseType = NoiseType.openSimplex2
      ..fractalType = FractalType.fbm
      ..octaves = 4
      ..frequency = 0.06;

    final blocks = InstancedMesh(
      geometry: CuboidGeometry(vm.Vector3(1, 1, 1)),
      material: PhysicallyBasedMaterial()..roughnessFactor = 0.9,
    );
    final leaves = InstancedMesh(
      geometry: CuboidGeometry(vm.Vector3(1, 1, 1)),
      material: PhysicallyBasedMaterial()..roughnessFactor = 0.8,
    );

    final sand = vm.Vector4(0.86, 0.78, 0.55, 1);
    final grass = vm.Vector4(0.33, 0.62, 0.22, 1);
    final dirt = vm.Vector4(0.45, 0.33, 0.2, 1);
    final stone = vm.Vector4(0.5, 0.5, 0.52, 1);
    final bark = vm.Vector4(0.36, 0.25, 0.15, 1);

    final rng = math.Random(7);
    const half = size / 2;
    for (var x = 0; x < size; x++) {
      for (var z = 0; z < size; z++) {
        final dx = (x - half) / half, dz = (z - half) / half;
        final falloff = 1 - math.sqrt(dx * dx + dz * dz);
        final n = noise.getNoise2(x.toDouble(), z.toDouble());
        final h = (falloff * 9 + n * 4.5).round();
        if (h < 1) continue; // open water
        final top = h;
        final isBeach = top <= waterLevel + 1;
        for (var y = math.max(0, top - 3); y < top; y++) {
          final color = y == top - 1
              ? (isBeach ? sand : (top > 10 ? stone : grass))
              : (isBeach ? sand : dirt);
          blocks.addInstance(
            vm.Matrix4.translation(vm.Vector3(x - half, y + 0.5, z - half)),
            color: color,
          );
        }
        // A few trees on the grass.
        if (!isBeach && top <= 10 && rng.nextDouble() < 0.035) {
          final trunk = 3 + rng.nextInt(2);
          for (var t = 0; t < trunk; t++) {
            blocks.addInstance(
              vm.Matrix4.translation(
                vm.Vector3(x - half, top + t + 0.5, z - half),
              ),
              color: bark,
            );
          }
          for (var lx = -1; lx <= 1; lx++) {
            for (var lz = -1; lz <= 1; lz++) {
              for (var ly = 0; ly < 2; ly++) {
                if (ly == 1 && lx.abs() + lz.abs() == 2) continue;
                final shade = 0.85 + rng.nextDouble() * 0.3;
                leaves.addInstance(
                  vm.Matrix4.translation(
                    vm.Vector3(
                      x - half + lx,
                      top + trunk + ly + 0.5,
                      z - half + lz,
                    ),
                  ),
                  color: vm.Vector4(0.25 * shade, 0.58 * shade, 0.2 * shade, 1),
                );
              }
            }
          }
        }
      }
    }
    scene.add(Node()..addComponent(InstancedMeshComponent(blocks)));
    scene.add(Node()..addComponent(InstancedMeshComponent(leaves)));

    // Lagoon: a glossy plane just under the beach line.
    final water = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.12, 0.55, 0.78, 1)
      ..roughnessFactor = 0.04
      ..metallicFactor = 0.0;
    scene.add(
      Node(
        mesh: Mesh(PlaneGeometry(width: 4000, depth: 4000), water),
        localTransform: vm.Matrix4.translation(
          vm.Vector3(0, waterLevel - 0.15, 0),
        ),
      ),
    );

    final sky = PhysicalSkySource(
      sunDirection: vm.Vector3(-0.5, 0.45, 0.6).normalized(),
    );
    scene.skyEnvironment = SkyEnvironment(sky);
    scene.sunLight = SunLight(sky);

    scene.environmentSettings = EnvironmentSettings(
      toneMapping: ToneMappingMode.aces,
      exposure: 1.0,
      colorGradingEnabled: true,
      saturation: 1.15,
      contrast: 1.05,
      bloomEnabled: true,
      bloomThreshold: 1.0,
      bloomIntensity: 0.2,
      bloomScatter: 0.7,
      ambientOcclusionEnabled: true,
      ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
      ambientOcclusionHalfResolution: true,
      screenSpaceReflectionsEnabled: true,
      screenSpaceReflectionsIntensity: 1.0,
      godRaysEnabled: true,
      godRaysIntensity: 0.8,
      godRaysDensity: 0.5,
      godRaysColor: vm.Vector3(1.0, 0.95, 0.85),
      vignetteEnabled: true,
      vignetteIntensity: 0.25,
    );
  }

  @override
  Widget build(BuildContext context) {
    // A painted sky behind the scene; the scene clears to transparent.
    const sky = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A90D9), Color(0xFFA9D4F5), Color(0xFFE8F4FF)],
        ),
      ),
    );
    if (!ready) return sky;
    return Stack(fit: StackFit.expand, children: [sky, _view()]);
  }

  Widget _view() {
    return SceneView(
      scene,
      cameraBuilder: (elapsed) {
        final a = elapsed.inMilliseconds / 1000 * 0.06;
        return PerspectiveCamera(
          position: vm.Vector3(math.cos(a) * 40, 13, math.sin(a) * 40),
          target: vm.Vector3(0, 4, 0),
        );
      },
    );
  }
}
