import 'package:flutter/material.dart';

class MatchTypeSelector extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onTypeChanged;

  const MatchTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildTypeCard(
            context,
            type: 'friendly',
            title: 'Amistoso',
            icon: Icons.casino_outlined, // Dice or fun icon
            color: Colors.greenAccent,
            isSelected: selectedType == 'friendly',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTypeCard(
            context,
            type: 'competitive',
            title: 'Competitivo',
            icon: Icons.emoji_events_outlined, // Trophy
            color: Colors.orangeAccent,
            isSelected: selectedType == 'competitive',
          ),
        ),
      ],
    );
  }

  Widget _buildTypeCard(
    BuildContext context, {
    required String type,
    required String title,
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => onTypeChanged(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : const Color(0xFF1A1A1A),
          border: Border.all(
            color: isSelected ? color : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.white54,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
