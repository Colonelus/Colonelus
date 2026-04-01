// lib/data/models/secret_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class SecretModel {
  final String id;
  final String authorId;
  final String authorName;
  final bool authorIsVip;
  final String content;
  final String tip;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final int laneIndex;
  final double xOffset;
  final double speedMul;
  final double phase;
  final String? bottleType;
  final String? parchmentType;
  final String? parchmentRarity;

  SecretModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorIsVip,
    required this.content,
    required this.tip,
    this.createdAt,
    this.expiresAt,
    required this.laneIndex,
    required this.xOffset,
    required this.speedMul,
    required this.phase,
    this.bottleType,
    this.parchmentType,
    this.parchmentRarity,
  });

  factory SecretModel.fromMap(String id, Map<String, dynamic> map) {
    return SecretModel(
      id: id,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorIsVip: map['authorIsVip'] ?? false,
      content: map['content'] ?? '',
      tip: map['tip'] ?? 'sise',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
      laneIndex: map['laneIndex'] ?? 0,
      xOffset: (map['xOffset'] as num?)?.toDouble() ?? 0.0,
      speedMul: (map['speedMul'] as num?)?.toDouble() ?? 1.0,
      phase: (map['phase'] as num?)?.toDouble() ?? 0.0,
      bottleType: map['bottleType'],
      parchmentType: map['parchmentType'] ?? map['kagitTip'],
      parchmentRarity: map['parchmentRarity'],
    );
  }
}
