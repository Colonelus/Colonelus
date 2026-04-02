import 'package:flutter/material.dart';

import 'secret_share_bootstrap.dart';
import 'secret_share_entry_handler.dart';
import 'viral_loop_models.dart';

class SecretShareGate extends StatefulWidget {
  final Widget child;
  final void Function(SecretShareResolveResult result)? onResolved;
  final void Function(Object error)? onError;

  const SecretShareGate({
    super.key,
    required this.child,
    this.onResolved,
    this.onError,
  });

  @override
  State<SecretShareGate> createState() => _SecretShareGateState();
}

class _SecretShareGateState extends State<SecretShareGate> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SecretShareBootstrap.instance.addListener(_consume);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consume());
  }

  @override
  void dispose() {
    SecretShareBootstrap.instance.removeListener(_consume);
    super.dispose();
  }

  Future<void> _consume() async {
    if (_busy) return;
    _busy = true;
    try {
      final result = await SecretShareEntryHandler.consumeIncomingLink();
      if (result != null && mounted) {
        widget.onResolved?.call(result);
      }
    } catch (e) {
      if (mounted) {
        widget.onError?.call(e);
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
