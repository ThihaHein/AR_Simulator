// lib/engine/object_detector.dart
// ---------------------------------------------------------------------------
// Maps detected objects to wireframes that match their bounding box shape.
// Uses YOLO's 80 COCO classes for label → wireframe type mapping.
// Generates wireframes proportional to the actual detected bounding box.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'wireframe_model.dart';

class DetectedObject {
  final String label;
  final double confidence;
  final double x, y, w, h; // normalised 0..1
  final WireframeModel? wireframe;

  const DetectedObject({
    required this.label,
    required this.confidence,
    required this.x, required this.y,
    required this.w, required this.h,
    this.wireframe,
  });
}

// ---------------------------------------------------------------------------
// Generates wireframes proportional to the bounding box
// ---------------------------------------------------------------------------
class ProportionalWireframeGen {

  static WireframeModel generate(String label, double boxW, double boxH) {
    final type = _classifyLabel(label);
    switch (type) {
      case _ObjType.person:   return _person(boxW, boxH);
      case _ObjType.vehicle:  return _vehicle(boxW, boxH);
      case _ObjType.building: return _building(boxW, boxH);
      case _ObjType.animal:   return _animal(boxW, boxH);
      case _ObjType.screen:   return _screen(boxW, boxH);
      case _ObjType.bottle:   return _bottle(boxW, boxH);
      case _ObjType.chair:    return _chair(boxW, boxH);
      case _ObjType.table:    return _table(boxW, boxH);
      case _ObjType.round:    return _sphere(boxW, boxH);
      case _ObjType.generic:  return _box3D(boxW, boxH, label);
    }
  }

  // --- Classify COCO labels ---
  static _ObjType _classifyLabel(String label) {
    final l = label.toLowerCase();
    if (['person', 'man', 'woman', 'child', 'human'].any((k) => l.contains(k))) return _ObjType.person;
    if (['car', 'truck', 'bus', 'motorcycle', 'bicycle', 'train', 'boat', 'vehicle'].any((k) => l.contains(k))) return _ObjType.vehicle;
    if (['airplane', 'aeroplane', 'helicopter'].any((k) => l.contains(k))) return _ObjType.vehicle;
    if (['building', 'house', 'tower', 'skyscraper'].any((k) => l.contains(k))) return _ObjType.building;
    if (['cat', 'dog', 'bird', 'horse', 'cow', 'sheep', 'bear', 'elephant', 'zebra', 'giraffe', 'animal'].any((k) => l.contains(k))) return _ObjType.animal;
    if (['tv', 'laptop', 'monitor', 'screen', 'cell phone', 'phone', 'tablet'].any((k) => l.contains(k))) return _ObjType.screen;
    if (['bottle', 'cup', 'wine glass', 'vase', 'glass'].any((k) => l.contains(k))) return _ObjType.bottle;
    if (['chair', 'couch', 'sofa', 'bench'].any((k) => l.contains(k))) return _ObjType.chair;
    if (['dining table', 'table', 'desk'].any((k) => l.contains(k))) return _ObjType.table;
    if (['ball', 'sports ball', 'orange', 'apple', 'clock', 'frisbee'].any((k) => l.contains(k))) return _ObjType.round;
    return _ObjType.generic;
  }

  // --- Person wireframe (stick figure proportional to bbox) ---
  static WireframeModel _person(double bw, double bh) {
    final w = bw * 150;  // scale to reasonable wireframe size
    final h = bh * 300;
    final v = <Vec3>[];
    final e = <List<int>>[];

    // Head
    _addCircle(v, e, 0, -h * 0.42, 0, w * 0.15, 10);
    // Neck
    final ni = v.length;
    v.addAll([Vec3(0, -h * 0.35, 0), Vec3(0, -h * 0.30, 0)]);
    e.add([ni, ni + 1]);
    // Shoulders
    final si = v.length;
    v.addAll([Vec3(-w * 0.3, -h * 0.30, 0), Vec3(w * 0.3, -h * 0.30, 0)]);
    e.add([si, si + 1]);
    // Spine
    final spi = v.length;
    v.addAll([Vec3(0, -h * 0.30, 0), Vec3(0, h * 0.05, 0)]);
    e.add([spi, spi + 1]);
    // Hips
    final hi = v.length;
    v.addAll([Vec3(-w * 0.2, h * 0.05, 0), Vec3(w * 0.2, h * 0.05, 0)]);
    e.add([hi, hi + 1]);
    // Left arm
    final la = v.length;
    v.addAll([Vec3(-w * 0.3, -h * 0.30, 0), Vec3(-w * 0.4, -h * 0.1, 0), Vec3(-w * 0.35, h * 0.05, 0)]);
    e.addAll([[la, la + 1], [la + 1, la + 2]]);
    // Right arm
    final ra = v.length;
    v.addAll([Vec3(w * 0.3, -h * 0.30, 0), Vec3(w * 0.4, -h * 0.1, 0), Vec3(w * 0.35, h * 0.05, 0)]);
    e.addAll([[ra, ra + 1], [ra + 1, ra + 2]]);
    // Left leg
    final ll = v.length;
    v.addAll([Vec3(-w * 0.2, h * 0.05, 0), Vec3(-w * 0.22, h * 0.25, 0), Vec3(-w * 0.2, h * 0.48, 0)]);
    e.addAll([[ll, ll + 1], [ll + 1, ll + 2]]);
    // Right leg
    final rl = v.length;
    v.addAll([Vec3(w * 0.2, h * 0.05, 0), Vec3(w * 0.22, h * 0.25, 0), Vec3(w * 0.2, h * 0.48, 0)]);
    e.addAll([[rl, rl + 1], [rl + 1, rl + 2]]);
    // Ribcage
    for (int r = 0; r < 3; r++) {
      final ry = -h * 0.25 + r * h * 0.08;
      final rw = w * (0.25 - r * 0.03);
      _addRect(v, e, 0, ry, 0, rw, 2, w * 0.08);
    }

    return WireframeModel(vertices: v, edges: e, name: 'PERSON', icon: '🧍');
  }

  // --- Vehicle wireframe ---
  static WireframeModel _vehicle(double bw, double bh) {
    final w = bw * 200;
    final h = bh * 150;
    final d = min(w, h) * 0.4;
    final v = <Vec3>[];
    final e = <List<int>>[];

    // Body lower
    _addBox(v, e, 0, h * 0.15, 0, w * 0.48, h * 0.12, d * 0.9);
    // Cabin
    _addBox(v, e, -w * 0.05, -h * 0.1, 0, w * 0.22, h * 0.15, d * 0.8);
    // Hood slope
    final hi = v.length;
    v.addAll([
      Vec3(w * 0.17, -h * 0.1, -d * 0.78), Vec3(w * 0.48, h * 0.03, -d * 0.88),
      Vec3(w * 0.17, -h * 0.1, d * 0.78),  Vec3(w * 0.48, h * 0.03, d * 0.88),
    ]);
    e.addAll([[hi, hi + 1], [hi + 2, hi + 3], [hi, hi + 2], [hi + 1, hi + 3]]);
    // Wheels
    for (final sx in [-1.0, 1.0]) {
      for (final sz in [-1.0, 1.0]) {
        _addCircle(v, e, sx * w * 0.32, h * 0.3, sz * d * 0.95, h * 0.12, 10);
      }
    }
    // Windshield
    final wi = v.length;
    v.addAll([
      Vec3(w * 0.17, -h * 0.25, -d * 0.75), Vec3(w * 0.17, -h * 0.25, d * 0.75),
      Vec3(w * 0.08, -h * 0.1, -d * 0.75),  Vec3(w * 0.08, -h * 0.1, d * 0.75),
    ]);
    e.addAll([[wi, wi + 1], [wi + 2, wi + 3], [wi, wi + 2], [wi + 1, wi + 3]]);

    return WireframeModel(vertices: v, edges: e, name: 'VEHICLE', icon: '🚗');
  }

  // --- Building wireframe ---
  static WireframeModel _building(double bw, double bh) {
    final w = bw * 150;
    final h = bh * 300;
    final d = w * 0.6;
    final v = <Vec3>[];
    final e = <List<int>>[];

    // Main structure
    _addBox(v, e, 0, 0, 0, w * 0.4, h * 0.48, d * 0.4);
    // Floors
    final floors = (h / 30).floor().clamp(3, 20);
    for (int f = 1; f < floors; f++) {
      final fy = -h * 0.48 + f * (h * 0.96 / floors);
      _addRect(v, e, 0, fy, -d * 0.4, w * 0.4, 0, 0); // front face
      _addRect(v, e, 0, fy, d * 0.4, w * 0.4, 0, 0);   // back face
    }
    // Window columns
    final cols = (w / 20).floor().clamp(2, 8);
    for (int c = 0; c < cols; c++) {
      final cx = -w * 0.35 + c * (w * 0.7 / (cols - 1));
      final ci = v.length;
      v.addAll([Vec3(cx, -h * 0.48, -d * 0.4), Vec3(cx, h * 0.48, -d * 0.4)]);
      e.add([ci, ci + 1]);
    }
    // Antenna
    final ai = v.length;
    v.addAll([Vec3(0, -h * 0.48, 0), Vec3(0, -h * 0.62, 0)]);
    e.add([ai, ai + 1]);

    return WireframeModel(vertices: v, edges: e, name: 'BUILDING', icon: '🏙️');
  }

  // --- Animal wireframe (quadruped) ---
  static WireframeModel _animal(double bw, double bh) {
    final w = bw * 180;
    final h = bh * 150;
    final d = min(w, h) * 0.3;
    final v = <Vec3>[];
    final e = <List<int>>[];

    // Body
    _addBox(v, e, 0, 0, 0, w * 0.35, h * 0.15, d * 0.8);
    // Head
    _addBox(v, e, w * 0.4, -h * 0.1, 0, w * 0.1, h * 0.1, d * 0.5);
    // Neck
    final ni = v.length;
    v.addAll([Vec3(w * 0.35, -h * 0.05, 0), Vec3(w * 0.3, h * 0.0, 0)]);
    e.add([ni, ni + 1]);
    // Legs (4)
    for (final sx in [0.2, -0.2]) {
      for (final sz in [-0.6, 0.6]) {
        final li = v.length;
        v.addAll([Vec3(w * sx, h * 0.15, d * sz), Vec3(w * sx, h * 0.45, d * sz)]);
        e.add([li, li + 1]);
      }
    }
    // Tail
    final ti = v.length;
    v.addAll([Vec3(-w * 0.35, -h * 0.05, 0), Vec3(-w * 0.45, -h * 0.15, 0)]);
    e.add([ti, ti + 1]);

    return WireframeModel(vertices: v, edges: e, name: 'ANIMAL', icon: '🐕');
  }

  // --- Screen/laptop wireframe ---
  static WireframeModel _screen(double bw, double bh) {
    final w = bw * 180;
    final h = bh * 150;
    final v = <Vec3>[];
    final e = <List<int>>[];

    // Screen
    _addBox(v, e, 0, -h * 0.1, 0, w * 0.45, h * 0.35, 3);
    // Bezel inner rect
    _addRect(v, e, 0, -h * 0.1, -3.1, w * 0.4, h * 0.3, 0);
    // Stand/base
    _addBox(v, e, 0, h * 0.35, 0, w * 0.15, h * 0.03, 15);
    // Neck
    final ni = v.length;
    v.addAll([Vec3(0, h * 0.25, 0), Vec3(0, h * 0.32, 0)]);
    e.add([ni, ni + 1]);

    return WireframeModel(vertices: v, edges: e, name: 'SCREEN', icon: '💻');
  }

  // --- Bottle wireframe ---
  static WireframeModel _bottle(double bw, double bh) {
    final w = bw * 100;
    final h = bh * 200;
    final v = <Vec3>[];
    final e = <List<int>>[];

    // Body cylinder
    for (int ring = 0; ring < 6; ring++) {
      final ry = -h * 0.1 + ring * h * 0.15;
      final r = (ring < 2) ? w * 0.1 : w * 0.25;
      _addCircle(v, e, 0, ry, 0, r, 8);
    }
    // Connect rings vertically
    for (int ring = 0; ring < 5; ring++) {
      for (int s = 0; s < 8; s += 2) {
        final a = ring * 8 + s;
        final b = (ring + 1) * 8 + s;
        if (a < v.length && b < v.length) e.add([a, b]);
      }
    }
    // Cap
    _addCircle(v, e, 0, -h * 0.15, 0, w * 0.08, 6);

    return WireframeModel(vertices: v, edges: e, name: 'BOTTLE', icon: '🍶');
  }

  // --- Chair ---
  static WireframeModel _chair(double bw, double bh) {
    final w = bw * 140;
    final h = bh * 180;
    final d = min(w, h) * 0.4;
    final v = <Vec3>[];
    final e = <List<int>>[];

    _addBox(v, e, 0, h * 0.05, 0, w * 0.35, 3, d * 0.8); // seat
    _addBox(v, e, 0, -h * 0.25, -d * 0.7, w * 0.35, h * 0.25, 3); // back
    // Legs
    for (final sx in [-0.3, 0.3]) {
      for (final sz in [-0.7, 0.7]) {
        final li = v.length;
        v.addAll([Vec3(w * sx, h * 0.08, d * sz), Vec3(w * sx, h * 0.45, d * sz)]);
        e.add([li, li + 1]);
      }
    }
    return WireframeModel(vertices: v, edges: e, name: 'CHAIR', icon: '🪑');
  }

  // --- Table ---
  static WireframeModel _table(double bw, double bh) {
    final w = bw * 180;
    final h = bh * 120;
    final d = min(w, h) * 0.5;
    final v = <Vec3>[];
    final e = <List<int>>[];

    _addBox(v, e, 0, -h * 0.1, 0, w * 0.45, 3, d * 0.9); // top
    for (final sx in [-0.4, 0.4]) {
      for (final sz in [-0.8, 0.8]) {
        final li = v.length;
        v.addAll([Vec3(w * sx, -h * 0.07, d * sz), Vec3(w * sx, h * 0.4, d * sz)]);
        e.add([li, li + 1]);
      }
    }
    return WireframeModel(vertices: v, edges: e, name: 'TABLE', icon: '🪑');
  }

  // --- Sphere ---
  static WireframeModel _sphere(double bw, double bh) {
    final r = min(bw, bh) * 80;
    final v = <Vec3>[];
    final e = <List<int>>[];

    for (int lat = 1; lat < 8; lat++) {
      final phi = lat / 8 * pi;
      final base = v.length;
      for (int s = 0; s <= 12; s++) {
        final theta = s / 12 * 2 * pi;
        v.add(Vec3(sin(phi) * cos(theta) * r, cos(phi) * r, sin(phi) * sin(theta) * r));
      }
      for (int s = 0; s < 12; s++) e.add([base + s, base + s + 1]);
    }
    for (int lon = 0; lon < 12; lon += 2) {
      final theta = lon / 12 * 2 * pi;
      final base = v.length;
      for (int s = 0; s <= 8; s++) {
        final phi = s / 8 * pi;
        v.add(Vec3(sin(phi) * cos(theta) * r, cos(phi) * r, sin(phi) * sin(theta) * r));
      }
      for (int s = 0; s < 8; s++) e.add([base + s, base + s + 1]);
    }
    return WireframeModel(vertices: v, edges: e, name: 'SPHERE', icon: '⚽');
  }

  // --- Generic 3D box matching aspect ratio ---
  static WireframeModel _box3D(double bw, double bh, String label) {
    final w = bw * 150;
    final h = bh * 150;
    final d = min(w, h) * 0.4;
    final v = <Vec3>[];
    final e = <List<int>>[];
    _addBox(v, e, 0, 0, 0, w * 0.4, h * 0.4, d);
    // Cross bracing
    final ci = v.length;
    v.addAll([
      Vec3(-w * 0.4, -h * 0.4, -d), Vec3(w * 0.4, h * 0.4, -d),
      Vec3(w * 0.4, -h * 0.4, -d), Vec3(-w * 0.4, h * 0.4, -d),
    ]);
    e.addAll([[ci, ci + 1], [ci + 2, ci + 3]]);
    return WireframeModel(vertices: v, edges: e, name: label.toUpperCase(), icon: '📦');
  }

  // --- Primitive helpers ---

  static void _addBox(List<Vec3> v, List<List<int>> e,
      double cx, double cy, double cz, double w, double h, double d) {
    final i = v.length;
    v.addAll([
      Vec3(cx-w,cy-h,cz-d), Vec3(cx+w,cy-h,cz-d),
      Vec3(cx+w,cy+h,cz-d), Vec3(cx-w,cy+h,cz-d),
      Vec3(cx-w,cy-h,cz+d), Vec3(cx+w,cy-h,cz+d),
      Vec3(cx+w,cy+h,cz+d), Vec3(cx-w,cy+h,cz+d),
    ]);
    e.addAll([
      [i,i+1],[i+1,i+2],[i+2,i+3],[i+3,i],
      [i+4,i+5],[i+5,i+6],[i+6,i+7],[i+7,i+4],
      [i,i+4],[i+1,i+5],[i+2,i+6],[i+3,i+7],
    ]);
  }

  static void _addRect(List<Vec3> v, List<List<int>> e,
      double cx, double cy, double cz, double w, double h, double d) {
    final i = v.length;
    v.addAll([
      Vec3(cx-w, cy-h, cz-d), Vec3(cx+w, cy-h, cz-d),
      Vec3(cx+w, cy+h, cz+d), Vec3(cx-w, cy+h, cz+d),
    ]);
    e.addAll([[i, i+1], [i+1, i+2], [i+2, i+3], [i+3, i]]);
  }

  static void _addCircle(List<Vec3> v, List<List<int>> e,
      double cx, double cy, double cz, double r, int segs) {
    final base = v.length;
    for (int s = 0; s < segs; s++) {
      final a = s / segs * 2 * pi;
      v.add(Vec3(cx + cos(a) * r, cy + sin(a) * r, cz));
    }
    for (int s = 0; s < segs; s++) {
      e.add([base + s, base + (s + 1) % segs]);
    }
  }
}

enum _ObjType { person, vehicle, building, animal, screen, bottle, chair, table, round, generic }

// ---------------------------------------------------------------------------
// Object detection channel
// ---------------------------------------------------------------------------
class ObjectDetectionChannel {
  static const _method = MethodChannel('atom_sim/object_detection');
  static const _event = EventChannel('atom_sim/object_detection/results');

  StreamSubscription? _sub;
  void Function(List<DetectedObject>)? onObjectsDetected;

  Future<bool> start() async {
    try {
      final ok = await _method.invokeMethod<bool>('init') ?? false;
      if (!ok) return false;
      _sub = _event.receiveBroadcastStream().listen(_onResult, onError: (e) {});
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    try { await _method.invokeMethod('dispose'); } catch (_) {}
  }

  void _onResult(dynamic data) {
    try {
      final Map<String, dynamic> map;
      if (data is Map) { map = Map<String, dynamic>.from(data); }
      else if (data is String) { map = jsonDecode(data); }
      else { return; }

      final rawList = map['objects'];
      if (rawList is! List) { onObjectsDetected?.call([]); return; }

      final objects = <DetectedObject>[];
      for (final obj in rawList) {
        if (obj is! Map) continue;
        final label = obj['label']?.toString() ?? 'unknown';
        final conf = (obj['confidence'] as num?)?.toDouble() ?? 0;
        final x = (obj['x'] as num?)?.toDouble() ?? 0;
        final y = (obj['y'] as num?)?.toDouble() ?? 0;
        final w = (obj['w'] as num?)?.toDouble() ?? 0;
        final h = (obj['h'] as num?)?.toDouble() ?? 0;
        if (conf < 0.25 || w < 0.03 || h < 0.03) continue;

        final wireframe = ProportionalWireframeGen.generate(label, w, h);

        objects.add(DetectedObject(
          label: label, confidence: conf,
          x: x, y: y, w: w, h: h,
          wireframe: wireframe,
        ));
      }

      onObjectsDetected?.call(objects);
    } catch (_) {}
  }
}