import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../auth/data/auth_service.dart';
import '../domain/user_profile.dart';

/// ===============================================================
/// 🧱 ProfileRepository
/// ===============================================================
/// Encargado de:
///  - Subir avatares al Storage.
///  - Crear o actualizar perfiles en Firestore.
///  - Recuperar perfiles existentes.
/// ===============================================================
class ProfileRepository {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = AuthService();

  /// 🔍 Verifica si existe un perfil en Firestore
  Future<bool> profileExists(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists;
  }

 /// 📥 Obtiene un perfil de Firestore y lo convierte a UserProfile
Future<UserProfile?> fetchProfile(String uid) async {
  final doc = await _firestore.collection('users').doc(uid).get();
  if (!doc.exists || doc.data() == null) return null;

  // ✅ anclaje correcto: el uid real es doc.id (porque NO lo guardas dentro del doc)
  return UserProfile.fromMap(doc.data()!, uid: doc.id);
}



  /// 🖼 Sube una imagen al Storage y devuelve su URL
  Future<String?> uploadAvatar({
    required String uid,
    required File file,
  }) async {
    try {
      final ref = _storage.ref().child('users/$uid/avatar.jpg');
      final task = await ref.putFile(file);
      return await task.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      print('⚠️ Error subiendo avatar: ${e.message}');
      return null;
    }
  }

  /// 💾 Crea o actualiza el documento de perfil
  Future<void> createOrUpdateProfile(UserProfile profile) async {
    final ref = _firestore.collection('users').doc(profile.uid);
    final now = FieldValue.serverTimestamp();

    final data = profile.toMap()
      ..remove('uid') // no se debe sobreescribir el ID
      ..['updatedAt'] = now;

    // ⚙️ Verificación de seguridad: el campo 'sex' debe existir
    if (!data.containsKey('sex') || data['sex'] == null) {
      print(
          '⚠️ Advertencia: el perfil ${profile.uid} no tiene campo "sex". Se establecerá por defecto "Masculino".');
      data['sex'] = 'Masculino';
    }

    // 🟢 Si el documento no existe, crear con createdAt también
    final exists = await ref.get().then((d) => d.exists);
    if (!exists) data['createdAt'] = now;

    await ref.set(data, SetOptions(merge: true));

    print('✅ Perfil actualizado correctamente para UID: ${profile.uid}');
  }
}
