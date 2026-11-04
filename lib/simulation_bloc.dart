import 'package:flutter/material.dart';
import '/simulation_3d.dart';

enum SimState { initializing, active, paused }

sealed class SimEvent {}
class SimStarted extends SimEvent {}
class SimPaused extends SimEvent {}
class SimResumed extends SimEvent {}
class SimGravityChanged extends SimEvent { final double value; SimGravityChanged(this.value); }
class SimWindXChanged extends SimEvent { final double value; SimWindXChanged(this.value); }
class SimWindZChanged extends SimEvent { final double value; SimWindZChanged(this.value); }
class SimRotationChanged extends SimEvent { final double value; SimRotationChanged(this.value); }
class SimColorSchemeChanged extends SimEvent { final int index; SimColorSchemeChanged(this.index); }
class SimModelChanged extends SimEvent { final int index; SimModelChanged(this.index); }

class SimulationBloc extends ChangeNotifier {
  SimState _state = SimState.initializing;
  SimState get state => _state;
  final SimParams params = SimParams();
  int colorScheme = 0;
  int modelIndex = 0;
  double fps = 0;
  int _fc = 0; double _fa = 0;

  void dispatch(SimEvent e) {
    switch (e) {
      case SimStarted(): _state = SimState.active; params.paused = false;
      case SimPaused(): _state = SimState.paused; params.paused = true;
      case SimResumed(): _state = SimState.active; params.paused = false;
      case SimGravityChanged(:final value): params.gravity = value;
      case SimWindXChanged(:final value): params.windX = value;
      case SimWindZChanged(:final value): params.windZ = value;
      case SimRotationChanged(:final value): params.rotationSpeed = value;
      case SimColorSchemeChanged(:final index): colorScheme = index;
      case SimModelChanged(:final index): modelIndex = index;
    }
    notifyListeners();
  }

  void tickFps(double dt) {
    _fc++; _fa += dt;
    if (_fa >= 0.5) { fps = _fc / _fa; _fc = 0; _fa = 0; }
  }
}

class SimulationProvider extends StatefulWidget {
  final Widget child;
  const SimulationProvider({super.key, required this.child});
  static SimulationBloc of(BuildContext ctx) =>
      ctx.dependOnInheritedWidgetOfExactType<_IB>()!.bloc;
  @override State<SimulationProvider> createState() => _SPState();
}
class _SPState extends State<SimulationProvider> {
  final bloc = SimulationBloc();
  @override void initState() { super.initState(); bloc.addListener(_r); }
  void _r() => setState(() {});
  @override void dispose() { bloc.removeListener(_r); bloc.dispose(); super.dispose(); }
  @override Widget build(BuildContext ctx) => _IB(bloc: bloc, child: widget.child);
}
class _IB extends InheritedWidget {
  final SimulationBloc bloc;
  const _IB({required this.bloc, required super.child});
  @override bool updateShouldNotify(_IB o) => true;
}