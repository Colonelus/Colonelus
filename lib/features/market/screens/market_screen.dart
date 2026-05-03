import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenue_cat_service.dart';
import 'dart:math' as math;

class MarketEkrani extends StatefulWidget {
  final Map<String, dynamic> me;
  const MarketEkrani({super.key, required this.me});

  @override
  State<MarketEkrani> createState() => _MarketEkraniState();
}

class _MarketEkraniState extends State<MarketEkrani>
    with TickerProviderStateMixin {
  bool _busy = false;
  Offerings? _offerings;
  List<StoreProduct> _incis = [];

  final Color _bgColor = const Color(0xFF0F172A);
  final Color _sectionColor = const Color(0xFF1E1E38);
  final Color _borderColor = const Color(0xFFB8860B);
  final Color _textColor = const Color(0xFFFACC15);

  @override
  void initState() {
    super.initState();
    _fetchOfferings();
  }

  Future<void> _fetchOfferings() async {
    setState(() => _busy = true);
    try {
      final offerings = await RevenueCatService.getOfferings();
      final incis = await Purchases.getProducts([
        'pearl_50',
        'pearl_120',
        'pearl_300',
        'pearl_700',
      ]);

      incis.sort((a, b) => a.price.compareTo(b.price));

      if (mounted) {
        setState(() {
          _offerings = offerings;
          _incis = incis;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buyPackage(Package package) async {
    setState(() => _busy = true);
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      EntitlementInfo? activeVip = customerInfo.entitlements.all["VIP"];

      PurchaseResult result;
      if (activeVip != null &&
          activeVip.isActive &&
          package.packageType != PackageType.unknown) {
        // ignore: deprecated_member_use
        result = await Purchases.purchasePackage(
          package,
          googleProductChangeInfo: GoogleProductChangeInfo(
            activeVip.productIdentifier,
            prorationMode: GoogleProrationMode.immediateAndChargeProratedPrice,
          ),
        );
      } else {
        // ignore: deprecated_member_use
        result = await Purchases.purchasePackage(package);
      }

      customerInfo = result.customerInfo;
      final uid = fb.FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      if (customerInfo.entitlements.all["VIP"]?.isActive ?? false) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'isVip': true,
          'vipType': package.packageType.toString(),
          'vipUpdateDate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buyStoreProduct(StoreProduct product) async {
    setState(() => _busy = true);
    try {
      // ignore: deprecated_member_use
      await Purchases.purchaseStoreProduct(product);

      final String id = product.identifier;
      final uid = fb.FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      int amount = 0;
      if (id.contains('50')) {
        amount = 50;
      } else if (id.contains('120')) {
        amount = 120;
      } else if (id.contains('300')) {
        amount = 300;
      } else if (id.contains('700')) {
        amount = 700;
      }

      if (amount > 0) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'inci': FieldValue.increment(amount),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$amount İnci hesabınıza eklendi!')),
          );
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buyBottleWithInci(String bottleId, int price) async {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final userSnap = await userRef.get();
    final currentInci = (userSnap.data()?['inci'] as int?) ?? 0;

    if (currentInci < price) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Yetersiz İnci!')));
      return;
    }

    setState(() => _busy = true);
    try {
      await userRef.update({
        'inci': FieldValue.increment(-price),
        'ownedBottles': FieldValue.arrayUnion([bottleId]),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Şişe satın alındı!')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _getPearlAsset(String id) {
    if (id.contains('50')) return 'assets/images/pearls/pearls_1.png';
    if (id.contains('120')) return 'assets/images/pearls/pearls_2.png';
    if (id.contains('300')) return 'assets/images/pearls/pearls_3.png';
    if (id.contains('700')) return 'assets/images/pearls/pearls_4.png';
    return 'assets/images/pearls/pearls_1.png';
  }

  @override
  Widget build(BuildContext context) {
    final inci = (widget.me['inci'] as int?) ?? 0;
    final currentOffering = _offerings?.current;

    List<Package> vips = [];

    if (currentOffering != null) {
      for (var p in currentOffering.availablePackages) {
        if (p.packageType != PackageType.unknown) {
          vips.add(p);
        }
      }
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Market',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                '$inci İnci',
                style: TextStyle(
                  color: _textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                if (vips.isNotEmpty) ...[
                  _buildSectionTitle('VIP PAKETLERİ'),
                  ...vips.map((package) => _buildVipCard(package)),
                ],
                if (_incis.isNotEmpty) ...[
                  _buildSectionTitle('İNCİ SATIN AL'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: _incis.map((p) => _buildInciCard(p)).toList(),
                    ),
                  ),
                ],
                _buildSectionTitle('ŞİŞE RENKLERİ'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildBottleItem(
                        'assets/images/bottles/bottle_green.png',
                        5,
                        'green',
                        glowColor: const Color(0xFF69F0AE),
                      ),
                      _buildBottleItem(
                        'assets/images/bottles/bottle_orange.png',
                        7,
                        'orange',
                        glowColor: const Color(0xFFFFAB40),
                      ),
                      _buildBottleItem(
                        'assets/images/bottles/bottle_purple.png',
                        10,
                        'purple',
                        glowColor: const Color(0xFFE040FB),
                      ),
                      _buildBottleItem(
                        'assets/images/bottles/bottle_diamond.png',
                        25,
                        'diamond',
                        glowColor: const Color(0xFF18FFFF),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          if (_busy)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      color: _sectionColor,
      padding: const EdgeInsets.symmetric(vertical: 12),
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildVipCard(Package package) {
    bool isVip = widget.me['isVip'] ?? false;

    String paketIsmi = "VIP Paket";
    if (package.packageType == PackageType.weekly) {
      paketIsmi = "Haftalık VIP";
    } else if (package.packageType == PackageType.monthly) {
      paketIsmi = "Aylık VIP";
    } else if (package.packageType == PackageType.threeMonth) {
      paketIsmi = "3 Aylık VIP";
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _borderColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: Colors.amber,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paketIsmi,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      package.storeProduct.description,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isVip ? null : () => _buyPackage(package),
              style: ElevatedButton.styleFrom(
                backgroundColor: _borderColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                isVip ? 'Aktif Üyelik' : package.storeProduct.priceString,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInciCard(StoreProduct product) {
    return GestureDetector(
      onTap: () => _buyStoreProduct(product),
      child: Container(
        width: 105,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Image.asset(
              _getPearlAsset(product.identifier),
              height: 45,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.auto_awesome,
                color: Colors.cyanAccent,
                size: 40,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product.title.split(' ').first,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              product.priceString,
              style: TextStyle(
                color: _textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottleItem(
    String assetPath,
    int price,
    String id, {
    Color glowColor = const Color(0xFFFACC15),
  }) {
    return Column(
      children: [
        SizedBox(
          height: 90,
          width: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: AtesBocegiEfekti(parcacikSayisi: 6, renk: glowColor),
              ),
              Image.asset(assetPath, fit: BoxFit.contain),
            ],
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _buyBottleWithInci(id, price),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: _borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$price İnci',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AtesBocegiEfekti extends StatefulWidget {
  final int parcacikSayisi;
  final Color renk;
  const AtesBocegiEfekti({
    super.key,
    required this.parcacikSayisi,
    required this.renk,
  });
  @override
  State<AtesBocegiEfekti> createState() => _AtesBocegiEfektiState();
}

class _AtesBocegiEfektiState extends State<AtesBocegiEfekti>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _opacityAnimations;
  late List<Animation<Offset>> _motionAnimations;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controllers = [];
    _opacityAnimations = [];
    _motionAnimations = [];
    for (int i = 0; i < widget.parcacikSayisi; i++) {
      final duration = Duration(milliseconds: 2000 + _random.nextInt(2000));
      final controller = AnimationController(vsync: this, duration: duration);
      Future.delayed(Duration(milliseconds: _random.nextInt(2000)), () {
        if (mounted) controller.repeat(reverse: true);
      });
      _opacityAnimations.add(
        Tween<double>(
          begin: 0.1,
          end: 0.8,
        ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
      );
      _motionAnimations.add(
        Tween<Offset>(
          begin: Offset(_random.nextDouble() - 0.5, _random.nextDouble() - 0.5),
          end: Offset(_random.nextDouble() - 0.5, _random.nextDouble() - 0.5),
        ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
      );
      _controllers.add(controller);
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: List.generate(widget.parcacikSayisi, (index) {
            final size = 2.0 + _random.nextDouble() * 3.0;
            return AnimatedBuilder(
              animation: _controllers[index],
              builder: (context, child) {
                final xPos =
                    constraints.maxWidth / 2 +
                    (_motionAnimations[index].value.dx * constraints.maxWidth);
                final yPos =
                    constraints.maxHeight / 2 +
                    (_motionAnimations[index].value.dy * constraints.maxHeight);
                return Positioned(
                  left: xPos,
                  top: yPos,
                  child: Opacity(
                    opacity: _opacityAnimations[index].value,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.renk,
                        boxShadow: [
                          BoxShadow(
                            color: widget.renk.withValues(alpha: 0.5),
                            blurRadius: size * 2,
                            spreadRadius: size / 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        );
      },
    );
  }
}