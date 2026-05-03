import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../shared/widgets/bottle_widgets.dart';

Future<void> sirriYakalaDialogGoster({
  required BuildContext context,
  required String karsiKullaniciId,
  required String karsiKullaniciRumuz,
  required String sirId,
  required String sirIcerigi,
  required Map<String, dynamic> me,
}) async {
  final TextEditingController mesajController = TextEditingController();
  bool isSending = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.white24, width: 1),
            ),
            title: const Text(
              "Sırrı Yakala",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Sohbet başlatmak için dikkat çekici bir ilk mesaj gönder.",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: mesajController,
                  maxLines: 4,
                  maxLength: 150,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white10,
                    hintText: "Mesajını buraya yaz...",
                    hintStyle: const TextStyle(color: Colors.white30),
                    counterStyle: const TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              OutlinedButton(
                onPressed: isSending ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("İptal"),
              ),
              ElevatedButton(
                onPressed: isSending
                    ? null
                    : () async {
                        final mesaj = mesajController.text.trim();
                        if (mesaj.isEmpty) return;

                        setState(() => isSending = true);

                        try {
                          final uid = fb.FirebaseAuth.instance.currentUser?.uid;
                          if (uid == null) return;

                          await FirebaseFirestore.instance
                              .collection('chat_requests')
                              .add({
                                'requesterId': uid,
                                'requesterName': me['rumuz'] ?? 'Sırdaş',
                                'secretId': sirId,
                                'secretAuthorId': karsiKullaniciId,
                                'secretAuthorName': karsiKullaniciRumuz,
                                'secretSnapshotText': sirIcerigi,
                                'firstMessageText': mesaj,
                                'status': 'pending',
                                'createdAt': FieldValue.serverTimestamp(),
                                'banned': false,
                                'suspendedUntil': null,
                                'decisionAt': null,
                                'conversationId': null,
                              });

                          if (context.mounted) {
                            Navigator.pop(context);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'İstek gönderildi! Sohbet sekmesinden takip edebilirsin.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint("Hata: $e");
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('Hata: $e')));
                          }
                        } finally {
                          if (context.mounted) {
                            setState(() => isSending = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Gönder",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}

class SecretRevealDialog extends StatefulWidget {
  final String author;
  final String content;
  final bool isVip;
  final String bottleType;
  final String parchmentType;
  final String parchmentRarity;
  final String meId;
  final String authorId;
  final Map<String, dynamic> secret;
  final Map<String, dynamic> me;
  final Future<void> Function() onSink;

  const SecretRevealDialog({
    super.key,
    required this.author,
    required this.content,
    required this.isVip,
    required this.bottleType,
    required this.parchmentType,
    required this.parchmentRarity,
    required this.meId,
    required this.authorId,
    required this.secret,
    required this.me,
    required this.onSink,
  });

  @override
  State<SecretRevealDialog> createState() => _SecretRevealDialogState();
}

class _SecretRevealDialogState extends State<SecretRevealDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _bottleScale;
  late final Animation<double> _bottleLift;
  late final Animation<double> _textFade;
  late final Animation<double> _textSlide;

  final String adminUid = 's9Vo2O5FnKZ7grNN3kRu7DUsN222';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2450),
    )..forward();

    _bottleScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.24, curve: Curves.easeOutBack),
      ),
    );
    _bottleLift = Tween<double>(begin: 58, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.26, curve: Curves.easeOutCubic),
      ),
    );
    _textFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.78, 1.0, curve: Curves.easeOut),
      ),
    );
    _textSlide = Tween<double>(begin: 28, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.78, 1.0, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showReportMenu() {
    final List<String> reasons = [
      'Zorbalık / Taciz',
      'Nefret Söylemi',
      'Küfür / Hakaret',
      'Cinsel İçerik',
      'Spam / Yanıltıcı',
      'Diğer',
    ];

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Neden Rapor Ediyorsunuz?'),
        backgroundColor: const Color(0xFF1E293B),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        children: reasons.map((reason) {
          return SimpleDialogOption(
            onPressed: () => _sendReport(reason),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                reason,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _sendReport(String reason) async {
    Navigator.pop(context);

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'reportedAt': FieldValue.serverTimestamp(),
        'reporterId': widget.meId,
        'authorId': widget.authorId,
        'secretId': widget.secret['id'],
        'content': widget.content,
        'reason': reason,
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Raporunuz iletildi.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B2235),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withAlpha(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.author,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: _showReportMenu,
                  icon: const Icon(
                    Icons.report_gmailerrorred,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => SizedBox(
                height: 380,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned(
                      left: 10,
                      right: 10,
                      top: 0,
                      bottom: 100,
                      child: Opacity(
                        opacity: _textFade.value,
                        child: Transform.translate(
                          offset: Offset(0, _textSlide.value),
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                widget.content,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: Transform.translate(
                        offset: Offset(0, _bottleLift.value),
                        child: Transform.scale(
                          scale: _bottleScale.value,
                          child: SizedBox(
                            width: 120,
                            height: 160,
                            child: AppBottleWidget(
                              type: widget.authorId == adminUid
                                  ? 'owner_diamond'
                                  : (widget.isVip
                                        ? 'tekne'
                                        : widget.bottleType),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await widget.onSink();
                    },
                    child: const Text('Denize Göm'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.authorId == widget.meId
                        ? null
                        : () => sirriYakalaDialogGoster(
                            context: context,
                            karsiKullaniciId: widget.authorId,
                            karsiKullaniciRumuz: widget.author,
                            sirId: widget.secret['id'] ?? '',
                            sirIcerigi: widget.content,
                            me: widget.me,
                          ),
                    child: const Text('Sırrı Yakala'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
