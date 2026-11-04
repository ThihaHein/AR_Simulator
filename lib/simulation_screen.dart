import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'simulation_bloc.dart';
import '../simulation_3d.dart';
import '../atom_painter.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  AtomSimulation3D? _sim;
  Duration _prev = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
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
    final dt = (_prev == Duration.zero)
        ? 0.0
        : (elapsed - _prev).inMicroseconds / 1e6;
    _prev = elapsed;
    if (dt <= 0 || dt > 0.1) return;

    _sim!.step(dt);
    SimulationProvider.of(context).tickFps(dt);

    (context as Element).markNeedsBuild();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = SimulationProvider.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF06060e),
      body: Stack(
        children: [
          // Simulation canvas
          if (_sim != null)
            Positioned.fill(
              child: CustomPaint(
                painter: AtomPainter(_sim!, schemeIdx: bloc.colorScheme),
              ),
            ),

          // HUD
          Positioned(
            top: 48, left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$kAtomCount atoms · 3D',
                  style: const TextStyle(
                    color: Colors.white54, fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${bloc.fps.toStringAsFixed(1)} FPS',
                  style: TextStyle(
                    color: bloc.fps >= 55
                        ? const Color(0xFF1DD1A1)
                        : const Color(0xFFFF6B6B),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bloc.state.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white30, fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // Pause button
          Positioned(
            top: 48, right: 16,
            child: _GlassButton(
              icon: bloc.state == SimState.paused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              onTap: () {
                bloc.dispatch(
                  bloc.state == SimState.paused
                      ? SimResumed()
                      : SimPaused(),
                );
              },
            ),
          ),

          // Bottom sheet
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _ControlPanel(bloc: bloc),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Glassmorphic control panel
// ---------------------------------------------------------------------------
class _ControlPanel extends StatefulWidget {
  final SimulationBloc bloc;
  const _ControlPanel({required this.bloc});

  @override
  State<_ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<_ControlPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bloc = widget.bloc;
    final bottom = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.fromLTRB(24, 16, 24, bottom + 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.15)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'CONTROLS',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
                if (_expanded) ...[
                  const SizedBox(height: 16),
                  _SliderRow(
                    label: 'Gravity',
                    value: bloc.params.gravity,
                    min: -1, max: 1,
                    onChanged: (v) => bloc.dispatch(SimGravityChanged(v)),
                  ),
                  _SliderRow(
                    label: 'Wind X',
                    value: bloc.params.windX,
                    min: -1, max: 1,
                    onChanged: (v) => bloc.dispatch(SimWindXChanged(v)),
                  ),
                  _SliderRow(
                    label: 'Wind Z',
                    value: bloc.params.windZ,
                    min: -1, max: 1,
                    onChanged: (v) => bloc.dispatch(SimWindZChanged(v)),
                  ),
                  _SliderRow(
                    label: 'Rotation',
                    value: bloc.params.rotationSpeed,
                    min: 0, max: 2,
                    onChanged: (v) => bloc.dispatch(SimRotationChanged(v)),
                  ),
                  const SizedBox(height: 12),
                  // Colour scheme selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(kColorSchemes.length, (i) {
                      final selected = bloc.colorScheme == i;
                      return GestureDetector(
                        onTap: () => bloc.dispatch(SimColorSchemeChanged(i)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? Colors.white
                                  : Colors.white24,
                              width: selected ? 2 : 1,
                            ),
                            gradient: LinearGradient(
                              colors: [
                                kColorSchemes[i][0],
                                kColorSchemes[i][2],
                                kColorSchemes[i][4],
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _SliderRow extends StatelessWidget {
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54, fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: Colors.white54,
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
                overlayColor: Colors.white10,
              ),
              child: Slider(
                value: value,
                min: min, max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              value.toStringAsFixed(1),
              style: const TextStyle(
                color: Colors.white38, fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Glass icon button
// ---------------------------------------------------------------------------
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Icon(icon, color: Colors.white70, size: 22),
          ),
        ),
      ),
    );
  }
}