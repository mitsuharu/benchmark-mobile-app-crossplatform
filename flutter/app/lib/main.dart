import 'package:flutter/material.dart';

import 'src/app_channel.dart';
import 'src/app_config.dart';
import 'src/home_screen.dart';

void main() => runApp(const BenchmarkApp());

/// The benchmark app, written entirely in Flutter: a home screen that hands a
/// keyword to a search screen and takes the results back.
class BenchmarkApp extends StatelessWidget {
  const BenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter',
      debugShowCheckedModeBanner: false,
      home: HomeScreen(
        channel: AppChannel.shared,
        apiBaseUrl: AppConfig.apiBaseUrl,
      ),
    );
  }
}
