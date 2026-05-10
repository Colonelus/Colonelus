import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../../auth/services/auth_profile_service.dart';
import '../../chat/services/chat_service.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> me;
  const ProfileScreen({super.key, required this.me});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;

  Future<void> _logout() async {
    setState(() => _busy = true);
    await GoogleSignIn().signOut();
    await fb.FirebaseAuth.instance.signOut();
    if (mounted) Navigator.of(context).pushReplacementNamed('/auth');
  }

  Future<void> _deleteAccount() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      await AuthProfileService.deleteAccountAndData(user.uid);
      await user.delete();
      await GoogleSignIn().signOut();
      if (mounted) Navigator.of(context).pushReplacementNamed('/auth');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rumuz = (widget.me['rumuz'] as String?) ?? "sırdaş";
    final isVip = (widget.me['isVip'] as bool?) ?? false;
    final inci = (widget.me['inci'] as int?) ?? 0;
    final myId = widget.me['uid'] ?? fb.FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Profil"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white10,
              child: Icon(Icons.person, size: 40, color: Colors.cyanAccent),
            ),
            const SizedBox(height: 16),
            Text(
              rumuz,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              isVip ? "VIP Sırdaş" : "Standart Üye",
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stat("Bakiye", "$inci", Icons.auto_awesome),
                const SizedBox(width: 16),
                _stat("Durum", isVip ? "VIP" : "STD", Icons.verified),
              ],
            ),
            const SizedBox(height: 30),
            Container(
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EngellenenlerEkrani(myId: myId),
                        ),
                      );
                    },
                    leading: const Icon(Icons.person_off_outlined, color: Colors.redAccent),
                    title: const Text("Engellenen Sırdaşlar"),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const InviteScreen()),
                      );
                    },
                    leading: const Icon(Icons.person_add_alt_1, color: Colors.cyanAccent),
                    title: const Text("Sırdaş Davet Et"),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _busy ? null : _logout,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: const Text("Çıkış Yap"),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _busy ? null : _deleteAccount,
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text("Hesabı Sil"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String t, String v, IconData i) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(i, color: Colors.cyanAccent, size: 20),
            const SizedBox(height: 8),
            Text(
              v,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(t, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      );
}

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  String _inviteCode = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInviteCode();
  }

  Future<void> _loadInviteCode() async {
    final code = await ReferralService.createInviteCode();
    if (mounted) setState(() { _inviteCode = code; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001B2E),
      appBar: AppBar(title: const Text('Sırdaş Davet Et'), backgroundColor: Colors.transparent),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stars_rounded, size: 80, color: Colors.cyanAccent),
                  const SizedBox(height: 24),
                  const Text('Arkadaşını davet et,\n3 gün VIP kazan!', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_inviteCode, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4, color: Colors.cyanAccent)),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.white70),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _inviteCode));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kod kopyalandı!')));
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () => ReferralService.shareInvite(code: _inviteCode),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('ARKADAŞLARINLA PAYLAŞ', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class ReferralService {
  static Future<String> createInviteCode() async {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return '';
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists && doc.data()?['inviteCode'] != null) return doc.data()!['inviteCode'].toString();
    final code = List.generate(6, (i) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[Random().nextInt(31)]).join();
    await FirebaseFirestore.instance.collection('users').doc(uid).set({'inviteCode': code}, SetOptions(merge: true));
    return code;
  }

  static Future<String> claimInviteCode(String code) async {
    final myUid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return "Giriş yapmalısın.";
    final deviceId = Platform.isIOS ? (await DeviceInfoPlugin().iosInfo).identifierForVendor : (await DeviceInfoPlugin().androidInfo).id;
    if (deviceId == null) return "Cihaz hatası.";
    final deviceRef = FirebaseFirestore.instance.collection('used_devices').doc(deviceId);
    if ((await deviceRef.get()).exists) return "Bu cihaz zaten ödül almış.";
    final query = await FirebaseFirestore.instance.collection('users').where('inviteCode', isEqualTo: code.trim().toUpperCase()).limit(1).get();
    if (query.docs.isEmpty) return "Geçersiz kod.";
    final referrer = query.docs.first;
    if (referrer.id == myUid) return "Kendi kodun olmaz.";
    await FirebaseFirestore.instance.runTransaction((t) async {
      t.set(deviceRef, {'usedBy': myUid, 'at': FieldValue.serverTimestamp()});
      DateTime now = DateTime.now();
      DateTime currentVip = (referrer.data()['vipUntil'] as Timestamp?)?.toDate() ?? now;
      t.update(referrer.reference, {'isVip': true, 'vipUntil': Timestamp.fromDate((currentVip.isAfter(now) ? currentVip : now).add(const Duration(days: 3))), 'totalInvites': FieldValue.increment(1)});
    });
    return "Başarılı!";
  }

  static Future<void> shareInvite({required String code}) async {
    await Share.share('Sırdaş uygulamasına gel, dertlerini denize sal. Davet kodum: $code https://sirdas-20e97.web.app/?code=$code');
  }
}

class EngellenenlerEkrani extends StatelessWidget {
  final String myId;
  const EngellenenlerEkrani({super.key, required this.myId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001B2E),
      appBar: AppBar(
        title: const Text("Engellenenler"),
        backgroundColor: const Color(0xFF001B2E),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ChatService.blockedUsersFullStream(myId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text("Henüz kimseyi engellemedin.", style: TextStyle(color: Colors.white54)));
          return ListView.separated(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(color: Colors.white10),
            itemBuilder: (context, i) {
              final data = docs[i].data();
              return ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.person_off, color: Colors.redAccent, size: 20)),
                title: Text(data['otherName'] ?? "sırdaş"),
                trailing: TextButton(
                  onPressed: () async => await ChatService.unblockUser(ownerId: myId, otherId: data['otherId'] ?? ""),
                  child: const Text("KALDIR", style: TextStyle(color: Colors.cyanAccent)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}