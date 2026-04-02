import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../services/secret_interaction_service.dart';
import '../../../core/utils/filter_service.dart';
import '../../../core/utils/rate_limiter.dart';

class YazmaEkrani extends StatefulWidget {
  final Map<String, dynamic> me;
  const YazmaEkrani({super.key, required this.me});
  @override
  State<YazmaEkrani> createState() => _YazmaEkraniState();
}

class _YazmaEkraniState extends State<YazmaEkrani>
    with SingleTickerProviderStateMixin {
  final TextEditingController _tc = TextEditingController();
  late AnimationController _oltaController;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _oltaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _tc.dispose();
    _oltaController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final uid = fb.FirebaseAuth.instance.currentUser!.uid;
    final t = _tc.text.trim();
    if (t.isEmpty) return;
    if (FilterService.isForbiddenContext("secret_$uid", t)) {
      if (context.mounted) await uygunsuzUyariDialog(context);
      return;
    }
    if (_busy) return;
    final isVip = (widget.me['isVip'] as bool?) ?? false;
    if (!RateLimiter.allowSecret(uid, t, isVip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Çok hızlısın. Biraz bekle.")),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await SecretInteractionService.createSecret(
        uid: uid,
        rumuz: (widget.me['rumuz'] as String?) ?? "sırdaş",
        isVip: isVip,
        content: t,
      );
      _oltaController.forward(from: 0).then((_) {
        if (!mounted) return;
        _tc.clear();
        FocusScope.of(context).unfocus();
      });
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gönderilemedi.")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              ((widget.me['isVip'] as bool?) ?? false)
                  ? "VIP Sırrını Yaz"
                  : "Sırrını Yaz",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _tc,
              maxLines: 5,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white10,
                hintText: "Denize fısılda...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _busy ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text("DENİZE SAL"),
              ),
            ),
          ],
        ),
      ),
      AnimatedBuilder(
        animation: _oltaController,
        builder: (context, child) => Positioned(
          bottom: 200 - (math.pow(_oltaController.value * 2 - 1, 2) * 250),
          left:
              MediaQuery.of(context).size.width / 2 +
              (_oltaController.value - 0.5) * 400 -
              20,
          child: Opacity(
            opacity: math.sin(_oltaController.value * math.pi),
            child: Icon(
              ((widget.me['isVip'] as bool?) ?? false)
                  ? Icons.directions_boat
                  : Icons.phishing,
              color: Colors.cyanAccent,
              size: 50,
            ),
          ),
        ),
      ),
    ],
  );
}
