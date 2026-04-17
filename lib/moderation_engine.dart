import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum BlockReason { profanity, rateLimit }

class ModerationResult {
  final bool blocked;
  final BlockReason? reason;
  final String title;
  final String message;
  const ModerationResult(this.blocked, this.reason, this.title, this.message);
}

Future<void> moderationUyariDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  await showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text("Tamam"),
        ),
      ],
    ),
  );
}

class ContactIntentBufferEntry {
  final String text;
  final int atMs;
  ContactIntentBufferEntry(this.text, this.atMs);
}

class ModerationEngine {
  static const int _windowMs = 25000;
  static const int _maxItems = 5;
  static final Map<String, List<ContactIntentBufferEntry>> _buffer = {};

  static const List<String> _suspectKeywords = [
    'c31k',
    'tetikçi',
    'tetikci',
    'okul',
    'baskın',
    'baskin',
    'silah',
    'pompalı',
    'pompali',
    'katliam',
    'discord',
    'dc',
    'telegram',
    'tg',
    'tgram',
  ];

  static void _logIfSuspect(String text) {
    final lowerText = text.toLowerCase();
    final cleanText = _mapLeet(_stripDiacriticsTr(lowerText));

    final hasSuspect = _suspectKeywords.any(
      (word) => cleanText.contains(word) || lowerText.contains(word),
    );

    if (hasSuspect) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        FirebaseFirestore.instance
            .collection('suspect_logs')
            .add({
              'uid': uid,
              'content': text,
              'timestamp': FieldValue.serverTimestamp(),
              'isReviewed': false,
            })
            .catchError((e) => debugPrint(e.toString()));
      }
    }
  }

  static String _stripDiacriticsTr(String s) {
    return s
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c');
  }

  static String _mapLeet(String s) {
    final sb = StringBuffer();
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      switch (ch) {
        case '0':
          sb.write('o');
          break;
        case '1':
          sb.write('l');
          break;
        case '!':
          sb.write('i');
          break;
        case '|':
          sb.write('l');
          break;
        case '3':
          sb.write('e');
          break;
        case '4':
          sb.write('a');
          break;
        case '@':
          sb.write('a');
          break;
        case '5':
          sb.write('s');
          break;
        case '7':
          sb.write('t');
          break;
        case '8':
          sb.write('b');
          break;
        case '9':
          sb.write('g');
          break;
        case r'$':
          sb.write('s');
          break;
        default:
          sb.write(ch);
      }
    }
    return sb.toString();
  }

  static List<String> tokenize(String input) {
    var s = input.toLowerCase();
    s = _stripDiacriticsTr(s);
    s = _mapLeet(s);
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    final parts = s.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    return parts
        .map((t) => t.replaceAll(RegExp(r'(.)\1{2,}'), r'$1$1'))
        .toList();
  }

  static ModerationResult evaluateSingle({
    required String text,
    required bool Function(String) profanityCheck,
  }) {
    _logIfSuspect(text);

    if (profanityCheck(text)) {
      return const ModerationResult(
        true,
        BlockReason.profanity,
        "Mesaj engellendi",
        "Uygunsuz veya kırıcı içerik tespit edildi.",
      );
    }

    return const ModerationResult(false, null, "", "");
  }

  static ModerationResult evaluateWithBuffer({
    required String scope,
    required String text,
    required bool Function(String) profanityCheck,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final list = _buffer.putIfAbsent(scope, () => <ContactIntentBufferEntry>[]);
    list.removeWhere((e) => now - e.atMs > _windowMs);

    final single = evaluateSingle(text: text, profanityCheck: profanityCheck);
    if (single.blocked) {
      _buffer.remove(scope);
      return single;
    }

    list.add(ContactIntentBufferEntry(text, now));
    if (list.length > _maxItems) {
      list.removeRange(0, list.length - _maxItems);
    }
    return single;
  }

  static Future<bool> allowOrWarn(
    BuildContext context, {
    required String scope,
    required String text,
    required bool Function(String) profanityCheck,
  }) async {
    final res = evaluateWithBuffer(
      scope: scope,
      text: text,
      profanityCheck: profanityCheck,
    );
    if (!res.blocked) return true;
    if (context.mounted) {
      await moderationUyariDialog(
        context,
        title: res.title,
        message: res.message,
      );
    }
    return false;
  }
}
