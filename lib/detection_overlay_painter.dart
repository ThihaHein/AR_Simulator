// lib/presentation/painters/detection_overlay_painter.dart
// ---------------------------------------------------------------------------
// Renders wireframe holograms positioned at detected object bounding boxes.
// Shows: wireframe model, label badge, bounding box, confidence.
// ---------------------------------------------------------------------------

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:stark_sim/wireframe_model.dart';

import 'object_detector.dart';

class DetectionOverlayPainter extends CustomPainter {
  final List<DetectedObject> objects;
  final double time;

  static const Color kCyan = Color(0xFF00E5FF);
  static const Color kOrange = Color(0xFFFF6D00);

  static const double _focal = 400;
  static const double _viewDist = 500;

  DetectionOverlayPainter({required this.objects, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    for (final obj in objects) {
      if (obj.wireframe == null) continue;

      // Bounding box in screen coords
      final bx = obj.x * size.width;
      final by = obj.y * size.height;
      final bw = obj.w * size.width;
      final bh = obj.h * size.height;
      final cx = bx + bw / 2;
      final cy = by + bh / 2;

      // Draw bounding box
      _drawBoundingBox(canvas, bx, by, bw, bh, obj.confidence);

      // Draw label
      _drawLabel(canvas, bx, by, obj.label, obj.confidence);

      // Draw wireframe model inside the bounding box
      _drawWireframe(canvas, obj.wireframe!, cx, cy, bw, bh);
    }
  }

  void _drawBoundingBox(Canvas canvas, double x, double y, double w, double h, double conf) {
    final cornerLen = min(w, h) * 0.2;
    final alpha = (0.3 + conf * 0.5).clamp(0.2, 0.8);

    final paint = Paint()
      ..color = kCyan.withOpacity(alpha)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Corners only (not full rect — looks more techy)
    // Top-left
    canvas.drawLine(Offset(x, y), Offset(x + cornerLen, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + cornerLen), paint);
    // Top-right
    canvas.drawLine(Offset(x + w, y), Offset(x + w - cornerLen, y), paint);
    canvas.drawLine(Offset(x + w, y), Offset(x + w, y + cornerLen), paint);
    // Bottom-left
    canvas.drawLine(Offset(x, y + h), Offset(x + cornerLen, y + h), paint);
    canvas.drawLine(Offset(x, y + h), Offset(x, y + h - cornerLen), paint);
    // Bottom-right
    canvas.drawLine(Offset(x + w, y + h), Offset(x + w - cornerLen, y + h), paint);
    canvas.drawLine(Offset(x + w, y + h), Offset(x + w, y + h - cornerLen), paint);

    // Scanning line
    final scanProgress = (time * 0.8) % 1.0;
    final scanY = y + scanProgress * h;
    final scanPaint = Paint()
      ..color = kCyan.withOpacity(0.15)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(x, scanY), Offset(x + w, scanY), scanPaint);
  }

  void _drawLabel(Canvas canvas, double x, double y, String label, double conf) {
    final text = '${label.toUpperCase()} ${(conf * 100).toStringAsFixed(0)}%';
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: kCyan,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Background pill
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y - 20, tp.width + 12, 18),
      const Radius.circular(4),
    );
    canvas.drawRRect(pillRect, Paint()..color = const Color(0xAA000000));
    canvas.drawRRect(pillRect, Paint()
      ..color = kCyan.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5);

    tp.paint(canvas, Offset(x + 6, y - 18));
  }

  void _drawWireframe(Canvas canvas, WireframeModel model,
      double cx, double cy, double boxW, double boxH) {
    // Find model bounds for scaling
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (final v in model.vertices) {
      if (v.x < minX) minX = v.x;
      if (v.x > maxX) maxX = v.x;
      if (v.y < minY) minY = v.y;
      if (v.y > maxY) maxY = v.y;
    }
    final modelW = (maxX - minX).clamp(1, double.infinity);
    final modelH = (maxY - minY).clamp(1, double.infinity);

    // Scale model to fit bounding box (with margin)
    final scaleX = boxW * 0.7 / modelW;
    final scaleY = boxH * 0.7 / modelH;
    final scale = min(scaleX, scaleY);

    // Slow rotation
    final rotY = time * 0.5;
    final cosR = cos(rotY);
    final sinR = sin(rotY);

    // Project vertices
    final projected = <Offset>[];
    final depths = <double>[];

    for (final v in model.vertices) {
      final x = v.x * scale;
      final y = v.y * scale;
      final z = v.z * scale;

      // Rotate around Y
      final rx = x * cosR + z * sinR;
      final rz = -x * sinR + z * cosR;

      final zOff = rz + _viewDist;
      final s = _focal / (zOff > 1 ? zOff : 1);
      projected.add(Offset(rx * s + cx, y * s + cy));
      depths.add(rz);
    }

    // Find depth range
    double minZ = double.infinity, maxZ = -double.infinity;
    for (final d in depths) {
      if (d < minZ) minZ = d;
      if (d > maxZ) maxZ = d;
    }
    final zRange = (maxZ - minZ).clamp(1.0, double.infinity);

    // Draw edges
    for (final edge in model.edges) {
      if (edge[0] >= projected.length || edge[1] >= projected.length) continue;
      final pa = projected[edge[0]];
      final pb = projected[edge[1]];

      final avgDepth = (depths[edge[0]] + depths[edge[1]]) / 2;
      final depthNorm = (avgDepth - minZ) / zRange;
      final alpha = (1.0 - depthNorm * 0.6).clamp(0.15, 0.9);
      final width = (1.5 - depthNorm * 0.8).clamp(0.3, 1.5);

      canvas.drawLine(pa, pb, Paint()
        ..color = kCyan.withOpacity(alpha * 0.8)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round);

      // Glow
      if (alpha > 0.5) {
        canvas.drawLine(pa, pb, Paint()
          ..color = kCyan.withOpacity(alpha * 0.1)
          ..strokeWidth = width + 2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant DetectionOverlayPainter old) => true;
}