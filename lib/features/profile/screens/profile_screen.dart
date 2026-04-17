import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rumuz = (widget.me['rumuz'] as String?) ?? "sırdaş";
    final isVip = (widget.me['isVip'] as bool?) ?? false;
    final inci = (widget.me['inci'] as int?) ?? 0;
    final myId =
        widget.me['uid'] ?? fb.FirebaseAuth.instance.currentUser?.uid ?? "";

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
                    leading: const Icon(
                      Icons.person_off_outlined,
                      color: Colors.redAccent,
                    ),
                    title: const Text("Engellenen Sırdaşlar"),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white24,
                    ),
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
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "Henüz kimseyi engellemedin.",
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            separatorBuilder: (context, index) =>
                const Divider(color: Colors.white10),
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final String otherId = data['otherId'] ?? "";
              final String otherName = data['otherName'] ?? "sırdaş";

              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.white10,
                  child: Icon(
                    Icons.person_off,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                ),
                title: Text(otherName),
                trailing: TextButton(
                  onPressed: () async {
                    await ChatService.unblockUser(
                      ownerId: myId,
                      otherId: otherId,
                    );
                  },
                  child: const Text(
                    "KALDIR",
                    style: TextStyle(color: Colors.cyanAccent),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
