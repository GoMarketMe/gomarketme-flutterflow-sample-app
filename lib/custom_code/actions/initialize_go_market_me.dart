import 'package:flutter/foundation.dart';
import 'package:gomarketme/gomarketme.dart';

/// FlutterFlow custom action sample.
///
/// Add this action to your app startup or before showing your paywall.
/// Returns affiliate marketing data when the current user was acquired through
/// a GoMarketMe affiliate campaign.
Future<GoMarketMeAffiliateMarketingData?> initializeGoMarketMe(
  String apiKey,
) async {
  final goMarketMeSDK = GoMarketMe();

  await goMarketMeSDK.initialize(apiKey);
  final data = goMarketMeSDK.affiliateMarketingData;

  if (data == null) {
    debugPrint('No GoMarketMe affiliate data found.');
    return null;
  }

  // Maps to GoMarketMe > Affiliates > Export > id column.
  debugPrint('Affiliate ID: ${data.affiliate.id}');

  // Maps to GoMarketMe > Campaigns > [Name] > Affiliate\'s Revenue Split (%).
  debugPrint('Affiliate %: ${data.saleDistribution.affiliatePercentage}');

  // Maps to GoMarketMe > Campaigns > [Name] > id in the URL.
  debugPrint('Campaign ID: ${data.campaign.id}');

  return data;
}
