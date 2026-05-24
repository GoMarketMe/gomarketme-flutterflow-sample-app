import 'package:flutter/material.dart';

import 'pages/home_page/home_page_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GoMarketMeSampleApp());
}

class GoMarketMeSampleApp extends StatelessWidget {
  const GoMarketMeSampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoMarketMe FlutterFlow Sample',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007AFF)),
        useMaterial3: true,
      ),
      home: const HomePageWidget(),
    );
  }
}
