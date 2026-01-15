import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Sfondo nero OLED
      body: Stack(
        children: [
          // 1. ANIMAZIONE CENTRALE
          Center(
            child: SizedBox(
              width: 300,
              height: 300,
              // Usiamo un Lottie da Network per test rapido.
              // In produzione scarica il JSON e usa Lottie.asset('assets/...')
              child: Lottie.asset('assets/animations/tech_loading.json', fit: BoxFit.contain),
            ),
          ),

          // 2. TESTO CON FADE IN/OUT (Pulsante)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: _PulsingText(),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget per il testo che respira
class _PulsingText extends StatefulWidget {
  @override
  State<_PulsingText> createState() => _PulsingTextState();
}

class _PulsingTextState extends State<_PulsingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true); // Avanti e indietro

    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Column(
        children: [
          Text(
            "TRENTIN MANOR",
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 14,
              letterSpacing: 8, // Spaziatura estrema molto "Cinematic"
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "INIZIALIZZAZIONE DEI SISTEMI...",
            style: GoogleFonts.outfit(
              color: Colors.blueAccent,
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}