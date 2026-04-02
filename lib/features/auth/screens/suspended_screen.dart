import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../shared/widgets/sea_background.dart';

class AskidaEkrani extends StatelessWidget {
  final DateTime? until;
  const AskidaEkrani({super.key, this.until});

  @override
  Widget build(BuildContext context) {
    final msg = until == null
        ? "Hesabınız askıya alındı."
        : "Hesabınız ${until!.day}.${until!.month}.${until!.year} tarihine kadar askıya alındı.";
    return Scaffold(
      body: Stack(
        children: [
          const DenizArkaPlani(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "SIRDAŞ",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 16),
                Text(msg, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => fb.FirebaseAuth.instance.signOut(),
                  child: const Text("Çıkış Yap"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
