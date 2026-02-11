import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/room_model.dart';

class MatchResultDialog extends StatefulWidget {
  final Room room;
  // Callback with results: scoreA, scoreB, mvpId
  final Function(int, int, String?) onSave;

  const MatchResultDialog({
    super.key,
    required this.room,
    required this.onSave,
  });

  @override
  State<MatchResultDialog> createState() => _MatchResultDialogState();
}

class _MatchResultDialogState extends State<MatchResultDialog> {
  final _scoreACtrl = TextEditingController();
  final _scoreBCtrl = TextEditingController();
  String? _selectedMvpId;
  bool _isLoading = false;

  Map<String, String> _playerNames = {};

  @override
  void initState() {
    super.initState();
    _fetchPlayerNames();
  }

  Future<void> _fetchPlayerNames() async {
    // 🧠 Carga nombres de todos los jugadores para el dropdown
    final firestore = FirebaseFirestore.instance;
    final players = widget.room.players;

    for (var uid in players) {
      if (!_playerNames.containsKey(uid)) {
        try {
          final doc = await firestore.collection('users').doc(uid).get();
          if (doc.exists && mounted) {
            final data = doc.data();
            setState(() {
              _playerNames[uid] = data?['name'] ?? 'Jugador';
            });
          }
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🏆 Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events,
                    color: Colors.amber, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Resultado Final',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ingresa el marcador y elige al MVP',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 32),

              // ⚽ Inputs de Marcador
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildScoreInput('Equipo A', _scoreACtrl, Colors.blueAccent),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      '-',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.2),
                          fontSize: 40,
                          fontWeight: FontWeight.w300),
                    ),
                  ),
                  _buildScoreInput('Equipo B', _scoreBCtrl, Colors.redAccent),
                ],
              ),
              const SizedBox(height: 32),

              // 🌟 MVP Selection (Dropdown mejorado)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MVP del Partido (Opcional)',
                    style: TextStyle(
                        color: Colors.amber,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252525),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedMvpId,
                        hint: const Text('Seleccionar Jugador Destacado',
                            style: TextStyle(color: Colors.white38)),
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2A2A2A),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 15),
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: Colors.white54),
                        items: widget.room.players.map((uid) {
                          final name = _playerNames[uid] ?? 'Cargando...';
                          return DropdownMenuItem<String>(
                            value: uid,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.amber,
                                  child: Text(name.isNotEmpty ? name[0] : '?',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(name,
                                        overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedMvpId = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // 💾 Botón Guardar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final sA = int.tryParse(_scoreACtrl.text);
                          final sB = int.tryParse(_scoreBCtrl.text);

                          if (sA == null || sB == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Por favor ingresa un marcador válido (números)')),
                            );
                            return;
                          }

                          setState(() => _isLoading = true);
                          // Llamar al callback
                          await widget.onSave(sA, sB, _selectedMvpId);
                          // El estado de carga se mantiene hasta que se cierra o falla
                          if (mounted) setState(() => _isLoading = false);
                        },
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.black),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Finalizar y Celebrar',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 8),
                            Text('🎉', style: TextStyle(fontSize: 18)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreInput(
      String label, TextEditingController ctrl, Color color) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Center(
            child: TextField(
              controller: ctrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: '0',
                hintStyle: TextStyle(color: Colors.white12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
