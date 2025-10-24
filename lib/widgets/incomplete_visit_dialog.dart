import 'package:QCEC/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../services/app_lifecycle_service.dart';
import '../core/constants/app_colors.dart';

/// نافذة تنبيه للزيارة غير المكتملة
class IncompleteVisitDialog extends StatelessWidget {
  final Map<String, dynamic> visitInfo;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;

  const IncompleteVisitDialog({
    Key? key,
    required this.visitInfo,
    this.onResume,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int visitId = visitInfo['visitId'] ?? 0;
    final int imagesCount = visitInfo['imagesCount'] ?? 0;
    final int videosCount = visitInfo['videosCount'] ?? 0;
    final DateTime lastModified = visitInfo['lastModified'] ?? DateTime.now();
    
    // حساب الوقت المنقضي
    final Duration elapsed = DateTime.now().difference(lastModified);
    String timeAgo;
    if (elapsed.inMinutes < 1) {
      timeAgo = 'منذ لحظات';
    } else if (elapsed.inHours < 1) {
      timeAgo = 'منذ ${elapsed.inMinutes} دقيقة';
    } else if (elapsed.inDays < 1) {
      timeAgo = 'منذ ${elapsed.inHours} ساعة';
    } else {
      timeAgo = 'منذ ${elapsed.inDays} يوم';
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: EdgeInsets.zero,
      content: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Container(
            width: double.maxFinite,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: themeProvider.isDarkMode ? [
                  AppColors.primaryDark,
                  AppColors.secondaryDark,
                ] : [
                  AppColors.primary.withOpacity(0.1),
                  Colors.white,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Iconsax.document_text,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'زيارة غير مكتملة',
                              style: GoogleFonts.cairo(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'الزيارة رقم $visitId',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          
                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لديك زيارة لم يتم إكمالها بعد. يمكنك استكمالها أو حذفها.',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          color: themeProvider.isDarkMode ? Colors.white: Colors.black,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
          
                      // Visit Info Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              icon: Iconsax.camera,
                              label: 'الصور',
                              value: '$imagesCount',
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoCard(
                              icon: Iconsax.video,
                              label: 'الفيديوهات',
                              value: '$videosCount',
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
          
                      // Time info
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.clock,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'آخر تحديث: $timeAgo',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color: Colors.orange[800],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          
                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onCancel?.call();
                          },
                          icon: const Icon(Iconsax.trash),
                          label: Text(
                            'حذف',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onResume?.call();
                          },
                          icon: const Icon(Iconsax.play),
                          label: Text(
                            'استكمال',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// عرض النافذة
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onResume,
    VoidCallback? onCancel,
  }) async {
    final appService = AppLifecycleService();
    
    // التحقق من وجود زيارة غير مكتملة
    bool hasIncomplete = await appService.hasIncompleteVisit();
    if (!hasIncomplete) return;

    // الحصول على معلومات الزيارة
    Map<String, dynamic>? visitInfo = await appService.getActiveVisitInfo();
    if (visitInfo == null) return;

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => IncompleteVisitDialog(
          visitInfo: visitInfo,
          onResume: onResume,
          onCancel: onCancel,
        ),
      );
    }
  }
}
