import 'package:QCEC/core/constants/app_colors.dart';
import 'package:QCEC/l10n/app_localizations.dart';
import 'package:QCEC/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../providers/auth_provider.dart';
import 'animated_stats_card.dart';

class StatsSection extends StatefulWidget {
  const StatsSection({super.key});

  @override
  State<StatsSection> createState() => _StatsSectionState();
}

class _StatsSectionState extends State<StatsSection> {
  bool _isLoading = true;
  Map<String, dynamic> _statsData = {};
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.getTotalStats();

      if (mounted) {
        if (result['success']) {
          final stats = result['stats'] as List;
          if (stats.isNotEmpty) {
            setState(() {
              _statsData = stats.first;
              _isLoading = false;
            });
          } else {
            setState(() {
              _errorMessage = 'لا توجد إحصائيات متاحة';
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _errorMessage = result['message'] ?? 'خطأ في جلب الإحصائيات';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ غير متوقع';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.statistics,
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.grey[800],
                  ),
                ),
                if (!_isLoading)
                  IconButton(
                    onPressed: _loadStats,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Iconsax.refresh,
                        color: Colors.blue,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Stats Content
            if (_isLoading)
              _buildLoadingState()
            else if (_errorMessage.isNotEmpty)
              _buildErrorState()
            else
              _buildStatsGrid(),
          ],
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 200,
      child: Row(
        children: [
          Expanded(child: _buildLoadingCard()),
          const SizedBox(width: 12),
          Expanded(child: _buildLoadingCard()),
          const SizedBox(width: 12),
          Expanded(child: _buildLoadingCard()),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 60,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.warning_2, color: Colors.orange, size: 40),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadStats,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              AppLocalizations.of(context)!.retry,
              style: GoogleFonts.cairo(fontSize: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    // Extract values from stats data
    final totalProjects =
        int.tryParse(_statsData['v1']?.toString() ?? '0') ?? 0;
    final totalVisits = int.tryParse(_statsData['v2']?.toString() ?? '0') ?? 0;
    final todayVisits = int.tryParse(_statsData['v3']?.toString() ?? '0') ?? 0;
    final monthlyVisits =
        int.tryParse(_statsData['v4']?.toString() ?? '0') ?? 0;

    // Calculate smart max values for better circle representation
    final maxProjects = totalProjects > 0
        ? (totalProjects * 1.25).round()
        : 100;
    final maxTotalVisits = totalVisits > 0 ? (totalVisits * 1.15).round() : 200;
    final maxTodayVisits = todayVisits > 0
        ? math.max(todayVisits * 2, (totalVisits * 0.1).round())
        : 10;
    final maxMonthlyVisits = monthlyVisits > 0
        ? (monthlyVisits * 1.2).round()
        : 50;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode
                ? AppColors.secondaryDark
                : AppColors.pureWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Headers Row
              Row(
                children: [
                  Expanded(
                    child: _buildStatHeader(
                      AppLocalizations.of(context)!.visitCount,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildStatHeader(
                      AppLocalizations.of(context)!.allProjects,
                      Colors.blue,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Top row - Total Visits and Projects
              Row(
                children: [
                  // Total Visits
                  Expanded(
                    child: AnimatedStatsCard(
                      title: '',
                      value: totalVisits,
                      maxValue: maxTotalVisits,
                      color: Colors.green,
                      icon: Iconsax.calendar,
                      animationDuration: const Duration(milliseconds: 2000),
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Total Projects
                  Expanded(
                    child: AnimatedStatsCard(
                      title: '',
                      value: totalProjects,
                      maxValue: maxProjects,
                      color: Colors.blue,
                      icon: Iconsax.folder_2,
                      animationDuration: const Duration(milliseconds: 1800),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Headers Row for bottom
              Row(
                children: [
                  Expanded(
                    child: _buildStatHeader(
                      AppLocalizations.of(context)!.monthlyVisits,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildStatHeader(
                      AppLocalizations.of(context)!.todayVisits,
                      Colors.indigo,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Bottom row - Monthly and Today's Visits
              Row(
                children: [
                  // Monthly Visits
                  Expanded(
                    child: AnimatedStatsCard(
                      title: '',
                      value: monthlyVisits,
                      maxValue: maxMonthlyVisits,
                      color: Colors.orange,
                      icon: Iconsax.calendar_2,
                      animationDuration: const Duration(milliseconds: 2000),
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Today's Visits
                  Expanded(
                    child: AnimatedStatsCard(
                      title: '',
                      value: todayVisits,
                      maxValue: maxTodayVisits,
                      color: Colors.indigo,
                      icon: Iconsax.clock,
                      animationDuration: const Duration(milliseconds: 2200),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
