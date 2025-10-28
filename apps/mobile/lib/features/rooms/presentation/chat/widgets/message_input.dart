import 'package:flutter/material.dart';

class MessageInput extends StatefulWidget {
  final Future<void> Function(String text) onSend;

  const MessageInput({super.key, required this.onSend});

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(text);
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1C1C1C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sending ? null : _submit,
            icon: const Icon(Icons.send, color: Colors.blueAccent),
          ),
        ],
      ),
    );
  }
}
