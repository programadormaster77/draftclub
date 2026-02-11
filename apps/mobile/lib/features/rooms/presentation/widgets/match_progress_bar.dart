import 'package:flutter/material.dart';

class MatchProgressBar extends StatelessWidget {
  final String currentPhase;
  final String matchType; // 'friendly' | 'competitive'

  const MatchProgressBar({
    Key? key,
    required this.currentPhase,
    required this.matchType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Definimos las 5 fases en orden
    final steps = [
      {'id': 'recruitment', 'label': 'Convocatoria', 'icon': Icons.group},
      {
        'id': 'scheduling',
        'label': 'Agendamiento',
        'icon': Icons.calendar_today
      },
      {'id': 'venue', 'label': 'Sede', 'icon': Icons.location_on},
      {'id': 'validation', 'label': 'Validación', 'icon': Icons.rule},
      {
        'id': 'ready',
        'label': 'Confirmado',
        'icon': Icons.check_circle_outline
      },
    ];

    // Indice de la fase actual
    int currentIndex = steps.indexWhere((s) => s['id'] == currentPhase);
    if (currentIndex == -1) currentIndex = 0; // Fallback

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      color: const Color(0xFF141414),
      child: Column(
        children: [
          Row(
            children: List.generate(steps.length, (index) {
              final step = steps[index];
              final isActive = index == currentIndex;
              final isPast = index < currentIndex;
              final isLast = index == steps.length - 1;

              Color color = isActive
                  ? Colors.blueAccent
                  : (isPast ? Colors.greenAccent : Colors.grey.shade800);

              return Expanded(
                child: Row(
                  children: [
                    // Icono del paso
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? color.withOpacity(0.2)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: isActive || isPast
                                      ? color
                                      : Colors.white12,
                                  width: isActive ? 2 : 1),
                            ),
                            child: Icon(
                              step['icon'] as IconData,
                              size: 16,
                              color:
                                  isActive || isPast ? color : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Línea conectora (si no es el último)
                    if (!isLast)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isPast ? Colors.greenAccent : Colors.white12,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // Label del paso actual
          Text(
            steps[currentIndex]['label'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getPhaseDescription(steps[currentIndex]['id'] as String),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _getPhaseDescription(String phaseId) {
    switch (phaseId) {
      case 'recruitment':
        return 'Esperando jugadores...';
      case 'scheduling':
        return 'Definiendo fecha y hora';
      case 'venue':
        return 'Seleccionando lugar';
      case 'validation':
        return matchType == 'competitive'
            ? 'Confirmando árbitro'
            : 'Confirmando detalles finales';
      case 'ready':
        return '¡Todo listo para jugar!';
      default:
        return '';
    }
  }
}
