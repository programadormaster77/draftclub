import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthController extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get user => _auth.currentUser;

  // Crear cuenta nueva
  Future<String?> register(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Iniciar sesión
  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Cerrar sesión
  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }
}
