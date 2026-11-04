import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/simulation_screen.dart';
import '/ar_simulation_screen.dart';
import '/simulation_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const AtomApp());
}

class AtomApp extends StatelessWidget {
  const AtomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atom Sim 3D',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: SimulationProvider(
        child: const ModeSelector(),
      ),
    );
  }
}

class ModeSelector extends StatelessWidget {
  const ModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06060e),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ATOM SIM',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 32,
                fontWeight: FontWeight.w200,
                letterSpacing: 12,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '10,000 PARTICLES',
              style: TextStyle(
                color: Color(0x55FFFFFF),
                fontSize: 10,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 60),
            _ModeCard(
              icon: Icons.view_in_ar_rounded,
              title: 'STANDARD',
              subtitle: '3D simulation with controls',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SimulationProvider(
                    child: const SimulationScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ModeCard(
              icon: Icons.back_hand_rounded,
              title: 'STARK MODE',
              subtitle: 'AR + hand tracking',
              color: const Color(0xFFFF6D00),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SimulationProvider(
                    child: const ARSimulationScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color = const Color(0xFF00E5FF),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0x66FFFFFF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}