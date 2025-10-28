import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

import '../models/room_model.dart';
import '../data/room_service.dart';
import 'team_list_page.dart';
import 'chat/chat_room_page.dart';

/// ====================================================================
/// ⚽ RoomDetailPage — Detalle de una sala específica (con actualización en tiempo real)
/// ====================================================================
/// 🔹 Escucha Firestore en vivo.
/// 🔹 Editar / eliminar sala (solo creador).
/// 🔹 Envía notificación al chat cuando hay cambios.
/// 🔹 Unirse / salir.
/// 🔹 Navegar a Equipos y Chat.
/// ====================================================================
class RoomDetailPage extends StatefulWidget {
  final Room room;
  const RoomDetailPage({super.key, required this.room});

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _roomService = RoomService();

  bool _loading = false;
  bool _joined = false;

  @override
  void initState() {
    super.initState();
    final uid = _auth.currentUser?.uid;
    _joined = uid != null && widget.room.players.contains(uid);
  }

  /// 🔁 Stream de la sala en tiempo real
  Stream<Room?> _roomStream() {
    return _firestore
        .collection('rooms')
        .doc(widget.room.id)
        .snapshots()
        .map((doc) => doc.exists ? Room.fromMap(doc.data()!) : null);
  }

  // ================================================================
  // 🗑️ Eliminar sala
  // ================================================================
  Future<void> _confirmDelete(Room room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text('Eliminar sala',
            style: TextStyle(color: Colors.redAccent)),
        content: const Text(
          '¿Seguro que deseas eliminar esta sala? Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        // 🔔 Notificar antes de eliminar
        await _sendSystemMessage(room.id,
            '⚠️ El administrador ha eliminado la sala "${room.name}".');

        await _roomService.deleteRoom(room.id);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sala eliminada correctamente'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar sala: $e')),
        );
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  // ================================================================
  // ✏️ Editar sala (modal)
  // ================================================================
  Future<void> _openEditModal(Room room) async {
    final TextEditingController addressCtrl =
        TextEditingController(text: room.city);
    final TextEditingController dateCtrl = TextEditingController(
      text: room.eventAt != null
          ? room.eventAt!.toLocal().toString().split(' ')[0]
          : '',
    );
    final TextEditingController timeCtrl = TextEditingController(
      text: room.eventAt != null
          ? TimeOfDay.fromDateTime(room.eventAt!.toLocal()).format(context)
          : '',
    );
    bool isPublic = room.isPublic;

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C1C1C),
              title: const Text('Editar sala',
                  style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: addressCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Dirección exacta (opcional)',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dateCtrl,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Fecha del partido (opcional)',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: room.eventAt ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          setModalState(() =>
                              dateCtrl.text = date.toString().split(' ')[0]);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: timeCtrl,
                      readOnly: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Hora del partido (opcional)',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          setModalState(
                              () => timeCtrl.text = time.format(context));
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      title: const Text('Sala pública',
                          style: TextStyle(color: Colors.white)),
                      value: isPublic,
                      onChanged: (val) => setModalState(() => isPublic = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar',
                      style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _saveEdits(room, addressCtrl.text, dateCtrl.text,
                        timeCtrl.text, isPublic);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveEdits(Room room, String newAddress, String date,
      String time, bool isPublic) async {
    try {
      DateTime? eventAt;
      if (date.isNotEmpty) {
        final dateOnly = DateTime.tryParse(date);
        if (dateOnly != null) {
          if (time.isNotEmpty) {
            final parts = time.split(':');
            final hour = int.parse(parts[0]);
            final minute = int.parse(parts[1].split(' ')[0]);
            eventAt = DateTime(
                dateOnly.year, dateOnly.month, dateOnly.day, hour, minute);
          } else {
            eventAt = dateOnly;
          }
        }
      }

      // 🔧 Actualiza Firestore
      await _roomService.updateRoom(room.id, {
        'city': newAddress.isNotEmpty ? newAddress : room.city,
        'eventAt': eventAt != null ? Timestamp.fromDate(eventAt) : null,
        'isPublic': isPublic,
      });

      // 🔔 Notificar cambio a los jugadores
      await _sendSystemMessage(
          room.id, '🔄 El administrador actualizó la sala "${room.name}".');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sala actualizada correctamente'),
          backgroundColor: Colors.greenAccent,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar sala: $e')),
      );
    }
  }

  /// 🔔 Envía mensaje de sistema al chat (notificaciones internas)
  Future<void> _sendSystemMessage(String roomId, String text) async {
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('messages')
          .add({
        'text': text,
        'type': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Si aún no existe la colección o chat, lo ignora silenciosamente
    }
  }

  // ================================================================
  // 🎨 UI + STREAM BUILDER
  // ================================================================
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Room?>(
      stream: _roomStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0E0E0E),
            body: Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            ),
          );
        }

        final room = snapshot.data!;
        final isCreator = room.creatorId == _auth.currentUser?.uid;

        return Scaffold(
          backgroundColor: const Color(0xFF0E0E0E),
          appBar: AppBar(
            title: Text(room.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.black,
            actions: [
              IconButton(
                  icon: const Icon(Icons.share, color: Colors.blueAccent),
                  tooltip: 'Compartir sala',
                  onPressed: () => Share.share(
                      '⚽ ¡Únete a mi sala en DraftClub!\n👉 https://draftclub.app/room/${room.id}')),
              if (isCreator)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (v) {
                    if (v == 'editar') _openEditModal(room);
                    if (v == 'eliminar') _confirmDelete(room);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'editar', child: Text('Editar sala')),
                    PopupMenuItem(
                        value: 'eliminar', child: Text('Eliminar sala')),
                  ],
                ),
            ],
          ),
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.grey.shade800, width: 0.8),
                          ),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: room.isPublic
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              child: const Icon(Icons.sports_soccer,
                                  color: Colors.black),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(room.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 20),
                        _buildInfoRow(Icons.location_on, 'Ciudad', room.city),
                        _buildInfoRow(
                            Icons.group, 'Equipos', '${room.teams} equipos'),
                        _buildInfoRow(Icons.person, 'Jugadores por equipo',
                            '${room.playersPerTeam}'),
                        _buildInfoRow(Icons.swap_horiz, 'Cambios permitidos',
                            '${room.substitutes}'),
                        _buildInfoRow(
                            room.isPublic ? Icons.public : Icons.lock,
                            'Tipo de sala',
                            room.isPublic ? 'Pública' : 'Privada'),
                        if (room.eventAt != null)
                          _buildInfoRow(Icons.schedule, 'Partido programado',
                              '${room.eventAt!.day}/${room.eventAt!.month}/${room.eventAt!.year} ${room.eventAt!.hour}:${room.eventAt!.minute.toString().padLeft(2, '0')}'),
                        const SizedBox(height: 30),
                        Center(
                          child: Column(children: [
                            if (!isCreator)
                              ElevatedButton.icon(
                                icon:
                                    Icon(_joined ? Icons.logout : Icons.login),
                                label: Text(_joined
                                    ? 'Salir de la sala'
                                    : 'Unirme a esta sala'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _joined
                                      ? Colors.redAccent
                                      : Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 40, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _loading
                                    ? null
                                    : (_joined
                                        ? () async {
                                            await _roomService
                                                .leaveRoom(room.id);
                                            setState(() => _joined = false);
                                          }
                                        : () async {
                                            await _roomService
                                                .joinRoom(room.id);
                                            setState(() => _joined = true);
                                          }),
                              ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.people_alt_outlined),
                              label: const Text('Ver equipos'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side:
                                    const BorderSide(color: Colors.blueAccent),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 40, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            TeamListPage(room: room)));
                              },
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Chat de la sala'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.grey),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 40, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            ChatRoomPage(room: room)));
                              },
                            ),
                          ]),
                        ),
                      ]),
                ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Icon(icon, color: Colors.blueAccent, size: 22),
        const SizedBox(width: 12),
        Text('$label: ',
            style: const TextStyle(
                color: Colors.white70, fontWeight: FontWeight.bold)),
        Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white))),
      ]),
    );
  }
}
