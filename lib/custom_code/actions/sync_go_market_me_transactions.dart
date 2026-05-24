import 'package:flutter/foundation.dart';
import 'package:gomarketme/gomarketme.dart';

/// FlutterFlow custom action sample.
///
/// Call this after your purchase provider reports a successful purchase and
/// before completing, acknowledging, consuming, or finishing the transaction.
Future<bool> syncGoMarketMeTransactions() async {
  final result = await GoMarketMe().syncAllTransactions();

  debugPrint(
    'GoMarketMe syncAllTransactions result: '
    'fetched=${result.fetchedCount}, '
    'sent=${result.sentCount}, '
    'failed=${result.failedCount}, '
    'success=${result.success}',
  );

  return result.success;
}
