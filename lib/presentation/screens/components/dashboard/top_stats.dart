import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart' as intlx;
import 'package:qcec/core/constants/app_colors.dart';
import 'package:qcec/presentation/providers/auth_provider.dart';


class TopStats extends StatelessWidget {
  final AuthProvider authProvider;
  final DateTime selectedDate;

  const TopStats({
    Key? key,
    required this.authProvider,
    required this.selectedDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateKey = intlx.DateFormat('yyyy-MM-dd').format(selectedDate);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إحصائيات اليوم',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: authProvider.getTopStats(datexx: dateKey),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError || 
                  snapshot.data == null || 
                  snapshot.data!['success'] != true) {
                return _buildErrorWidget();
              }

              final stats = snapshot.data!['stats'] as List<dynamic>;
              if (stats.isEmpty) {
                return _buildEmptyWidget();
              }

              return _buildStatsGrid(stats);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(List<dynamic> stats) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index] as Map<String, dynamic>;
        return _buildStatCard(stat, index);
      },
    );
  }

  Widget _buildStatCard(Map<String, dynamic> stat, int index) {
    final title = stat['title'] ?? 'إحصائية';
    final value = stat['value']?.toString() ?? '0';
    final IconData icon = _getIconForIndex(index);
    final Color color = _getColorForIndex(index);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(51),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.cairo(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          children: [
            Icon(Iconsax.warning_2, size: 32, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'خطأ في جلب الإحصائيات',
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          children: [
            Icon(Iconsax.chart_fail, size: 32, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'لا توجد إحصائيات متاحة',
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForIndex(int index) {
    switch (index % 4) {
      case 0:
        return Iconsax.user_octagon;
      case 1:
        return Iconsax.calendar;
      case 2:
        return Iconsax.folder_2;
      case 3:
        return Iconsax.chart_success;
      default:
        return Iconsax.chart;
    }
  }

  Color _getColorForIndex(int index) {
    switch (index % 4) {
      case 0:
        return Colors.blue;
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.purple;
      default:
        return AppColors.primary;
    }
  }
}
