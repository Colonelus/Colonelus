import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

class VipPlan {
  final String id;
  final String productId;
  final String basePlanId;
  final String title;
  final String subtitle;
  final String priceText;
  final String badge;
  final String? offerToken;
  final ProductDetails rawProduct;

  const VipPlan({
    required this.id,
    required this.productId,
    required this.basePlanId,
    required this.title,
    required this.subtitle,
    required this.priceText,
    required this.badge,
    required this.rawProduct,
    this.offerToken,
  });

  String get price => priceText;
}

class InciPackage {
  final String id;
  final String title;
  final String price;
  final ProductDetails rawProduct;

  InciPackage({
    required this.id,
    required this.title,
    required this.price,
    required this.rawProduct,
  });
}

class BillingService {
  BillingService._();

  static final InAppPurchase _iap = InAppPurchase.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );
  static final InAppPurchaseAndroidPlatformAddition _androidAddition = _iap
      .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();

  static const List<String> _subscriptionProductIds = <String>['sirdas_vip'];
  static const List<String> _inciProductIds = <String>[
    'pearl_50',
    'pearl_120',
    'pearl_300',
    'pearl_700',
  ];

  static StreamSubscription<List<PurchaseDetails>>? _sub;
  static void Function(String message)? _onMessage;

  static Future<bool> isAvailable() {
    return _iap.isAvailable();
  }

  static Future<void> start({void Function(String message)? onMessage}) async {
    _onMessage = onMessage;
    await _sub?.cancel();
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (_) {
        _onMessage?.call('Satın alma akışı açılamadı.');
      },
    );
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  static Future<Map<String, dynamic>> loadStoreItems() async {
    final available = await _iap.isAvailable();
    if (!available) return {'plans': <VipPlan>[], 'incis': <InciPackage>[]};

    final response = await _iap.queryProductDetails(
      {..._subscriptionProductIds, ..._inciProductIds}.toSet(),
    );

    if (response.error != null) {
      throw Exception(response.error!.message);
    }

    final List<VipPlan> plans = <VipPlan>[];
    final List<InciPackage> incis = <InciPackage>[];

    for (final product in response.productDetails) {
      if (_inciProductIds.contains(product.id)) {
        incis.add(
          InciPackage(
            id: product.id,
            title: product.title,
            price: product.price,
            rawProduct: product,
          ),
        );
      } else {
        if (product is GooglePlayProductDetails) {
          final dynamic native = product.productDetails;
          final dynamic offerDetails = native.subscriptionOfferDetails;

          if (offerDetails is List && offerDetails.isNotEmpty) {
            for (final dynamic offer in offerDetails) {
              final String basePlanId = '${offer.basePlanId ?? ''}';
              final String? offerToken =
                  offer.offerIdToken?.toString() ??
                  offer.offerToken?.toString();
              final String priceText =
                  _extractPriceText(offer) ?? product.price;

              plans.add(
                VipPlan(
                  id: basePlanId.isEmpty ? product.id : basePlanId,
                  productId: product.id,
                  basePlanId: basePlanId,
                  title: _titleForBasePlan(basePlanId),
                  subtitle: _subtitleForBasePlan(basePlanId),
                  priceText: priceText,
                  badge: _badgeForBasePlan(basePlanId),
                  offerToken: offerToken,
                  rawProduct: product,
                ),
              );
            }
          }
        }
      }
    }

    plans.sort(
      (a, b) => _sortOrder(a.basePlanId).compareTo(_sortOrder(b.basePlanId)),
    );

    return {'plans': plans, 'incis': incis};
  }

  static Future<void> buyInci(InciPackage package) async {
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: package.rawProduct,
    );
    await _iap.buyConsumable(purchaseParam: purchaseParam);
  }

  static Future<GooglePlayPurchaseDetails?> _findOwnedSubscription() async {
    final response = await _androidAddition.queryPastPurchases();
    if (response.error != null) return null;

    for (final purchase in response.pastPurchases) {
      if (_subscriptionProductIds.contains(purchase.productID)) {
        return purchase;
      }
    }
    return null;
  }

  static Future<void> buyPlan(VipPlan plan, {required String uid}) async {
    final product = plan.rawProduct;
    GooglePlayPurchaseDetails? oldSubscription;

    try {
      oldSubscription = await _findOwnedSubscription();
    } catch (_) {}

    final PurchaseParam purchaseParam = product is GooglePlayProductDetails
        ? GooglePlayPurchaseParam(
            productDetails: product,
            offerToken: plan.offerToken,
            changeSubscriptionParam: oldSubscription != null
                ? ChangeSubscriptionParam(
                    oldPurchaseDetails: oldSubscription,
                    replacementMode: ReplacementMode.withTimeProration,
                  )
                : null,
          )
        : PurchaseParam(productDetails: product);

    final ok = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    if (!ok) {
      throw Exception('purchase-flow-not-started');
    }
  }

  static Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      try {
        if (purchase.status == PurchaseStatus.pending) {
          _onMessage?.call('Satın alma bekleniyor...');
        }

        if (purchase.status == PurchaseStatus.error) {
          _onMessage?.call('Satın alma başarısız.');
        }

        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          await _verify(purchase);
          _onMessage?.call('İşlem başarılı.');
        }
      } catch (_) {
        _onMessage?.call('Doğrulama başarısız.');
      } finally {
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  static Future<void> _verify(PurchaseDetails purchase) async {
    final token = purchase.verificationData.serverVerificationData;
    if (token.isEmpty) {
      throw Exception('missing-purchase-token');
    }

    final callable = _functions.httpsCallable('verifyAndroidPurchase');

    await callable.call(<String, dynamic>{
      'productId': purchase.productID,
      'purchaseToken': token,
      'packageName': kIsWeb ? '' : 'com.colonelus.sirdas',
    });
  }

  static String _titleForBasePlan(String basePlanId) {
    if (basePlanId.contains('week')) return 'VIP - 1 Hafta';
    if (basePlanId.contains('3month')) return 'VIP - 3 Ay';
    if (basePlanId.contains('month')) return 'VIP - 1 Ay';
    return 'Sırdaş VIP';
  }

  static String _subtitleForBasePlan(String basePlanId) {
    if (basePlanId.contains('week')) return 'Denizi keşfetmeye başla';
    if (basePlanId.contains('3month')) return 'En uzun süreli avantaj';
    return 'Sırların tekne olarak görünür';
  }

  static String _badgeForBasePlan(String basePlanId) {
    if (basePlanId.contains('week')) return 'Popüler';
    if (basePlanId.contains('3month')) return 'Avantajlı';
    return 'En İyi';
  }

  static int _sortOrder(String basePlanId) {
    if (basePlanId.contains('week')) return 1;
    if (basePlanId.contains('month') && !basePlanId.contains('3')) return 2;
    if (basePlanId.contains('3month')) return 3;
    return 99;
  }

  static String? _extractPriceText(dynamic offer) {
    try {
      final dynamic pricingPhases = offer.pricingPhases;
      final dynamic list = pricingPhases.pricingPhaseList;
      if (list is List && list.isNotEmpty) {
        final dynamic phase = list.first;
        final dynamic formatted = phase.formattedPrice;
        if (formatted != null) return formatted.toString();
      }
    } catch (_) {}
    return null;
  }
}