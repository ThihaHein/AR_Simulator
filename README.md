# Atom Sim 3D (`stark_sim`)

A Flutter app that renders a real-time, 10,000-particle 3D atom/particle simulation and layers an "Iron Man"–style AR mode on top of it: a live camera feed with on-device object detection, MediaPipe hand tracking for gesture control, and AI-generated 3D wireframes overlaid on detected objects.

> The in-app name is **ATOM SIM**; the repository/package name is `stark_sim`.

## Features

- **Standard mode** — a GPU-light, CPU-driven 3D particle simulation (~10k particles) with interactive controls, rendered entirely with Flutter `CustomPainter`.
- **Stark mode (AR)** — live native camera feed with:
  - **Object detection** — maps detected objects (YOLO / 80 COCO classes) to wireframes sized to the detected bounding box.
  - **Hand tracking** — MediaPipe 21-landmark hand tracking interpreted into gestures: grab-move, pinch-scale, point-rotate, open-palm reset, and two-hand pinch.
  - **AI wireframes** — sends a detected object's label + aspect ratio to the Claude API, which returns 3D wireframe vertices/edges as JSON for rendering.

## Project structure

```
lib/
  main.dart                      App entry, ModeSelector (Standard vs Stark)
  simulation_screen.dart         Standard 3D simulation screen
  ar_simulation_screen.dart      Stark/AR screen (camera + detection + hands)
  simulation_3d.dart             Particle simulation core
  simulation_bloc.dart           Simulation state/params provider
  atom_painter.dart              Particle renderer (CustomPainter)
  hud_painter.dart               HUD overlay renderer
  WireframePainter.dart          Wireframe renderer
  detection_overlay_painter.dart Detection bounding-box overlay
  wireframe_model.dart           Vertices/edges model
  house_wireframe.dart           Built-in wireframe
  object_detector.dart           Detected-object → proportional wireframe mapping
  ai_wireframe_service.dart      Claude API client for AI-generated wireframes
  hand_tracker.dart              Gesture recognition from hand landmarks
  hand_tracking_channel.dart     Dart side of the hand-tracking platform channel
  media_pipe.dart / media_pipe_handler.kt   MediaPipe integration
  native_bridger.dart            Native platform-channel bridge
  models.dart                    Shared data models

macos/Runner/AppDelegate.swift   Native camera, Vision/CoreML detection, hand tracking
```

### Platform channels

The Dart and native layers communicate over these channels:

| Channel | Type | Purpose |
| --- | --- | --- |
| `atom_sim/native_camera` | Method | Start/stop the native camera, texture registration |
| `atom_sim/hand_tracking` | Method | Init/dispose hand tracking |
| `atom_sim/hand_tracking/results` | Event | Stream of hand landmarks |
| `atom_sim/object_detection` | Method | Init/dispose object detection |
| `atom_sim/object_detection/results` | Event | Stream of detection results |
| `atom_sim/mediapipe` / `.../landmarks` | Method / Event | MediaPipe integration |

## Platforms

Configured for **macOS**, **iOS**, and **Android**. Stark mode relies on native camera, Vision/CoreML, and MediaPipe integrations; the macOS native side lives in `macos/Runner/AppDelegate.swift`.

## Prerequisites

- Flutter SDK (Dart `^3.11.4`)
- For macOS/iOS builds: Xcode and CocoaPods
- For Android builds: Android SDK / Android Studio

## Getting started

```bash
flutter pub get
flutter run                 # choose a device, or:
flutter run -d macos
flutter run -d ios
flutter run -d android
```

Grant **camera** permission when prompted — Stark mode requires it.

## Object detection models (macOS)

Object detection loads a CoreML model from the app bundle at runtime (`initYOLO` in `AppDelegate.swift`). It probes, in order:

```
YOLOv3, YOLOv3FP16, YOLOv3Int8LUT, YOLOv8s, YOLOv8n, YOLOv3Tiny, YOLOv3TinyInt8LUT
```

Model loading is **optional and gracefully degrades** — if no model is bundled, detection stays a no-op and the rest of the app runs normally. To enable detection, add one of the above `.mlmodel` (or precompiled `.mlmodelc`) files to the Runner target in Xcode so the on-disk file and the project reference stay in sync. Models are **not** checked into this repo.


## Tech notes
- There's a project demo screenshots in /screenshots folder
- Rendering is done with Flutter `CustomPainter` / `Ticker`-driven animation — no external 3D engine.
- Simulation state flows through a lightweight BLoC-style provider (`simulation_bloc.dart`).
- Dependencies: `camera`, `http`, `cupertino_icons`.
