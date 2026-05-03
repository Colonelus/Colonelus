import 'package:flutter/material.dart';
import '../services/drop_service.dart';

class DropDialog extends StatefulWidget {
  const DropDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const DropDialog(),
    );
  }

  @override
  State<DropDialog> createState() => _DropDialogState();
}

class _DropDialogState extends State<DropDialog> {
  bool _isOpening = false;
  Map<String, dynamic>? _result;

  Future<void> _open() async {
    setState(() => _isOpening = true);
    try {
      final res = await DropService.openDropBox();
      if (mounted) setState(() => _result = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF001B2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.5)),
      ),
      title: const Text(
        "Sürpriz Kutu",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isOpening)
            const CircularProgressIndicator(color: Colors.cyanAccent)
          else if (_result == null) ...[
            const Icon(Icons.card_giftcard, size: 64, color: Colors.cyanAccent),
            const SizedBox(height: 16),
            const Text(
              "Kutuyu açarak rastgele inci veya VIP kazanabilirsin!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ] else ...[
            Icon(
              _result!['isVip'] ? Icons.stars : Icons.auto_awesome,
              size: 64,
              color: Colors.yellowAccent,
            ),
            const SizedBox(height: 16),
            Text(
              "Tebrikler!\n${_result!['name']}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (_result == null && !_isOpening) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
              side: const BorderSide(color: Colors.cyanAccent),
            ),
            onPressed: _open,
            child: const Text("Aç", style: TextStyle(color: Colors.white)),
          ),
        ] else if (_result != null)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Kapat",
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
      ],
    );
  }
}