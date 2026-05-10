import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

class ReferralService {
  ReferralService._();

  static Future<String> createInviteCode() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return '';

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    
    if (doc.exists && doc.data()?['inviteCode'] != null) {
      return doc.data()!['inviteCode'].toString();
    }

    final code = _generateCode();
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'inviteCode': code},
      SetOptions(merge: true),
    );
    return code;
  }

  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  static Future<String> claimInviteCode(String code) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return "Giriş yapmalısın.";

    final deviceId = await _getDeviceId();
    if (deviceId == null) return "Cihaz kimliği doğrulanamadı.";

    final deviceRef = FirebaseFirestore.instance.collection('used_devices').doc(deviceId);
    final deviceDoc = await deviceRef.get();

    if (deviceDoc.exists) {
      return "Bu cihaz daha önce bir davet koduyla ödül almış.";
    }

    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('inviteCode', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return "Geçersiz davet kodu.";
    
    final referrer = query.docs.first;
    if (referrer.id == myUid) return "Kendi kodunu kullanamazsın.";

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.set(deviceRef, {
          'usedBy': myUid,
          'at': FieldValue.serverTimestamp(),
        });

        final data = referrer.data();
        DateTime currentVipUntil = (data['vipUntil'] as Timestamp?)?.toDate() ?? DateTime.now();
        DateTime baseDate = currentVipUntil.isAfter(DateTime.now()) ? currentVipUntil : DateTime.now();
        DateTime newVipUntil = baseDate.add(const Duration(days: 3));

        transaction.update(referrer.reference, {
          'isVip': true,
          'vipUntil': Timestamp.fromDate(newVipUntil),
          'totalInvites': FieldValue.increment(1),
        });
      });
      return "Başarılı! Arkadaşına 3 gün VIP kazandırdın.";
    } catch (e) {
      return "İşlem sırasında hata oluştu.";
    }
  }

  static Future<void> shareInvite({required String code}) async {
    await Share.share('Sırdaş uygulamasına gel, dertlerini denize sal. Davet kodum: $code');
  }

  static Future<String?> _getDeviceId() async {
    var info = DeviceInfoPlugin();
    if (Platform.isIOS) return (await info.iosInfo).identifierForVendor;
    if (Platform.isAndroid) return (await info.androidInfo).id;
    return null;
  }
}