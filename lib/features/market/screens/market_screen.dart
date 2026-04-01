import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../services/billing_service.dart';
import '../../auth/services/auth_profile_service.dart';
import '../../../data/models/user_model.dart';

class MarketEkrani extends StatefulWidget {
  final Map<String, dynamic> me;
  const MarketEkrani({super.key, required this.me});

  @override
  State<MarketEkrani> createState() => _MarketEkraniState();
}

class _MarketEkraniState extends State<MarketEkrani> {
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    BillingService.start(
      onMessage: (message) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _status = message;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
    );
  }

  @override
  void dispose() {
    BillingService.stop();
    super.dispose();
  }

  Future<void> _handleItemTap(String id) async {
    if (_busy) return;
    // Satın alma ve ürün seçme mantığı buraya gelecek
  }

  @override
  Widget build(BuildContext context) {
    final inci = (widget.me['inci'] as int?) ?? 0;
    final isVip = (widget.me['isVip'] as bool?) ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/market_mock.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Positioned(
                      left: constraints.maxWidth * 0.085,
                      top: constraints.maxHeight * 0.035,
                      child: Text(
                        '$inci',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_busy) const Center(child: CircularProgressIndicator()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
