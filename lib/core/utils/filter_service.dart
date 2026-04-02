import 'package:flutter/material.dart';

class FilterService {
  static bool isForbiddenContext(String key, String text) {
    return false;
  }
}

Future<void> uygunsuzUyariDialog(BuildContext context) async {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Uygunsuz İçerik"),
      content: const Text(
        "Lütfen topluluk kurallarına uygun bir dil kullanın.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Tamam"),
        ),
      ],
    ),
  );
}
