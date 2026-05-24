import 'package:flutter_test/flutter_test.dart';
import 'package:gomarketme_flutterflow_sample_app/main.dart';

void main() {
  testWidgets('renders the GoMarketMe sample app title', (tester) async {
    await tester.pumpWidget(const GoMarketMeSampleApp());
    expect(find.text('Sample FlutterFlow App 5.0.5'), findsOneWidget);
  });
}
