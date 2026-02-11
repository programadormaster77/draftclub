import 'dart:io'; // 🆕
import 'package:path_provider/path_provider.dart'; // 🆕
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 📋 Clipboard (copiar ID)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

// AGREGA ESTE:
import 'package:cloud_functions/cloud_functions.dart';

import '../models/room_model.dart';
import '../data/room_service.dart';
import 'team_list_page.dart';
import 'chat/chat_room_page.dart';
import '../../../core/location/place_service.dart'; // 🆕 direcciones exactas
import 'widgets/match_card.dart'; // 🆕 Widget reutilizable
import 'widgets/match_progress_bar.dart'; // 🆕 Import
import 'package:draftclub_mobile/core/notifications/notification_service.dart'; // 🆕

import 'widgets/match_card_image.dart'; // 🆕
import 'widgets/versus_overlay.dart'; // 🆕
import 'package:screenshot/screenshot.dart'; // 🆕
import 'package:add_2_calendar/add_2_calendar.dart'; // 🆕
import '../../profile/presentation/rate_player_page.dart'; // 🆕
import 'widgets/soccer_field_widget.dart';
import 'dialogs/match_result_dialog.dart'; // 🆕 Dialogo de resultados
import 'package:lottie/lottie.dart'; // 🆕 Animación

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
  final _notificationService = NotificationService(); // 🆕
  final ScreenshotController _screenshotController =
      ScreenshotController(); // 🆕

  bool _loading = false;
  bool _showLineup = true; // Default to true for engagement
  bool _searchingAddress = false;
  bool _showVersus = false; // 🆕
  bool _hasShownVersus = false; // 🆕

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    await _notificationService.init();
    // Agendar recordatorio si ya hay fecha definida
    if (widget.room.eventAt != null) {
      _scheduleMatchReminder(widget.room);
    }
  }

  void _scheduleMatchReminder(Room room) {
    if (room.eventAt == null) return;
    _notificationService.scheduleMatchReminder(
      id: room.id.hashCode, // Simple ID based on hash
      title: '⚽ ¡Tu partido se acerca!',
      body: 'El partido "${room.name}" comienza en 1 hora. ¡Prepárate!',
      scheduledDate: room.eventAt!,
    );
  }

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
    // ===============================
    // 📍 Controles existentes
    // ===============================
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

    // ===============================
    // 🆕 Controles NUEVOS
    // ===============================
    final nameCtrl = TextEditingController(text: room.name);
    final teamsCtrl = TextEditingController(text: room.teams.toString());
    final playersCtrl =
        TextEditingController(text: room.playersPerTeam.toString());
    final subsCtrl = TextEditingController(text: room.substitutes.toString());

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1C1C1C),
            title: const Text(
              'Editar sala',
              style: TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  // ==========================
                  // 📍 Dirección exacta
                  // ==========================
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

                  // ==========================
                  // 🚻 Género del partido
                  // ==========================
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

                  // ==========================
                  // 📅 Fecha
                  // ==========================
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
                        setModalState(() {
                          dateCtrl.text = date.toString().split(' ')[0];
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 10),

                  // ==========================
                  // ⏰ Hora
                  // ==========================
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
                          () => timeCtrl.text = time.format(context),
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 10),

                  // ==========================
                  // 🔓 Sala pública / privada
                  // ==========================
                  SwitchListTile(
                    title: const Text(
                      'Sala pública',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: isPublic,
                    onChanged: (val) => setModalState(() => isPublic = val),
                  ),

                  const Divider(color: Colors.white24, height: 24),

                  // ==========================
                  // 🏷 Nombre de la sala
                  // ==========================
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la sala',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ==========================
                  // ⚽ Número de equipos
                  // ==========================
                  TextField(
                    controller: teamsCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Número de equipos',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ==========================
                  // 👥 Jugadores por equipo
                  // ==========================
                  TextField(
                    controller: playersCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Jugadores por equipo',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ==========================
                  // 🔄 Suplentes
                  // ==========================
                  TextField(
                    controller: subsCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Suplentes permitidos',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
                onPressed: () async {
                  Navigator.pop(context);

                  // 1️⃣ Guardamos lo que ya tenías (dirección, fecha, hora, público, género)
                  await _saveEdits(
                    room,
                    addressCtrl.text,
                    dateCtrl.text,
                    timeCtrl.text,
                    isPublic,
                    sex,
                    selectedAddress,
                  );

                  // 2️⃣ Actualizamos los NUEVOS campos: nombre, equipos, jugadores, suplentes
                  try {
                    int? parseInt(String text) {
                      text = text.trim();
                      if (text.isEmpty) return null;
                      return int.tryParse(text);
                    }

                    final updateData = <String, dynamic>{};

                    final newName = nameCtrl.text.trim();
                    if (newName.isNotEmpty && newName != room.name) {
                      updateData['name'] = newName;
                    }

                    final newTeams = parseInt(teamsCtrl.text);
                    if (newTeams != null && newTeams > 0) {
                      updateData['teams'] = newTeams;
                    }

                    final newPlayersPerTeam = parseInt(playersCtrl.text);
                    if (newPlayersPerTeam != null && newPlayersPerTeam > 0) {
                      updateData['playersPerTeam'] = newPlayersPerTeam;
                    }

                    final newSubs = parseInt(subsCtrl.text);
                    if (newSubs != null && newSubs >= 0) {
                      updateData['substitutes'] = newSubs;
                    }

                    if (updateData.isNotEmpty) {
                      await _roomService.updateRoom(room.id, updateData);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Error al actualizar detalles adicionales: $e'),
                        ),
                      );
                    }
                  }
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
  // 🪄 CREAR PARTIDO DE PRUEBA (DEBUG)
  // ================================================================

  Future<void> _debugFillRoom(Room room) async {
    try {
      final currentPlayers = List<String>.from(room.players);
      final needed = (room.maxPlayers * 0.8).ceil();
      if (currentPlayers.length >= needed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('La sala ya tiene suficiente gente 👍')),
          );
        }
        return;
      }

      for (int i = currentPlayers.length; i < needed; i++) {
        currentPlayers.add('dummy_player_$i');
      }

      await _roomService.updateRoom(room.id, {'players': currentPlayers});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sala llenada con bots 🤖')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error debug fill: $e')),
        );
      }
    }
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
  // 📅 Agregar al Calendario
  // ================================================================
  void _addToCalendar(Room room) {
    if (room.eventAt == null) return;
    final event = Event(
      title: 'Partido: ${room.name}',
      description: 'Partido en DraftClub. Fase: ${room.phase}',
      location: room.exactAddress ?? room.city,
      startDate: room.eventAt!,
      endDate: room.eventAt!.add(const Duration(hours: 2)),
      iosParams: const IOSParams(reminder: Duration(minutes: 60)),
      androidParams: const AndroidParams(emailInvites: []),
    );
    Add2Calendar.addEvent2Cal(event);
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

        // 🆕 Reagendar notificación si hay fecha
        if (room.eventAt != null) {
          _scheduleMatchReminder(room);
        }

        // 🆕 VS Screen Trigger
        if (room.phase == 'ready' && !_hasShownVersus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_showVersus && !_hasShownVersus) {
              setState(() {
                _showVersus = true;
                _hasShownVersus = true;
              });
            }
          });
        }

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
    final now = DateTime.now();

    bool canCloseMatch = false;

    if (!room.isClosed && room.eventAt != null) {
      final eventTime = room.eventAt!;
      final now = DateTime.now();

      if (isCreator) {
        // 🟢 Administrador: puede cerrar apenas llegue la hora exacta
        if (now.isAfter(eventTime)) {
          canCloseMatch = true;
        }
      } else {
        // 🔵 Usuario normal: puede cerrar 1 hora después del partido
        final eventPlus1h = eventTime.add(const Duration(hours: 1));
        if (now.isAfter(eventPlus1h)) {
          canCloseMatch = true;
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============================================================
          // 🔧 BOTÓN DE EDITAR SALA
          // ============================================================
          if (isCreator)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openEditModal(room),
                icon:
                    const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                label: const Text(
                  'Editar sala',
                  style: TextStyle(color: Colors.blueAccent),
                ),
              ),
            ),

          // ============================================================
          // 🏁 BOTÓN “CERRAR PARTIDO”
          // ============================================================
          if (canCloseMatch)
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.flag, color: Colors.white),
                label: const Text(
                  'Cerrar partido',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _openCloseMatchModal(room),
              ),
            ),

          const SizedBox(height: 10),

          // ============================================================
          // TARJETA PRINCIPAL
          // ============================================================
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

          // ============================================================
          // INFORMACIÓN GENERAL
          // ============================================================
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
              TextButton.icon(
                onPressed: () => setState(() => _showLineup = !_showLineup),
                icon: Icon(_showLineup ? Icons.list : Icons.sports_soccer,
                    color: Colors.blueAccent),
                label: Text(_showLineup ? 'Ver Lista' : 'Ver Cancha',
                    style: const TextStyle(color: Colors.blueAccent)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          AnimatedCrossFade(
            duration: const Duration(milliseconds: 400),
            crossFadeState: _showLineup
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Center(
              child: SoccerFieldWidget(
                playerPositions: room.playerPositions,
                allPlayers: room.players,
                onPositionTap: (pos) => _handlePositionTap(room, pos),
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

          const SizedBox(height: 30),

          // ============================================================
          // ID DE LA SALA
          // ============================================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<m.Match>>(
            stream: _roomService.getMatches(room.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Error al cargar partidos.',
                    style: TextStyle(color: Colors.redAccent));
              }
              if (!snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent));
              }

              final matches = snapshot.data!;
              final pending = matches.where((m) => !m.isFinished).toList();

              print('DEBUG: Total matches: ${matches.length}');
              print('DEBUG: Pending: ${pending.length}');

              return Column(
                children: [
                  // 1. Partidos Pendientes
                  if (pending.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pendientes (${pending.length})',
                        style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...pending.map((match) => MatchCard(
                          match: match,
                          roomName: room.name,
                        )),
                    const SizedBox(height: 16),
                  ],

                  if (pending.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'No hay partidos programados.',
                          style: TextStyle(color: Colors.white38),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy, color: Colors.white70),
                ),
                IconButton(
                  tooltip: 'Compartir',
                  onPressed: () => _openShareIdSheet(room),
                  icon: const Icon(Icons.ios_share, color: Colors.blueAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // ============================================================
          // BOTONES PRINCIPALES
          // ============================================================
          _buildActionButtons(room, isCreator, joined),
        ],
      ),
    );
  }

  // ================================================================
// 🔹 Builder reutilizable para mostrar filas de información
// ================================================================
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
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

  Future<void> _openCloseMatchModal(Room room) async {
    final teamsSnap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(room.id)
        .collection('teams')
        .get();

    final teams = teamsSnap.docs;

    if (teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay equipos registrados en esta sala.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    String? selectedTeamId;

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C1C1C),
              title: const Text(
                'Cerrar partido',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Selecciona el equipo ganador:',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),

                    ...teams.map((t) {
                      final data = t.data() as Map<String, dynamic>;
                      final id = t.id;
                      final name = data['name'] ?? 'Equipo';

                      return RadioListTile<String>(
                        activeColor: Colors.blueAccent,
                        value: id,
                        groupValue: selectedTeamId,
                        onChanged: (v) {
                          setStateDialog(() {
                            selectedTeamId = v;
                          });
                        },
                        title: Text(
                          name,
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 10),

                    // 🟥 Botón eliminar sala
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _confirmDelete(room);
                      },
                      child: const Text(
                        'Eliminar sala',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),

                // 🟩 Guardar resultado
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                  ),
                 onPressed: (selectedTeamId == null || _loading)
    ? null
    : () async {
        Navigator.pop(context);
        setState(() => _loading = true);
        try {
          await _processMatchResult(room, selectedTeamId!);
        } finally {
          if (mounted) setState(() => _loading = false);
        }
      },

                  child: const Text('Guardar resultado'),
                ),
              ],
            );
          },
        );
      },
    );
  }


// ================================================================
// 🧮 Lógica de cierre de partido (versión final con Cloud Functions)
// ================================================================
  Future<void> _processMatchResult(Room room, String winnerTeamId) async {
    final teamsSnap = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(room.id)
        .collection('teams')
        .get();

    final uid = _auth.currentUser!.uid;

    // ------------------------------------------------------------
    // Identificar ganador
    // ------------------------------------------------------------
    final winnerDoc = teamsSnap.docs.firstWhere((t) => t.id == winnerTeamId);
    final winnerName = winnerDoc.data()['name'] ?? 'Equipo';

    // ------------------------------------------------------------
    // Preparar arrays de ganadores / perdedores
    // ------------------------------------------------------------
    final Set<String> winners = {};
    final Set<String> losers = {};

    for (var t in teamsSnap.docs) {
      final data = t.data();
      final players = List<String>.from(data['players'] ?? []);

      if (t.id == winnerTeamId) {
        winners.addAll(players);
      } else {
        losers.addAll(players);
      }
    }

    // ------------------------------------------------------------
    // 1️⃣ LLAMAR FUNCIÓN HTTPS: Notificaciones + Histórico
    // ------------------------------------------------------------
    try {
      final callableNotif = FirebaseFunctions.instance.httpsCallable(
        'sendMatchResultNotification',
      );

      await callableNotif.call({
        'roomId': room.id,
        'roomName': room.name,
        'winnerTeamId': winnerTeamId,
        'winnerTeamName': winnerName,
        'winners': winners.toList(),
        'losers': losers.toList(),
      });
    } catch (e) {
      print("ERROR enviando notificaciones: $e");
    }

// ------------------------------------------------------------
// 2️⃣ ACTUALIZAR XP + PARTIDOS usando Cloud Function updateUserStats
// ------------------------------------------------------------
try {
 final callableStats =
    FirebaseFunctions.instance.httpsCallable('updateUserStats');

await callableStats.call({
  'roomId': room.id,
  'winnerUserIds': winners.toList(),
  'loserUserIds': losers.toList(),
  'xpWinner': 120,
  'xpLoser': 60,
});

} catch (e) {
  print("ERROR updateUserStats: $e");
}


    // ------------------------------------------------------------
// 3️⃣ UI: Mostrar tarjeta de victoria/derrota
// ------------------------------------------------------------
    final myTeamId = _getUserTeamId(uid, teamsSnap.docs);
    final userWon = myTeamId == winnerTeamId;

    if (userWon) {
      _showVictoryCard(winnerName);
    } else {
      _showDefeatCard(winnerName);
    }

// Esperar 5 segundos para que el usuario lea la tarjeta
    await Future.delayed(const Duration(seconds: 5));

// Cerrar tarjeta manualmente si el usuario no lo hizo
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop(); // Cierra la tarjeta
    }

// Salir de la sala (volver al dashboard)
    if (mounted) Navigator.pop(context);

// ------------------------------------------------------------
// 4️⃣ Eliminar sala después de procesar todo (segundo plano)
// ------------------------------------------------------------
    Future.delayed(const Duration(seconds: 3), () async {
      await _roomService.deleteRoom(room.id);
    });
  }

// ================================================================
// Helpers
// ================================================================

  String? _getUserTeamId(
    String uid,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> teams,
  ) {
    for (var t in teams) {
      final players = List<String>.from(t.data()['players'] ?? []);
      if (players.contains(uid)) return t.id;
    }
    return null;
  }

  void _showVictoryCard(String teamName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          '🏆 ¡Victoria!',
          style: TextStyle(color: Colors.greenAccent),
        ),
        content: Text(
          'Tu equipo $teamName ganó el partido.',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _showDefeatCard(String teamName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          '❌ Derrota',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Text(
          'El equipo $teamName ganó, pero no fue el tuyo.',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildStatusSelector(Room room) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final currentStatus = room.playerStatus[uid];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MI ESTADO',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip(room, 'on_way', '🏃 Voy en camino',
                    Colors.orangeAccent, currentStatus),
                const SizedBox(width: 8),
                _buildStatusChip(room, 'arrived', '📍 Ya llegué',
                    Colors.greenAccent, currentStatus),
                const SizedBox(width: 8),
                _buildStatusChip(room, 'late', '⏰ Llego tarde',
                    Colors.redAccent, currentStatus),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
      Room room, String code, String label, Color color, String? current) {
    final isSelected = current == code;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) _roomService.updatePlayerStatus(room.id, code);
      },
      selectedColor: color.withOpacity(0.2),
      backgroundColor: Colors.white10,
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? color : Colors.white12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  // ================================================================
  // ⚽ Helper Methods for Lineup / Player List
  // ================================================================

  // ================================================================
  // 📸 Compartir Tarjeta del Partido
  // ================================================================

  Future<void> _shareMatchCard(Room room) async {
    setState(() => _loading = true);
    try {
      // 1. Generar imagen
      final imageBytes = await _screenshotController.captureFromWidget(
        Material(child: MatchCardImage(room: room)),
        delay: const Duration(milliseconds: 100),
        pixelRatio: 2.0,
      );

      // 2. Guardar en archivo temporal
      final directory = await getTemporaryDirectory();
      final imagePath =
          await File('${directory.path}/match_card_${room.id}.png').create();
      await imagePath.writeAsBytes(imageBytes);

      // 3. Compartir
      if (!mounted) return;
      await Share.shareXFiles([XFile(imagePath.path)],
          text: '¡Únete a mi partido en DraftClub! ⚽🔥');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al compartir: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildPlayerList(Room room) {
    if (room.players.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No hay jugadores aún.',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: room.players.length,
      itemBuilder: (context, index) {
        final userId = room.players[index];
        final position = room.playerPositions[userId] ?? 'Sin posición';
        final status = room.playerStatus[userId];

        return FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('users').doc(userId).get(),
          builder: (context, snapshot) {
            String name = 'Cargando...';
            String? photoUrl;

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              name = data['name'] ?? 'Usuario';
              photoUrl = data['photoUrl'];
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl) : null,
                  backgroundColor: Colors.blueAccent,
                  child: photoUrl == null
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white))
                      : null,
                ),
                title: Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                subtitle: Text(position,
                    style: const TextStyle(
                        color: Colors.blueAccent, fontSize: 12)),
                trailing: status != null ? _buildListStatusChip(status) : null,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildListStatusChip(String status) {
    Color color = Colors.grey;
    String label = status;
    if (status == 'ready') {
      color = Colors.green;
      label = 'Llegó';
    }
    if (status == 'on_way') {
      color = Colors.blue;
      label = 'En camino';
    }
    if (status == 'late') {
      color = Colors.orange;
      label = 'Retrasado';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5))),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _handlePositionTap(Room room, String position) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    if (!room.players.contains(currentUser.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes unirte a la sala primero.')));
      return;
    }

    try {
      await _roomService.updatePlayerPosition(room.id, position);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.green,
            content: Text('Posición actualizada a: $position')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
