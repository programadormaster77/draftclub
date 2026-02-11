import 'package:flutter/material.dart';
import '../../models/room_model.dart';

class MatchCardImage extends StatelessWidget {
  final Room room;

  const MatchCardImage({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: 600, // Aspect ratio for stories (approx)
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Stack(
        children: [
          // Background Pattern (Optional)
          Positioned.fill(
              child: Opacity(
            opacity: 0.05,
            child:
                GridPaper(color: Colors.white, divisions: 1, subdivisions: 1),
          )),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo / Header
              const Icon(Icons.sports_soccer, size: 60, color: Colors.white),
              const SizedBox(height: 10),
              const Text(
                'DRAFTCLUB',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4),
              ),
              const SizedBox(height: 40),

              // Match Name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  room.name.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                          color: Colors.black45,
                          blurRadius: 10,
                          offset: Offset(0, 4))
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // VS
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTeamCircle(Colors.blueAccent, 'A'),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('VS',
                        style: TextStyle(
                            color: Colors.amber,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic)),
                  ),
                  _buildTeamCircle(Colors.redAccent, 'B'),
                ],
              ),

              const SizedBox(height: 40),

              // Details
              _buildDetailRow(Icons.calendar_today, room.formattedEventDate),
              const SizedBox(height: 16),
              _buildDetailRow(
                  Icons.location_on, room.exactAddress ?? room.city),

              const Spacer(),

              // Footer
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  '¡ÚNETE AL PARTIDO!',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCircle(Color color, String label) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.2),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
