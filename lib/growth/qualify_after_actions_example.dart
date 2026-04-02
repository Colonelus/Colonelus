import 'secret_share_qualifier.dart';

Future<void> qualifyAfterFirstCatch() async {
  await SecretShareQualifier.onFirstCatch();
}

Future<void> qualifyAfterFirstChat() async {
  await SecretShareQualifier.onFirstChat();
}

Future<void> qualifyAfterFirstSecretShare() async {
  await SecretShareQualifier.onFirstSecretShare();
}
