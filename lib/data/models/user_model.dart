// lib/data/models/user_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String rumuz;
  final bool isVip;
  final int vipLevel;
  final int inci;
  final DateTime? createdAt;
  final bool banned;
  final DateTime? suspendedUntil;

  UserModel({
    required this.uid,
    required this.rumuz,
    required this.isVip,
    required this.vipLevel,
    required this.inci,
    this.createdAt,
    required this.banned,
    this.suspendedUntil,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      rumuz: map['rumuz'] ?? '',
      isVip: map['isVip'] ?? false,
      vipLevel: map['vipLevel'] ?? 0,
      inci: map['inci'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      banned: map['banned'] ?? false,
      suspendedUntil: (map['suspendedUntil'] as Timestamp?)?.toDate(),
    );
  }
}
