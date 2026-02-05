import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data/auth_service.dart';

/// ===============================================================
/// 🔁 DraftClub — Recuperación de cuenta (estética glass premium)
/// ===============================================================
/// ✅ Flujo UX PRO:
/// - No filtra si el correo existe o no (mensaje neutro).
/// - Cooldown para reenviar.
/// - Estados claros: enviando / enviado / error.
/// - Coherente con LoginPage (background + glass + iluminación).
/// ===============================================================
class ForgotPasswordPage extends StatefulWidget {
  final String? prefilledEmail;

  const ForgotPasswordPage({super.key, this.prefilledEmail});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _authService = AuthService();
  late final TextEditingController _emailController;

  bool isLoading = false;

  // Estado UX (no técnico)
  String infoMessage = '';
  String errorMessage = '';

  // Cooldown de reenvío
  static const int _cooldownSeconds = 30;
  int _cooldownLeft = 0;
  Timer? _cooldownTimer;

  bool get _canResend => _cooldownLeft == 0 && !isLoading;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.prefilledEmail ?? '');
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownLeft = _cooldownSeconds);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldownLeft <= 1) {
        t.cancel();
        setState(() => _cooldownLeft = 0);
      } else {
        setState(() => _cooldownLeft -= 1);
      }
    });
  }

  String _normalizeException(Object e) {
    final raw = e.toString();
    return raw.startsWith('Exception: ')
        ? raw.replaceFirst('Exception: ', '')
        : raw;
  }

  bool _isEmailLooksValid(String email) {
    // Validación UX (simple y suficiente para frontend)
    final trimmed = email.trim();
    if (trimmed.isEmpty) return false;
    if (!trimmed.contains('@')) return false;
    if (!trimmed.contains('.')) return false;
    return true;
  }

  Future<void> _sendReset() async {
    final email = _emailController.text.trim();

    setState(() {
      isLoading = true;
      infoMessage = '';
      errorMessage = '';
    });

    if (!_isEmailLooksValid(email)) {
      setState(() {
        isLoading = false;
        errorMessage = 'Ingresa un correo válido para continuar.';
      });
      return;
    }

    try {
      await _authService.sendPasswordResetEmail(email);

      // ✅ Mensaje neutro PRO (no filtra existencia)
      setState(() {
        infoMessage =
            'Si existe una cuenta con ese correo, te enviamos un enlace para restablecer tu contraseña.\n\n'
            'Revisa tu bandeja de entrada y también spam. Puede tardar unos minutos.';
      });

      _startCooldown();
    } catch (e) {
      setState(() {
        errorMessage = _normalizeException(e);
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _onBackPressed() async {
    // Back robusto: intenta volver; si no puede, igual intenta salir.
    final nav = Navigator.of(context);
    final popped = await nav.maybePop();
    if (!popped) {
      // fallback (por si esta pantalla quedó como root por un flujo raro)
      if (mounted) {
        nav.pop();
      }
    }
  }

  void _openHelpSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(26)),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '¿No te llegó el correo?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _helpRow(
                      icon: Icons.mark_email_read_outlined,
                      title: 'Revisa Spam / Promociones',
                      subtitle: 'A veces llega filtrado por tu proveedor.',
                    ),
                    _helpRow(
                      icon: Icons.timer_outlined,
                      title: 'Espera 1–3 minutos',
                      subtitle: 'Puede tardar un poco en llegar.',
                    ),
                    _helpRow(
                      icon: Icons.edit_outlined,
                      title: 'Verifica el correo escrito',
                      subtitle: 'Un carácter mal y no llegará.',
                    ),
                    _helpRow(
                      icon: Icons.refresh_outlined,
                      title: 'Reenviar enlace',
                      subtitle: _cooldownLeft > 0
                          ? 'Disponible en $_cooldownLeft s.'
                          : 'Puedes reenviar si lo necesitas.',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                  color: Colors.white.withOpacity(0.22)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Cerrar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _canResend
                                ? () async {
                                    Navigator.of(context).pop();
                                    await _sendReset();
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(_cooldownLeft > 0
                                ? 'Reenviar ($_cooldownLeft)'
                                : 'Reenviar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _helpRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // 🏟️ Fondo coherente con LoginPage
                Image.asset(
                  'assets/backgrounds/login_bg.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),

                // 🌈 Iluminación dinámica (igual estilo)
                AnimatedContainer(
                  duration: const Duration(seconds: 5),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.5,
                      colors: [
                        Colors.blueAccent.withOpacity(0.35),
                        Colors.amberAccent.withOpacity(0.12),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(begin: -0.02, end: 0.02, duration: 5.seconds),

                // 🌌 Capa oscura ligera
                Container(color: Colors.black.withOpacity(0.25)),

                // 💎 Contenedor principal (Glass) — NO se come la barra porque la barra va al FINAL
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: 72,
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 40,
                  ),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: size.width * 0.88,
                          constraints: const BoxConstraints(maxWidth: 430),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 32,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withOpacity(0.18),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: _buildContent(),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 900.ms)
                        .slideY(begin: 0.08),
                  ),
                ),

                // 🔙 Barra superior minimalista
                // ✅ IMPORTANTE: va AL FINAL para quedar arriba y agarrar taps
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        _glassIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: _onBackPressed,
                        ),
                        const Spacer(),
                        _glassIconButton(
                          icon: Icons.help_outline_rounded,
                          onTap: _openHelpSheet,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _glassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    // ✅ Tap robusto: Material + InkWell + opaque
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/icons/draftclub_logo.png', height: 72)
            .animate()
            .fadeIn(duration: 600.ms),
        const SizedBox(height: 12),
        const Text(
          'Recuperar cuenta',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Te enviaremos un enlace para restablecer tu contraseña.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 22),
        _buildInputField(
          controller: _emailController,
          label: 'Correo electrónico',
          icon: Icons.email_outlined,
        ),
        const SizedBox(height: 16),

        // CTA principal
        ElevatedButton(
          onPressed: isLoading ? null : _sendReset,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            minimumSize: const Size(double.infinity, 50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            shadowColor: Colors.blueAccent.withOpacity(0.4),
            elevation: 6,
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Enviar enlace',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),

        const SizedBox(height: 14),

        // Acciones secundarias
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _openHelpSheet,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.22)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('No me llegó'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _canResend ? _sendReset : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.22)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  _cooldownLeft > 0 ? 'Reenviar ($_cooldownLeft)' : 'Reenviar',
                ),
              ),
            ),
          ],
        ),

        if (infoMessage.isNotEmpty) ...[
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.25)),
            ),
            child: Text(
              infoMessage,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 12,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],

        if (errorMessage.isNotEmpty) ...[
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
            ),
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],

        const SizedBox(height: 18),
        Text(
          'Por tu seguridad, no podemos confirmar si un correo está registrado.\n'
          'Si existe una cuenta, recibirás instrucciones.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 11,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }
}
