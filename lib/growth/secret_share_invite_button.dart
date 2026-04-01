import 'package:flutter/material.dart';

import 'viral_loop_service.dart';

class SecretShareInviteButton extends StatefulWidget {
  final String secretId;
  final String? shareText;
  final Widget? child;

  const SecretShareInviteButton({
    super.key,
    required this.secretId,
    this.shareText,
    this.child,
  });

  @override
  State<SecretShareInviteButton> createState() => _SecretShareInviteButtonState();
}

class _SecretShareInviteButtonState extends State<SecretShareInviteButton> {
  bool _loading = false;

  Future<void> _share() async {
    if (_loading) return;
    setState(() {
      _loading = true;
    });
    try {
      await ViralLoopService.shareSecret(
        secretId: widget.secretId,
        textPrefix: widget.shareText ?? 'Bana anonim bir sır bırak',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.child != null) {
      return InkWell(
        onTap: _loading ? null : _share,
        child: widget.child!,
      );
    }
    return ElevatedButton(
      onPressed: _loading ? null : _share,
      child: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Sırrı Paylaş'),
    );
  }
}
