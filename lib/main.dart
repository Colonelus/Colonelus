import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

import 'features/auth/screens/login_screen.dart';
import 'features/sea/screens/sea_view_screen.dart';
import 'features/sea/screens/write_secret_screen.dart';
import 'features/chat/screens/chat_center_screen.dart';
import 'features/market/screens/market_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/auth/services/auth_profile_service.dart';
import 'shared/widgets/sea_background.dart';
import 'features/market/services/revenue_cat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await RevenueCatService.init();
  runApp(const SirdasApp());
}

class SirdasApp extends StatelessWidget {
  const SirdasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF001B2E),
      ),
      home: StreamBuilder<fb.User?>(
        stream: fb.FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            return const AnaSayfa();
          }
          return const AuthEkrani();
        },
      ),
    );
  }
}

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  int _seciliSayfa = 0;

  @override
  Widget build(BuildContext context) {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return const AuthEkrani();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: AuthProfileService.meStream(user.uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final me = snap.data?.data();
        if (me == null) {
          return const Scaffold(
            body: Center(child: Text("Profil yükleniyor...")),
          );
        }

        final bool isBanned = me['banned'] == true;
        final Timestamp? suspendedUntil = me['suspendedUntil'] as Timestamp?;
        final bool isSuspended =
            suspendedUntil != null &&
            suspendedUntil.toDate().isAfter(DateTime.now());

        if (isBanned || isSuspended) {
          return CezaEkrani(
            isBanned: isBanned,
            suspendedUntil: suspendedUntil?.toDate(),
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              const DenizArkaPlani(),
              IndexedStack(
                index: _seciliSayfa,
                children: [
                  DenizAkisiEkrani(me: me),
                  YazmaEkrani(me: me),
                  SohbetMerkeziEkrani(me: me),
                  MarketEkrani(me: me),
                  ProfileScreen(me: me),
                ],
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _seciliSayfa,
            onTap: (i) => setState(() => _seciliSayfa = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: const Color(0xFF001B2E),
            selectedItemColor: Colors.cyanAccent,
            unselectedItemColor: Colors.white54,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.waves), label: 'Deniz'),
              BottomNavigationBarItem(
                icon: Icon(Icons.add_circle),
                label: 'Sır Bırak',
              ),
              BottomNavigationBarItem(icon: Icon(Icons.forum), label: 'Sohbet'),
              BottomNavigationBarItem(
                icon: Icon(Icons.shopping_bag),
                label: 'Market',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profil',
              ),
            ],
          ),
        );
      },
    );
  }
}

class CezaEkrani extends StatelessWidget {
  final bool isBanned;
  final DateTime? suspendedUntil;

  const CezaEkrani({super.key, required this.isBanned, this.suspendedUntil});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.gavel, size: 80, color: Colors.redAccent),
              const SizedBox(height: 20),
              Text(
                isBanned
                    ? "Hesabın Kalıcı Olarak Kapatıldı"
                    : "Hesabın Geçici Olarak Askıya Alındı",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              if (!isBanned && suspendedUntil != null)
                Text(
                  "Erişim Tarihi: ${suspendedUntil!.day}/${suspendedUntil!.month}/${suspendedUntil!.year} ${suspendedUntil!.hour}:${suspendedUntil!.minute.toString().padLeft(2, '0')}",
                  style: const TextStyle(color: Colors.white70),
                ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => fb.FirebaseAuth.instance.signOut(),
                child: const Text("Çıkış Yap"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
