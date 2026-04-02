import 'package:cloud_functions/cloud_functions.dart';

class AdminUserActionsService {
  AdminUserActionsService._();

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  static HttpsCallable get _setBan => _functions.httpsCallable('adminSetBan');
  static HttpsCallable get _setVip => _functions.httpsCallable('adminSetVip');
  static HttpsCallable get _setCoins =>
      _functions.httpsCallable('adminSetCoins');

  static Future<void> setBan({
    required String uid,
    String? bannedUntil,
  }) async {
    await _setBan.call({
      'uid': uid,
      'bannedUntil': bannedUntil,
    });
  }

  static Future<void> setVip({
    required String uid,
    required String vipUntil,
  }) async {
    await _setVip.call({
      'uid': uid,
      'isVip': true,
      'vipUntil': vipUntil,
    });
  }

  static Future<void> removeVip({
    required String uid,
  }) async {
    await _setVip.call({
      'uid': uid,
      'isVip': false,
      'vipUntil': null,
    });
  }

  static Future<void> setCoins({
    required String uid,
    required int coins,
  }) async {
    await _setCoins.call({
      'uid': uid,
      'coins': coins,
    });
  }
}
