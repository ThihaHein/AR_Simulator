// lib/presentation/painters/stark_hud_painter.dart
// ---------------------------------------------------------------------------
// Iron Man / Tony Stark style holographic HUD overlay.
// Renders: hand skeleton, gesture label, targeting reticle,
//          holographic arc reactor rings, data readouts.
// ---------------------------------------------------------------------------

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'hand_tracker.dart';

class StarkHudPainter extends CustomPainter {
  final List<HandData> hands;
  final GestureResult gesture;
  final double simScale;
  final double simRotY;
  final double fps;
  final double time; // elapsed seconds for animation

  StarkHudPainter({
    required this.hands,
    required this.gesture,
    required this.simScale,
    required this.simRotY,
    required this.fps,
    required this.time,
  });

  // Stark palette
  static const Color kCyan = Color(0xFF00E5FF);
  static const Color kCyanDim = Color(0x5500E5FF);
  static const Color kCyanGhost = Color(0x2200E5FF);
  static const Color kOrange = Color(0xFFFF6D00);
  static const Color kWhite = Color(0xCCFFFFFF);

  // MediaPipe hand connection pairs
  static const List<List<int>> kConnections = [
    [0,1],[1,2],[2,3],[3,4],       // thumb
    [0,5],[5,6],[6,7],[7,8],       // index
    [0,9],[9,10],[10,11],[11,12],   // middle
    [0,13],[13,14],[14,15],[15,16], // ring
    [0,17],[17,18],[18,19],[19,20], // pinky
    [5,9],[9,13],[13,17],          // palm
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _drawCornerBrackets(canvas, size);
    _drawHolographicRings(canvas, size);
    _drawHandSkeleton(canvas, size);
    _drawGestureIndicator(canvas, size);
    _drawDataReadouts(canvas, size);
    _drawTargetReticle(canvas, size);
  }

  // ---- Corner brackets (like Stark's HUD frame) ----
  void _drawCornerBrackets(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kCyanDim
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const len = 40.0;
    const margin = 24.0;

    // Top-left
    canvas.drawLine(Offset(margin, margin), Offset(margin + len, margin), paint);
    canvas.drawLine(Offset(margin, margin), Offset(margin, margin + len), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - margin, margin), Offset(size.width - margin - len, margin), paint);
    canvas.drawLine(Offset(size.width - margin, margin), Offset(size.width - margin, margin + len), paint);

    // Bottom-left
    canvas.drawLine(Offset(margin, size.height - margin), Offset(margin + len, size.height - margin), paint);
    canvas.drawLine(Offset(margin, size.height - margin), Offset(margin, size.height - margin - len), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - margin, size.height - margin), Offset(size.width - margin - len, size.height - margin), paint);
    canvas.drawLine(Offset(size.width - margin, size.height - margin), Offset(size.width - margin, size.height - margin - len), paint);
  }

  // ---- Animated holographic rings around simulation center ----
  void _drawHolographicRings(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.45;

    for (int i = 0; i < 3; i++) {
      final radius = 80.0 + i * 35.0;
      final rotSpeed = (i.isEven ? 1.0 : -1.0) * (0.3 + i * 0.15);
      final startAngle = time * rotSpeed;
      final sweepAngle = pi * (0.4 + i * 0.2);
      final opacity = (0.15 - i * 0.03).clamp(0.05, 0.2);

      final paint = Paint()
        ..color = kCyan.withOpacity(opacity)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius * simScale),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      // Second arc opposite side
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius * simScale),
        startAngle + pi,
        sweepAngle * 0.7,
        false,
        paint,
      );
    }

    // Center dot
    canvas.drawCircle(
      Offset(cx, cy),
      3,
      Paint()..color = kCyan.withOpacity(0.4 + 0.2 * sin(time * 3)),
    );
  }

  // ---- Hand skeleton wireframe ----
  void _drawHandSkeleton(Canvas canvas, Size size) {
    for (final hand in hands) {
      if (hand.landmarks.length < 21) continue;

      // Connection lines
      final linePaint = Paint()
        ..color = kCyan.withOpacity(0.7)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      for (final conn in kConnections) {
        final a = hand.landmarks[conn[0]];
        final b = hand.landmarks[conn[1]];
        canvas.drawLine(
          Offset(a.x * size.width, a.y * size.height),
          Offset(b.x * size.width, b.y * size.height),
          linePaint,
        );
      }

      // Joint dots
      final jointPaint = Paint()..color = kCyan;
      final tipPaint = Paint()..color = kOrange;

      for (int i = 0; i < 21; i++) {
        final lm = hand.landmarks[i];
        final pos = Offset(lm.x * size.width, lm.y * size.height);
        final isTip = (i == 4 || i == 8 || i == 12 || i == 16 || i == 20);
        canvas.drawCircle(pos, isTip ? 4.0 : 2.5, isTip ? tipPaint : jointPaint);

        // Glow ring on fingertips
        if (isTip) {
          canvas.drawCircle(
            pos, 8,
            Paint()
              ..color = kCyan.withOpacity(0.15)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      }

      // Pinch line (thumb to index)
      if (gesture.type == GestureType.pinch || gesture.type == GestureType.twoHandPinch) {
        final thumb = hand.landmarks[4];
        final index = hand.landmarks[8];
        final pinchPaint = Paint()
          ..color = kOrange.withOpacity(0.8)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(thumb.x * size.width, thumb.y * size.height),
          Offset(index.x * size.width, index.y * size.height),
          pinchPaint,
        );
      }
    }
  }

  // ---- Gesture label + icon ----
  void _drawGestureIndicator(Canvas canvas, Size size) {
    if (gesture.type == GestureType.none) return;

    final label = switch (gesture.type) {
      GestureType.grab => 'GRAB · MOVE',
      GestureType.pinch => 'PINCH · SCALE',
      GestureType.openPalm => 'OPEN · IDLE',
      GestureType.point => 'POINT · ROTATE',
      GestureType.twoHandPinch => 'DUAL · SCALE',
      GestureType.none => '',
    };

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: kCyan,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Position near the palm
    final px = gesture.palmX * size.width;
    final py = gesture.palmY * size.height - 40;

    // Background pill
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(px, py), width: tp.width + 24, height: 26),
      const Radius.circular(13),
    );
    canvas.drawRRect(
      pillRect,
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = kCyan.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    tp.paint(canvas, Offset(px - tp.width / 2, py - tp.height / 2));
  }

  // ---- Data readouts (top-right) ----
  void _drawDataReadouts(Canvas canvas, Size size) {
    final entries = [
      'SCALE ${(simScale * 100).toStringAsFixed(0)}%',
      'ROT ${(simRotY * 180 / pi).toStringAsFixed(1)}°',
      'FPS ${fps.toStringAsFixed(0)}',
      'ATOMS 10000',
      'HANDS ${hands.length}',
    ];

    for (int i = 0; i < entries.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: entries[i],
          style: TextStyle(
            color: i == 2
                ? (fps >= 55 ? const Color(0xFF1DD1A1) : kOrange)
                : kCyan.withOpacity(0.6),
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(size.width - tp.width - 20, 100 + i * 18.0));
    }
  }

  // ---- Targeting reticle on palm ----
  void _drawTargetReticle(Canvas canvas, Size size) {
    if (hands.isEmpty) return;

    final px = gesture.palmX * size.width;
    final py = gesture.palmY * size.height;
    final pulse = 1.0 + 0.1 * sin(time * 4);

    final reticlePaint = Paint()
      ..color = kCyan.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Outer ring
    canvas.drawCircle(Offset(px, py), 30 * pulse, reticlePaint);

    // Cross hairs
    const gap = 12.0;
    const arm = 22.0;
    final crossPaint = Paint()
      ..color = kCyan.withOpacity(0.25)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(px - arm, py), Offset(px - gap, py), crossPaint);
    canvas.drawLine(Offset(px + gap, py), Offset(px + arm, py), crossPaint);
    canvas.drawLine(Offset(px, py - arm), Offset(px, py - gap), crossPaint);
    canvas.drawLine(Offset(px, py + gap), Offset(px, py + arm), crossPaint);
  }

  @override
  bool shouldRepaint(covariant StarkHudPainter old) => true;
}