import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../services/crab_service.dart';

class CrabWidget extends StatefulWidget {
  const CrabWidget({super.key});

  @override
  State<CrabWidget> createState() => _CrabWidgetState();
}

class _CrabWidgetState extends State<CrabWidget>
    with SingleTickerProviderStateMixin {
  bool _isClaiming = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    CrabService.checkCrabStatus();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _catchCrab() async {
    if (_isClaiming) return;
    setState(() => _isClaiming = true);
    try {
      int reward = await CrabService.claimCrab();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.yellowAccent),
                const SizedBox(width: 10),
                Text(
                  'Yakaladın! +$reward İnci',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF001B2E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: const BorderSide(color: Colors.cyanAccent),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('system')
          .doc('crab_drop')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final isActive = data['isActive'] ?? false;
        final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
        final List claimedBy = data['claimedBy'] ?? [];

        if (!isActive) return const SizedBox.shrink();
        if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
          return const SizedBox.shrink();
        }
        if (claimedBy.contains(uid)) return const SizedBox.shrink();
        if (claimedBy.length >= 10) return const SizedBox.shrink();

        return Positioned(
          bottom: 120,
          right: 20,
          child: GestureDetector(
            onTap: _catchCrab,
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A237E).withOpacity(0.8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withOpacity(0.6),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(color: Colors.cyanAccent, width: 2),
                    ),
                    child: _isClaiming
                        ? const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              color: Colors.cyanAccent,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text("🦀", style: TextStyle(fontSize: 30)),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
