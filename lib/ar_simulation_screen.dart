import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../simulation_bloc.dart';
import '../simulation_3d.dart';
import '../hand_tracker.dart';
import '../hand_tracking_channel.dart';
import '../models.dart';
import '../wireframe_model.dart';
import '../atom_painter.dart';
import '../hud_painter.dart';
import 'WireframePainter.dart';
import 'ai_wireframe_service.dart';
import 'detection_overlay_painter.dart';
import 'object_detector.dart';



enum ViewMode {
  manual,      // manual wireframe/particle selection
  detecting,   // camera scanning for objects
  generating,  // AI is building wireframe
  aiWireframe, // showing AI-generated wireframe
}

class ARSimulationScreen extends StatefulWidget {
  const ARSimulationScreen({super.key});
  @override
  State<ARSimulationScreen> createState() => _ARSimulationScreenState();
}

class _ARSimulationScreenState extends State<ARSimulationScreen>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  AtomSimulation3D? _sim;
  Duration _prev = Duration.zero;
  double _elapsed = 0;

  // Camera
  bool _cameraReady = false;
  int _nativeTextureId = -1;

  // Hand tracking
  final _handChannel = HandTrackingChannel();
  final _gestureEngine = HandGestureEngine();
  List<HandData> _hands = [];
  GestureResult _gesture = const GestureResult();

  // Transform
  double _offsetX = 0, _offsetY = 0, _scale = 1.0, _extraRotY = 0;
  double _baseScale = 1.0, _baseRotation = 0;
  bool _hudVisible = true, _handTrackingActive = false;

  // Manual models
  late final List<WireframeModel> _wireframeModels;
  int _selectedModel = 0;
  bool _useWireframe = true;

  // Detection + AI
  ViewMode _mode = ViewMode.manual;
  final _objectChannel = ObjectDetectionChannel();
  List<DetectedObject> _detectedObjects = [];
  WireframeModel? _aiWireframe;
  String _aiStatus = '';
  String _selectedLabel = '';

  @override
  void initState() {
    super.initState();
    _wireframeModels = WireframeLibrary.all();
    _ticker = createTicker(_onTick)..start();
    _initCamera();
    _checkApiKey();
  }

  void _checkApiKey() {
    // Show key dialog on first launch if not set
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AIWireframeService.apiKey == null || AIWireframeService.apiKey!.isEmpty) {
        _showApiKeyDialog();
      }
    });
  }

  Future<void> _initCamera() async {
    try {
      const channel = MethodChannel('atom_sim/native_camera');
      final id = await channel.invokeMethod<int>('start');
      if (id != null && id >= 0) _nativeTextureId = id;

      _handChannel.onHandsDetected = (hands) {
        _hands = hands;
        _gesture = _gestureEngine.process(hands);
        _applyHandGesture(_gesture);
      };
      final started = await _handChannel.start();
      _handTrackingActive = started;

      _objectChannel.onObjectsDetected = (objects) {
        if (_mode == ViewMode.detecting) {
          _detectedObjects = objects;
        }
      };
      await _objectChannel.start();

      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  void _applyHandGesture(GestureResult g) {
    switch (g.type) {
      case GestureType.grab:
        _offsetX += g.dx * 300; _offsetY += g.dy * 300;
      case GestureType.pinch:
      case GestureType.twoHandPinch:
        _scale = (_scale * g.scale).clamp(0.3, 3.0);
      case GestureType.point:
        _extraRotY += g.rotY * 0.5;
      case GestureType.openPalm:
        _offsetX *= 0.97; _offsetY *= 0.97;
      case GestureType.none:
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sim == null) {
      final bloc = SimulationProvider.of(context);
      final size = MediaQuery.of(context).size;
      _sim = AtomSimulation3D(size.width, size.height, bloc.params);
      bloc.dispatch(SimStarted());
    }
  }

  void _onTick(Duration elapsed) {
    if (_sim == null) return;
    final dt = (_prev == Duration.zero) ? 0.0 : (elapsed - _prev).inMicroseconds / 1e6;
    _prev = elapsed;
    if (dt <= 0 || dt > 0.1) return;
    _elapsed += dt;
    _sim!.step(dt);
    SimulationProvider.of(context).tickFps(dt);
    (context as Element).markNeedsBuild();
  }

  // --- Tap on detected object → ask AI to generate wireframe ---
  void _onDetectedObjectTapped(DetectedObject obj) {
    setState(() {
      _mode = ViewMode.generating;
      _selectedLabel = obj.label;
      _aiStatus = 'Generating wireframe for "${obj.label}"...';
    });

    AIWireframeService.generate(
      label: obj.label,
      aspectW: obj.w,
      aspectH: obj.h,
      extraDescription: 'confidence: ${(obj.confidence * 100).toStringAsFixed(0)}%',
    ).then((wireframe) {
      if (mounted) {
        setState(() {
          if (wireframe != null) {
            _aiWireframe = wireframe;
            _mode = ViewMode.aiWireframe;
            _offsetX = 0; _offsetY = 0;
            _scale = 1.0; _extraRotY = 0;
            _aiStatus = '';
          } else {
            _aiStatus = 'Failed to generate. Check API key.';
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => _mode = ViewMode.detecting);
            });
          }
        });
      }
    });
  }

  void _backToDetect() {
    setState(() {
      _mode = ViewMode.detecting;
      _aiWireframe = null;
      _detectedObjects = [];
    });
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController(text: AIWireframeService.apiKey ?? '');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('API Key', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your Anthropic API key for AI wireframe generation.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'sk-ant-...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0x3300E5FF)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Skip', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              AIWireframeService.apiKey = controller.text.trim();
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFF00E5FF))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _handChannel.stop();
    _objectChannel.stop();
    if (_nativeTextureId >= 0) {
      const MethodChannel('atom_sim/native_camera').invokeMethod('stop');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = SimulationProvider.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onScaleStart: (d) { _baseScale = _scale; _baseRotation = _extraRotY; },
        onScaleUpdate: (d) {
          setState(() {
            if (d.pointerCount == 1) {
              // In detect mode, check if tapping a detected object
              if (_mode == ViewMode.detecting && _detectedObjects.isNotEmpty) {
                // Only move if dragging (not initial tap)
                if (d.focalPointDelta.distance > 2) {
                  _offsetX += d.focalPointDelta.dx;
                  _offsetY += d.focalPointDelta.dy;
                }
              } else {
                _offsetX += d.focalPointDelta.dx;
                _offsetY += d.focalPointDelta.dy;
              }
            } else {
              _scale = (_baseScale * d.scale).clamp(0.3, 3.0);
              _extraRotY = _baseRotation + d.rotation;
            }
          });
        },
        onDoubleTap: () => setState(() {
          _offsetX = 0; _offsetY = 0; _scale = 1.0; _extraRotY = 0;
        }),
        // Tap to select detected object
        onTapUp: (details) {
          if (_mode != ViewMode.detecting) return;
          final tapX = details.localPosition.dx / size.width;
          final tapY = details.localPosition.dy / size.height;

          for (final obj in _detectedObjects) {
            if (tapX >= obj.x && tapX <= obj.x + obj.w &&
                tapY >= obj.y && tapY <= obj.y + obj.h) {
              _onDetectedObjectTapped(obj);
              return;
            }
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // === Camera feed ===
            if (_cameraReady && _nativeTextureId >= 0)
              Positioned.fill(child: Texture(textureId: _nativeTextureId))
            else
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.3), radius: 1.2,
                      colors: [Color(0xFF0d0d20), Color(0xFF06060e)],
                    ),
                  ),
                ),
              ),

            if (_cameraReady)
              Positioned.fill(child: Container(color: Colors.black.withOpacity(0.25))),

            // === Content layer (depends on mode) ===
            if (_mode == ViewMode.detecting)
            // Show detection bounding boxes (tappable)
              Positioned.fill(
                child: CustomPaint(
                  painter: DetectionOverlayPainter(
                    objects: _detectedObjects,
                    time: _elapsed,
                  ),
                ),
              )
            else if (_mode == ViewMode.aiWireframe && _aiWireframe != null)
            // Show AI-generated wireframe
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(_offsetX, _offsetY),
                  child: CustomPaint(
                    painter: WireframePainter(
                      model: _aiWireframe!,
                      rotY: _elapsed * 0.3 + _extraRotY,
                      rotX: 0.15,
                      scale: _scale,
                      time: _elapsed,
                    ),
                  ),
                ),
              )
            else if (_mode == ViewMode.manual && _useWireframe)
              // Manual wireframe selection
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(_offsetX, _offsetY),
                    child: CustomPaint(
                      painter: WireframePainter(
                        model: _wireframeModels[_selectedModel],
                        rotY: _elapsed * 0.3 + _extraRotY,
                        rotX: 0.15,
                        scale: _scale,
                        time: _elapsed,
                      ),
                    ),
                  ),
                )
              else if (_mode == ViewMode.manual && _sim != null)
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(_offsetX, _offsetY),
                      child: Transform.scale(
                        scale: _scale,
                        child: CustomPaint(
                          painter: AtomPainter(_sim!, schemeIdx: bloc.colorScheme),
                        ),
                      ),
                    ),
                  ),

            // === Generating overlay ===
            if (_mode == ViewMode.generating)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: const Color(0x33000000),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0x3300E5FF)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 40, height: 40,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Color(0xFF00E5FF)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'GENERATING WIREFRAME',
                                style: const TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  letterSpacing: 3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '"$_selectedLabel"',
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'AI is building the hologram...',
                                style: TextStyle(color: Colors.white30, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // === HUD ===
            if (_hudVisible && _mode != ViewMode.generating)
              Positioned.fill(
                child: CustomPaint(
                  painter: StarkHudPainter(
                    hands: _hands,
                    gesture: _gesture,
                    simScale: _scale,
                    simRotY: (_sim?.angle ?? 0) + _extraRotY,
                    fps: bloc.fps,
                    time: _elapsed,
                  ),
                ),
              ),

            // === Top bar ===
            Positioned(
              top: 50, left: 16, right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StarkBtn(
                    icon: Icons.arrow_back_ios_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  Column(
                    children: [
                      Text(
                        _mode == ViewMode.detecting ? 'D E T E C T' :
                        _mode == ViewMode.aiWireframe ? 'A I   M O D E L' :
                        'S T A R K   M O D E',
                        style: const TextStyle(
                          color: Color(0xFF00E5FF), fontSize: 11,
                          fontWeight: FontWeight.w600, letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatusDot(active: _cameraReady, label: 'CAM'),
                          const SizedBox(width: 12),
                          if (_mode == ViewMode.detecting)
                            _StatusDot(
                              active: _detectedObjects.isNotEmpty,
                              label: 'OBJ ${_detectedObjects.length}',
                            )
                          else
                            _StatusDot(
                              active: _handTrackingActive && _hands.isNotEmpty,
                              label: 'HANDS ${_hands.length}',
                            ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StarkBtn(
                        icon: Icons.key_rounded,
                        onTap: _showApiKeyDialog,
                      ),
                      const SizedBox(width: 8),
                      _StarkBtn(
                        icon: _hudVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        onTap: () => setState(() => _hudVisible = !_hudVisible),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // === Detect mode hint ===
            if (_mode == ViewMode.detecting && _detectedObjects.isNotEmpty)
              Positioned(
                top: 100, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x66000000),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'TAP AN OBJECT TO GENERATE WIREFRAME',
                      style: TextStyle(
                        color: Color(0xFF00E5FF), fontSize: 9,
                        fontWeight: FontWeight.w600, letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),

            // === AI wireframe: back to detect button ===
            if (_mode == ViewMode.aiWireframe)
              Positioned(
                top: 100, left: 0, right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _backToDetect,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0x3300E5FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0x5500E5FF)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.radar_rounded, color: Color(0xFF00E5FF), size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'BACK TO DETECT',
                            style: TextStyle(
                              color: Color(0xFF00E5FF), fontSize: 10,
                              fontWeight: FontWeight.w700, letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // === Model picker ===
            Positioned(
              left: 0, right: 0, bottom: 80,
              child: SizedBox(
                height: 70,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // DETECT mode
                    GestureDetector(
                      onTap: () => setState(() {
                        _mode = ViewMode.detecting;
                        _aiWireframe = null;
                      }),
                      child: _ModelChip(
                        icon: '👁️', name: 'DETECT',
                        selected: _mode == ViewMode.detecting || _mode == ViewMode.generating,
                      ),
                    ),
                    // AI wireframe (if generated)
                    if (_aiWireframe != null)
                      GestureDetector(
                        onTap: () => setState(() {
                          _mode = ViewMode.aiWireframe;
                          _offsetX = 0; _offsetY = 0; _scale = 1.0; _extraRotY = 0;
                        }),
                        child: _ModelChip(
                          icon: '🤖', name: _aiWireframe!.name,
                          selected: _mode == ViewMode.aiWireframe,
                        ),
                      ),
                    // Manual wireframes
                    ..._wireframeModels.asMap().entries.map((entry) {
                      final i = entry.key;
                      final m = entry.value;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _mode = ViewMode.manual;
                          _useWireframe = true;
                          _selectedModel = i;
                          _offsetX = 0; _offsetY = 0; _scale = 1.0; _extraRotY = 0;
                        }),
                        child: _ModelChip(
                          icon: m.icon, name: m.name,
                          selected: _mode == ViewMode.manual && _useWireframe && _selectedModel == i,
                        ),
                      );
                    }),
                    // Particles
                    GestureDetector(
                      onTap: () => setState(() {
                        _mode = ViewMode.manual;
                        _useWireframe = false;
                        _offsetX = 0; _offsetY = 0; _scale = 1.0; _extraRotY = 0;
                      }),
                      child: _ModelChip(
                        icon: '⚛️', name: 'ATOMS',
                        selected: _mode == ViewMode.manual && !_useWireframe,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // === Bottom bar ===
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _BottomBar(bloc: bloc),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------
class _StatusDot extends StatelessWidget {
  final bool active;
  final String label;
  const _StatusDot({required this.active, required this.label});
  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF1DD1A1) : const Color(0xFFFF6B6B);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1)),
    ]);
  }
}

class _StarkBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StarkBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: const Color(0x1500E5FF), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x2200E5FF)),
        ),
        child: Icon(icon, color: const Color(0xFF00E5FF), size: 18),
      ),
    );
  }
}

class _ModelChip extends StatelessWidget {
  final String icon, name;
  final bool selected;
  const _ModelChip({required this.icon, required this.name, required this.selected});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 60, margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: selected ? const Color(0x3300E5FF) : const Color(0x15FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? const Color(0xFF00E5FF) : const Color(0x22FFFFFF),
          width: selected ? 1.5 : 0.5,
        ),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(name, style: TextStyle(
          color: selected ? const Color(0xFF00E5FF) : const Color(0x88FFFFFF),
          fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1,
        )),
      ]),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final SimulationBloc bloc;
  const _BottomBar({required this.bloc});
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 14, 20, bottom + 14),
          decoration: const BoxDecoration(
            color: Color(0x66000000),
            border: Border(top: BorderSide(color: Color(0x1500E5FF))),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _BarIcon(Icons.palette_outlined, 'THEME', () {
              final n = (bloc.colorScheme + 1) % kColorSchemes.length;
              bloc.dispatch(SimColorSchemeChanged(n));
            }),
            _BarIcon(
              bloc.state == SimState.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              bloc.state == SimState.paused ? 'PLAY' : 'PAUSE',
                  () => bloc.dispatch(bloc.state == SimState.paused ? SimResumed() : SimPaused()),
            ),
            _BarIcon(Icons.speed_rounded, 'SPEED', () {
              final cur = bloc.params.rotationSpeed;
              bloc.dispatch(SimRotationChanged(cur >= 1.5 ? 0.0 : cur + 0.3));
            }),
          ]),
        ),
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BarIcon(this.icon, this.label, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: const Color(0xFF00E5FF), size: 22),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(
          color: Color(0x8800E5FF), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2,
        )),
      ]),
    );
  }
}