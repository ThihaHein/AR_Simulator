// lib/engine/hand_tracking_channel.dart
// ---------------------------------------------------------------------------
// Simple platform channel for hand tracking.
// Sends camera frames to native, receives hand landmarks back.
// Works with Apple Vision (iOS) and MediaPipe (Android).
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'hand_tracker.dart';

class HandTrackingChannel {
  static const _method = MethodChannel('atom_sim/hand_tracking');
  static const _event = EventChannel('atom_sim/hand_tracking/results');

  StreamSubscription? _sub;
  bool _running = false;
  bool _processing = false; // throttle: one frame at a time

  // Callback
  void Function(List<HandData>)? onHandsDetected;

  Future<bool> start() async {
    try {
      final ok = await _method.invokeMethod<bool>('init') ?? false;
      if (!ok) return false;

      _sub = _event.receiveBroadcastStream().listen(
        _onResult,
        onError: (e) => debugPrint('Hand tracking error: $e'),
      );
      _running = true;
      return true;
    } catch (e) {
      debugPrint('Hand tracking init failed: $e');
      return false;
    }
  }

  Future<void> stop() async {
    _running = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _method.invokeMethod('dispose');
    } catch (_) {}
  }

  /// Call this with each camera frame from CameraController.startImageStream
  void processFrame(CameraImage image) {
    if (!_running || _processing) return;
    _processing = true;

    // Send frame dimensions and plane data to native
    // Native side will read the pixel buffer directly
    _method.invokeMethod('processFrame', {
      'width': image.width,
      'height': image.height,
      'bytesPerRow': image.planes[0].bytesPerRow,
      'bytes': image.planes[0].bytes,
    }).then((_) {
      _processing = false;
    }).catchError((e) {
      _processing = false;
    });
  }

  void _onResult(dynamic data) {
    try {
      // Native sends a Map with "hands" key
      final Map<String, dynamic> map;
      if (data is Map) {
        map = Map<String, dynamic>.from(data);
      } else if (data is String) {
        map = jsonDecode(data) as Map<String, dynamic>;
      } else {
        return;
      }

      final handsList = map['hands'];
      if (handsList == null || handsList is! List) {
        onHandsDetected?.call([]);
        return;
      }

      final hands = <HandData>[];
      for (final h in handsList) {
        if (h is! Map) continue;
        final lmRaw = h['landmarks'];
        if (lmRaw is! List) continue;

        final landmarks = <HandLandmark>[];
        for (final p in lmRaw) {
          if (p is List && p.length >= 2) {
            landmarks.add(HandLandmark(
              (p[0] as num).toDouble(),
              (p[1] as num).toDouble(),
              p.length > 2 ? (p[2] as num).toDouble() : 0.0,
            ));
          }
        }

        if (landmarks.length == 21) {
          hands.add(HandData(
            landmarks: landmarks,
            isLeft: h['isLeft'] == true,
          ));
        }
      }

      onHandsDetected?.call(hands);
    } catch (e) {
      debugPrint('Hand result parse error: $e');
    }
  }

  void debugPrint(String msg) {
    // ignore: avoid_print
    print(msg);
  }
}