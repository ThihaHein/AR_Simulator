import 'dart:math';
import 'dart:typed_data';
import 'models.dart';

const int kAtomCount = 10000;
const double kAtomRadius = 2.0;
const double kAtomDiameter = kAtomRadius * 2;
const double kMaxSpeed = 100.0;
const double kRestitution = 0.95;
const int kGridCellSize = 8;
const double kWorldHalf = 300.0;
const double kFocalLength = 600.0;
const double kViewerDistance = 800.0;

class SimParams {
  double gravity, windX, windZ, rotationSpeed;
  bool paused;
  SimParams({this.gravity = 0, this.windX = 0, this.windZ = 0, this.rotationSpeed = 0.3, this.paused = false});
}

class AtomSimulation3D {
  final double screenW, screenH;
  final SimParams params;
  late final Float64List px, py, pz, vx, vy, vz;
  late final Uint8List colorIdx;
  double _angle = 0;
  double get angle => _angle;
  late final Float32List screenX, screenY;
  late final Float64List screenDepth;
  late int _gx, _gy, _gz;
  late List<List<int>> _grid;

  AtomSimulation3D(this.screenW, this.screenH, this.params) {
    px = Float64List(kAtomCount); py = Float64List(kAtomCount); pz = Float64List(kAtomCount);
    vx = Float64List(kAtomCount); vy = Float64List(kAtomCount); vz = Float64List(kAtomCount);
    colorIdx = Uint8List(kAtomCount);
    screenX = Float32List(kAtomCount); screenY = Float32List(kAtomCount);
    screenDepth = Float64List(kAtomCount);
    _gx = (kWorldHalf * 2 / kGridCellSize).ceil() + 1; _gy = _gx; _gz = _gx;
    _grid = List.generate(_gx * _gy * _gz, (_) => <int>[]);
    loadModel(ModelType.atoms);
  }

  void loadModel(ModelType type) {
    _angle = 0;
    ModelGenerator.generate(type, px, py, pz, vx, vy, vz, colorIdx, kAtomCount);
  }

  void step(double dt) {
    if (params.paused) { _project(); return; }
    _angle += params.rotationSpeed * dt;
    final g = params.gravity * 200, wx = params.windX * 80, wz = params.windZ * 80;
    for (int i = 0; i < kAtomCount; i++) { vy[i] += g * dt; vx[i] += wx * dt; vz[i] += wz * dt; }
    for (int i = 0; i < kAtomCount; i++) { px[i] += vx[i] * dt; py[i] += vy[i] * dt; pz[i] += vz[i] * dt; }
    _wallBounce(); _buildGrid(); _collide(); _project();
  }

  void _wallBounce() {
    const lo = -kWorldHalf + kAtomRadius, hi = kWorldHalf - kAtomRadius;
    for (int i = 0; i < kAtomCount; i++) {
      if (px[i] < lo) { px[i] = lo; vx[i] *= -kRestitution; } else if (px[i] > hi) { px[i] = hi; vx[i] *= -kRestitution; }
      if (py[i] < lo) { py[i] = lo; vy[i] *= -kRestitution; } else if (py[i] > hi) { py[i] = hi; vy[i] *= -kRestitution; }
      if (pz[i] < lo) { pz[i] = lo; vz[i] *= -kRestitution; } else if (pz[i] > hi) { pz[i] = hi; vz[i] *= -kRestitution; }
    }
  }

  void _buildGrid() {
    for (final c in _grid) c.clear();
    for (int i = 0; i < kAtomCount; i++) {
      final cx = ((px[i] + kWorldHalf) / kGridCellSize).floor().clamp(0, _gx - 1);
      final cy = ((py[i] + kWorldHalf) / kGridCellSize).floor().clamp(0, _gy - 1);
      final cz = ((pz[i] + kWorldHalf) / kGridCellSize).floor().clamp(0, _gz - 1);
      _grid[(cz * _gy + cy) * _gx + cx].add(i);
    }
  }

  void _collide() {
    final md2 = kAtomDiameter * kAtomDiameter;
    for (int i = 0; i < kAtomCount; i++) {
      final cx = ((px[i] + kWorldHalf) / kGridCellSize).floor().clamp(0, _gx - 1);
      final cy = ((py[i] + kWorldHalf) / kGridCellSize).floor().clamp(0, _gy - 1);
      final cz = ((pz[i] + kWorldHalf) / kGridCellSize).floor().clamp(0, _gz - 1);
      for (int nz = (cz - 1).clamp(0, _gz - 1); nz <= (cz + 1).clamp(0, _gz - 1); nz++)
        for (int ny = (cy - 1).clamp(0, _gy - 1); ny <= (cy + 1).clamp(0, _gy - 1); ny++)
          for (int nx = (cx - 1).clamp(0, _gx - 1); nx <= (cx + 1).clamp(0, _gx - 1); nx++) {
            final cell = _grid[(nz * _gy + ny) * _gx + nx];
            for (int ki = 0; ki < cell.length; ki++) {
              final j = cell[ki]; if (j <= i) continue;
              final dx = px[j] - px[i], dy = py[j] - py[i], dz = pz[j] - pz[i];
              final d2 = dx * dx + dy * dy + dz * dz;
              if (d2 < md2 && d2 > 1e-8) {
                final d = sqrt(d2), inv = 1 / d;
                final nnx = dx * inv, nny = dy * inv, nnz = dz * inv;
                final ov = (kAtomDiameter - d) * 0.5;
                px[i] -= nnx * ov; py[i] -= nny * ov; pz[i] -= nnz * ov;
                px[j] += nnx * ov; py[j] += nny * ov; pz[j] += nnz * ov;
                final dvx = vx[i] - vx[j], dvy = vy[i] - vy[j], dvz = vz[i] - vz[j];
                final dot = dvx * nnx + dvy * nny + dvz * nnz;
                if (dot > 0) {
                  final imp = dot * kRestitution;
                  vx[i] -= imp * nnx; vy[i] -= imp * nny; vz[i] -= imp * nnz;
                  vx[j] += imp * nnx; vy[j] += imp * nny; vz[j] += imp * nnz;
                }
              }
            }
          }
    }
  }

  void _project() {
    final cosA = cos(_angle), sinA = sin(_angle);
    final cx = screenW * 0.5, cy = screenH * 0.5;
    for (int i = 0; i < kAtomCount; i++) {
      final rx = px[i] * cosA + pz[i] * sinA, ry = py[i], rz = -px[i] * sinA + pz[i] * cosA;
      final zOff = rz + kViewerDistance;
      final s = kFocalLength / (zOff > 1 ? zOff : 1);
      screenX[i] = (rx * s + cx).toDouble(); screenY[i] = (ry * s + cy).toDouble();
      screenDepth[i] = rz;
    }
  }
}