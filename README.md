# GoMarketMe FlutterFlow Sample App

This sample demonstrates how to use the GoMarketMe Flutter SDK `6.0.0` in a FlutterFlow-style Flutter app.

## Supported platforms

- iOS
- Android

## What it shows

- Initialize GoMarketMe with your API key.
- Read optional affiliate marketing data for programmatic affiliate experiences.
- Fetch an in-app purchase product with `in_app_purchase`.
- Start a purchase flow.
- Call `GoMarketMe().syncAllTransactions()` after a successful purchase update and before completing the transaction.
- Open an iOS offer-code redemption URL.

## Configure

Edit `lib/pages/home_page/home_page_widget.dart`:

```dart
const String kGoMarketMeApiKey = 'API_KEY';
const List<String> kProductIds = <String>['FlutterSubscription1'];
const String kAppleAppId = '1234';
```

Replace those values with your real GoMarketMe API key, StoreKit/Google Play product IDs, and Apple app ID.

The app depends on the published v6 SDK:

```yaml
gomarketme: ^6.0.0
```

## Run

```bash
cd sdks/flutter/sample-app
flutter pub get
flutter run
```

For iOS, set your signing team and bundle identifier in Xcode if needed:

```bash
open ios/Runner.xcworkspace
```

## FlutterFlow usage

The app is intentionally organized with FlutterFlow-like folders:

- `lib/flutter_flow/` contains small theme/util shims.
- `lib/custom_code/actions/` contains reusable custom actions for GoMarketMe initialization and transaction sync.
- `lib/pages/home_page/home_page_widget.dart` contains the sample UI and purchase flow.

You can copy the two custom actions into a FlutterFlow project and call them from Action Flow Editor around your paywall or purchase logic.

## iOS consumables

If your iOS app sells consumable in-app purchases, keep this key in `ios/Runner/Info.plist`:

```xml
<key>SKIncludeConsumableInAppPurchaseHistory</key>
<true/>
```

The sample uses `GoMarketMe().showReferralCodeTrigger()`, so its link or button
appearance comes from the GoMarketMe settings endpoint and affiliate data is
refreshed after success.
Attributed installs cannot apply another code. The sample displays the optional
referral code when attribution came from redemption, or identifies link
attribution when cached system-info data does not include `referral_code`.
