import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../chat/services/chat_service.dart';
import '../../chat/screens/chat_center_screen.dart';
import '../../sea/screens/sea_view_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../auth/services/auth_service.dart';

class MainScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const MainScreen({super.key, required this.user});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DenizAkisiEkrani(me: widget.user),
      SohbetMerkeziEkrani(me: widget.user),
      ProfileScreen(me: widget.user),
    ];

    final String uid =
        widget.user['uid'] ??
        widget.user['id'] ??
        fb.FirebaseAuth.instance.currentUser?.uid ??
        "";

    if (uid.isNotEmpty) {
      AuthService.updateSecurityData(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String uid =
        widget.user['uid'] ??
        widget.user['id'] ??
        fb.FirebaseAuth.instance.currentUser?.uid ??
        "";

    return Scaffold(
      backgroundColor: const Color(0xFF001B2E),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          TickerMode(enabled: _currentIndex == 0, child: _pages[0]),
          TickerMode(enabled: _currentIndex == 1, child: _pages[1]),
          TickerMode(enabled: _currentIndex == 2, child: _pages[2]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: const Color(0xFF000F1A),
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (_currentIndex == index) return;
          setState(() => _currentIndex = index);
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.waves),
            label: "Deniz",
          ),
          BottomNavigationBarItem(
            icon: StreamBuilder<int>(
              stream: ChatService.unreadConversationsCountStream(uid),
              builder: (context, unreadSnap) {
                return StreamBuilder<int>(
                  stream: ChatService.pendingRequestsCountStream(uid),
                  builder: (context, pendingSnap) {
                    final int unreadCount = unreadSnap.data ?? 0;
                    final int pendingCount = pendingSnap.data ?? 0;
                    final int total = unreadCount + pendingCount;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.chat_bubble_outline),
                        if (total > 0)
                          Positioned(
                            right: -10,
                            top: -10,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Center(
                                child: Text(
                                  total > 9 ? '9+' : '$total',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
            label: "Sohbet",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profil",
          ),
        ],
      ),
    );
  }
}
