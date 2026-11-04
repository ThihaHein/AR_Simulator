
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

typedef AtomStepNative = Void Function(
    Pointer<Double> px, Pointer<Double> py, Pointer<Double> pz,
    Pointer<Double> vx, Pointer<Double> vy, Pointer<Double> vz,
    Int32 count,
    Double gravity, Double windX, Double windZ,
    Double worldHalf, Double atomRadius, Int32 gridCellSize,
    Double restitution, Double dt,
    );

typedef AtomStepDart = void Function(
    Pointer<Double> px, Pointer<Double> py, Pointer<Double> pz,
    Pointer<Double> vx, Pointer<Double> vy, Pointer<Double> vz,
    int count,
    double gravity, double windX, double windZ,
    double worldHalf, double atomRadius, int gridCellSize,
    double restitution, double dt,
    );

class NativeBridge {
  NativeBridge._();

  static AtomStepDart? _step;
  static bool _tried = false;

  static bool get available {
    _init();
    return _step != null;
  }

  static void _init() {
    if (_tried) return;
    _tried = true;
    try {
      final String libName;
      if (Platform.isAndroid || Platform.isLinux) {
        libName = 'libatom_engine.so';
      } else if (Platform.isIOS || Platform.isMacOS) {
        libName = 'libatom_engine.dylib';
      } else if (Platform.isWindows) {
        libName = 'atom_engine.dll';
      } else {
        return;
      }
      final dylib = DynamicLibrary.open(libName);
      _step = dylib.lookupFunction<AtomStepNative, AtomStepDart>('atom_step');
    } catch (_) {
      // Native lib not found – fall back to pure Dart
      _step = null;
    }
  }


  static void step(
      Float64List px, Float64List py, Float64List pz,
      Float64List vx, Float64List vy, Float64List vz,
      int count,
      double gravity, double windX, double windZ,
      double worldHalf, double atomRadius, int gridCellSize,
      double restitution, double dt,
      ) {
    assert(_step != null, 'Native library not loaded');


    final pPx = _ptrOf(px);
    final pPy = _ptrOf(py);
    final pPz = _ptrOf(pz);
    final pVx = _ptrOf(vx);
    final pVy = _ptrOf(vy);
    final pVz = _ptrOf(vz);

    _step!(pPx, pPy, pPz, pVx, pVy, pVz,
        count, gravity, windX, windZ,
        worldHalf, atomRadius, gridCellSize,
        restitution, dt);
  }


  static Pointer<Double> _ptrOf(Float64List list) {
    return Pointer<Double>.fromAddress(
      list.buffer.asUint8List().offsetInBytes + list.offsetInBytes,
    );
  }
}