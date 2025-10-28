import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';
import 'room_detail_page.dart';

/// ====================================================================
/// 🔍 FindRoomPage — Buscar sala por ID (versión optimizada)
/// ====================================================================
class FindRoomPage extends StatefulWidget {
  const FindRoomPage({super.key});

  @override
  State<FindRoomPage> createState() => _FindRoomPageState();
}

class _FindRoomPageState extends State<FindRoomPage> {
  final _idCtrl = TextEditingController();
  bool _loading = false;
  final _db = FirebaseFirestore.instance;

  /// 🔹 Busca la sala en Firestore por ID
  Future<void> _searchRoom() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa el ID de la sala'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final snap = await _db.collection('rooms').doc(id).get();

      if (!snap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No se encontró ninguna sala con ese ID'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final data = snap.data()!;
      final room = Room.fromMap(data);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoomDetailPage(room: room),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al buscar sala: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      resizeToAvoidBottomInset:
          true, // ✅ evita el overflow cuando sale el teclado
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Buscar sala por ID'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // ✅ permite desplazarse cuando el teclado se abre
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 30,
            bottom: MediaQuery.of(context).viewInsets.bottom +
                30, // margen dinámico según el teclado
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Ingresa el ID exacto de la sala para unirte:',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _idCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'ID de la sala',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1C1C1C),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blueAccent),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _searchRoom(),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _searchRoom,
                  icon: const Icon(Icons.search, color: Colors.white),
                  label: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Buscar sala',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
