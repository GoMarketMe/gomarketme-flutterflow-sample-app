import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gomarketme/gomarketme.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../custom_code/actions/initialize_go_market_me.dart';
import '../../custom_code/actions/sync_go_market_me_transactions.dart';

const String kGoMarketMeApiKey = 'API_KEY';
const List<String> kProductIds = <String>['FlutterSubscription1'];
const String kAppleAppId = '1234';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final TextEditingController _referralCodeController = TextEditingController();

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  List<ProductDetails> _products = <ProductDetails>[];
  GoMarketMeAffiliateMarketingData? _affiliateData;

  bool _isInitializing = true;
  bool _isPurchasing = false;
  bool _isPurchased = false;
  bool _isSyncing = false;
  bool _iapAvailable = false;
  bool _isRedeemingReferralCode = false;

  _SampleMessage? _initializationMessage;
  _SampleMessage? _referralMessage;
  _SampleMessage? _syncMessage;
  _SampleMessage? _purchaseMessage;

  bool get _isApplePlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  String? get _offerCode => _nonEmpty(_affiliateData?.offerCode);

  @override
  void initState() {
    super.initState();
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _purchaseSubscription?.cancel(),
      onError: (Object error) {
        _setPurchaseMessage(
          _SampleMessage.error('Purchase stream error: $error'),
        );
      },
    );
    _initializeSampleApp();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _initializeSampleApp() async {
    try {
      final data = await initializeGoMarketMe(kGoMarketMeApiKey);
      if (mounted) {
        setState(() {
          _affiliateData = data;
          _isInitializing = false;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('GoMarketMe initialization error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initializationMessage = _SampleMessage.error(
            'GoMarketMe could not initialize: $error',
          );
        });
      }
    }

    await _initializePurchases();
  }

  Future<void> _initializePurchases() async {
    try {
      final available = await _inAppPurchase.isAvailable();
      if (!available) {
        _setPurchaseMessage(
          _SampleMessage.info(
            'In-app purchases are unavailable on this device.',
          ),
        );
        return;
      }

      final response = await _inAppPurchase.queryProductDetails(
        kProductIds.toSet(),
      );
      if (response.error != null) {
        _setPurchaseMessage(_SampleMessage.error(response.error!.message));
      }
      if (response.notFoundIDs.isNotEmpty) {
        _setPurchaseMessage(
          _SampleMessage.info(
            'Test product not found: ${response.notFoundIDs.join(', ')}',
          ),
        );
      }

      if (mounted) {
        setState(() {
          _iapAvailable = true;
          _products = response.productDetails;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Purchase setup error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setPurchaseMessage(
        _SampleMessage.error('Purchase setup failed: $error'),
      );
    }
  }

  Future<void> _syncPurchases() async {
    setState(() {
      _isSyncing = true;
      _syncMessage = null;
    });

    try {
      final success = await syncGoMarketMeTransactions();
      if (mounted) {
        setState(() {
          _syncMessage = success
              ? _SampleMessage.success('Current purchases synced.')
              : _SampleMessage.error('Purchase sync did not complete.');
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _syncMessage = _SampleMessage.error('Purchase sync failed: $error');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _handlePurchase() async {
    if (_products.isEmpty) {
      _setPurchaseMessage(
        _SampleMessage.error('No test product is available.'),
      );
      return;
    }

    setState(() {
      _isPurchasing = true;
      _isPurchased = false;
      _purchaseMessage = null;
    });

    try {
      final purchaseParam = PurchaseParam(productDetails: _products.first);
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (error, stackTrace) {
      debugPrint('Purchase request error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _setPurchaseMessage(_SampleMessage.error('Purchase failed: $error'));
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _setPurchaseMessage(_SampleMessage.info('Purchase pending…'));
          break;
        case PurchaseStatus.error:
          _setPurchaseMessage(
            _SampleMessage.error(
              purchaseDetails.error?.message ?? 'Purchase failed.',
            ),
          );
          if (mounted) {
            setState(() => _isPurchasing = false);
          }
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _syncAndCompletePurchase(purchaseDetails);
          break;
        case PurchaseStatus.canceled:
          _setPurchaseMessage(_SampleMessage.info('Purchase cancelled.'));
          if (mounted) {
            setState(() => _isPurchasing = false);
          }
          break;
      }
    }
  }

  Future<void> _syncAndCompletePurchase(PurchaseDetails purchaseDetails) async {
    var synced = false;
    try {
      synced = await syncGoMarketMeTransactions();
    } catch (error, stackTrace) {
      debugPrint('GoMarketMe purchase sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }

      if (mounted) {
        setState(() {
          _isPurchased = true;
          _isPurchasing = false;
          _purchaseMessage = synced
              ? _SampleMessage.success('Purchase completed and synced.')
              : _SampleMessage.error(
                  'Purchase completed, but GoMarketMe sync needs attention.',
                );
        });
      }
    } catch (error) {
      _setPurchaseMessage(
        _SampleMessage.error('Could not complete purchase: $error'),
      );
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _redeemOfferCode() async {
    if (!_isApplePlatform) {
      return;
    }

    final codeQuery = _offerCode == null ? '' : '&code=$_offerCode';
    final uri = Uri.parse(
      'https://apps.apple.com/redeem/?ctx=offercodes&id=$kAppleAppId$codeQuery',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      _setPurchaseMessage(
        _SampleMessage.error('Could not open Apple offer-code redemption.'),
      );
    }
  }

  Future<void> _redeemReferralCode() async {
    final code = _nonEmpty(_referralCodeController.text);
    if (code == null || _isRedeemingReferralCode) return;
    setState(() => _isRedeemingReferralCode = true);
    try {
      final data = await GoMarketMe().redeemReferralCode(code);
      if (mounted) {
        setState(() {
          _affiliateData = data;
          _referralCodeController.clear();
          _referralMessage = _SampleMessage.success(
            'Referral code ${_nonEmpty(data.referralCode) ?? code} applied.',
          );
        });
      }
    } on GoMarketMeReferralCodeException catch (error) {
      if (mounted) {
        setState(() {
          _referralMessage = _SampleMessage.error(_referralErrorMessage(error));
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _referralMessage = _SampleMessage.error(error.toString());
        });
      }
    } finally {
      if (mounted) setState(() => _isRedeemingReferralCode = false);
    }
  }

  void _setPurchaseMessage(_SampleMessage message) {
    if (!mounted) {
      return;
    }
    setState(() => _purchaseMessage = message);
  }

  @override
  Widget build(BuildContext context) {
    final product = _products.firstOrNull;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _SampleHeader(),
                  const SizedBox(height: 20),
                  _initializationSection(),
                  const SizedBox(height: 16),
                  _referralCodeSection(),
                  const SizedBox(height: 16),
                  _purchaseSection(product),
                  const SizedBox(height: 16),
                  _programmaticDataSection(),
                  if (_isApplePlatform) ...<Widget>[
                    const SizedBox(height: 16),
                    _appleOfferCodeSection(),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _initializationSection() {
    final ready = GoMarketMe().isInitialized;
    return _SampleSection(
      badge: 'Required',
      title: 'Initialize',
      description:
          'Initialize once when your app starts. Affiliate-link attribution is handled automatically.',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              if (_isInitializing)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  ready ? Icons.check_circle : Icons.error,
                  color: ready ? Colors.green : Colors.red,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _isInitializing
                          ? 'Initializing GoMarketMe…'
                          : ready
                          ? 'SDK ready'
                          : 'Initialization failed',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      ready
                          ? _affiliateData == null
                                ? 'Ready · no existing attribution'
                                : 'Ready · attribution loaded'
                          : 'Calling GoMarketMe().initialize(apiKey)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_initializationMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            _MessageView(message: _initializationMessage!),
          ],
        ],
      ),
    );
  }

  Widget _referralCodeSection() {
    return _SampleSection(
      badge: 'Optional',
      title: 'Referral codes',
      description:
          'Referral codes are the fallback when an affiliate link is not practical. Place this UI on the first screen users see after installing the app.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GoMarketMe().showReferralCodeTrigger(
            onResult: (data) {
              if (!mounted || data == null) {
                return;
              }
              setState(() {
                _affiliateData = data;
                final code = _nonEmpty(data.referralCode);
                _referralMessage = code == null
                    ? _SampleMessage.info(
                        'This device is already attributed through an affiliate link.',
                      )
                    : _SampleMessage.success('Referral code $code applied.');
              });
            },
            onError: (error) {
              if (mounted) {
                setState(() {
                  _referralMessage = _SampleMessage.error(error.toString());
                });
              }
            },
          ),
          const Divider(height: 32),
          Text(
            'Custom referral-code UI',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _referralCodeController,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Referral code',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed:
                GoMarketMe().isInitialized &&
                    !_isRedeemingReferralCode &&
                    _nonEmpty(_referralCodeController.text) != null
                ? _redeemReferralCode
                : null,
            child: Text(
              _isRedeemingReferralCode ? 'Applying…' : 'Apply referral code',
            ),
          ),
          if (_referralMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            _MessageView(message: _referralMessage!),
          ],
          const SizedBox(height: 8),
          Text(
            'The trigger text, colors, typography, and layout are configured in GoMarketMe.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _purchaseSection(ProductDetails? product) {
    return _SampleSection(
      badge: 'Recommended',
      title: 'Report purchases',
      description:
          'GoMarketMe detects and reports purchases automatically. We also recommend manually syncing after your purchase provider confirms a successful transaction.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FilledButton.icon(
            onPressed: GoMarketMe().isInitialized && !_isSyncing
                ? _syncPurchases
                : null,
            icon: _isSyncing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(_isSyncing ? 'Syncing…' : 'Manually sync purchases'),
          ),
          if (_syncMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            _MessageView(message: _syncMessage!),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          Text(
            'In-app purchase test',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Uses the sample product ${kProductIds.first}. After a successful purchase, the sample syncs with GoMarketMe before completing it.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _iapAvailable && product != null && !_isPurchasing
                ? _handlePurchase
                : null,
            icon: const Icon(Icons.shopping_cart_outlined),
            label: Text(
              _isPurchasing
                  ? 'Purchasing…'
                  : _isPurchased
                  ? 'Purchased'
                  : product == null
                  ? 'Test product unavailable'
                  : 'Buy ${product.title} (${product.price})',
              textAlign: TextAlign.center,
            ),
          ),
          if (_purchaseMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            _MessageView(message: _purchaseMessage!),
          ],
        ],
      ),
    );
  }

  Widget _programmaticDataSection() {
    return _SampleSection(
      badge: 'Optional',
      title: 'Programmatic affiliate data',
      description:
          'Use the initialization response to personalize onboarding, paywalls, offers, or other app content.',
      child: _affiliateData == null
          ? const _MessageView(
              message: _SampleMessage(
                _MessageKind.info,
                'No attribution is active. Referral codes remain available as a fallback.',
              ),
            )
          : _AffiliateData(
              data: _affiliateData!,
              showAppleOfferCode: _isApplePlatform,
            ),
    );
  }

  Widget _appleOfferCodeSection() {
    return _SampleSection(
      badge: 'iOS feature',
      title: 'Apple offer codes',
      description:
          'Apple subscription offer codes are separate from GoMarketMe referral codes. This opens Apple\'s redemption flow.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            _offerCode == null
                ? 'No offer code was detected, but users can still enter one manually.'
                : 'Detected offer code: $_offerCode',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _redeemOfferCode,
            child: const Text('Open Apple offer-code redemption'),
          ),
        ],
      ),
    );
  }
}

class _SampleHeader extends StatelessWidget {
  const _SampleHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Image.asset(
              'assets/gomarketme-logo.png',
              width: 40,
              height: 40,
              semanticLabel: 'GoMarketMe logo',
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'GoMarketMe Flutter SDK',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Sample integration · SDK 6.0.1',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SampleSection extends StatelessWidget {
  const _SampleSection({
    required this.badge,
    required this.title,
    required this.description,
    required this.child,
  });

  final String badge;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colors.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _AffiliateData extends StatelessWidget {
  const _AffiliateData({required this.data, required this.showAppleOfferCode});

  final GoMarketMeAffiliateMarketingData data;
  final bool showAppleOfferCode;

  @override
  Widget build(BuildContext context) {
    final referralCode = _nonEmpty(data.referralCode);
    final offerCode = _nonEmpty(data.offerCode);
    return Column(
      children: <Widget>[
        _KeyValueRow(
          label: 'Attribution',
          value: referralCode == null
              ? 'Affiliate link'
              : 'Referral code ($referralCode)',
        ),
        _KeyValueRow(label: 'Affiliate ID', value: data.affiliate.id),
        _KeyValueRow(label: 'Campaign ID', value: data.campaign.id),
        if (data.deviceId.trim().isNotEmpty)
          _KeyValueRow(label: 'Device ID', value: data.deviceId.trim()),
        _KeyValueRow(
          label: 'Affiliate share',
          value: data.saleDistribution.affiliatePercentage.isEmpty
              ? '—'
              : '${data.saleDistribution.affiliatePercentage}%',
        ),
        _KeyValueRow(label: 'Referral code', value: referralCode ?? '—'),
        _KeyValueRow(
          label: 'Campaign metadata',
          value: jsonEncode(data.campaign.metadata),
        ),
        _KeyValueRow(
          label: 'Affiliate metadata',
          value: jsonEncode(data.affiliate.metadata),
        ),
        _KeyValueRow(
          label: 'Affiliate campaign metadata',
          value: jsonEncode(data.affiliateCampaign.metadata),
        ),
        if (showAppleOfferCode)
          _KeyValueRow(label: 'Apple offer code', value: offerCode ?? '—'),
        const SizedBox(height: 8),
        Text(
          'This device is attributed. A referral code cannot replace the existing attribution.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: SelectableText(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MessageKind { info, success, error }

class _SampleMessage {
  const _SampleMessage(this.kind, this.text);

  const _SampleMessage.info(String text) : this(_MessageKind.info, text);
  const _SampleMessage.success(String text) : this(_MessageKind.success, text);
  const _SampleMessage.error(String text) : this(_MessageKind.error, text);

  final _MessageKind kind;
  final String text;
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.message});

  final _SampleMessage message;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (message.kind) {
      _MessageKind.info => (Colors.blue, Icons.info),
      _MessageKind.success => (Colors.green, Icons.check_circle),
      _MessageKind.error => (Colors.red, Icons.error),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.text,
                style: TextStyle(color: color, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _referralErrorMessage(GoMarketMeReferralCodeException error) {
  return switch (error.code) {
    GoMarketMeReferralCodeErrorCode.invalidCode =>
      'That referral code is not valid. Check it and try again.',
    GoMarketMeReferralCodeErrorCode.expiredCode =>
      'That referral code has expired.',
    GoMarketMeReferralCodeErrorCode.inactiveCode =>
      'That referral code is no longer active.',
    GoMarketMeReferralCodeErrorCode.networkError ||
    GoMarketMeReferralCodeErrorCode.timeout =>
      'Could not connect. Check your connection and try again.',
    GoMarketMeReferralCodeErrorCode.notInitialized =>
      'Referral codes are not ready yet. Please try again.',
    _ =>
      error.isRetryable
          ? 'Could not apply the referral code. Please try again.'
          : error.message,
  };
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
