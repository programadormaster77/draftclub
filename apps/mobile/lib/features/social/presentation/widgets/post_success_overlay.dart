import 'package:flutter/material.dart';

/// ===============================================================
/// 🌟 PostSuccessOverlay — Animación tras crear una publicación
/// ===============================================================
/// - Muestra una animación breve con ícono ✅
/// - Se desvanece automáticamente después de 1.5 segundos.
/// ===============================================================
class PostSuccessOverlay extends StatefulWidget {
  const PostSuccessOverlay({super.key});

  @override
  State<PostSuccessOverlay> createState() => _PostSuccessOverlayState();
}

class _PostSuccessOverlayState extends State<PostSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.of(context).pop(); // Cierra automáticamente
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.6),
      body: Center(
        child: ScaleTransition(
          scale: _scale,
          child: FadeTransition(
            opacity: _opacity,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.4),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle,
                      color: Colors.lightGreenAccent, size: 72),
                  SizedBox(height: 12),
                  Text(
                    'Publicación enviada',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}