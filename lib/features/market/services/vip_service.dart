import 'package:cloud_firestore/cloud_firestore.dart';

class VipService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> activateVip(String uid, String productId) async {
    int days = (productId == 'vip-week')
        ? 7
        : (productId == 'vip-month' ? 30 : 90);
    final expireDate = DateTime.now().add(Duration(days: days));

    await _db.collection('users').doc(uid).update({
      'isVip': true,
      'vipUntil': Timestamp.fromDate(expireDate),
      'vipType': productId,
    });
  }
}
