import 'package:cloud_functions/cloud_functions.dart';
import 'package:share_plus/share_plus.dart';

class ReferralService {
  ReferralService._();

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  static Future<String> createInviteCode() async {
    final result = await _functions.httpsCallable('createInviteLink').call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return (data['code'] ?? '').toString();
  }

  static Future<bool> claimInviteCode(String code) async {
    final result = await _functions.httpsCallable('claimInvite').call({
      'code': code.trim(),
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['ok'] == true;
  }

  static Future<void> shareInvite({required String code}) async {
    await SharePlus.instance.share(
      ShareParams(text: 'Sırdaş uygulamasına gel. Davet kodum: $code'),
    );
  }
}
