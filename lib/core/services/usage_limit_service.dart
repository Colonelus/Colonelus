import 'package:cloud_functions/cloud_functions.dart';

class UserPlanLimits {
  final bool isVip;
  final String? vipUntil;
  final LimitBucket shareSecret;
  final LimitBucket catchSecret;

  const UserPlanLimits({
    required this.isVip,
    required this.vipUntil,
    required this.shareSecret,
    required this.catchSecret,
  });

  factory UserPlanLimits.fromMap(Map<String, dynamic> data) {
    final limits = Map<String, dynamic>.from(
      data['limits'] as Map? ?? const {},
    );
    return UserPlanLimits(
      isVip: data['isVip'] == true,
      vipUntil: data['vipUntil']?.toString(),
      shareSecret: LimitBucket.fromMap(
        Map<String, dynamic>.from(limits['shareSecret'] as Map? ?? const {}),
      ),
      catchSecret: LimitBucket.fromMap(
        Map<String, dynamic>.from(limits['catchSecret'] as Map? ?? const {}),
      ),
    );
  }
}

class LimitBucket {
  final int limit;
  final int used;
  final int remaining;
  final String? resetAt;

  const LimitBucket({
    required this.limit,
    required this.used,
    required this.remaining,
    required this.resetAt,
  });

  factory LimitBucket.fromMap(Map<String, dynamic> data) {
    return LimitBucket(
      limit: (data['limit'] as num? ?? 0).toInt(),
      used: (data['used'] as num? ?? 0).toInt(),
      remaining: (data['remaining'] as num? ?? 0).toInt(),
      resetAt: data['resetAt']?.toString(),
    );
  }
}

class UsageLimitService {
  UsageLimitService._();

  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  static HttpsCallable get _getMyLimits =>
      _functions.httpsCallable('getMyLimits');

  static HttpsCallable get _consumeShareSecret =>
      _functions.httpsCallable('consumeShareSecret');

  static HttpsCallable get _consumeCatchSecret =>
      _functions.httpsCallable('consumeCatchSecret');

  static Future<UserPlanLimits> getMyLimits() async {
    final response = await _getMyLimits.call();
    final data = Map<String, dynamic>.from(response.data as Map);
    return UserPlanLimits.fromMap(data);
  }

  static Future<UserPlanLimits> consumeShareSecret() async {
    final response = await _consumeShareSecret.call();
    final data = Map<String, dynamic>.from(response.data as Map);
    return UserPlanLimits.fromMap(data);
  }

  static Future<UserPlanLimits> consumeCatchSecret() async {
    final response = await _consumeCatchSecret.call();
    final data = Map<String, dynamic>.from(response.data as Map);
    return UserPlanLimits.fromMap(data);
  }
}
