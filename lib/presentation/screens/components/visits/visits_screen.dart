import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart' as intlx;
import 'package:QCEC/core/constants/app_colors.dart';
import 'package:QCEC/presentation/providers/auth_provider.dart';
import '../statistics/statistics_screen.dart';
import 'visit_card.dart';

class VisitsScreen extends StatefulWidget {
  final AuthProvider authProvider;
  final DateTime selectedDate;
  final Map<String, Map<String, dynamic>> visitsCache;
  final String searchQueryVisits;
  final bool showingStats;
  final Function(bool) onStatsToggle;

  const VisitsScreen({
    super.key,
    required this.authProvider,
    required this.selectedDate,
    required this.visitsCache,
    required this.searchQueryVisits,
    required this.showingStats,
    required this.onStatsToggle,
  });

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Stats toggle button (only for admin)
          if (widget.authProvider.isAdmin()) _buildStatsToggle(),

          // Content - either visits or statistics
          Expanded(
            child: widget.showingStats
                ? StatisticsScreen(
                    authProvider: widget.authProvider,
                    selectedDate: widget.selectedDate,
                  )
                : _buildVisitsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsToggle() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => widget.onStatsToggle(!widget.showingStats),
              icon: Icon(
                widget.showingStats ? Iconsax.calendar : Iconsax.chart_success,
                size: 20,
              ),
              label: Text(
                widget.showingStats ? 'عرض الزيارات' : 'عرض الإحصائيات',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.showingStats
                    ? Colors.grey[600]
                    : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitsList() {
    final dateKey = intlx.DateFormat('yyyy-MM-dd').format(widget.selectedDate);

    // Check if we have cached data for this date
    if (widget.visitsCache.containsKey(dateKey)) {
      return _buildVisitsListFromCache(dateKey);
    }

    // If no cache, load from API
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadVisitsData(dateKey),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.warning_2, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'حدث خطأ في جلب الزيارات',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }

        final result = snapshot.data;
        if (result == null || result['success'] != true) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.calendar_remove,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد زيارات في هذا التاريخ',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final visits = result['visits'] as List<dynamic>;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: visits.length,
          itemBuilder: (context, index) {
            final visit = visits[index] as Map<String, dynamic>;
            return VisitCard(
              visit: visit,
              serialNumber: index + 1,
              authProvider: widget.authProvider,
            );
          },
        );
      },
    );
  }

  Widget _buildVisitsListFromCache(String dateKey) {
    final result = widget.visitsCache[dateKey];
    if (result == null || result['success'] != true) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.calendar_remove, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'لا توجد زيارات في هذا التاريخ',
              style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final visits = result['visits'] as List<dynamic>;

    // Filter visits based on search query
    final filteredVisits = widget.searchQueryVisits.isEmpty
        ? visits
        : visits.where((visit) {
            final visitMap = visit as Map<String, dynamic>;
            final searchLower = widget.searchQueryVisits.toLowerCase();

            return (visitMap['cname']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (visitMap['ename']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (visitMap['cn_name']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (visitMap['proj']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (visitMap['place']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (visitMap['a2']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (visitMap['a4']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false);
          }).toList();

    if (filteredVisits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.searchQueryVisits.isEmpty
                  ? Iconsax.calendar_remove
                  : Iconsax.search_normal,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              widget.searchQueryVisits.isEmpty
                  ? 'لا توجد زيارات في هذا التاريخ'
                  : 'لا توجد نتائج للبحث عن "${widget.searchQueryVisits}"',
              style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredVisits.length,
      itemBuilder: (context, index) {
        final visit = filteredVisits[index] as Map<String, dynamic>;
        return VisitCard(
          visit: visit,
          serialNumber: index + 1,
          authProvider: widget.authProvider,
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadVisitsData(String dateKey) async {
    return await widget.authProvider.getFullVisitsData(selectedDate: dateKey);
  }
}
