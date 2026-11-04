import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '/simulation_3d.dart';

// ---------------------------------------------------------------------------
// Colour schemes
// ---------------------------------------------------------------------------
const List<List<Color>> kColorSchemes = [
  // 0 – Neon
  [Color(0xFFFF6B6B), Color(0xFF48DBFB), Color(0xFF1DD1A1),
    Color(0xFFFECA57), Color(0xFFFF9FF3), Color(0xFF54A0FF)],
  // 1 – Plasma
  [Color(0xFFFF0080), Color(0xFFFF8C00), Color(0xFFFFE600),
    Color(0xFF00FF80), Color(0xFF0080FF), Color(0xFFBF00FF)],
  // 2 – Ice
  [Color(0xFFB3E5FC), Color(0xFF81D4FA), Color(0xFF4FC3F7),
    Color(0xFF29B6F6), Color(0xFF03A9F4), Color(0xFFE1F5FE)],
  // 3 – Fire
  [Color(0xFFFF1744), Color(0xFFFF5722), Color(0xFFFF9100),
    Color(0xFFFFAB00), Color(0xFFFFD600), Color(0xFFFF6D00)],
];

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------
class AtomPainter extends CustomPainter {
  final AtomSimulation3D sim;
  final int schemeIdx;

  AtomPainter(this.sim, {this.schemeIdx = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final palette = kColorSchemes[schemeIdx % kColorSchemes.length];
    final n = kAtomCount;

    // Depth range for alpha modulation
    const double nearZ = -kWorldHalf;
    const double farZ = kWorldHalf;
    const double range = farZ - nearZ;

    // Bucket by colour AND depth band (near / far) for size variation
    // Near atoms → larger stroke, far atoms → smaller stroke
    // 2 depth bands × 6 colours = 12 draw calls max
    final nearBuckets = List.generate(6, (_) => <double>[]);
    final farBuckets = List.generate(6, (_) => <double>[]);

    for (int i = 0; i < n; i++) {
      final sx = sim.screenX[i];
      final sy = sim.screenY[i];
      // Cull off-screen
      if (sx < -20 || sx > size.width + 20 || sy < -20 || sy > size.height + 20) {
        continue;
      }
      final depth = sim.screenDepth[i];
      final c = sim.colorIdx[i] % 6;
      if (depth < 0) {
        nearBuckets[c].add(sx);
        nearBuckets[c].add(sy);
      } else {
        farBuckets[c].add(sx);
        farBuckets[c].add(sy);
      }
    }

    // Draw far (smaller, dimmer) first, then near on top
    for (int c = 0; c < 6; c++) {
      if (farBuckets[c].isNotEmpty) {
        final pts = Float32List.fromList(farBuckets[c]);
        final paint = Paint()
          ..color = palette[c].withOpacity(0.45)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        canvas.drawRawPoints(ui.PointMode.points, pts, paint);
      }
    }
    for (int c = 0; c < 6; c++) {
      if (nearBuckets[c].isNotEmpty) {
        final pts = Float32List.fromList(nearBuckets[c]);
        final paint = Paint()
          ..color = palette[c]
          ..strokeWidth = 4.0
          ..strokeCap = StrokeCap.round;
        canvas.drawRawPoints(ui.PointMode.points, pts, paint);
      }
    }

    // Wireframe cube outline
    _drawCube(canvas, size);
  }

  void _drawCube(Canvas canvas, Size size) {
    final cosA = _cosA(sim.angle);
    final sinA = _sinA(sim.angle);
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;
    const h = kWorldHalf;

    final corners = <List<double>>[
      [-h, -h, -h], [h, -h, -h], [h, h, -h], [-h, h, -h],
      [-h, -h, h],  [h, -h, h],  [h, h, h],  [-h, h, h],
    ];

    List<double> proj(List<double> p) {
      final rx = p[0] * cosA + p[2] * sinA;
      final ry = p[1];
      final rz = -p[0] * sinA + p[2] * cosA;
      final zOff = rz + kViewerDistance;
      final s = kFocalLength / (zOff > 1.0 ? zOff : 1.0);
      return [rx * s + cx, ry * s + cy];
    }

    final edges = [
      [0,1],[1,2],[2,3],[3,0],
      [4,5],[5,6],[6,7],[7,4],
      [0,4],[1,5],[2,6],[3,7],
    ];

    final paint = Paint()
      ..color = const Color(0x22ffffff)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (final e in edges) {
      final a = proj(corners[e[0]]);
      final b = proj(corners[e[1]]);
      canvas.drawLine(Offset(a[0], a[1]), Offset(b[0], b[1]), paint);
    }
  }

  double _cosA(double a) => a.isFinite ? cos(a) : 1.0;
  double _sinA(double a) => a.isFinite ? sin(a) : 0.0;

  @override
  bool shouldRepaint(covariant AtomPainter old) => true;
}