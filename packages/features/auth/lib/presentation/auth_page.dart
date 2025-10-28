import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DraftClub — Inicio de sesión')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => context.go('/feed'),
          child: const Text('Entrar al Feed'),
        ),
      ),
    );
  }
}
