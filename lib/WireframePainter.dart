// lib/presentation/painters/wireframe_painter.dart
// ---------------------------------------------------------------------------
// Renders WireframeModel as holographic blueprint lines.
// Features: perspective projection, depth-based alpha, glow effect, grid floor.
// ---------------------------------------------------------------------------

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../wireframe_model.dart';

class WireframePainter extends CustomPainter {
  final WireframeModel model;
  final double rotY; // Y rotation in radians
  final double rotX; // X rotation
  final double scale;
  final double time; // for animation effects

  static const double _focal = 600;
  static const double _viewDist = 800;

  // Holographic colors
  static const Color kCyan = Color(0xFF00E5FF);
  static const Color kCyanBright = Color(0xFF40FFFF);
  static const Color kCyanDim = Color(0x6600E5FF);

  WireframePainter({
    required this.model,
    required this.rotY,
    this.rotX = 0,
    this.scale = 1.0,
    this.time = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Rotation matrices
    final cosY = cos(rotY);
    final sinY = sin(rotY);
    final cosX = cos(rotX);
    final sinX = sin(rotX);

    // Project all vertices
    final projected = <Offset>[];
    final depths = <double>[];

    for (final v in model.vertices) {
      // Scale
      var x = v.x * scale;
      var y = v.y * scale;
      var z = v.z * scale;

      // Rotate Y
      final rx = x * cosY + z * sinY;
      final rz = -x * sinY + z * cosY;

      // Rotate X
      final ry = y * cosX - rz * sinX;
      final rz2 = y * sinX + rz * cosX;

      // Project
      final zOff = rz2 + _viewDist;
      final s = _focal / (zOff > 1 ? zOff : 1);
      projected.add(Offset(rx * s + cx, ry * s + cy));
      depths.add(rz2);
    }

    // Find depth range for alpha mapping
    double minZ = double.infinity, maxZ = -double.infinity;
    for (final d in depths) {
      if (d < minZ) minZ = d;
      if (d > maxZ) maxZ = d;
    }
    final zRange = (maxZ - minZ).clamp(1.0, double.infinity);

    // Draw grid floor
    _drawGridFloor(canvas, size, cosY, sinY, cosX, sinX, cx, cy);

    // Draw edges with depth-based alpha
    for (final edge in model.edges) {
      final a = edge[0];
      final b = edge[1];
      if (a >= projected.length || b >= projected.length) continue;

      final pa = projected[a];
      final pb = projected[b];

      // Cull off-screen
      if ((pa.dx < -50 && pb.dx < -50) ||
          (pa.dx > size.width + 50 && pb.dx > size.width + 50) ||
          (pa.dy < -50 && pb.dy < -50) ||
          (pa.dy > size.height + 50 && pb.dy > size.height + 50)) {
        continue;
      }

      // Average depth for this edge
      final avgDepth = (depths[a] + depths[b]) / 2;
      final depthNorm = (avgDepth - minZ) / zRange; // 0 = near, 1 = far

      // Nearer = brighter and thicker
      final alpha = (1.0 - depthNorm * 0.7).clamp(0.15, 1.0);
      final width = (2.0 - depthNorm * 1.2).clamp(0.5, 2.5);

      final paint = Paint()
        ..color = kCyan.withOpacity(alpha)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(pa, pb, paint);

      // Glow pass (wider, dimmer)
      if (alpha > 0.5) {
        final glowPaint = Paint()
          ..color = kCyan.withOpacity(alpha * 0.15)
          ..strokeWidth = width + 3
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawLine(pa, pb, glowPaint);
      }
    }

    // Draw vertices as dots (only near ones)
    for (int i = 0; i < projected.length; i++) {
      final depthNorm = (depths[i] - minZ) / zRange;
      if (depthNorm > 0.5) continue; // skip far vertices

      final alpha = (1.0 - depthNorm).clamp(0.0, 1.0);
      canvas.drawCircle(
        projected[i],
        1.5 * (1.0 - depthNorm * 0.5),
        Paint()..color = kCyanBright.withOpacity(alpha * 0.6),
      );
    }

    // Scan line effect (horizontal line moving down)
    final scanY = (time * 60) % size.height;
    final scanPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, scanY - 2), Offset(0, scanY + 2),
        [kCyan.withOpacity(0), kCyan.withOpacity(0.08), kCyan.withOpacity(0)],
        [0, 0.5, 1],
      );
    canvas.drawRect(
      Rect.fromLTWH(0, scanY - 2, size.width, 4),
      scanPaint,
    );
  }

  void _drawGridFloor(Canvas canvas, Size size,
      double cosY, double sinY, double cosX, double sinX,
      double cx, double cy) {
    final gridPaint = Paint()
      ..color = kCyan.withOpacity(0.06)
      ..strokeWidth = 0.5;

    final groundY = 200.0 * scale;
    final gridSize = 400.0 * scale;
    final gridStep = 40.0 * scale;

    for (double gx = -gridSize; gx <= gridSize; gx += gridStep) {
      final p1 = _projectPoint(gx, groundY, -gridSize, cosY, sinY, cosX, sinX, cx, cy);
      final p2 = _projectPoint(gx, groundY, gridSize, cosY, sinY, cosX, sinX, cx, cy);
      if (p1 != null && p2 != null) canvas.drawLine(p1, p2, gridPaint);
    }
    for (double gz = -gridSize; gz <= gridSize; gz += gridStep) {
      final p1 = _projectPoint(-gridSize, groundY, gz, cosY, sinY, cosX, sinX, cx, cy);
      final p2 = _projectPoint(gridSize, groundY, gz, cosY, sinY, cosX, sinX, cx, cy);
      if (p1 != null && p2 != null) canvas.drawLine(p1, p2, gridPaint);
    }
  }

  Offset? _projectPoint(double x, double y, double z,
      double cosY, double sinY, double cosX, double sinX,
      double cx, double cy) {
    final rx = x * cosY + z * sinY;
    final rz1 = -x * sinY + z * cosY;
    final ry = y * cosX - rz1 * sinX;
    final rz = y * sinX + rz1 * cosX;
    final zOff = rz + _viewDist;
    if (zOff < 10) return null;
    final s = _focal / zOff;
    return Offset(rx * s + cx, ry * s + cy);
  }

  @override
  bool shouldRepaint(covariant WireframePainter old) => true;
}