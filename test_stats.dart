import 'package:flutter/material.dart';
import 'lib/presentation/widgets/stats_demo.dart';

void main() {
  runApp(const StatsTestApp());
}

class StatsTestApp extends StatelessWidget {
  const StatsTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'اختبار الإحصائيات',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Cairo',
      ),
      home: const StatsDemo(),
      debugShowCheckedModeBanner: false,
    );
  }
}
