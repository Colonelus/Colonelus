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

class BillingService {
  BillingService._();

  static final InAppPurchase _iap = InAppPurchase.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );
  static final InAppPurchaseAndroidPlatformAddition _androidAddition = _iap
      .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();

  static const List<String> _subscriptionProductIds = <String>['sirdas-vip'];

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

  static Future<List<ProductDetails>> _loadRawProducts() async {
    final available = await _iap.isAvailable();
    debugPrint('BILLING available=$available');
    if (!available) return const <ProductDetails>[];

    final response = await _iap.queryProductDetails(
      _subscriptionProductIds.toSet(),
    );
    debugPrint('BILLING found=${response.productDetails.length}');
    debugPrint('BILLING notFound=${response.notFoundIDs}');
    debugPrint('BILLING error=${response.error}');

    if (response.error != null) {
      throw Exception(response.error!.message ?? 'query-failed');
    }

    return response.productDetails.toList(growable: false);
  }

  static Future<List<VipPlan>> loadPlans() async {
    final products = await _loadRawProducts();
    final List<VipPlan> plans = <VipPlan>[];

    for (final product in products) {
      debugPrint('BILLING product=${product.id}');
      if (product is GooglePlayProductDetails) {
        final dynamic native = product.productDetails;
        final dynamic offerDetails = native.subscriptionOfferDetails;
        debugPrint('BILLING offers=${offerDetails?.length}');

        if (offerDetails is List && offerDetails.isNotEmpty) {
          for (final dynamic offer in offerDetails) {
            final String basePlanId = '${offer.basePlanId ?? ''}';
            final String? offerToken =
                offer.offerIdToken?.toString() ?? offer.offerToken?.toString();
            final String priceText = _extractPriceText(offer) ?? product.price;

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
        } else {
          plans.add(
            VipPlan(
              id: product.id,
              productId: product.id,
              basePlanId: '',
              title: product.title,
              subtitle: product.description,
              priceText: product.price,
              badge: 'VIP',
              offerToken: product.offerToken,
              rawProduct: product,
            ),
          );
        }
      } else {
        plans.add(
          VipPlan(
            id: product.id,
            productId: product.id,
            basePlanId: '',
            title: product.title,
            subtitle: product.description,
            priceText: product.price,
            badge: 'VIP',
            rawProduct: product,
          ),
        );
      }
    }

    plans.sort(
      (a, b) => _sortOrder(a.basePlanId).compareTo(_sortOrder(b.basePlanId)),
    );
    return plans;
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
          _onMessage?.call('VIP aktif edildi.');
        }
      } catch (_) {
        _onMessage?.call('VIP doğrulanamadı.');
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
    switch (basePlanId) {
      case 'vip-week':
      case 'vip_week':
        return 'VIP - 1 Hafta';
      case 'vip-month':
      case 'vip_month':
        return 'VIP - 1 Ay';
      case 'vip-3month':
      case 'vip_3month':
        return 'VIP - 3 Ay';
      default:
        return 'Sırdaş VIP';
    }
  }

  static String _subtitleForBasePlan(String basePlanId) {
    switch (basePlanId) {
      case 'vip-week':
      case 'vip_week':
        return 'Daha fazla sır bırak ve daha fazla sır yakala';
      case 'vip-month':
      case 'vip_month':
        return 'Sırların tekne olarak görünür';
      case 'vip-3month':
      case 'vip_3month':
        return 'Uzun süreli VIP avantajı';
      default:
        return 'VIP avantajlarını aç';
    }
  }

  static String _badgeForBasePlan(String basePlanId) {
    switch (basePlanId) {
      case 'vip-week':
      case 'vip_week':
        return 'Popüler';
      case 'vip-month':
      case 'vip_month':
        return 'En İyi';
      case 'vip-3month':
      case 'vip_3month':
        return 'Avantajlı';
      default:
        return 'VIP';
    }
  }

  static int _sortOrder(String basePlanId) {
    switch (basePlanId) {
      case 'vip-week':
      case 'vip_week':
        return 1;
      case 'vip-month':
      case 'vip_month':
        return 2;
      case 'vip-3month':
      case 'vip_3month':
        return 3;
      default:
        return 99;
    }
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
