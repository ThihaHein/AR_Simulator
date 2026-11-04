// lib/engine/models.dart
// ---------------------------------------------------------------------------
// 3D model definitions. Each model arranges 10,000 particles into a shape.
// Particles are positioned in world space (-kWorldHalf..kWorldHalf).
// The simulation engine animates them from there.
// ---------------------------------------------------------------------------

import 'dart:math';
import 'dart:typed_data';
import 'simulation_3d.dart';

enum ModelType {
  atoms,
  car,
  building,
  sphere,
  dna,
  heart,
  galaxy,
  human,
}

class ModelInfo {
  final ModelType type;
  final String name;
  final String icon;
  final String description;

  const ModelInfo({
    required this.type,
    required this.name,
    required this.icon,
    required this.description,
  });
}

const List<ModelInfo> kModels = [
  ModelInfo(type: ModelType.atoms, name: 'ATOMS', icon: '⚛️', description: 'Chaotic particles'),
  ModelInfo(type: ModelType.car, name: 'CAR', icon: '🏎️', description: 'Sports car silhouette'),
  ModelInfo(type: ModelType.building, name: 'TOWER', icon: '🏙️', description: 'Skyscraper'),
  ModelInfo(type: ModelType.sphere, name: 'SPHERE', icon: '🌍', description: 'Globe'),
  ModelInfo(type: ModelType.dna, name: 'DNA', icon: '🧬', description: 'Double helix'),
  ModelInfo(type: ModelType.heart, name: 'HEART', icon: '❤️', description: 'Heart shape'),
  ModelInfo(type: ModelType.galaxy, name: 'GALAXY', icon: '🌀', description: 'Spiral galaxy'),
  ModelInfo(type: ModelType.human, name: 'HUMAN', icon: '🧍', description: 'Human figure'),
];

// ---------------------------------------------------------------------------
// Generator
// ---------------------------------------------------------------------------
class ModelGenerator {
  static final _rng = Random(42);

  static void generate(
      ModelType type,
      Float64List px, Float64List py, Float64List pz,
      Float64List vx, Float64List vy, Float64List vz,
      Uint8List colorIdx,
      int count,
      ) {
    switch (type) {
      case ModelType.atoms:
        _generateAtoms(px, py, pz, vx, vy, vz, colorIdx, count);
      case ModelType.car:
        _generateCar(px, py, pz, vx, vy, vz, colorIdx, count);
      case ModelType.building:
        _generateBuilding(px, py, pz, vx, vy, vz, colorIdx, count);
      case ModelType.sphere:
        _generateSphere(px, py, pz, vx, vy, vz, colorIdx, count);
      case ModelType.dna:
        _generateDNA(px, py, pz, vx, vy, vz, colorIdx, count);
      case ModelType.heart:
        _generateHeart(px, py, pz, vx, vy, vz, colorIdx, count);
      case ModelType.galaxy:
        _generateGalaxy(px, py, pz, vx, vy, vz, colorIdx, count);
      case ModelType.human:
        _generateHuman(px, py, pz, vx, vy, vz, colorIdx, count);
    }
  }

  // --- Atoms: random in cube ---
  static void _generateAtoms(
      Float64List px, Float64List py, Float64List pz,
      Float64List vx, Float64List vy, Float64List vz,
      Uint8List colorIdx, int count) {
    for (int i = 0; i < count; i++) {
      px[i] = (_rng.nextDouble() - 0.5) * kWorldHalf * 1.8;
      py[i] = (_rng.nextDouble() - 0.5) * kWorldHalf * 1.8;
      pz[i] = (_rng.nextDouble() - 0.5) * kWorldHalf * 1.8;
      final a = _rng.nextDouble() * 2 * pi;
      final b = _rng.nextDouble() * 2 * pi;
      final s = 20 + _rng.nextDouble() * 80;
      vx[i] = cos(a) * cos(b) * s;
      vy[i] = sin(a) * s;
      vz[i] = cos(a) * sin(b) * s;
      colorIdx[i] = _rng.nextInt(6);
    }
  }

  // --- Car: low-poly sports car shape ---
  static void _generateCar(
      Float64List px, Float64List py, Float64List pz,
      Float64List vx, Float64List vy, Float64List vz,
      Uint8List colorIdx, int count) {
    final scale = kWorldHalf * 0.8;
    for (int i = 0; i < count; i++) {
      final t = _rng.nextDouble();

      if (t < 0.4) {
        // Body (long flat box)
        px[i] = (_rng.nextDouble() - 0.5) * scale * 2.0;
        py[i] = (_rng.nextDouble() - 0.5) * scale * 0.3 + scale * 0.15;
        pz[i] = (_rng.nextDouble() - 0.5) * scale * 0.7;
        colorIdx[i] = 0; // red
      } else if (t < 0.6) {
        // Cabin (smaller box on top)
        px[i] = (_rng.nextDouble() - 0.5) * scale * 0.9 - scale * 0.1;
        py[i] = (_rng.nextDouble() - 0.5) * scale * 0.35 - scale * 0.2;
        pz[i] = (_rng.nextDouble() - 0.5) * scale * 0.6;
        colorIdx[i] = 5; // blue (windows)
      } else if (t < 0.7) {
        // Hood (front slope)
        final u = _rng.nextDouble();
        px[i] = scale * 0.5 + u * scale * 0.4;
        py[i] = scale * 0.15 - u * scale * 0.2 + (_rng.nextDouble() - 0.5) * 10;
        pz[i] = (_rng.nextDouble() - 0.5) * scale * 0.65;
        colorIdx[i] = 0; // red
      } else if (t < 0.8) {
        // Rear
        final u = _rng.nextDouble();
        px[i] = -scale * 0.8 - u * scale * 0.2;
        py[i] = (_rng.nextDouble() - 0.5) * scale * 0.35;
        pz[i] = (_rng.nextDouble() - 0.5) * scale * 0.65;
        colorIdx[i] = 0; // red
      } else {
        // Wheels (4 circles)
        final wheel = _rng.nextInt(4);
        final wx = (wheel < 2 ? 1 : -1) * scale * 0.6;
        final wz = (wheel % 2 == 0 ? 1 : -1) * scale * 0.35;
        final angle = _rng.nextDouble() * 2 * pi;
        final r = scale * 0.15 * sqrt(_rng.nextDouble());
        px[i] = wx + cos(angle) * r * 0.3;
        py[i] = scale * 0.35 + sin(angle) * r;
        pz[i] = wz + cos(angle) * r;
        colorIdx[i] = 4; // dark
      }

      _slowVelocity(vx, vy, vz, i);
    }
  }

  // --- Building: skyscraper with floors ---
  static void _generateBuilding(
      Float64List px, Float64List py, Float64List pz,
      Float64List vx, Float64List vy, Float64List vz,
      Uint8List colorIdx, int count) {
    final scale = kWorldHalf * 0.7;
    for (int i = 0; i < count; i++) {
      final t = _rng.nextDouble();

      if (t < 0.6) {
        // Main tower
        px[i] = (_rng.nextDouble() - 0.5) * scale * 0.6;
        py[i] = (_rng.nextDouble() - 0.5) * scale * 2.0;
        pz[i] = (_rng.nextDouble() - 0.5) * scale * 0.6;

        // Windows (color based on floor)
        final floor = ((py[i] + scale) / (scale * 0.15)).floor();
        colorIdx[i] = floor % 2 == 0 ? 1 : 5; // cyan / blue
      } else if (t < 0.75) {
        // Antenna/spire
        px[i] = (_rng.nextDouble() - 0.5) * scale * 0.08;
        py[i] = -scale + (_rng.nextDouble()) * scale * 0.5;
        pz[i] = (_rng.nextDouble() - 0.5) * scale * 0.08;
        colorIdx[i] = 3; // yellow
      } else if (t < 0.85) {
        // Base (wider)
        px[i] = (_rng.nextDouble() - 0.5) * scale * 0.9;
        py[i] = scale * 0.7 + _rng.nextDouble() * scale * 0.3;
        pz[i] = (_rng.nextDouble() - 0.5) * scale * 0.9;
        colorIdx[i] = 1; // cyan
      } else {
        // Ground plane
        px[i] = (_rng.nextDouble() - 0.5) * scale * 2.5;
        py[i] = scale + (_rng.nextDouble()) * 5;
        pz[i] = (_rng.nextDouble() - 0.5) * scale * 2.5;
        colorIdx[i] = 2; // green
      }

      _slowVelocity(vx, vy, vz, i);
    }
  }

  // --- Sphere: points on sphere surface ---
  static void _generateSphere(
      Float64List px, Float64List py, Float64List pz,
      Float64List vx, Float64List vy, Float64List vz,
      Uint8List colorIdx, int count) {
    final r = kWorldHalf * 0.7;
    for (int i = 0; i < count; i++) {
      // Fibonacci sphere for even distribution
      final golden = pi * (3.0 - sqrt(5.0));
      final y = 1 - (i / (count - 1.0)) * 2;
      final radiusAtY = sqrt(1 - y * y);
      final theta = golden * i;

      // Add some thickness
      final rr = r * (0.95 + _rng.nextDouble() * 0.1);
      px[i] = cos(theta) * radiusAtY * rr;
      py[i] = y * rr;
      pz[i] = sin(theta) * radiusAtY * rr;

      // Color by latitude
      final lat = (y + 1) / 2; // 0..1
      if (lat < 0.15 || lat > 0.85) {
        colorIdx[i] = 2; // green (poles = ice → green for contrast)
      } else if (lat < 0.3 || lat > 0.7) {
        colorIdx[i] = 1; // cyan
      } else {
        colorIdx[i] = 5; // blue (equator = ocean)
      }

      _slowVelocity(vx, vy, vz, i);
    }
  }

  // --- DNA: double helix ---
  static void _generateDNA(
      Float64List px, Float64List py, Float64List pz,
      Float64List vx, Float64List vy, Float64List vz,
      Uint8List colorIdx, int count) {
    final scale = kWorldHalf * 0.6;
    final helixR = scale * 0.5;

    for (int i = 0; i < count; i++) {
      final t = i / count.toDouble();
      final angle = t * 8 * pi;
      final y = (t - 0.5) * scale * 2.5;

      if (i % 5 == 0) {
        // Rungs (connecting bars)
        final rungPos = _rng.nextDouble();
        px[i] = cos(angle) * helixR * rungPos + sin(angle) * helixR * (1 - rungPos) * -1;
        py[i] = y + (_rng.nextDouble() - 0.5) * 5;
        pz[i] = sin(angle) * helixR * rungPos + cos(angle) * helixR * (1 - rungPos);
        colorIdx[i] = (i ~/ 50) % 2 == 0 ? 3 : 0; // yellow / red
      } else if (i % 2 == 0) {
        // Strand 1
        final jitter = (_rng.nextDouble() - 0.5) * 8;
        px[i] = cos(angle) * helixR + jitter;
        py[i] = y + jitter;
        pz[i] = sin(angle) * helixR + jitter;
        colorIdx[i] = 1; // cyan
      } else {
        // Strand 2 (offset by pi)
        final jitter = (_rng.nextDouble() - 0.5) * 8;
        px[i] = cos(angle + pi) * helixR + jitter;
        py[i] = y + jitter;
        pz[i] = sin(angle + pi) * helixR + jitter;
        colorIdx[i] = 4; // pink
      }

      _slowVelocity(vx, vy, vz, i);
    }
  }

  // --- Heart: 3D heart shape ---
  static void _generateHeart(
      Float64List px, Float64List py, Float64List pz,
      Float64List vx, Float64List vy, Float64List vz,
      Uint8List colorIdx, int count) {
    final scale = kWorldHalf * 0.55;
    for (int i = 0; i < count; i++) {
      // Parametric heart surface
      final u = _rng.nextDouble() * 2 * pi;
      final v = _rng.nextDouble() * pi;

      // Heart equation
      final sinU = sin(u);
      final cosU = cos(u);
      final sinV = sin(v);
      final cosV = cos(v);

      final x = sinU * sinV * scale;
      final y = -(cosU + cosU * cosV) * scale * 0.45 + scale * 0.3;
      final z = sinV * cosU * scale * 0.5;

      // Add some volume
      final jitter = 1.0 + (_rng.nextDouble() - 0.5) * 0.15;
      px[i] = x * jitter;
      py[i] = y * jitter;
      pz[i] = z * jitter;

      // Gradient from red to pink
      final depth = (pz[i] + scale) / (scale * 2);
      colorIdx[i] = depth > 0.5 ? 0 : 4; // red / pink

      _slowVelocity(vx, vy, vz, i);
    }
  }

  // --- Galaxy: spiral arms ---
  static void _generateGalaxy(
      Float64List px, Float64List py, Float64List pz,
      Float64List vx, Float64List vy, Float64List vz,
      Uint8List colorIdx, int count) {
    final scale = kWorldHalf * 0.8;
    for (int i = 0; i < count; i++) {
      final t = _rng.nextDouble();

      if (t < 0.1) {
        // Core (dense center)
        final r = _rng.nextDouble() * scale * 0.15;
        final a = _rng.nextDouble() * 2 * pi;
        px[i] = cos(a) * r;
        py[i] = (_rng.nextDouble() - 0.5) * scale * 0.1;
        pz[i] = sin(a) * r;
        colorIdx[i] = 3; // yellow (bright center)
      } else {
        // Spiral arms (2 arms)
        final arm = _rng.nextInt(2);
        final dist = 0.1 + _rng.nextDouble() * 0.9;
        final r = dist * scale;
        final twist = dist * 3.0; // tighter spiral
        final baseAngle = arm * pi + twist;
        final spread = (1 - dist) * 0.3 + 0.05;
        final a = baseAngle + (_rng.nextDouble() - 0.5) * spread * 3;

        px[i] = cos(a) * r;
        py[i] = (_rng.nextDouble() - 0.5) * scale * 0.06 * (1 + dist * 0.5);
        pz[i] = sin(a) * r;

        // Color by distance from center
        if (dist < 0.3) {
          colorIdx[i] = 3; // yellow
        } else if (dist < 0.6) {
          colorIdx[i] = 1; // cyan
        } else {
          colorIdx[i] = 5; // blue
        }
      }

      // Orbital velocity
      final dist = sqrt(px[i] * px[i] + pz[i] * pz[i]);
      final speed = 30 + dist * 0.3;
      final angle = atan2(pz[i], px[i]) + pi / 2;
      vx[i] = cos(angle) * speed;
      vy[i] = (_rng.nextDouble() - 0.5) * 5;
      vz[i] = sin(angle) * speed;
    }
  }

  // --- Human: stick figure made of particles ---
  static void _generateHuman(
      Float64List px, Float64List py, Float64List pz,
      Float64List vx, Float64List vy, Float64List vz,
      Uint8List colorIdx, int count) {
    final scale = kWorldHalf * 0.6;
    for (int i = 0; i < count; i++) {
      final t = i / count.toDouble();

      if (t < 0.12) {
        // Head (sphere)
        final r = scale * 0.2;
        final a1 = _rng.nextDouble() * 2 * pi;
        final a2 = _rng.nextDouble() * pi;
        final rr = r * pow(_rng.nextDouble(), 0.33);
        px[i] = cos(a1) * sin(a2) * rr;
        py[i] = -scale * 0.7 + sin(a1) * rr.abs();
        pz[i] = cos(a2) * rr;
        colorIdx[i] = 1; // cyan
      } else if (t < 0.4) {
        // Torso (cylinder)
        final a = _rng.nextDouble() * 2 * pi;
        final r = scale * 0.2 * sqrt(_rng.nextDouble());
        final h = _rng.nextDouble() * scale * 0.6;
        px[i] = cos(a) * r;
        py[i] = -scale * 0.45 + h;
        pz[i] = sin(a) * r;
        colorIdx[i] = 5; // blue
      } else if (t < 0.55) {
        // Left arm
        final u = _rng.nextDouble();
        final jitter = (_rng.nextDouble() - 0.5) * scale * 0.08;
        px[i] = -scale * 0.2 - u * scale * 0.45 + jitter;
        py[i] = -scale * 0.4 + u * scale * 0.15 + jitter;
        pz[i] = jitter;
        colorIdx[i] = 1; // cyan
      } else if (t < 0.7) {
        // Right arm
        final u = _rng.nextDouble();
        final jitter = (_rng.nextDouble() - 0.5) * scale * 0.08;
        px[i] = scale * 0.2 + u * scale * 0.45 + jitter;
        py[i] = -scale * 0.4 + u * scale * 0.15 + jitter;
        pz[i] = jitter;
        colorIdx[i] = 1; // cyan
      } else if (t < 0.85) {
        // Left leg
        final u = _rng.nextDouble();
        final jitter = (_rng.nextDouble() - 0.5) * scale * 0.08;
        px[i] = -scale * 0.1 - u * scale * 0.15 + jitter;
        py[i] = scale * 0.15 + u * scale * 0.6 + jitter;
        pz[i] = jitter;
        colorIdx[i] = 4; // pink
      } else {
        // Right leg
        final u = _rng.nextDouble();
        final jitter = (_rng.nextDouble() - 0.5) * scale * 0.08;
        px[i] = scale * 0.1 + u * scale * 0.15 + jitter;
        py[i] = scale * 0.15 + u * scale * 0.6 + jitter;
        pz[i] = jitter;
        colorIdx[i] = 4; // pink
      }

      _slowVelocity(vx, vy, vz, i);
    }
  }

  // Slow drifting velocity for shaped models
  static void _slowVelocity(Float64List vx, Float64List vy, Float64List vz, int i) {
    vx[i] = (_rng.nextDouble() - 0.5) * 15;
    vy[i] = (_rng.nextDouble() - 0.5) * 15;
    vz[i] = (_rng.nextDouble() - 0.5) * 15;
  }
}