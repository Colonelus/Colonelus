import 'secret_share_entry_handler.dart';

Future<void> claimPendingSecretShareAfterLogin() async {
  await SecretShareEntryHandler.claimIfPossible();
}
