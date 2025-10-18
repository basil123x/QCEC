import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart' as intlx;
import 'package:qcec/core/constants/app_colors.dart';
import 'package:qcec/presentation/providers/auth_provider.dart';
import 'engineer_stat_card.dart';

class StatisticsScreen extends StatelessWidget {
  final AuthProvider authProvider;
  final DateTime selectedDate;

  const StatisticsScreen({
    Key? key,
    required this.authProvider,
    required this.selectedDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateKey = intlx.DateFormat('yyyy-MM-dd').format(selectedDate);
    
    // Check user type and show appropriate content
    if (authProvider.isAdmin()) {
      // Show full statistics for admin
      return FutureBuilder<Map<String, dynamic>>(
        future: authProvider.getEngineersStats(datexx: dateKey),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorWidget(() => _rebuild(context));
          }

          final result = snapshot.data;
          if (result == null || result['success'] != true) {
            return _buildErrorWidget(() => _rebuild(context));
          }

          final engineersStats = result['engineers_stats'] as List<dynamic>;

          if (engineersStats.isEmpty) {
            return _buildEmptyStatsWidget();
          }

          return _buildAdminStatsView(engineersStats);
        },
      );
    } else if (authProvider.isEngineer()) {
      // Show a circle with number for engineers
      return _buildEngineerView();
    } else {
      // For customers and contractors, show empty space
      return _buildEmptyView();
    }
  }

  Widget _buildAdminStatsView(List<dynamic> engineersStats) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[50]!,
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(51),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Iconsax.chart_success, color: Colors.blue, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إحصائيات المهندسين',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        intlx.DateFormat('yyyy-MM-dd').format(selectedDate),
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Statistics List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: engineersStats.length,
              itemBuilder: (context, index) {
                final stat = engineersStats[index] as Map<String, dynamic>;
                return EngineerStatCard(stat: stat, rank: index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineerView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Text(
                authProvider.getUserId(),
                style: GoogleFonts.cairo(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'معرف المهندس',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            authProvider.getUserName(),
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[50],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.chart,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'الإحصائيات غير متاحة',
              style: GoogleFonts.cairo(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.warning_2, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'حدث خطأ في جلب الإحصائيات',
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onRetry,
            child: Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStatsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.chart_fail,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد إحصائيات في هذا التاريخ',
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'جرب تاريخ آخر أو تأكد من وجود زيارات',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _rebuild(BuildContext context) {
    // This will trigger a rebuild of the widget
    (context as Element).markNeedsBuild();
  }
}
