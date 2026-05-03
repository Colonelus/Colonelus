import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static String generateSirdasNick() {
    const String chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final Random random = Random();
    final String randomPart = List.generate(
      9,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
    return 'sırdaş-$randomPart';
  }

  static Future<Map<String, String>> getSecurityData() async {
    String ip = "Bilinmiyor";
    String deviceId = "Bilinmiyor";
    String deviceModel = "Bilinmiyor";

    try {
      final ipResponse = await http.get(Uri.parse('https://api.ipify.org'));
      if (ipResponse.statusCode == 200) {
        ip = ipResponse.body;
      }
    } catch (_) {}

    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceModel = "${androidInfo.brand} ${androidInfo.model}";
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? "Bilinmiyor";
        deviceModel = iosInfo.utsname.machine;
      }
    } catch (_) {}

    return {"ipAddress": ip, "deviceId": deviceId, "deviceModel": deviceModel};
  }

  static Future<void> updateSecurityData(String uid) async {
    final data = await getSecurityData();
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'securityData': {
        'ipAddress': data['ipAddress'],
        'deviceId': data['deviceId'],
        'deviceModel': data['deviceModel'],
        'lastActiveAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      final securityData = await getSecurityData();

      if (userCredential.additionalUserInfo?.isNewUser == true) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'uid': userCredential.user!.uid,
              'email': userCredential.user!.email,
              'rumuz': generateSirdasNick(),
              'inci': 100,
              'isVip': false,
              'createdAt': FieldValue.serverTimestamp(),
              'securityData': {
                'ipAddress': securityData['ipAddress'],
                'deviceId': securityData['deviceId'],
                'deviceModel': securityData['deviceModel'],
                'recordedAt': FieldValue.serverTimestamp(),
              },
            });
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({
              'securityData': {
                'ipAddress': securityData['ipAddress'],
                'deviceId': securityData['deviceId'],
                'deviceModel': securityData['deviceModel'],
                'recordedAt': FieldValue.serverTimestamp(),
              },
            });
      }

      return userCredential;
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      return null;
    }
  }
}