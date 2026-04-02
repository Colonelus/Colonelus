import 'package:flutter/foundation.dart';

@immutable
class SecretShareLinkResult {
  final String shareId;
  final String url;
  final String ownerUid;
  final String secretId;

  const SecretShareLinkResult({
    required this.shareId,
    required this.url,
    required this.ownerUid,
    required this.secretId,
  });

  factory SecretShareLinkResult.fromMap(Map<String, dynamic> map) {
    return SecretShareLinkResult(
      shareId: (map['shareId'] ?? '').toString(),
      url: (map['url'] ?? '').toString(),
      ownerUid: (map['ownerUid'] ?? '').toString(),
      secretId: (map['secretId'] ?? '').toString(),
    );
  }
}

@immutable
class SecretShareResolveResult {
  final bool ok;
  final String shareId;
  final String ownerUid;
  final String secretId;
  final String deepLink;
  final bool alreadyClaimed;

  const SecretShareResolveResult({
    required this.ok,
    required this.shareId,
    required this.ownerUid,
    required this.secretId,
    required this.deepLink,
    required this.alreadyClaimed,
  });

  factory SecretShareResolveResult.fromMap(Map<String, dynamic> map) {
    return SecretShareResolveResult(
      ok: map['ok'] == true,
      shareId: (map['shareId'] ?? '').toString(),
      ownerUid: (map['ownerUid'] ?? '').toString(),
      secretId: (map['secretId'] ?? '').toString(),
      deepLink: (map['deepLink'] ?? '').toString(),
      alreadyClaimed: map['alreadyClaimed'] == true,
    );
  }
}

@immutable
class SecretShareClaimResult {
  final bool ok;
  final bool claimed;
  final String shareId;

  const SecretShareClaimResult({
    required this.ok,
    required this.claimed,
    required this.shareId,
  });

  factory SecretShareClaimResult.fromMap(Map<String, dynamic> map) {
    return SecretShareClaimResult(
      ok: map['ok'] == true,
      claimed: map['claimed'] == true,
      shareId: (map['shareId'] ?? '').toString(),
    );
  }
}

@immutable
class SecretShareQualifyResult {
  final bool ok;
  final bool rewarded;
  final String shareId;
  final String rewardType;
  final int rewardAmount;

  const SecretShareQualifyResult({
    required this.ok,
    required this.rewarded,
    required this.shareId,
    required this.rewardType,
    required this.rewardAmount,
  });

  factory SecretShareQualifyResult.fromMap(Map<String, dynamic> map) {
    return SecretShareQualifyResult(
      ok: map['ok'] == true,
      rewarded: map['rewarded'] == true,
      shareId: (map['shareId'] ?? '').toString(),
      rewardType: (map['rewardType'] ?? '').toString(),
      rewardAmount: (map['rewardAmount'] ?? 0) is int
          ? (map['rewardAmount'] ?? 0) as int
          : int.tryParse((map['rewardAmount'] ?? '0').toString()) ?? 0,
    );
  }
}
