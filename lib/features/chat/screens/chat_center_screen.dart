import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../services/chat_service.dart';
import 'chat_detail_screen.dart';

class SohbetMerkeziEkrani extends StatelessWidget {
  final Map<String, dynamic> me;
  const SohbetMerkeziEkrani({super.key, required this.me});

  @override
  Widget build(BuildContext context) {
    final uid = fb.FirebaseAuth.instance.currentUser!.uid;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF001B2E),
        appBar: AppBar(
          title: const Text('Sohbet'),
          backgroundColor: const Color(0xFF001B2E),
          bottom: TabBar(
            indicatorColor: Colors.cyanAccent,
            labelColor: Colors.cyanAccent,
            unselectedLabelColor: Colors.white38,
            tabs: [
              Tab(
                child: StreamBuilder<int>(
                  stream: ChatService.pendingRequestsCountStream(uid),
                  builder: (context, snap) =>
                      _buildTab(title: 'İstekler', count: snap.data ?? 0),
                ),
              ),
              Tab(
                child: StreamBuilder<int>(
                  stream: ChatService.unreadConversationsCountStream(uid),
                  builder: (context, snap) =>
                      _buildTab(title: 'Sohbetler', count: snap.data ?? 0),
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _IncomingRequestsList(uid: uid, me: me),
            _ConversationsList(uid: uid),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({required String title, required int count}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title),
        if (count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _IncomingRequestsList extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> me;
  const _IncomingRequestsList({required this.uid, required this.me});

  void _showReportOptions(
    BuildContext context,
    String requestId,
    Map<String, dynamic> r,
  ) {
    final options = ["Taciz", "Tehdit", "Uygunsuz İçerik", "Spam", "Diğer"];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF001B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Şikayet Sebebi Seçin",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              ...options.map(
                (option) => ListTile(
                  title: Text(
                    option,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await ChatService.createReport(
                      reporterId: uid,
                      reporterName: me['username'] ?? "Sırdaş",
                      targetId: r['requesterId'] ?? "",
                      targetName: r['requesterName'] ?? "Sırdaş",
                      targetType: "chat_request",
                      reason: "$option: ${r['firstMessageText']}",
                      secretId: r['secretId'],
                    );
                    await ChatService.rejectRequest(
                      requestId: requestId,
                      rejecterId: uid,
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ChatService.incomingRequestsStream(uid),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text("İstek yok.", style: TextStyle(color: Colors.white38)),
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (c, i) {
            final r = docs[i].data();
            final requestId = docs[i].id;
            return ListTile(
              title: Text(
                r['requesterName'] ?? "Sırdaş",
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                r['firstMessageText'] ?? "",
                style: const TextStyle(color: Colors.white54),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.report_problem_outlined,
                      color: Colors.orangeAccent,
                      size: 22,
                    ),
                    onPressed: () => _showReportOptions(context, requestId, r),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    onPressed: () => ChatService.rejectRequest(
                      requestId: requestId,
                      rejecterId: uid,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.cyanAccent),
                    onPressed: () async {
                      final convId = await ChatService.acceptRequest(
                        requestId: requestId,
                        accepterId: uid,
                      );
                      if (convId != null && context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SohbetEkrani(
                              convId: convId,
                              otherId: r['requesterId'],
                              otherName: r['requesterName'] ?? "Sırdaş",
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ConversationsList extends StatelessWidget {
  final String uid;
  const _ConversationsList({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ChatService.conversationsStream(uid),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text("Sohbet yok.", style: TextStyle(color: Colors.white38)),
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (c, i) {
            final d = docs[i].data();
            final members = List<String>.from(d['memberIds']);
            final otherId = members.firstWhere((id) => id != uid);
            final otherName = d['memberNames']?[otherId] ?? "Sırdaş";
            final unread = (d['unreadBy']?[uid] ?? 0) as int;

            return ListTile(
              title: Text(
                otherName,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                d['lastText'] ?? "",
                style: const TextStyle(color: Colors.white54),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: unread > 0
                  ? CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.cyanAccent,
                      child: Text(
                        "$unread",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SohbetEkrani(
                    convId: docs[i].id,
                    otherId: otherId,
                    otherName: otherName,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
