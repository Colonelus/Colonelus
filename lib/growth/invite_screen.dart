import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'referral_service.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key, ReferralService? service}) : _service = service;

  final ReferralService? _service;

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  late final ReferralService _service;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service = widget._service ?? ReferralService();
    _prime();
  }

  Future<void> _prime() async {
    try {
      await _service.ensureInviteCode();
    } catch (_) {}
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final text = await _service.buildShareText();
      await Share.share(text);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Davet kodu kopyalandı')),
    );
  }

  String _statusText(String status) {
    switch (status) {
      case 'qualified':
        return 'Aktif oldu';
      case 'rewarded':
        return 'Ödül verildi';
      default:
        return 'Bekliyor';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arkadaşını davet et')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _service.watchMyUser(),
        builder: (context, userSnapshot) {
          final userData = userSnapshot.data?.data() ?? <String, dynamic>{};
          final inviteCode = ((userData['inviteCode'] ?? '') as String).trim();
          final bonusCatches = ((userData['entitlements'] is Map
                      ? (userData['entitlements'] as Map)['referralBonusCatches']
                      : 0) ??
                  0)
              .toString();
          final qualifiedCount = ((userData['growth'] is Map &&
                      (userData['growth'] as Map)['referrals'] is Map
                  ? ((userData['growth'] as Map)['referrals'] as Map)
                      ['qualifiedInvites']
                  : 0) ??
              0)
              .toString();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Davet kodun',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            inviteCode.isEmpty ? 'Hazırlanıyor...' : inviteCode,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: inviteCode.isEmpty ? null : () => _copyCode(inviteCode),
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Kazanılan bonus yakalama: $bonusCatches'),
                    const SizedBox(height: 4),
                    Text('Aktif olan davet: $qualifiedCount'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _share,
                        child: const Text('Davet paylaş'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Davet geçmişi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _service.watchMyReferrals(),
                builder: (context, referralSnapshot) {
                  if (referralSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ));
                  }
                  final docs = referralSnapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      child: const Text('Henüz davet hareketi yok'),
                    );
                  }
                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data();
                      final inviteeUid = ((data['inviteeUid'] ?? '') as String).trim();
                      final status = ((data['status'] ?? 'pending') as String).trim();
                      final createdAt = data['createdAt'];
                      final dt = createdAt is Timestamp ? createdAt.toDate() : null;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(child: Icon(Icons.person_add_alt_1_rounded)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    inviteeUid.isEmpty ? 'Yeni kullanıcı' : inviteeUid,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(_statusText(status)),
                                  if (dt != null) ...[
                                    const SizedBox(height: 2),
                                    Text('${dt.day}.${dt.month}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
