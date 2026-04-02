import 'package:flutter/material.dart';
import '../../chat/screens/chat_center_screen.dart';
import '../../sea/screens/sea_view_screen.dart';
import '../../profile/screens/profile_screen.dart';

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
  }

  @override
  Widget build(BuildContext context) {
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.waves), label: "Deniz"),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: "Mesajlar",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profil",
          ),
        ],
      ),
    );
  }
}
