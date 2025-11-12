import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 📋 Clipboard (copiar ID)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

import '../models/room_model.dart';
import '../data/room_service.dart';
import 'team_list_page.dart';
import 'chat/chat_room_page.dart';
import '../../../core/location/place_service.dart'; // 🆕 direcciones exactas

/// ====================================================================
/// ⚽ RoomDetailPage — Detalle de sala (con stream en tiempo real)
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
  bool _searchingAddress = false;

  /// ===============================================================
  /// 🧩 Normalizador de género (consistencia global)
  /// ===============================================================
  String _normalizeSex(String? sex) {
    if (sex == null || sex.trim().isEmpty) return 'mixto';
    final s = sex.trim().toLowerCase();
    if (s == 'masculino' || s == 'femenino' || s == 'mixto') return s;
    return 'mixto';
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
  // 🏠 Buscador de dirección exacta con Google Places
  // ================================================================
  Future<void> _openAddressPicker(
    TextEditingController addressCtrl,
    void Function(Map<String, dynamic>) onSelect,
  ) async {
    TextEditingController searchCtrl = TextEditingController();
    List<Map<String, dynamic>> suggestions = [];

    await showModalBottomSheet<Map<String, dynamic>>(
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheet) {
          Future<void> search(String query) async {
            if (query.isEmpty) {
              setSheet(() => suggestions = []);
              return;
            }
            setSheet(() => _searchingAddress = true);
            final results = await PlaceService.fetchAddressSuggestions(query);
            setSheet(() {
              suggestions = results
                  .map((r) => {
                        'address': r['address'],
                        'lat': r['lat'],
                        'lng': r['lng'],
                      })
                  .toList();
              _searchingAddress = false;
            });
          }

          return Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: Container(
              padding: const EdgeInsets.all(20),
              height: 500,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Buscar dirección exacta',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchCtrl,
                    onChanged: search,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ej: Calle 45 #12...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.location_on,
                          color: Colors.blueAccent),
                      filled: true,
                      fillColor: const Color(0xFF111111),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.white24, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Colors.blueAccent, width: 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_searchingAddress)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Colors.blueAccent,
                        strokeWidth: 2.5,
                      ),
                    )
                  else if (suggestions.isEmpty)
                    const Center(
                      child: Text(
                        'Escribe para buscar...',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white12),
                        itemBuilder: (context, i) {
                          final s = suggestions[i];
                          return ListTile(
                            leading: const Icon(Icons.location_city,
                                color: Colors.blueAccent),
                            title: Text(
                              s['address'],
                              style: const TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              onSelect(s);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ================================================================
  // ✏️ Editar sala (modal) — coherente con CreateRoomPage
  // ================================================================
  Future<void> _openEditModal(Room room) async {
    final addressCtrl = TextEditingController(text: room.exactAddress ?? '');
    final dateCtrl = TextEditingController(
      text: room.eventAt != null
          ? room.eventAt!.toLocal().toString().split(' ')[0]
          : '',
    );
    final timeCtrl = TextEditingController(
      text: room.eventAt != null
          ? TimeOfDay.fromDateTime(room.eventAt!.toLocal()).format(context)
          : '',
    );

    bool isPublic = room.isPublic;
    String sex = _normalizeSex(room.sex);
    Map<String, dynamic>? selectedAddress;

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1C1C1C),
            title: const Text('Editar sala',
                style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _openAddressPicker(addressCtrl, (data) {
                      setModalState(() {
                        selectedAddress = data;
                        addressCtrl.text = data['address'];
                      });
                    }),
                    child: AbsorbPointer(
                      child: TextField(
                        controller: addressCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Dirección exacta (opcional)',
                          labelStyle: TextStyle(color: Colors.white70),
                          prefixIcon:
                              Icon(Icons.home_work, color: Colors.blueAccent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: sex,
                    dropdownColor: const Color(0xFF2A2A2A),
                    decoration: const InputDecoration(
                      labelText: 'Género del partido',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'masculino',
                        child: Text('Masculino',
                            style: TextStyle(color: Colors.white)),
                      ),
                      DropdownMenuItem(
                        value: 'femenino',
                        child: Text('Femenino',
                            style: TextStyle(color: Colors.white)),
                      ),
                      DropdownMenuItem(
                        value: 'mixto',
                        child: Text('Mixto',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                    onChanged: (v) => setModalState(() => sex = v ?? 'mixto'),
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
                        initialTime: room.eventAt != null
                            ? TimeOfDay.fromDateTime(room.eventAt!)
                            : TimeOfDay.now(),
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
                  await _saveEdits(
                    room,
                    addressCtrl.text,
                    dateCtrl.text,
                    timeCtrl.text,
                    isPublic,
                    sex,
                    selectedAddress,
                  );
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _saveEdits(
    Room room,
    String newAddress,
    String date,
    String time,
    bool isPublic,
    String sex, [
    Map<String, dynamic>? addressData,
  ]) async {
    try {
      final normalizedSex = _normalizeSex(sex);

      DateTime? eventAt;
      if (date.isNotEmpty) {
        final dateOnly = DateTime.tryParse(date);
        if (dateOnly != null) {
          if (time.isNotEmpty) {
            // Soporte 12/24h; tomamos los números del formato local
            final parts = time.split(':'); // "HH:mm" o "h:mm a"
            int hour = int.tryParse(parts[0]) ?? 0;
            int minute = 0;
            if (parts.length > 1) {
              final tail = parts[1];
              final mm = RegExp(r'\d+').firstMatch(tail)?.group(0);
              minute = int.tryParse(mm ?? '0') ?? 0;
              // Si trae "PM" y parece formato 12h
              final isPm = tail.toLowerCase().contains('pm');
              final isAm = tail.toLowerCase().contains('am');
              if (isPm && hour < 12) hour += 12;
              if (isAm && hour == 12) hour = 0;
            }
            eventAt = DateTime(
                dateOnly.year, dateOnly.month, dateOnly.day, hour, minute);
          } else {
            eventAt = dateOnly;
          }
        }
      }

      await _roomService.updateRoom(room.id, {
        'exactAddress': newAddress.trim().isNotEmpty ? newAddress.trim() : null,
        'lat': addressData?['lat'],
        'lng': addressData?['lng'],
        'eventAt': eventAt != null ? Timestamp.fromDate(eventAt) : null,
        'isPublic': isPublic,
        'sex': normalizedSex,
      });

      await _sendSystemMessage(
        room.id,
        '🔄 El administrador actualizó la sala "${room.name}".',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sala actualizada correctamente'),
          backgroundColor: Colors.greenAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar sala: $e')),
      );
    }
  }

  // 📩 Mensaje del sistema
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
    } catch (_) {}
  }

  // ================================================================
  // 📤 Compartir por ID — hoja con copiar + compartir
  // ================================================================
  Future<void> _openShareIdSheet(Room room) async {
    final roomId = room.id;
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Compartir sala por ID',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ID de la sala',
                        style: TextStyle(
                            color: Colors.white60,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    SelectableText(
                      roomId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        letterSpacing: 0.2,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                                ClipboardData(text: roomId));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('ID copiado al portapapeles'),
                                  backgroundColor: Colors.blueAccent,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy, color: Colors.white70),
                          label: const Text('Copiar',
                              style: TextStyle(color: Colors.white70)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            final msg =
                                'Únete a mi sala en DraftClub con este ID: $roomId\n'
                                '📲 Ve a "Salas" → "Buscar" y pega el ID para entrar.';
                            Share.share(msg);
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('Compartir'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Quien reciba el ID puede ir a "Salas" → "Buscar", pegar el ID y unirse.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12.5),
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
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
        final uid = _auth.currentUser?.uid;
        final isCreator = room.creatorId == uid;
        final joined = uid != null && room.players.contains(uid);

        return Scaffold(
          backgroundColor: const Color(0xFF0E0E0E),

          // 🚫 Quitamos el AppBar para que no se duplique con el del DashboardPage.
          // Conservamos el cuerpo tal cual.
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                )
              : _buildRoomBody(room, isCreator, joined),
        );
      },
    );
  }

  // ================================================================
  // 🧩 Cuerpo de la pantalla de detalle
  // ================================================================
  Widget _buildRoomBody(Room room, bool isCreator, bool joined) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjeta encabezado
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade800, width: 0.8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor:
                      room.isPublic ? Colors.greenAccent : Colors.redAccent,
                  child: const Icon(Icons.sports_soccer, color: Colors.black),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    room.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Info base
          _buildInfoRow(Icons.location_on, 'Ciudad', room.city),
          if (room.exactAddress != null && room.exactAddress!.isNotEmpty)
            _buildInfoRow(Icons.home_work, 'Dirección', room.exactAddress!)
          else if (isCreator)
            GestureDetector(
              onTap: () => _openEditModal(room),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent, width: 1),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_location_alt,
                        color: Colors.blueAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Definir dirección exacta',
                        style: TextStyle(color: Colors.blueAccent)),
                  ],
                ),
              ),
            ),
          _buildInfoRow(Icons.group, 'Equipos', '${room.teams} equipos'),
          _buildInfoRow(
              Icons.person, 'Jugadores por equipo', '${room.playersPerTeam}'),
          _buildInfoRow(
              Icons.swap_horiz, 'Cambios permitidos', '${room.substitutes}'),
          _buildInfoRow(
              Icons.male, 'Género del partido', _normalizeSex(room.sex)),
          _buildInfoRow(
            room.isPublic ? Icons.public : Icons.lock,
            'Tipo de sala',
            room.isPublic ? 'Pública' : 'Privada',
          ),
          if (room.eventAt != null)
            _buildInfoRow(
              Icons.schedule,
              'Partido programado',
              '${room.eventAt!.day}/${room.eventAt!.month}/${room.eventAt!.year} '
                  '${room.eventAt!.hour}:${room.eventAt!.minute.toString().padLeft(2, '0')}',
            ),

          const SizedBox(height: 12),

          // ID de la sala (con copiar rápido)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.key, color: Colors.blueAccent, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'ID de la sala:',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      room.id,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Copiar ID',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: room.id));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ID copiado al portapapeles'),
                          backgroundColor: Colors.blueAccent,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy, color: Colors.white70),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Compartir por ID',
                  onPressed: () => _openShareIdSheet(room),
                  icon: const Icon(Icons.ios_share, color: Colors.blueAccent),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Acciones principales
          _buildActionButtons(room, isCreator, joined),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Room room, bool isCreator, bool joined) {
    return Center(
      child: Column(
        children: [
          if (!isCreator)
            ElevatedButton.icon(
              icon: Icon(joined ? Icons.logout : Icons.login),
              label: Text(joined ? 'Salir de la sala' : 'Unirme a esta sala'),
              style: ElevatedButton.styleFrom(
                backgroundColor: joined ? Colors.redAccent : Colors.blueAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      try {
                        if (joined) {
                          await _roomService.leaveRoom(room.id);
                        } else {
                          await _roomService.joinRoom(room.id);
                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => TeamListPage(room: room)),
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.people_alt_outlined),
            label: const Text('Ver equipos'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.blueAccent),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TeamListPage(room: room)),
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Chat de la sala'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.grey),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
              );
            },
          ),
        ],
      ),
    );
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
        await _sendSystemMessage(
          room.id,
          '⚠️ El administrador ha eliminado la sala "${room.name}".',
        );
        await _roomService.deleteRoom(room.id);
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sala eliminada correctamente'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar sala: $e')),
        );
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  // ================================================================
  // 🔠 Fila de info
  // ================================================================
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 22),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
                color: Colors.white70, fontWeight: FontWeight.bold),
          ),
          Expanded(
              child: Text(value, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}
