import 'package:flutter/material.dart';
import '../../features/growth/services/referral_service.dart';

class InviteButton extends StatefulWidget {
  const InviteButton({super.key});

  @override
  State<InviteButton> createState() => _InviteButtonState();
}

class _InviteButtonState extends State<InviteButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final code = await ReferralService.createInviteCode();
      await ReferralService.shareInvite(code: code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _busy ? null : _run,
      child: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Arkadaşını Davet Et'),
    );
  }
}
