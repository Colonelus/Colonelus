import 'package:flutter/material.dart';

Future<void> uygunsuzUyariDialog(BuildContext context) async {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF0B2235),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
          SizedBox(width: 10),
          Text("Uygunsuz İçerik", style: TextStyle(color: Colors.white)),
        ],
      ),
      content: const Text(
        "Yazdığın mesaj topluluk kurallarımıza aykırı ifadeler içeriyor olabilir. Lütfen içeriği kontrol edip tekrar dene.",
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "Tamam",
            style: TextStyle(
              color: Colors.cyanAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}
