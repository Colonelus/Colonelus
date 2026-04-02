import 'package:flutter/material.dart';

class IlkMesajEkrani extends StatefulWidget {
  final String secretId;
  final String secretAuthorId;
  final String secretAuthorName;
  final String secretText;

  const IlkMesajEkrani({
    super.key,
    required this.secretId,
    required this.secretAuthorId,
    required this.secretAuthorName,
    required this.secretText,
  });

  @override
  State<IlkMesajEkrani> createState() => _IlkMesajEkraniState();
}

class _IlkMesajEkraniState extends State<IlkMesajEkrani> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001B2E),
      appBar: AppBar(
        title: const Text("İlk Mesaj"),
        backgroundColor: const Color(0xFF001B2E),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.secretAuthorName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.secretText,
                    style: const TextStyle(color: Colors.white70, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: TextField(
                controller: _c,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  hintText: "Sır sahibine ilk mesajını yaz...",
                  filled: true,
                  fillColor: Colors.white.withAlpha(15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context, {
                  "firstMessageText": _c.text.trim(),
                }),
                child: const Text("Gönder"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
