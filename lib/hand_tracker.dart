// lib/engine/hand_tracker.dart
// ---------------------------------------------------------------------------
// Gesture recognition engine that interprets MediaPipe hand landmarks
// into simulation controls: grab-move, pinch-scale, swipe-rotate.
//
// MediaPipe gives 21 landmarks per hand (x, y, z normalised 0..1).
// Landmark indices:
//   0  = wrist
//   4  = thumb tip
//   8  = index tip
//   12 = middle tip
//   16 = ring tip
//   20 = pinky tip
//   5  = index MCP (knuckle)
// ---------------------------------------------------------------------------

import 'dart:math';

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------
class HandLandmark {
  final double x, y, z; // normalised 0..1 (screen coords)
  const HandLandmark(this.x, this.y, this.z);
}

class HandData {
  final List<HandLandmark> landmarks; // length == 21
  final bool isLeft;
  const HandData({required this.landmarks, this.isLeft = false});
}

enum GestureType {
  none,
  grab,       // closed fist → move the simulation cube
  pinch,      // thumb + index close → scale
  openPalm,   // all fingers extended → reset / idle
  point,      // index extended, others closed → rotate axis
  twoHandPinch, // two hands pinch → scale with both
}

class GestureResult {
  final GestureType type;

  // Movement delta (normalised)
  final double dx, dy, dz;

  // Scale factor (1.0 = no change)
  final double scale;

  // Rotation delta (radians)
  final double rotX, rotY;

  // Palm center position (normalised 0..1)
  final double palmX, palmY;

  // Confidence 0..1
  final double confidence;

  const GestureResult({
    this.type = GestureType.none,
    this.dx = 0, this.dy = 0, this.dz = 0,
    this.scale = 1.0,
    this.rotX = 0, this.rotY = 0,
    this.palmX = 0.5, this.palmY = 0.5,
    this.confidence = 0,
  });
}

// ---------------------------------------------------------------------------
// Gesture engine
// ---------------------------------------------------------------------------
class HandGestureEngine {
  // Previous frame state for delta calculations
  double _prevPalmX = 0.5, _prevPalmY = 0.5;
  double _prevPinchDist = 0;
  double _prevIndexX = 0.5, _prevIndexY = 0.5;
  bool _hadHand = false;

  // Smoothing
  GestureType _prevGesture = GestureType.none;
  int _gestureFrames = 0;
  static const int kGestureLockFrames = 3; // debounce

  // Two-hand tracking
  double _prevTwoHandDist = 0;

  GestureResult process(List<HandData> hands) {
    if (hands.isEmpty) {
      _hadHand = false;
      _gestureFrames = 0;
      _prevGesture = GestureType.none;
      return const GestureResult();
    }

    // Two-hand pinch (Tony Stark expand/shrink)
    if (hands.length >= 2) {
      return _processTwoHands(hands[0], hands[1]);
    }

    return _processSingleHand(hands[0]);
  }

  GestureResult _processSingleHand(HandData hand) {
    final lm = hand.landmarks;
    if (lm.length < 21) return const GestureResult();

    final wrist = lm[0];
    final thumbTip = lm[4];
    final indexTip = lm[8];
    final middleTip = lm[12];
    final ringTip = lm[16];
    final pinkyTip = lm[20];
    final indexMCP = lm[5];
    final middleMCP = lm[9];
    final ringMCP = lm[13];
    final pinkyMCP = lm[17];

    // Palm center (average of MCPs)
    final palmX = (indexMCP.x + middleMCP.x + ringMCP.x + pinkyMCP.x) / 4;
    final palmY = (indexMCP.y + middleMCP.y + ringMCP.y + pinkyMCP.y) / 4;

    // Finger extension: tip is farther from wrist than MCP
    final indexExt = _dist2D(indexTip, wrist) > _dist2D(indexMCP, wrist) * 1.3;
    final middleExt = _dist2D(middleTip, wrist) > _dist2D(middleMCP, wrist) * 1.3;
    final ringExt = _dist2D(ringTip, wrist) > _dist2D(ringMCP, wrist) * 1.3;
    final pinkyExt = _dist2D(pinkyTip, wrist) > _dist2D(pinkyMCP, wrist) * 1.3;

    // Pinch: thumb-index distance
    final pinchDist = _dist2D(thumbTip, indexTip);
    final isPinching = pinchDist < 0.06;

    // Count extended fingers
    final extCount = [indexExt, middleExt, ringExt, pinkyExt]
        .where((e) => e).length;

    // Classify gesture
    GestureType gesture;
    if (isPinching && extCount <= 1) {
      gesture = GestureType.pinch;
    } else if (extCount == 0) {
      gesture = GestureType.grab;
    } else if (extCount >= 3) {
      gesture = GestureType.openPalm;
    } else if (indexExt && !middleExt && !ringExt && !pinkyExt) {
      gesture = GestureType.point;
    } else {
      gesture = GestureType.none;
    }

    // Debounce: require consistent gesture for N frames
    if (gesture != _prevGesture) {
      _gestureFrames = 0;
      _prevGesture = gesture;
    }
    _gestureFrames++;
    if (_gestureFrames < kGestureLockFrames) {
      gesture = GestureType.none;
    }

    // Calculate deltas
    double dx = 0, dy = 0, scale = 1.0, rotX = 0, rotY = 0;

    if (_hadHand) {
      switch (gesture) {
        case GestureType.grab:
        // Move simulation cube with fist
          dx = (palmX - _prevPalmX) * 3.0;
          dy = (palmY - _prevPalmY) * 3.0;
          break;

        case GestureType.pinch:
        // Scale: pinch distance delta
          if (_prevPinchDist > 0) {
            final delta = pinchDist - _prevPinchDist;
            scale = 1.0 + delta * 8.0;
            scale = scale.clamp(0.8, 1.2);
          }
          break;

        case GestureType.point:
        // Rotate: index finger direction
          rotY = (indexTip.x - _prevIndexX) * 5.0;
          rotX = (indexTip.y - _prevIndexY) * 5.0;
          break;

        case GestureType.openPalm:
        case GestureType.none:
        case GestureType.twoHandPinch:
          break;
      }
    }

    _prevPalmX = palmX;
    _prevPalmY = palmY;
    _prevPinchDist = pinchDist;
    _prevIndexX = indexTip.x;
    _prevIndexY = indexTip.y;
    _hadHand = true;

    return GestureResult(
      type: gesture,
      dx: dx, dy: dy,
      scale: scale,
      rotX: rotX, rotY: rotY,
      palmX: palmX, palmY: palmY,
      confidence: gesture == GestureType.none ? 0.3 : 0.9,
    );
  }

  GestureResult _processTwoHands(HandData left, HandData right) {
    if (left.landmarks.length < 21 || right.landmarks.length < 21) {
      return const GestureResult();
    }

    // Two-hand distance (between palm centers)
    final lPalmX = (left.landmarks[5].x + left.landmarks[9].x +
        left.landmarks[13].x + left.landmarks[17].x) / 4;
    final lPalmY = (left.landmarks[5].y + left.landmarks[9].y +
        left.landmarks[13].y + left.landmarks[17].y) / 4;
    final rPalmX = (right.landmarks[5].x + right.landmarks[9].x +
        right.landmarks[13].x + right.landmarks[17].x) / 4;
    final rPalmY = (right.landmarks[5].y + right.landmarks[9].y +
        right.landmarks[13].y + right.landmarks[17].y) / 4;

    final dist = sqrt(pow(rPalmX - lPalmX, 2) + pow(rPalmY - lPalmY, 2));
    final centerX = (lPalmX + rPalmX) / 2;
    final centerY = (lPalmY + rPalmY) / 2;

    double scale = 1.0;
    double dx = 0, dy = 0;

    if (_hadHand && _prevTwoHandDist > 0) {
      // Scale from hand spread
      final delta = dist - _prevTwoHandDist;
      scale = 1.0 + delta * 4.0;
      scale = scale.clamp(0.85, 1.15);

      // Move from center movement
      dx = (centerX - _prevPalmX) * 2.0;
      dy = (centerY - _prevPalmY) * 2.0;
    }

    _prevTwoHandDist = dist;
    _prevPalmX = centerX;
    _prevPalmY = centerY;
    _hadHand = true;

    return GestureResult(
      type: GestureType.twoHandPinch,
      dx: dx, dy: dy,
      scale: scale,
      palmX: centerX, palmY: centerY,
      confidence: 0.95,
    );
  }

  double _dist2D(HandLandmark a, HandLandmark b) {
    return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
  }
}