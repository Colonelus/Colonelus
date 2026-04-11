import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  static const _sdkKey = "goog_YBPwYpxHdCtuQDGYDKAaTsCUDaj";

  static Future<void> init() async {
    await Purchases.setLogLevel(LogLevel.debug);
    if (Platform.isAndroid) {
      await Purchases.configure(PurchasesConfiguration(_sdkKey));
    }
  }

  static Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      return null;
    }
  }
}
