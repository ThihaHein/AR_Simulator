// lib/engine/wireframe_model.dart
// ---------------------------------------------------------------------------
// 3D wireframe mesh: vertices + edges rendered as lines.
// Procedural generators create detailed architectural/mechanical models.
// ---------------------------------------------------------------------------

import 'dart:math';
import 'house_wireframe.dart';

class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);
  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
}

class WireframeModel {
  final List<Vec3> vertices;
  final List<List<int>> edges; // pairs of vertex indices
  final String name;
  final String icon;

  const WireframeModel({
    required this.vertices,
    required this.edges,
    required this.name,
    required this.icon,
  });
}


// ---------------------------------------------------------------------------
// Model library
// ---------------------------------------------------------------------------
class WireframeLibrary {
  static List<WireframeModel> all() => [
    HouseWireframe.generate(),
    skyscraper(),
    cityBlock(),
    sportsCar(),
    helicopter(),
    dnaHelix(),
    globe(),
    crystal(),
    spaceship(),
  ];

  // ===================== SKYSCRAPER =====================
  static WireframeModel skyscraper() {
    final verts = <Vec3>[];
    final edges = <List<int>>[];

    void addBox(double cx, double cy, double cz, double w, double h, double d) {
      final i = verts.length;
      verts.addAll([
        Vec3(cx - w, cy - h, cz - d), Vec3(cx + w, cy - h, cz - d),
        Vec3(cx + w, cy + h, cz - d), Vec3(cx - w, cy + h, cz - d),
        Vec3(cx - w, cy - h, cz + d), Vec3(cx + w, cy - h, cz + d),
        Vec3(cx + w, cy + h, cz + d), Vec3(cx - w, cy + h, cz + d),
      ]);
      // 12 edges of a box
      edges.addAll([
        [i,i+1],[i+1,i+2],[i+2,i+3],[i+3,i],
        [i+4,i+5],[i+5,i+6],[i+6,i+7],[i+7,i+4],
        [i,i+4],[i+1,i+5],[i+2,i+6],[i+3,i+7],
      ]);
    }

    // Main tower
    addBox(0, 0, 0, 50, 180, 50);

    // Floors (horizontal lines)
    for (int f = 0; f < 20; f++) {
      final y = -170.0 + f * 18.0;
      final i = verts.length;
      verts.addAll([
        Vec3(-50, y, -50), Vec3(50, y, -50),
        Vec3(50, y, 50), Vec3(-50, y, 50),
      ]);
      edges.addAll([[i,i+1],[i+1,i+2],[i+2,i+3],[i+3,i]]);
    }

    // Window columns (vertical lines on each face)
    for (int c = 0; c < 6; c++) {
      final x = -40.0 + c * 16.0;
      final i = verts.length;
      // Front face
      verts.addAll([Vec3(x, -180, -50), Vec3(x, 180, -50)]);
      edges.add([i, i + 1]);
      // Back face
      verts.addAll([Vec3(x, -180, 50), Vec3(x, 180, 50)]);
      edges.add([i + 2, i + 3]);
    }
    for (int c = 0; c < 6; c++) {
      final z = -40.0 + c * 16.0;
      final i = verts.length;
      // Left face
      verts.addAll([Vec3(-50, -180, z), Vec3(-50, 180, z)]);
      edges.add([i, i + 1]);
      // Right face
      verts.addAll([Vec3(50, -180, z), Vec3(50, 180, z)]);
      edges.add([i + 2, i + 3]);
    }

    // Crown structure
    addBox(0, -190, 0, 35, 15, 35);
    addBox(0, -210, 0, 20, 10, 20);

    // Antenna
    final ai = verts.length;
    verts.addAll([Vec3(0, -220, 0), Vec3(0, -270, 0)]);
    edges.add([ai, ai + 1]);
    // Antenna cross bars
    for (int b = 0; b < 3; b++) {
      final y = -230.0 - b * 12.0;
      final i = verts.length;
      verts.addAll([Vec3(-8, y, 0), Vec3(8, y, 0), Vec3(0, y, -8), Vec3(0, y, 8)]);
      edges.addAll([[i, i+1], [i+2, i+3]]);
    }

    // Base platform
    addBox(0, 190, 0, 70, 10, 70);

    // X-bracing on each face
    for (int s = 0; s < 4; s++) {
      for (int seg = 0; seg < 3; seg++) {
        final y0 = -180.0 + seg * 120.0;
        final y1 = y0 + 120.0;
        final i = verts.length;
        if (s == 0) { // front
          verts.addAll([Vec3(-50, y0, -50), Vec3(50, y1, -50), Vec3(50, y0, -50), Vec3(-50, y1, -50)]);
        } else if (s == 1) { // back
          verts.addAll([Vec3(-50, y0, 50), Vec3(50, y1, 50), Vec3(50, y0, 50), Vec3(-50, y1, 50)]);
        } else if (s == 2) { // left
          verts.addAll([Vec3(-50, y0, -50), Vec3(-50, y1, 50), Vec3(-50, y0, 50), Vec3(-50, y1, -50)]);
        } else { // right
          verts.addAll([Vec3(50, y0, -50), Vec3(50, y1, 50), Vec3(50, y0, 50), Vec3(50, y1, -50)]);
        }
        edges.addAll([[i, i+1], [i+2, i+3]]);
      }
    }

    return WireframeModel(vertices: verts, edges: edges, name: 'TOWER', icon: '🏙️');
  }

  // ===================== CITY BLOCK =====================
  static WireframeModel cityBlock() {
    final verts = <Vec3>[];
    final edges = <List<int>>[];
    final rng = Random(99);

    void addBuilding(double cx, double cz, double w, double d, double h) {
      final i = verts.length;
      final y0 = 100.0; // ground
      final y1 = y0 - h;
      verts.addAll([
        Vec3(cx-w, y0, cz-d), Vec3(cx+w, y0, cz-d),
        Vec3(cx+w, y1, cz-d), Vec3(cx-w, y1, cz-d),
        Vec3(cx-w, y0, cz+d), Vec3(cx+w, y0, cz+d),
        Vec3(cx+w, y1, cz+d), Vec3(cx-w, y1, cz+d),
      ]);
      edges.addAll([
        [i,i+1],[i+1,i+2],[i+2,i+3],[i+3,i],
        [i+4,i+5],[i+5,i+6],[i+6,i+7],[i+7,i+4],
        [i,i+4],[i+1,i+5],[i+2,i+6],[i+3,i+7],
      ]);

      // Floor lines
      final floors = (h / 25).floor();
      for (int f = 1; f < floors; f++) {
        final y = y0 - f * (h / floors);
        final fi = verts.length;
        verts.addAll([
          Vec3(cx-w, y, cz-d), Vec3(cx+w, y, cz-d),
          Vec3(cx+w, y, cz+d), Vec3(cx-w, y, cz+d),
        ]);
        edges.addAll([[fi,fi+1],[fi+1,fi+2],[fi+2,fi+3],[fi+3,fi]]);
      }
    }

    // Ground plane
    final gi = verts.length;
    verts.addAll([
      Vec3(-200, 100, -200), Vec3(200, 100, -200),
      Vec3(200, 100, 200), Vec3(-200, 100, 200),
    ]);
    edges.addAll([[gi,gi+1],[gi+1,gi+2],[gi+2,gi+3],[gi+3,gi]]);

    // Grid of buildings
    for (int bx = -2; bx <= 2; bx++) {
      for (int bz = -2; bz <= 2; bz++) {
        if (bx == 0 && bz == 0) continue; // leave center empty
        final w = 15.0 + rng.nextDouble() * 15;
        final d = 15.0 + rng.nextDouble() * 15;
        final h = 60.0 + rng.nextDouble() * 200;
        addBuilding(bx * 80.0, bz * 80.0, w, d, h);
      }
    }

    return WireframeModel(vertices: verts, edges: edges, name: 'CITY', icon: '🌃');
  }

  // ===================== SPORTS CAR =====================
  static WireframeModel sportsCar() {
    final verts = <Vec3>[];
    final edges = <List<int>>[];

    void addBox(double cx, double cy, double cz, double w, double h, double d) {
      final i = verts.length;
      verts.addAll([
        Vec3(cx-w,cy-h,cz-d), Vec3(cx+w,cy-h,cz-d),
        Vec3(cx+w,cy+h,cz-d), Vec3(cx-w,cy+h,cz-d),
        Vec3(cx-w,cy-h,cz+d), Vec3(cx+w,cy-h,cz+d),
        Vec3(cx+w,cy+h,cz+d), Vec3(cx-w,cy+h,cz+d),
      ]);
      edges.addAll([
        [i,i+1],[i+1,i+2],[i+2,i+3],[i+3,i],
        [i+4,i+5],[i+5,i+6],[i+6,i+7],[i+7,i+4],
        [i,i+4],[i+1,i+5],[i+2,i+6],[i+3,i+7],
      ]);
    }

    // Body lower
    addBox(0, 30, 0, 130, 15, 55);
    // Body upper / cabin
    addBox(-15, 5, 0, 55, 20, 48);

    // Hood slope
    final hi = verts.length;
    verts.addAll([
      Vec3(40, 5, -48), Vec3(130, 15, -55),
      Vec3(40, 5, 48), Vec3(130, 15, 55),
      Vec3(40, 25, -48), Vec3(130, 15, -55),
      Vec3(40, 25, 48), Vec3(130, 15, 55),
    ]);
    edges.addAll([[hi,hi+1],[hi+2,hi+3],[hi+4,hi+5],[hi+6,hi+7],
      [hi,hi+2],[hi+1,hi+3],[hi+4,hi+6],[hi+5,hi+7]]);

    // Trunk slope
    final ti = verts.length;
    verts.addAll([
      Vec3(-70, 5, -48), Vec3(-130, 20, -50),
      Vec3(-70, 5, 48), Vec3(-130, 20, 50),
    ]);
    edges.addAll([[ti,ti+1],[ti+2,ti+3],[ti,ti+2],[ti+1,ti+3]]);

    // Windshield
    final wi = verts.length;
    verts.addAll([
      Vec3(40, -15, -46), Vec3(40, -15, 46),
      Vec3(15, 5, -46), Vec3(15, 5, 46),
    ]);
    edges.addAll([[wi,wi+1],[wi+2,wi+3],[wi,wi+2],[wi+1,wi+3]]);

    // Rear window
    final ri = verts.length;
    verts.addAll([
      Vec3(-70, -15, -46), Vec3(-70, -15, 46),
      Vec3(-50, 5, -46), Vec3(-50, 5, 46),
    ]);
    edges.addAll([[ri,ri+1],[ri+2,ri+3],[ri,ri+2],[ri+1,ri+3]]);

    // Wheels (circles approximated with octagon)
    void addWheel(double cx, double cy, double cz, double r) {
      final segs = 12;
      for (int ring = 0; ring < 2; ring++) {
        final z = cz + (ring == 0 ? -5 : 5);
        final base = verts.length;
        for (int s = 0; s < segs; s++) {
          final a = s / segs * 2 * pi;
          verts.add(Vec3(cx + cos(a) * r, cy + sin(a) * r, z.toDouble()));
        }
        for (int s = 0; s < segs; s++) {
          edges.add([base + s, base + (s + 1) % segs]);
        }
        // Spokes
        final ci = verts.length;
        verts.add(Vec3(cx, cy, z.toDouble()));
        for (int s = 0; s < segs; s += 2) {
          edges.add([ci, base + s]);
        }
      }
      // Connect rings
      final r0 = verts.length - segs * 2 - 2;
      final r1 = r0 + segs;
      for (int s = 0; s < segs; s += 3) {
        edges.add([r0 + s, r1 + s]);
      }
    }

    addWheel(85, 45, -60, 22);
    addWheel(85, 45, 60, 22);
    addWheel(-85, 45, -60, 22);
    addWheel(-85, 45, 60, 22);

    // Spoiler
    addBox(-130, -10, 0, 5, 3, 55);
    final si = verts.length;
    verts.addAll([
      Vec3(-125, -10, -50), Vec3(-125, 15, -45),
      Vec3(-125, -10, 50), Vec3(-125, 15, 45),
    ]);
    edges.addAll([[si,si+1],[si+2,si+3]]);

    return WireframeModel(vertices: verts, edges: edges, name: 'CAR', icon: '🏎️');
  }

  // ===================== HELICOPTER =====================
  static WireframeModel helicopter() {
    final verts = <Vec3>[];
    final edges = <List<int>>[];

    void addBox(double cx, double cy, double cz, double w, double h, double d) {
      final i = verts.length;
      verts.addAll([
        Vec3(cx-w,cy-h,cz-d), Vec3(cx+w,cy-h,cz-d),
        Vec3(cx+w,cy+h,cz-d), Vec3(cx-w,cy+h,cz-d),
        Vec3(cx-w,cy-h,cz+d), Vec3(cx+w,cy-h,cz+d),
        Vec3(cx+w,cy+h,cz+d), Vec3(cx-w,cy+h,cz+d),
      ]);
      edges.addAll([
        [i,i+1],[i+1,i+2],[i+2,i+3],[i+3,i],
        [i+4,i+5],[i+5,i+6],[i+6,i+7],[i+7,i+4],
        [i,i+4],[i+1,i+5],[i+2,i+6],[i+3,i+7],
      ]);
    }

    // Fuselage
    addBox(0, 0, 0, 80, 30, 35);
    // Cockpit (front)
    addBox(70, -5, 0, 30, 25, 32);
    // Tail boom
    addBox(-140, 5, 0, 60, 10, 10);
    // Tail rotor housing
    addBox(-200, -10, 0, 8, 20, 5);

    // Main rotor mast
    final mi = verts.length;
    verts.addAll([Vec3(0, -30, 0), Vec3(0, -50, 0)]);
    edges.add([mi, mi + 1]);

    // Main rotor blades (4)
    for (int b = 0; b < 4; b++) {
      final a = b * pi / 2;
      final i = verts.length;
      verts.addAll([
        Vec3(0, -50, 0),
        Vec3(cos(a) * 150, -50, sin(a) * 150),
        Vec3(cos(a) * 150, -48, sin(a) * 150 + cos(a) * 8),
      ]);
      edges.addAll([[i, i+1], [i+1, i+2]]);
    }

    // Tail rotor (circle)
    final segs = 10;
    final trBase = verts.length;
    for (int s = 0; s < segs; s++) {
      final a = s / segs * 2 * pi;
      verts.add(Vec3(-200, -10 + cos(a) * 18, sin(a) * 18));
    }
    for (int s = 0; s < segs; s++) {
      edges.add([trBase + s, trBase + (s + 1) % segs]);
    }

    // Landing skids
    for (final side in [-1.0, 1.0]) {
      final z = side * 35;
      final i = verts.length;
      verts.addAll([
        Vec3(60, 35, z), Vec3(60, 50, z),
        Vec3(-40, 50, z), Vec3(-40, 35, z),
      ]);
      edges.addAll([[i, i+1], [i+1, i+2], [i+2, i+3]]);
    }

    // Struts
    for (final side in [-1.0, 1.0]) {
      final z = side * 35;
      final i = verts.length;
      verts.addAll([Vec3(30, 30, z), Vec3(30, 50, z.toDouble())]);
      edges.add([i, i + 1]);
      verts.addAll([Vec3(-20, 30, z), Vec3(-20, 50, z.toDouble())]);
      edges.add([i + 2, i + 3]);
    }

    return WireframeModel(vertices: verts, edges: edges, name: 'HELI', icon: '🚁');
  }

  // ===================== DNA HELIX =====================
  static WireframeModel dnaHelix() {
    final verts = <Vec3>[];
    final edges = <List<int>>[];
    final steps = 120;
    final r = 50.0;
    final height = 400.0;

    // Two helical strands
    for (int strand = 0; strand < 2; strand++) {
      final offset = strand * pi;
      final base = verts.length;
      for (int s = 0; s <= steps; s++) {
        final t = s / steps;
        final a = t * 6 * pi + offset;
        final y = (t - 0.5) * height;
        verts.add(Vec3(cos(a) * r, y, sin(a) * r));
      }
      for (int s = 0; s < steps; s++) {
        edges.add([base + s, base + s + 1]);
      }
    }

    // Rungs connecting strands
    for (int s = 0; s < steps; s += 4) {
      final t = s / steps;
      final a1 = t * 6 * pi;
      final a2 = a1 + pi;
      final y = (t - 0.5) * height;
      final i = verts.length;
      verts.addAll([
        Vec3(cos(a1) * r, y, sin(a1) * r),
        Vec3(cos(a2) * r, y, sin(a2) * r),
      ]);
      edges.add([i, i + 1]);
    }

    return WireframeModel(vertices: verts, edges: edges, name: 'DNA', icon: '🧬');
  }

  // ===================== GLOBE =====================
  static WireframeModel globe() {
    final verts = <Vec3>[];
    final edges = <List<int>>[];
    final r = 130.0;
    final latLines = 12;
    final lonLines = 16;

    // Latitude circles
    for (int lat = 1; lat < latLines; lat++) {
      final phi = lat / latLines * pi;
      final base = verts.length;
      for (int s = 0; s <= lonLines; s++) {
        final theta = s / lonLines * 2 * pi;
        verts.add(Vec3(
          sin(phi) * cos(theta) * r,
          cos(phi) * r,
          sin(phi) * sin(theta) * r,
        ));
      }
      for (int s = 0; s < lonLines; s++) {
        edges.add([base + s, base + s + 1]);
      }
    }

    // Longitude lines
    for (int lon = 0; lon < lonLines; lon++) {
      final theta = lon / lonLines * 2 * pi;
      final base = verts.length;
      for (int s = 0; s <= latLines; s++) {
        final phi = s / latLines * pi;
        verts.add(Vec3(
          sin(phi) * cos(theta) * r,
          cos(phi) * r,
          sin(phi) * sin(theta) * r,
        ));
      }
      for (int s = 0; s < latLines; s++) {
        edges.add([base + s, base + s + 1]);
      }
    }

    return WireframeModel(vertices: verts, edges: edges, name: 'GLOBE', icon: '🌍');
  }

  // ===================== CRYSTAL =====================
  static WireframeModel crystal() {
    final verts = <Vec3>[];
    final edges = <List<int>>[];
    final r = 100.0;
    final h = 180.0;

    // Top point
    verts.add(Vec3(0, -h, 0)); // 0
    // Bottom point
    verts.add(Vec3(0, h, 0)); // 1

    // Upper ring
    final segs = 8;
    for (int s = 0; s < segs; s++) {
      final a = s / segs * 2 * pi;
      verts.add(Vec3(cos(a) * r, -h * 0.3, sin(a) * r));
    }
    // Lower ring
    for (int s = 0; s < segs; s++) {
      final a = s / segs * 2 * pi + pi / segs;
      verts.add(Vec3(cos(a) * r * 0.8, h * 0.3, sin(a) * r * 0.8));
    }

    // Connect top to upper ring
    for (int s = 0; s < segs; s++) {
      edges.add([0, 2 + s]);
    }
    // Upper ring
    for (int s = 0; s < segs; s++) {
      edges.add([2 + s, 2 + (s + 1) % segs]);
    }
    // Connect upper to lower ring
    for (int s = 0; s < segs; s++) {
      edges.add([2 + s, 2 + segs + s]);
      edges.add([2 + s, 2 + segs + (s + segs - 1) % segs]);
    }
    // Lower ring
    for (int s = 0; s < segs; s++) {
      edges.add([2 + segs + s, 2 + segs + (s + 1) % segs]);
    }
    // Connect bottom to lower ring
    for (int s = 0; s < segs; s++) {
      edges.add([1, 2 + segs + s]);
    }

    // Inner structure - middle ring
    final midBase = verts.length;
    for (int s = 0; s < segs; s++) {
      final a = s / segs * 2 * pi + pi / segs / 2;
      verts.add(Vec3(cos(a) * r * 0.4, 0, sin(a) * r * 0.4));
    }
    for (int s = 0; s < segs; s++) {
      edges.add([midBase + s, midBase + (s + 1) % segs]);
      edges.add([midBase + s, 2 + s]);
      edges.add([midBase + s, 2 + segs + s]);
    }

    return WireframeModel(vertices: verts, edges: edges, name: 'CRYSTAL', icon: '💎');
  }

  // ===================== SPACESHIP =====================
  static WireframeModel spaceship() {
    final verts = <Vec3>[];
    final edges = <List<int>>[];

    void addBox(double cx, double cy, double cz, double w, double h, double d) {
      final i = verts.length;
      verts.addAll([
        Vec3(cx-w,cy-h,cz-d), Vec3(cx+w,cy-h,cz-d),
        Vec3(cx+w,cy+h,cz-d), Vec3(cx-w,cy+h,cz-d),
        Vec3(cx-w,cy-h,cz+d), Vec3(cx+w,cy-h,cz+d),
        Vec3(cx+w,cy+h,cz+d), Vec3(cx-w,cy+h,cz+d),
      ]);
      edges.addAll([
        [i,i+1],[i+1,i+2],[i+2,i+3],[i+3,i],
        [i+4,i+5],[i+5,i+6],[i+6,i+7],[i+7,i+4],
        [i,i+4],[i+1,i+5],[i+2,i+6],[i+3,i+7],
      ]);
    }

    // Nose cone
    final ni = verts.length;
    verts.add(Vec3(200, 0, 0)); // tip
    final noseSegs = 8;
    for (int s = 0; s < noseSegs; s++) {
      final a = s / noseSegs * 2 * pi;
      verts.add(Vec3(100, cos(a) * 30, sin(a) * 30));
    }
    for (int s = 0; s < noseSegs; s++) {
      edges.add([ni, ni + 1 + s]);
      edges.add([ni + 1 + s, ni + 1 + (s + 1) % noseSegs]);
    }

    // Main body (octagonal tube)
    for (int ring = 0; ring < 5; ring++) {
      final x = 100.0 - ring * 60.0;
      final r = 30.0 + ring * 3;
      final base = verts.length;
      for (int s = 0; s < noseSegs; s++) {
        final a = s / noseSegs * 2 * pi;
        verts.add(Vec3(x, cos(a) * r, sin(a) * r));
      }
      for (int s = 0; s < noseSegs; s++) {
        edges.add([base + s, base + (s + 1) % noseSegs]);
      }
      // Connect to previous ring
      if (ring > 0) {
        final prevBase = base - noseSegs;
        for (int s = 0; s < noseSegs; s++) {
          edges.add([prevBase + s, base + s]);
        }
      }
    }

    // Wings
    for (final side in [-1.0, 1.0]) {
      final i = verts.length;
      verts.addAll([
        Vec3(40, side * 30, 0), Vec3(-80, side * 120, 0),
        Vec3(-140, side * 120, 0), Vec3(-100, side * 30, 0),
      ]);
      edges.addAll([[i,i+1],[i+1,i+2],[i+2,i+3],[i+3,i],[i,i+2]]);
    }

    // Engines
    for (final side in [-1.0, 1.0]) {
      addBox(-160, side * 90, 0, 30, 12, 12);
      // Engine nozzle circle
      final eBase = verts.length;
      for (int s = 0; s < 8; s++) {
        final a = s / 8 * 2 * pi;
        verts.add(Vec3(-190, side * 90 + cos(a) * 15, sin(a) * 15));
      }
      for (int s = 0; s < 8; s++) {
        edges.add([eBase + s, eBase + (s + 1) % 8]);
      }
    }

    // Tail fin
    final fi = verts.length;
    verts.addAll([
      Vec3(-100, -30, 0), Vec3(-180, -80, 0), Vec3(-200, -30, 0),
    ]);
    edges.addAll([[fi,fi+1],[fi+1,fi+2],[fi+2,fi]]);

    return WireframeModel(vertices: verts, edges: edges, name: 'SHIP', icon: '🚀');
  }
}