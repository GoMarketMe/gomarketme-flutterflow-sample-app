import 'package:flutter_test/flutter_test.dart';
import 'package:gomarketme_flutterflow_sample_app/main.dart';

void main() {
  testWidgets('renders the GoMarketMe integration guide', (tester) async {
    await tester.pumpWidget(const GoMarketMeSampleApp());
    expect(find.text('GoMarketMe Flutter SDK'), findsOneWidget);
    expect(find.text('Initialize'), findsOneWidget);
    expect(find.text('Referral codes'), findsOneWidget);
  });
}
