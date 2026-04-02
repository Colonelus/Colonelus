import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class SecretShareBootstrap extends ChangeNotifier {
  SecretShareBootstrap._();

  static final SecretShareBootstrap instance = SecretShareBootstrap._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  Uri? _pendingUri;
  bool _started = false;

  Uri? get pendingUri => _pendingUri;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      _pendingUri = initial;
      notifyListeners();
    }
    _subscription = _appLinks.uriLinkStream.listen((uri) {
      _pendingUri = uri;
      notifyListeners();
    });
  }

  String? takeShareId() {
    final uri = _pendingUri;
    if (uri == null) return null;
    final shareId = uri.queryParameters['sid'] ?? uri.queryParameters['shareId'];
    _pendingUri = null;
    notifyListeners();
    if (shareId == null || shareId.trim().isEmpty) return null;
    return shareId.trim();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
