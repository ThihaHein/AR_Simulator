// lib/engine/ai_wireframe_service.dart
// ---------------------------------------------------------------------------
// Sends detected object info to Claude API.
// Claude returns detailed 3D wireframe vertices + edges as JSON.
// Parses into WireframeModel for rendering.
// ---------------------------------------------------------------------------

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'wireframe_model.dart';

class AIWireframeService {
  // Set your API key here or pass it in
  static String apiKey = "{APIKEY}";

  static Future<WireframeModel?> generate({
    required String label,
    required double aspectW,
    required double aspectH,
    String? extraDescription,
  }) async {
    if (apiKey!.isEmpty) {
      debugPrint('AI Wireframe: No API key set');
      return null;
    }

    final prompt = '''
Generate a detailed 3D wireframe model of: "$label"
${extraDescription != null ? 'Additional details: $extraDescription' : ''}

The object's bounding box aspect ratio is ${aspectW.toStringAsFixed(2)} wide by ${aspectH.toStringAsFixed(2)} tall.
Scale the model to fit roughly within -150 to 150 on each axis.

Return ONLY valid JSON (no markdown, no explanation) in this exact format:
{
  "vertices": [[x,y,z], [x,y,z], ...],
  "edges": [[startIndex, endIndex], [startIndex, endIndex], ...],
  "name": "SHORT_NAME"
}

Rules for the wireframe:
- Make it DETAILED with 80-200 vertices minimum
- Include structural details: internal frames, cross-bracing, panel lines
- For vehicles: include wheels (as polygons), windows, bumpers, mirrors, door lines
- For buildings: include floors, windows (as grids), structural beams, antenna
- For people: include ribcage, joints, fingers, facial features outline
- For animals: include ribcage, leg joints, tail, ears, snout outline
- For furniture: include joints, cushion outlines, support struts
- For electronics: include screen bezels, ports, buttons, vents
- Make it look like a technical blueprint / holographic scan
- All edges must reference valid vertex indices
- Vertices are [x, y, z] where y-up, centered at origin
''';

    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 8000,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('AI Wireframe error: ${response.statusCode} ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body);
      final content = data['content'] as List;
      final text = content
          .where((c) => c['type'] == 'text')
          .map((c) => c['text'] as String)
          .join();

      // Clean response — strip markdown fences if present
      var clean = text.trim();
      if (clean.startsWith('```')) {
        clean = clean.replaceFirst(RegExp(r'^```\w*\n?'), '');
        clean = clean.replaceFirst(RegExp(r'\n?```$'), '');
      }

      final json = jsonDecode(clean) as Map<String, dynamic>;
      return _parseWireframe(json, label);

    } catch (e) {
      debugPrint('AI Wireframe error: $e');
      return null;
    }
  }

  static WireframeModel? _parseWireframe(Map<String, dynamic> json, String fallbackName) {
    try {
      final rawVerts = json['vertices'] as List;
      final rawEdges = json['edges'] as List;
      final name = (json['name'] as String?) ?? fallbackName.toUpperCase();

      final vertices = <Vec3>[];
      for (final v in rawVerts) {
        final coords = v as List;
        vertices.add(Vec3(
          (coords[0] as num).toDouble(),
          (coords[1] as num).toDouble(),
          (coords[2] as num).toDouble(),
        ));
      }

      final edges = <List<int>>[];
      for (final e in rawEdges) {
        final pair = e as List;
        final a = (pair[0] as num).toInt();
        final b = (pair[1] as num).toInt();
        // Validate indices
        if (a >= 0 && a < vertices.length && b >= 0 && b < vertices.length) {
          edges.add([a, b]);
        }
      }

      if (vertices.isEmpty || edges.isEmpty) return null;

      return WireframeModel(
        vertices: vertices,
        edges: edges,
        name: name,
        icon: '🤖',
      );
    } catch (e) {
      debugPrint('AI Wireframe parse error: $e');
      return null;
    }
  }
}
