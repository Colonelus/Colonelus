import 'package:flutter/material.dart';
import '../services/admin_user_actions_service.dart';

class AdminUserActionsPanel extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onUpdated;

  const AdminUserActionsPanel({
    super.key,
    required this.user,
    this.onUpdated,
  });

  @override
  State<AdminUserActionsPanel> createState() => _AdminUserActionsPanelState();
}

class _AdminUserActionsPanelState extends State<AdminUserActionsPanel> {
  bool _busy = false;

  String get _uid => (widget.user['uid'] ?? '').toString();
  String get _name {
    final displayName = widget.user['displayName']?.toString() ?? '';
    final email = widget.user['email']?.toString() ?? '';
    if (displayName.isNotEmpty) return displayName;
    if (email.isNotEmpty) return email;
    return _uid;
  }

  Future<void> _run(Future<void> Function() task, String successText) async {
    if (_busy || _uid.isEmpty) return;
    setState(() => _busy = true);
    try {
      await task();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successText)),
      );
      widget.onUpdated?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _ban30Days() async {
    final until =
        DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String();
    await _run(
      () => AdminUserActionsService.setBan(uid: _uid, bannedUntil: until),
      'Kullanıcı 30 gün banlandı',
    );
  }

  Future<void> _unban() async {
    await _run(
      () => AdminUserActionsService.setBan(uid: _uid, bannedUntil: null),
      'Ban kaldırıldı',
    );
  }

  Future<void> _vip30Days() async {
    final until =
        DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String();
    await _run(
      () => AdminUserActionsService.setVip(uid: _uid, vipUntil: until),
      '30 günlük VIP verildi',
    );
  }

  Future<void> _removeVip() async {
    await _run(
      () => AdminUserActionsService.removeVip(uid: _uid),
      'VIP kaldırıldı',
    );
  }

  Future<void> _editCoins() async {
    final controller = TextEditingController(
      text: (widget.user['coins'] ?? 0).toString(),
    );

    final value = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Coin Güncelle'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Yeni coin değeri',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed == null || parsed < 0) return;
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (value == null) return;

    await _run(
      () => AdminUserActionsService.setCoins(uid: _uid, coins: value),
      'Coin güncellendi',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            SelectableText('UID: $_uid'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy ? null : _ban30Days,
                  child: const Text('30 Gün Ban'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _unban,
                  child: const Text('Unban'),
                ),
                FilledButton(
                  onPressed: _busy ? null : _vip30Days,
                  child: const Text('30 Gün VIP'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _removeVip,
                  child: const Text('VIP Kaldır'),
                ),
                FilledButton(
                  onPressed: _busy ? null : _editCoins,
                  child: const Text('Coin Düzenle'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
