class ViralShareResolution {
  final bool ok;
  final String token;
  final String ownerUid;
  final String secretId;
  final String previewText;
  final bool alreadyClaimed;
  final bool ownerIsCurrentUser;

  const ViralShareResolution({
    required this.ok,
    required this.token,
    required this.ownerUid,
    required this.secretId,
    required this.previewText,
    required this.alreadyClaimed,
    required this.ownerIsCurrentUser,
  });

  factory ViralShareResolution.fromMap(Map<dynamic, dynamic> map) {
    return ViralShareResolution(
      ok: map['ok'] == true,
      token: (map['token'] ?? '').toString(),
      ownerUid: (map['ownerUid'] ?? '').toString(),
      secretId: (map['secretId'] ?? '').toString(),
      previewText: (map['previewText'] ?? '').toString(),
      alreadyClaimed: map['alreadyClaimed'] == true,
      ownerIsCurrentUser: map['ownerIsCurrentUser'] == true,
    );
  }
}
