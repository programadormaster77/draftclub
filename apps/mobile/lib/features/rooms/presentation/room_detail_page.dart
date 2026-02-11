import 'dart:io'; // 🆕
import 'package:path_provider/path_provider.dart'; // 🆕
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 📋 Clipboard (copiar ID)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

import '../models/match_model.dart'
    as m; // Alias para evitar conflicto con widgets
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
          appBar: AppBar(
            title: Text(room.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.black,
            actions: [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.blueAccent),
                tooltip: 'Compartir Tarjeta',
                onPressed: () => _shareMatchCard(room),
              ),
              IconButton(
                icon: const Icon(Icons.amp_stories_rounded,
                    color: Colors.white70),
                tooltip: 'Compartir por ID',
                onPressed: () => _openShareIdSheet(room),
              ),
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
          body: Stack(
            children: [
              _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Colors.blueAccent))
                  : _buildRoomBody(room, isCreator, joined),
              if (_showVersus)
                VersusOverlay(
                  roomName: room.name,
                  onDismiss: () => setState(() => _showVersus = false),
                ),
            ],
          ),
        );
      },
    );
  }

  // ================================================================
  // 🧩 Cuerpo de la pantalla de detalle
  // ================================================================
  Widget _buildRoomBody(Room room, bool isCreator, bool joined) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🆕 Barra de Progreso del Partido
          MatchProgressBar(
            currentPhase: room.phase,
            matchType: room.matchType,
          ),
          const SizedBox(height: 20),

          // 🆕 Tarjeta de Acción según Fase
          if (isCreator) _buildPhaseActionCard(room),

          const SizedBox(height: 20),

          // 🏆 RESULTADO FINAL (Solo si ya terminó)
          if (room.phase == 'finished') ...[
            _buildMatchResultCard(room),
            const SizedBox(height: 24),
          ],

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

          // 🆕 DASHBOARD EN VIVO
          _buildLiveDashboard(room, isCreator),

          const SizedBox(height: 30),

          // ⚽ ALINEACIÓN (Cancha Visual vs Lista)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ALINEACIÓN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
            secondChild: _buildPlayerList(
                room), // We need to create this method as it seems missing or hidden
          ),

          const SizedBox(height: 30),

          // Secciones de Partidos
          // ================================================================
          const SizedBox(height: 24),
          const Text(
            'Partidos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
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
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 30),

          if (isCreator) ...[
            const SizedBox(height: 20),
            // 🛠️ ZONA DE PRUEBAS (DEBUG)
            _buildDebugSection(room),
            const SizedBox(height: 40),
          ],
          // Acciones principales
          _buildActionButtons(room, isCreator, joined),
        ],
      ),
    );
  }

  // ================================================================
  // 🛠️ ZONA DE PRUEBAS (DEBUG)
  // ================================================================
  Widget _buildDebugSection(Room room) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bug_report, color: Colors.redAccent),
              SizedBox(width: 8),
              Text(
                'ZONA DE PRUEBAS',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDebugButton(
            icon: Icons.group_add,
            label: 'Llenar Sala (Bots)',
            description: 'Agrega jugadores falsos hasta el 80%',
            color: Colors.blueAccent,
            onTap: () => _debugFillRoom(room),
          ),
          _buildDebugButton(
            icon: Icons.calendar_today,
            label: 'Definir Fecha',
            description: 'Asigna fecha mañana a las 10:00 PM',
            color: Colors.orangeAccent,
            onTap: () => _debugSetDate(room),
          ),
          _buildDebugButton(
            icon: Icons.location_on,
            label: 'Definir Sede',
            description: 'Asigna ubicación de prueba',
            color: Colors.purpleAccent,
            onTap: () => _debugSetLocation(room),
          ),
          const Divider(color: Colors.white24, height: 24),
          _buildDebugButton(
            icon: Icons.restore,
            label: 'RESETEAR SALA',
            description: 'Borra todo y vuelve al inicio',
            color: Colors.redAccent,
            onTap: () => _debugReset(room),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugButton({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _debugSetDate(Room room) async {
    try {
      final tomorrow = DateTime.now().add(const Duration(days: 1, hours: 2));
      await _roomService.updateRoom(room.id, {
        'eventAt': Timestamp.fromDate(tomorrow),
        // Si estamos en recruitment, pasamos directo a scheduling -> venue
        if (room.phase == 'recruitment' || room.phase == 'scheduling')
          'phase': 'venue',
      });
      // Forzar actualización de fase si quedó atrás
      if (room.phase == 'scheduling') {
        await _roomService.updatePhase(room.id, 'venue');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📅 Fecha de prueba asignada')));
      }
    } catch (e) {
      debugPrint('Error debug date: $e');
    }
  }

  Future<void> _debugSetLocation(Room room) async {
    try {
      await _roomService.updateRoom(room.id, {
        'exactAddress': 'Estadio Azteca (Demo)',
        'lat': 19.3029,
        'lng': -99.1505,
        'countryCode': 'MX', // Opcional
        // Si estamos antes de venue, saltamos a validation
        if (room.phase != 'validation' && room.phase != 'ready')
          'phase': 'validation'
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📍 Ubicación de prueba asignada')));
      }
    } catch (e) {
      debugPrint('Error debug location: $e');
    }
  }

  Future<void> _debugReset(Room room) async {
    try {
      // Dejar solo al creador
      final creatorOnly = [room.creatorId];
      await _roomService.updateRoom(room.id, {
        'players': creatorOnly,
        'eventAt': null,
        'exactAddress': null,
        'cityLat': null,
        'cityLng': null,
        'countryCode': null,
        'lat': null,
        'lng': null,
        'phase': 'recruitment',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🔄 Sala reseteada a fábrica')));
      }
    } catch (e) {
      debugPrint('Error debug reset: $e');
    }
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

  // ====================================================================
  // 🚦 Lógica de Fases y Acciones del Admin
  // ====================================================================
  Widget _buildPhaseActionCard(Room room) {
    String title = '';
    String subtitle = '';
    String buttonText = '';
    IconData icon = Icons.help;
    VoidCallback? onPressed;
    Color color = Colors.blueAccent;

    switch (room.phase) {
      case 'recruitment':
        final percent = room.players.length / room.maxPlayers;
        if (percent >= 0.8) {
          title = '¡Cuórum alcanzado!';
          subtitle = 'Ya hay suficientes jugadores para agendar.';
          buttonText = 'Pasar a Agendamiento';
          icon = Icons.calendar_today;
          onPressed = () => _advancePhase(room, 'scheduling');
          color = Colors.greenAccent;
        } else {
          title = 'Convocatoria en curso';
          subtitle =
              'Invita a más jugadores (${room.players.length}/${room.maxPlayers})';
          buttonText = 'Compartir Sala';
          icon = Icons.share;
          onPressed = () => _openShareIdSheet(room);
        }
        break;

      case 'scheduling':
        if (room.eventAt != null) {
          title = 'Fecha definida';
          subtitle = room.formattedEventDate;
          buttonText = 'Confirmar y pasar a Sede';
          icon = Icons.location_on;
          onPressed = () => _advancePhase(room, 'venue');
          color = Colors.greenAccent;
        } else {
          title = 'Definir Fecha';
          subtitle = 'Es necesario acordar cuándo se juega.';
          buttonText = 'Elegir Fecha';
          icon = Icons.edit_calendar;
          onPressed = () => _openEditModal(room);
          color = Colors.orangeAccent;
        }
        break;

      case 'venue':
        if (room.hasLocation) {
          title = 'Sede definida';
          subtitle = room.exactAddress ?? room.city;
          buttonText = 'Pasar a Validación';
          icon = Icons.fact_check;
          onPressed = () => _advancePhase(room, 'validation');
          color = Colors.greenAccent;
        } else {
          title = 'Definir Sede';
          subtitle = 'Falta seleccionar la cancha o lugar.';
          buttonText = 'Elegir Ubicación';
          icon = Icons.map;
          onPressed =
              () => _openEditModal(room); // Abre modal para editar location
          color = Colors.orangeAccent;
        }
        break;

      case 'validation':
        if (room.matchType == 'competitive') {
          title = 'Validación Competitiva';
          subtitle = 'Se requiere designar un árbitro oficial.';
          buttonText = 'Designar Árbitro';
          icon = Icons.sports_score;
          onPressed = () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Funcionalidad de Árbitros en desarrollo. Avanzando por prueba.')));
            _advancePhase(room, 'ready');
          };
          color = Colors.purpleAccent;
        } else {
          title = 'Validación Amistosa';
          subtitle = 'Confirma que todo está listo para jugar.';
          buttonText = '¡Todo Listo!';
          icon = Icons.check_circle;
          onPressed = () => _advancePhase(room, 'ready');
          color = Colors.greenAccent;
        }
        break;

      case 'ready':
        if (room.eventAt != null && room.eventAt!.isBefore(DateTime.now())) {
          title = 'Partido Finalizado';
          subtitle = 'El evento ha concluido. ¿Cómo estuvo?';
          buttonText = 'Finalizar Evento';
          icon = Icons.flag;
          onPressed = () => _showFinishMatchDialog(room);
          color = Colors.redAccent;
        } else {
          // Si es ready pero aún no es la hora, igual permitimos finalizar manualmente si ya pasó
          // O si el creador quiere forzarlo
          if (room.eventAt != null &&
              DateTime.now().difference(room.eventAt!).inHours > -2) {
            title = 'Partido en Curso / Finalizado';
            subtitle = 'Registra el marcador cuando termine.';
            buttonText = 'Registrar Resultado';
            icon = Icons.emoji_events;
            onPressed = () => _showFinishMatchDialog(room); // 🆕 Dialogo
            color = Colors.amber;
          } else {
            return const SizedBox.shrink(); // Aún no ha pasado el tiempo
          }
        }
        break;

      case 'finished':
        title = '¡Evento Concluido!';
        subtitle = 'Califica a tus compañeros para subir su reputación.';
        buttonText = 'Calificar Jugadores';
        icon = Icons.star;
        onPressed = () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => RatePlayerPage(room: room)));
        };
        color = Colors.amber;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onPressed,
              child: Text(buttonText,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _advancePhase(Room room, String nextPhase) async {
    try {
      await RoomService().updatePhase(room.id, nextPhase);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.green,
        content: Text('✅ Fase actualizada a: $nextPhase'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red,
        content: Text('Error al avanzar fase: $e'),
      ));
    }
  }

  // ================================================================
  // 🏆 Finalizar Partido + Dialog
  // ================================================================
  void _showFinishMatchDialog(Room room) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MatchResultDialog(
        room: room,
        onSave: (scoreA, scoreB, mvpId) async {
          Navigator.pop(ctx); // Cerrar dialog
          await _finishMatchConfig(room, scoreA, scoreB, mvpId);
        },
      ),
    );
  }

  Future<void> _finishMatchConfig(
      Room room, int scoreA, int scoreB, String? mvpId) async {
    try {
      setState(() => _loading = true);

      await _roomService.finishMatch(
        roomId: room.id,
        scoreTeamA: scoreA,
        scoreTeamB: scoreB,
        mvpPlayerId: mvpId,
      );

      // ✨ Animación de celebración (Dialog temporal con Lottie)
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.network(
                  'https://assets10.lottiefiles.com/packages/lf20_u4yrau.json', // Confetti
                  repeat: false,
                  height: 200,
                ),
                const SizedBox(height: 16),
                const Text(
                  '¡Partido Registrado!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
        // Cerrar confetti después de 3s
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        });
      }

      await _sendSystemMessage(
        room.id,
        '🏆 PARTIDO FINALIZADO\nMarcador: $scoreA - $scoreB',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar resultado: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ================================================================
  // 📊 Widget de Resultado Final
  // ================================================================
  Widget _buildMatchResultCard(Room room) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
              color: Colors.blueAccent.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          const Text(
            'RESULTADO FINAL',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${room.scoreTeamA ?? 0}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('-',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 48,
                        fontWeight: FontWeight.w300)),
              ),
              Text(
                '${room.scoreTeamB ?? 0}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (room.mvpPlayerId != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: FutureBuilder<DocumentSnapshot>(
                future:
                    _firestore.collection('users').doc(room.mvpPlayerId).get(),
                builder: (context, snapshot) {
                  String mvpName = 'Cargando...';
                  if (snapshot.hasData && snapshot.data!.exists) {
                    mvpName = snapshot.data!.get('name') ?? 'Jugador';
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'MVP: $mvpName',
                        style: const TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.bold),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /*
  Future<void> _launchMapsSearch(String query) async {
    final Uri url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir mapas: $e')),
        );
      }
    }
  }
  */

  // ================================================================
  // 📊 DASHBOARD EN VIVO
  // ================================================================
  Widget _buildLiveDashboard(Room room, bool isCreator) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // 1. Header: Status & Privacy
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: room.isPublic
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: room.isPublic ? Colors.green : Colors.orange),
                  ),
                  child: Row(
                    children: [
                      Icon(room.isPublic ? Icons.public : Icons.lock,
                          size: 14,
                          color: room.isPublic ? Colors.green : Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        room.isPublic ? 'Pública' : 'Privada',
                        style: TextStyle(
                            color: room.isPublic ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 8),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _normalizeSex(room.sex),
                    style: const TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // 2. Jugadores (Con visual de progreso)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('JUGADORES',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                              text: '${room.players.length}',
                              style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          TextSpan(
                              text: '/${room.maxPlayers}',
                              style: const TextStyle(
                                  fontSize: 18, color: Colors.white38)),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: room.players.length / room.maxPlayers,
                        backgroundColor: Colors.white10,
                        color: Colors.blueAccent,
                        strokeWidth: 6,
                      ),
                      const Icon(Icons.people, color: Colors.white70),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // 🆕 SELECTOR DE POSICIÓN
          if (room.players.contains(_auth.currentUser?.uid))
            _buildPositionSelector(room),

          // 🆕 SELECTOR DE ESTADO
          if (room.players.contains(_auth.currentUser?.uid))
            _buildStatusSelector(room),

          if (room.players.contains(_auth.currentUser?.uid))
            const Divider(height: 1, color: Colors.white10),

          // 3. Tarjetas de Detalle (Fecha & Lugar)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // FECHA
                _buildDashboardRow(
                  icon: Icons.calendar_today,
                  label: 'FECHA',
                  value: room.eventAt != null
                      ? room.formattedEventDate
                      : 'Por definir',
                  isMissing: room.eventAt == null,
                  actionLabel: room.eventAt == null
                      ? (isCreator ? 'Definir' : null)
                      : 'Agendar',
                  onAction: () {
                    if (room.eventAt == null) {
                      if (isCreator) _openEditModal(room);
                    } else {
                      _addToCalendar(room);
                    }
                  },
                ),
                const SizedBox(height: 16),
                // LUGAR
                _buildDashboardRow(
                  icon: Icons.location_on,
                  label: 'SEDE',
                  value: room.hasLocation
                      ? (room.exactAddress ?? room.city)
                      : 'Por definir (${room.city})',
                  isMissing: !room.hasLocation,
                  actionLabel:
                      isCreator && !room.hasLocation ? 'Definir' : null,
                  onAction: () => _openEditModal(room),
                  extraWidget: !room.hasLocation
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.search, size: 16),
                            label: const Text('Buscar canchas cercanas',
                                style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blueAccent,
                              side: BorderSide(
                                  color: Colors.blueAccent.withOpacity(0.5)),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              final query =
                                  'canchas de futbol soccer ${room.city}';
                              // _launchMapsSearch(query);
                            },
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isMissing,
    String? actionLabel,
    VoidCallback? onAction,
    Widget? extraWidget,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isMissing
                ? Colors.orange.withOpacity(0.1)
                : Colors.blueAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isMissing ? Colors.orange : Colors.blueAccent,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        color: isMissing ? Colors.orange : Colors.white,
                        fontWeight:
                            isMissing ? FontWeight.bold : FontWeight.normal,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (actionLabel != null)
                    GestureDetector(
                      onTap: onAction,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          actionLabel,
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              if (extraWidget != null) extraWidget,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPositionSelector(Room room) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final currentPos = room.playerPositions[uid];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MI POSICIÓN',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPosOption(
                  room, 'GK', 'Portero', Icons.sports_handball, currentPos),
              _buildPosOption(room, 'DEF', 'Defensa', Icons.shield, currentPos),
              _buildPosOption(
                  room, 'MID', 'Medio', Icons.directions_run, currentPos),
              _buildPosOption(
                  room, 'FWD', 'Delantero', Icons.sports_soccer, currentPos),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPosOption(
      Room room, String code, String label, IconData icon, String? current) {
    final isSelected = current == code;
    return GestureDetector(
      onTap: () => _roomService.updatePlayerPosition(room.id, code),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blueAccent : Colors.white10,
              shape: BoxShape.circle,
              border: Border.all(
                  color: isSelected ? Colors.blueAccent : Colors.white24),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blueAccent : Colors.white54,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
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
