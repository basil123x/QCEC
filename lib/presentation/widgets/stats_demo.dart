import 'package:flutter/material.dart';
import 'animated_stats_card.dart';
import 'package:iconsax/iconsax.dart';

/// Demo widget لاختبار الإحصائيات بدون الحاجة للـ API
class StatsDemo extends StatelessWidget {
  const StatsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تجربة الإحصائيات'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الإحصائيات التجريبية',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Row of 3 stats cards
            Row(
              children: [
                // Total Projects
                Expanded(
                  child: AnimatedStatsCard(
                    title: 'إجمالي المشاريع',
                    value: 25,
                    maxValue: 50, // 50% مكتمل
                    color: Colors.blue,
                    icon: Iconsax.folder_2,
                    animationDuration: const Duration(milliseconds: 1800),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Total Visits
                Expanded(
                  child: AnimatedStatsCard(
                    title: 'إجمالي الزيارات',
                    value: 150,
                    maxValue: 200, // 75% مكتمل
                    color: Colors.green,
                    icon: Iconsax.calendar,
                    animationDuration: const Duration(milliseconds: 2000),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Today's Visits
                Expanded(
                  child: AnimatedStatsCard(
                    title: 'زيارات اليوم',
                    value: 5,
                    maxValue: 15, // 33% مكتمل
                    color: Colors.orange,
                    icon: Iconsax.clock,
                    animationDuration: const Duration(milliseconds: 2200),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            
            // Large numbers demo
            const Text(
              'أرقام كبيرة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: AnimatedStatsCard(
                    title: 'مشاريع كبيرة',
                    value: 1250,
                    maxValue: 2000, // 62.5% مكتمل
                    color: Colors.purple,
                    icon: Iconsax.building,
                    animationDuration: const Duration(milliseconds: 2500),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                Expanded(
                  child: AnimatedStatsCard(
                    title: 'زيارات بالآلاف',
                    value: 15000,
                    maxValue: 20000, // 75% مكتمل
                    color: Colors.red,
                    icon: Iconsax.chart_success,
                    animationDuration: const Duration(milliseconds: 3000),
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // Reset button
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // Restart the page to see animation again
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const StatsDemo()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'إعادة تشغيل الحركة',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
