import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class VersusOverlay extends StatelessWidget {
  final String roomName;
  final VoidCallback onDismiss;

  const VersusOverlay({
    super.key,
    required this.roomName,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onDismiss,
        child: Container(
          color: Colors.black.withOpacity(0.9),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Team A (Left)
              Positioned(
                left: -50,
                bottom: 0,
                top: 0,
                child: Transform(
                  transform: Matrix4.skewX(-0.2),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.6,
                    color: Colors.blueAccent.withOpacity(0.8),
                    child: Center(
                      child: Transform(
                        transform: Matrix4.skewX(0.2), // Unskew text
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield, size: 80, color: Colors.white),
                            SizedBox(height: 20),
                            Text('EQUIPO\nAZUL',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().moveX(
                    begin: -200,
                    end: 0,
                    duration: 800.ms,
                    curve: Curves.easeOutExpo),
              ),

              // Team B (Right)
              Positioned(
                right: -50,
                bottom: 0,
                top: 0,
                child: Transform(
                  transform: Matrix4.skewX(-0.2),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.6,
                    color: Colors.redAccent.withOpacity(0.8),
                    child: Center(
                      child: Transform(
                        transform: Matrix4.skewX(0.2),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_fire_department,
                                size: 80, color: Colors.white),
                            SizedBox(height: 20),
                            Text('EQUIPO\nROJO',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().moveX(
                    begin: 200,
                    end: 0,
                    duration: 800.ms,
                    curve: Curves.easeOutExpo),
              ),

              // VS Badge
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 5),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5)
                    ]),
                child: const Center(
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
                  .animate()
                  .scale(
                      duration: 600.ms, delay: 500.ms, curve: Curves.elasticOut)
                  .shake(delay: 1000.ms),

              // Ready Text
              Positioned(
                bottom: 100,
                child: const Text(
                  '¡PARTIDO LISTO!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.blueAccent, blurRadius: 10)],
                  ),
                ).animate().fadeIn(delay: 1200.ms).slideY(begin: 1.0, end: 0.0),
              ),

              // Tap to dismiss hint
              Positioned(
                bottom: 50,
                child: Text(
                  'Toca para continuar',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 12),
                ).animate().fadeIn(delay: 2000.ms),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
