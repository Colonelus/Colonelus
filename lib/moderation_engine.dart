import 'package:flutter/material.dart';

enum BlockReason { contactHard, contactIntent, profanity, rateLimit }

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

  static const Set<String> _platformTokens = {
    'instagram',
    'insta',
    'telegram',
    'whatsapp',
    'snapchat',
    'snap',
    'discord',
  };

  static const Set<String> _shortCodes = {'ig', 'tg', 'wp', 'dc'};

  static const Set<String> _actionTokens = {
    'ekle',
    'ekleyin',
    'ekler',
    'eklerim',
    'eklesene',
    'yaz',
    'yazsana',
    'mesaj',
    'dm',
    'ozelden',
    'ozel',
    'takip',
    'takipet',
    'ulas',
    'ulasalim',
    'ulaş',
    'ulaşalım',
    'ara',
    'at',
    'atsana',
    'gonder',
    'gönder',
  };

  static const Set<String> _idTokens = {
    'id',
    'nick',
    'nickname',
    'kullanici',
    'kullaniciadi',
    'kullanıcı',
    'kullanıcıadı',
    'username',
    'user',
    'hesap',
    'hesabim',
    'hesabım',
    'hesabin',
    'hesabın',
  };

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

  static bool _hasEmail(String lower) {
    return RegExp(r'[\w\.\-]+@[\w\.\-]+\.\w+').hasMatch(lower);
  }

  static bool _hasUrlLike(String lower) {
    if (lower.contains('http://') ||
        lower.contains('https://') ||
        lower.contains('www.')) {
      return true;
    }

    if (RegExp(
      r'\b([a-z0-9-]+\.)+(com|net|org|io|gg|me|co|app|dev|site|link)\b',
    ).hasMatch(lower)) {
      return true;
    }

    if (lower.contains('t.me/') ||
        lower.contains('telegram.me/') ||
        lower.contains('wa.me/') ||
        lower.contains('chat.whatsapp.com/') ||
        lower.contains('discord.gg/')) {
      return true;
    }

    return false;
  }

  static bool _hasPhoneLike(String text) {
    final onlyNumbers = text.replaceAll(RegExp(r'[^0-9]'), '');
    return onlyNumbers.length >= 10;
  }

  static int _intentScore(String combined) {
    final tokens = tokenize(combined);
    var score = 0;

    final hasPlatform = tokens.any(_platformTokens.contains);
    final hasShort = tokens.any(_shortCodes.contains);
    final hasAction = tokens.any(_actionTokens.contains);
    final hasIdToken = tokens.any(_idTokens.contains);

    final hasAtHandle = RegExp(r'@[\w\.]{3,}').hasMatch(combined.toLowerCase());
    final hasLabelHandle = RegExp(
      r'\b(ig|insta|instagram|tg|telegram|wp|whatsapp|dc|discord)\s*[:\-]\s*[\w\.]{3,}\b',
    ).hasMatch(combined.toLowerCase());
    final hasShortThenName = RegExp(
      r'\b(ig|tg|wp|dc)\s+[\w\.]{3,}\b',
    ).hasMatch(combined.toLowerCase());
    final hasShortDigits = tokens.any((t) => RegExp(r'^\d{3,6}\$').hasMatch(t));

    if (hasPlatform) score += 2;
    if (hasShort) score += 1;
    if (hasAction) score += 2;

    if (hasAtHandle || hasLabelHandle || hasIdToken || hasShortThenName) {
      score += 3;
    } else if (hasShortDigits) {
      score += 2;
    }

    final anchor = hasPlatform || hasShort;
    final intent = hasAction || hasAtHandle || hasLabelHandle || hasIdToken;
    if (anchor && intent) score += 2;

    return score;
  }

  static ModerationResult evaluateSingle({
    required String text,
    required bool Function(String) profanityCheck,
  }) {
    final lower = _stripDiacriticsTr(text.toLowerCase());

    if (_hasPhoneLike(text) || _hasEmail(lower) || _hasUrlLike(lower)) {
      return const ModerationResult(
        true,
        BlockReason.contactHard,
        "Paylaşım engellendi",
        "İletişim bilgisi veya bağlantı tespit edildi. Sohbeti uygulama içinde tutmalısın.",
      );
    }

    if (profanityCheck(text)) {
      return const ModerationResult(
        true,
        BlockReason.profanity,
        "Mesaj engellendi",
        "Uygunsuz veya kırıcı içerik tespit edildi.",
      );
    }

    final score = _intentScore(text);
    if (score >= 4) {
      return const ModerationResult(
        true,
        BlockReason.contactIntent,
        "Mesaj gönderilemedi",
        "Başka platformlara yönlendirme algılandı. Güvenlik nedeniyle bu mesaj iletilemedi.",
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

    if (list.isEmpty) {
      list.add(ContactIntentBufferEntry(text, now));
      return single;
    }

    final combined = [...list.map((e) => e.text), text].join(' ').trim();
    final lowerCombined = _stripDiacriticsTr(combined.toLowerCase());

    if (_hasPhoneLike(combined) ||
        _hasEmail(lowerCombined) ||
        _hasUrlLike(lowerCombined)) {
      _buffer.remove(scope);
      return const ModerationResult(
        true,
        BlockReason.contactHard,
        "Paylaşım engellendi",
        "İletişim bilgisi veya bağlantı tespit edildi. Sohbeti uygulama içinde tutmalısın.",
      );
    }

    final score = _intentScore(combined);
    if (score >= 4) {
      _buffer.remove(scope);
      return const ModerationResult(
        true,
        BlockReason.contactIntent,
        "Mesaj gönderilemedi",
        "Başka platformlara yönlendirme algılandı. Güvenlik nedeniyle bu mesaj iletilemedi.",
      );
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
