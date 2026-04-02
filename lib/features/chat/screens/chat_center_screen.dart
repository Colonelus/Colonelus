import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:intl/intl.dart';
import '../services/chat_service.dart';
import 'chat_detail_screen.dart';
import '../../../core/constants/app_enums.dart';

class SohbetMerkeziEkrani extends StatelessWidget {
  final Map<String, dynamic> me;
  const SohbetMerkeziEkrani({super.key, required this.me});

  @override
  Widget build(BuildContext context) {
    final uid = fb.FirebaseAuth.instance.currentUser!.uid;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Sohbet'),
          backgroundColor: Colors.transparent,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'İstekler'),
              Tab(text: 'Sohbetler'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ChatService.incomingRequestsStream(uid),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (c, i) {
                    final r = docs[i].data();
                    return ListTile(
                      title: Text(r['requesterName'] ?? "Sırdaş"),
                      subtitle: Text(r['firstMessageText'] ?? ""),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          final convId = await ChatService.acceptRequest(
                            requestId: docs[i].id,
                            accepterId: uid,
                          );
                          if (convId != null && context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SohbetEkrani(
                                  convId: convId,
                                  otherId: r['requesterId'],
                                  otherName: r['requesterName'],
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text("Kabul Et"),
                      ),
                    );
                  },
                );
              },
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ChatService.conversationsStream(uid),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (c, i) {
                    final d = docs[i].data();
                    final members = List<String>.from(d['memberIds']);
                    final otherId = members.firstWhere((id) => id != uid);
                    return ListTile(
                      title: Text(d['memberNames'][otherId] ?? "Sırdaş"),
                      subtitle: Text(d['lastText'] ?? ""),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SohbetEkrani(
                            convId: docs[i].id,
                            otherId: otherId,
                            otherName: d['memberNames'][otherId],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
