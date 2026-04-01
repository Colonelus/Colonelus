import 'package:flutter/widgets.dart';

import 'secret_share_bootstrap.dart';
import 'secret_share_gate.dart';

class SecretShareBootstrapCallExample extends StatefulWidget {
  final Widget child;

  const SecretShareBootstrapCallExample({
    super.key,
    required this.child,
  });

  @override
  State<SecretShareBootstrapCallExample> createState() => _SecretShareBootstrapCallExampleState();
}

class _SecretShareBootstrapCallExampleState extends State<SecretShareBootstrapCallExample> {
  @override
  void initState() {
    super.initState();
    SecretShareBootstrap.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    return SecretShareGate(
      child: widget.child,
    );
  }
}
