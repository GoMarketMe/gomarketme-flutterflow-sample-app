import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gomarketme/gomarketme.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../custom_code/actions/initialize_go_market_me.dart';
import '../../custom_code/actions/sync_go_market_me_transactions.dart';
import '../../flutter_flow/flutter_flow_theme.dart';

const String kGoMarketMeApiKey = 'API_KEY';
const List<String> kProductIds = <String>['FlutterSubscription1'];
const String kAppleAppId = '1234';
const String kFallbackOfferCode = 'NO_OFFER_CODE_FOUND';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  List<ProductDetails> _products = <ProductDetails>[];
  GoMarketMeAffiliateMarketingData? _affiliateData;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isPurchased = false;

  String get _offerCode => _affiliateData?.offerCode?.trim().isNotEmpty == true
      ? _affiliateData!.offerCode!.trim()
      : kFallbackOfferCode;

  @override
  void initState() {
    super.initState();
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _purchaseSubscription?.cancel(),
      onError: (Object error) => _showError('Purchase stream error: $error'),
    );
    _initializeSampleApp();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeSampleApp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🧩 Initializing GoMarketMe...');
      final affiliateData = await initializeGoMarketMe(kGoMarketMeApiKey);

      debugPrint('🧩 Checking IAP availability...');
      final isAvailable = await _inAppPurchase.isAvailable();
      if (!isAvailable) {
        _showError('In-app purchases are not available on this device.');
        return;
      }

      debugPrint('🧾 Fetching products: $kProductIds');
      final productResponse = await _inAppPurchase.queryProductDetails(
        kProductIds.toSet(),
      );

      if (productResponse.error != null) {
        _showError(productResponse.error!.message);
      }

      if (productResponse.notFoundIDs.isNotEmpty) {
        debugPrint('Products not found: ${productResponse.notFoundIDs}');
      }

      setState(() {
        _affiliateData = affiliateData;
        _products = productResponse.productDetails;
      });
    } catch (error, stackTrace) {
      debugPrint('❌ Initialization error: $error');
      debugPrint(stackTrace.toString());
      _showError('Failed to initialize the sample app.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePurchase() async {
    if (_products.isEmpty) {
      _showError('No products available for purchase.');
      return;
    }

    setState(() => _isPurchasing = true);

    try {
      final purchaseParam = PurchaseParam(productDetails: _products.first);

      debugPrint('🛒 Buying product: ${_products.first.id}');

      // Use buyNonConsumable for subscriptions and non-consumables.
      // For consumables, change this to buyConsumable.
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (error, stackTrace) {
      debugPrint('❌ Purchase request error: $error');
      debugPrint(stackTrace.toString());
      _showError('Purchase failed: $error');
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      debugPrint(
        'purchaseStream update: ${purchaseDetails.productID} '
        '${purchaseDetails.status}',
      );

      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          if (mounted) {
            setState(() => _isPurchasing = true);
          }
          break;
        case PurchaseStatus.error:
          _showError(purchaseDetails.error?.message ?? 'Purchase error.');
          if (mounted) {
            setState(() => _isPurchasing = false);
          }
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _syncAndCompletePurchase(purchaseDetails);
          break;
        case PurchaseStatus.canceled:
          if (mounted) {
            setState(() => _isPurchasing = false);
          }
          break;
      }
    }
  }

  Future<void> _syncAndCompletePurchase(PurchaseDetails purchaseDetails) async {
    try {
      await syncGoMarketMeTransactions();
    } catch (error, stackTrace) {
      debugPrint('GoMarketMe syncAllTransactions error: $error');
      debugPrint(stackTrace.toString());
    }

    try {
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
        debugPrint('completePurchase completed: ${purchaseDetails.productID}');
      }

      if (mounted) {
        setState(() {
          _isPurchased = true;
          _isPurchasing = false;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('completePurchase error: $error');
      debugPrint(stackTrace.toString());
      _showError('Could not complete purchase: $error');
    }
  }

  Future<void> _redeemOfferCode() async {
    final uri = Uri.parse(
      'https://apps.apple.com/redeem/?ctx=offercodes&id=$kAppleAppId&code=$_offerCode',
    );

    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.iOS) {
      _showError('Offer-code redemption is only available for iOS apps.');
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      _showError('Could not open offer-code redemption URL.');
    }
  }

  void _showError(String message) {
    debugPrint(message);
    if (!mounted) {
      return;
    }

    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final product = _products.isNotEmpty ? _products.first : null;
    final title = product == null
        ? 'No products available'
        : _isPurchased
        ? 'Purchased!'
        : 'Buy ${product.title} (${product.price})';

    return Scaffold(
      backgroundColor: FlutterFlowTheme.secondaryBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Sample FlutterFlow App 6.0.0',
                    textAlign: TextAlign.center,
                    style: FlutterFlowTheme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...<Widget>[
                    FilledButton(
                      onPressed: _isPurchasing || product == null
                          ? null
                          : _handlePurchase,
                      child: _isPurchasing
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(title),
                    ),
                    const SizedBox(height: 12),
                    GoMarketMe().showReferralCodeTrigger(
                      onResult: (data) {
                        if (mounted && data != null) {
                          setState(() => _affiliateData = data);
                        }
                      },
                      onError: (error) {
                        if (mounted) {
                          setState(() => _errorMessage = error.toString());
                        }
                      },
                    ),
                    TextButton(
                      onPressed: _redeemOfferCode,
                      child: Text('Redeem Offer Code: $_offerCode'),
                    ),
                    if (_affiliateData != null) ...<Widget>[
                      const SizedBox(height: 20),
                      _AffiliateDataCard(data: _affiliateData!),
                    ],
                    if (_errorMessage != null) ...<Widget>[
                      const SizedBox(height: 20),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AffiliateDataCard extends StatelessWidget {
  const _AffiliateDataCard({required this.data});

  final GoMarketMeAffiliateMarketingData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Affiliate campaign detected',
              style: FlutterFlowTheme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Affiliate ID: ${data.affiliate.id}'),
            Text('Affiliate %: ${data.saleDistribution.affiliatePercentage}'),
            Text('Campaign ID: ${data.campaign.id}'),
            Text(
              data.referralCode == null
                  ? 'Attribution source: affiliate link'
                  : 'Referral Code: ${data.referralCode}',
            ),
          ],
        ),
      ),
    );
  }
}
