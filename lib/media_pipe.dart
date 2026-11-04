// lib/engine/mediapipe_bridge.dart
// ---------------------------------------------------------------------------
// Platform channel bridge to native MediaPipe Hand Landmarker.
//
// Android: Uses MediaPipe's Android SDK (com.google.mediapipe:tasks-vision)
// iOS:     Uses MediaPipe's iOS SDK (MediaPipeTasksVision)
//
// The native side runs the hand landmark model on each camera frame
// and sends 21 landmarks per hand back to Dart via EventChannel stream.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'hand_tracker.dart';

class MediaPipeBridge {
  static const _methodChannel = MethodChannel('atom_sim/mediapipe');
  static const _eventChannel = EventChannel('atom_sim/mediapipe/landmarks');

  StreamSubscription? _sub;
  final HandGestureEngine gestureEngine = HandGestureEngine();

  // Callback for processed gestures
  void Function(GestureResult)? onGesture;
  // Callback for raw landmarks (for HUD rendering)
  void Function(List<HandData>)? onLandmarks;

  bool _running = false;
  bool get isRunning => _running;

  /// Start the hand tracking pipeline
  Future<bool> start() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('startTracking');
      if (result == true) {
        _running = true;
        _sub = _eventChannel
            .receiveBroadcastStream()
            .listen(_onLandmarkData, onError: _onError);
      }
      return result ?? false;
    } on PlatformException catch (e) {
      print('MediaPipe init failed: ${e.message}');
      return false;
    }
  }

  /// Stop hand tracking
  Future<void> stop() async {
    _running = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _methodChannel.invokeMethod('stopTracking');
    } catch (_) {}
  }

  void _onLandmarkData(dynamic data) {
    // Native side sends JSON:
    // {
    //   "hands": [
    //     {
    //       "landmarks": [[x,y,z], [x,y,z], ...],  // 21 points
    //       "isLeft": true
    //     },
    //     ...
    //   ]
    // }
    try {
      final Map<String, dynamic> json;
      if (data is String) {
        json = jsonDecode(data);
      } else if (data is Map) {
        json = Map<String, dynamic>.from(data);
      } else {
        return;
      }

      final handsJson = json['hands'] as List<dynamic>? ?? [];
      final hands = <HandData>[];

      for (final h in handsJson) {
        final lmList = h['landmarks'] as List<dynamic>;
        final landmarks = lmList.map<HandLandmark>((p) {
          final coords = p as List<dynamic>;
          return HandLandmark(
            (coords[0] as num).toDouble(),
            (coords[1] as num).toDouble(),
            coords.length > 2 ? (coords[2] as num).toDouble() : 0.0,
          );
        }).toList();

        hands.add(HandData(
          landmarks: landmarks,
          isLeft: h['isLeft'] == true,
        ));
      }

      // Fire raw landmarks callback
      onLandmarks?.call(hands);

      // Process gestures
      final gesture = gestureEngine.process(hands);
      onGesture?.call(gesture);

    } catch (e) {
      print('Landmark parse error: $e');
    }
  }

  void _onError(dynamic error) {
    print('MediaPipe stream error: $error');
  }

  void dispose() {
    stop();
    onGesture = null;
    onLandmarks = null;
  }
}