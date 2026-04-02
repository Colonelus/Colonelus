import 'viral_loop_models.dart';
import 'secret_share_entry_handler.dart';

class SecretShareQualifier {
  SecretShareQualifier._();

  static Future<SecretShareQualifyResult?> onFirstCatch() {
    return SecretShareEntryHandler.qualifyIfPossible(action: 'first_catch');
  }

  static Future<SecretShareQualifyResult?> onFirstChat() {
    return SecretShareEntryHandler.qualifyIfPossible(action: 'first_chat');
  }

  static Future<SecretShareQualifyResult?> onFirstSecretShare() {
    return SecretShareEntryHandler.qualifyIfPossible(action: 'first_secret_share');
  }
}
