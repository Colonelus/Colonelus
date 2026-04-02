import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../../../core/constants/app_enums.dart';

class RequestsScreen extends StatelessWidget {
  final String uid;
  const RequestsScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Colors.cyanAccent,
            labelColor: Colors.cyanAccent,
            unselectedLabelColor: Colors.white38,
            tabs: [
              Tab(text: "Gelenler"),
              Tab(text: "Gidenler"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _RequestList(uid: uid, isIncoming: true),
                _RequestList(uid: uid, isIncoming: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  final String uid;
  final bool isIncoming;
  const _RequestList({required this.uid, required this.isIncoming});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: isIncoming
          ? ChatService.incomingRequestsStream(uid)
          : ChatService.outgoingRequestsStream(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.cyanAccent),
          );
        }
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "Henüz bir istek yok.",
              style: TextStyle(color: Colors.white38),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text(
                  isIncoming
                      ? (data['requesterName'] ?? "Sırdaş")
                      : (data['secretAuthorName'] ?? "Sırdaş"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  data['firstMessageText'] ?? "",
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                trailing: _buildActions(doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActions(String requestId, Map<String, dynamic> data) {
    final status = data['status'];

    if (status != RequestStatus.pending.name) {
      return Text(
        status == RequestStatus.accepted.name ? "KABUL EDİLDİ" : "REDDEDİLDİ",
        style: TextStyle(
          color: status == RequestStatus.accepted.name
              ? Colors.greenAccent
              : Colors.redAccent,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (isIncoming) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
            onPressed: () => ChatService.acceptRequest(
              requestId: requestId,
              accepterId: uid,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.redAccent),
            onPressed: () => ChatService.rejectRequest(
              requestId: requestId,
              rejecterId: uid,
            ),
          ),
        ],
      );
    } else {
      return TextButton(
        onPressed: () => FirebaseFirestore.instance
            .collection('chat_requests')
            .doc(requestId)
            .delete(),
        child: const Text(
          "İPTAL ET",
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      );
    }
  }
}
