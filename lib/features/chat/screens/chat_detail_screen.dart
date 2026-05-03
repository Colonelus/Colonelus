import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../services/chat_service.dart';

class SohbetEkrani extends StatefulWidget {
  final String convId;
  final String otherId;
  final String otherName;
  const SohbetEkrani({
    super.key,
    required this.convId,
    required this.otherId,
    required this.otherName,
  });
  @override
  State<SohbetEkrani> createState() => _SohbetEkraniState();
}

class _SohbetEkraniState extends State<SohbetEkrani> {
  static const MethodChannel _secure = MethodChannel('sirdas/secure');
  final TextEditingController _c = TextEditingController();
  final ScrollController _sc = ScrollController();

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) _secure.invokeMethod('enable');
    final meId = fb.FirebaseAuth.instance.currentUser?.uid;
    if (meId != null) {
      ChatService.markConversationRead(convId: widget.convId, userId: meId);
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) _secure.invokeMethod('disable');
    _c.dispose();
    _sc.dispose();
    super.dispose();
  }

  void _showReportDialog(String meId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF001B2E),
        title: const Text("Rapor Et", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children:
              [
                    'Şiddet / Tehdit',
                    'Taciz / Rahatsız Edici',
                    'Dolandırıcılık',
                    'Uygunsuz İçerik',
                  ]
                  .map(
                    (reason) => ListTile(
                      title: Text(
                        reason,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      onTap: () async {
                        await ChatService.createReport(
                          reporterId: meId,
                          reporterName: "sırdaş",
                          targetId: widget.otherId,
                          targetName: widget.otherName,
                          targetType: "chat_user",
                          reason: reason,
                          convId: widget.convId,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Raporunuz iletildi."),
                          ),
                        );
                      },
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }

  void _handleMenu(String val, String meId) async {
    if (val == 'delete') {
      await ChatService.deleteConversationForBothSides(widget.convId);
      if (!mounted) return;
      Navigator.pop(context);
    } else if (val == 'report') {
      _showReportDialog(meId);
    } else if (val == 'block') {
      await ChatService.blockUser(
        ownerId: meId,
        otherId: widget.otherId,
        otherName: widget.otherName,
      );
      await ChatService.deleteConversationForBothSides(widget.convId);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meId = fb.FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      backgroundColor: const Color(0xFF001B2E),
      appBar: AppBar(
        title: Text(widget.otherName),
        backgroundColor: const Color(0xFF001B2E),
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) => _handleMenu(val, meId),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'delete', child: Text('Sohbeti Sil')),
              const PopupMenuItem(value: 'report', child: Text('Raporla')),
              const PopupMenuItem(value: 'block', child: Text('Engelle')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ChatService.messagesStream(widget.convId),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                final msgs = docs.map((d) => d.data()).toList();
                return ListView.builder(
                  controller: _sc,
                  reverse: true,
                  itemCount: msgs.length,
                  itemBuilder: (c, i) {
                    final m = msgs[i];
                    final isMe = m['senderId'] == meId;
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.cyan[800] : Colors.blueGrey[800],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          m['text'] ?? "",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _c,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Mesaj...",
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final t = _c.text.trim();
                    if (t.isEmpty) return;
                    _c.clear();
                    await ChatService.sendMessage(
                      convId: widget.convId,
                      senderId: meId,
                      text: t,
                    );
                  },
                  icon: const Icon(Icons.send, color: Colors.cyanAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}