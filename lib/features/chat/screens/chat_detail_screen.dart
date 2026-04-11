import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:intl/intl.dart';
import '../services/chat_service.dart';
import '../../../core/utils/filter_service.dart';
import '../../../core/utils/rate_limiter.dart';

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

  @override
  Widget build(BuildContext context) {
    final meId = fb.FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      backgroundColor: const Color(0xFF001B2E),
      appBar: AppBar(
        title: Text(widget.otherName),
        backgroundColor: const Color(0xFF001B2E),
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
                        child: Text(m['text'] ?? ""),
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
                    decoration: const InputDecoration(hintText: "Mesaj..."),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final t = _c.text.trim();
                    if (t.isEmpty) return;
                    await ChatService.sendMessage(
                      convId: widget.convId,
                      senderId: meId,
                      text: t,
                    );
                    _c.clear();
                  },
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
