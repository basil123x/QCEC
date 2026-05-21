import 'package:QCEC/core/constants/app_colors.dart';
import 'package:QCEC/l10n/app_localizations.dart';
import 'package:QCEC/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          backgroundColor: themeProvider.isDarkMode
              ? AppColors.primaryDark
              : Colors.grey[50],
          appBar: AppBar(
            title: Text(
              l10n.aboutUs,
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: themeProvider.isDarkMode
                ? AppColors.secondaryDark
                : AppColors.primary,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Iconsax.arrow_right_3, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode
                        ? AppColors.secondaryDark
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: themeProvider.isDarkMode
                              ? AppColors.primaryDark
                              : AppColors.primary.withAlpha(51),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Iconsax.building_4,
                          size: 40,
                          color: themeProvider.isDarkMode
                              ? AppColors.pureWhite
                              : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.qcecFullName,
                        style: GoogleFonts.cairo(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode
                              ? AppColors.pureWhite
                              : Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.sinceYear,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          color: themeProvider.isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // About Us Section
                _buildSectionCard(
                  context: context,
                  themeProvider: themeProvider,
                  title: l10n.aboutUsTitle,
                  content: l10n.aboutUsContent,
                  icon: Iconsax.info_circle,
                ),

                const SizedBox(height: 16),

                // Our Mission Section
                _buildSectionCard(
                  context: context,
                  themeProvider: themeProvider,
                  title: l10n.inTheBeginning,
                  content: l10n.ourMissionContent,
                  icon: Iconsax.flag,
                ),

                const SizedBox(height: 24),

                // Services Grid
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode
                        ? AppColors.secondaryDark
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.ourServices,
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode
                              ? AppColors.pureWhite
                              : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildServiceItem(
                              context: context,
                              themeProvider: themeProvider,
                              icon: Iconsax.home_2,
                              title: l10n.buildingDesign,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildServiceItem(
                              context: context,
                              themeProvider: themeProvider,
                              icon: Iconsax.eye,
                              title: l10n.executionSupervision,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildServiceItem(
                              context: context,
                              themeProvider: themeProvider,
                              icon: Iconsax.setting_2,
                              title: l10n.technicalSolutions,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildServiceItem(
                              context: context,
                              themeProvider: themeProvider,
                              icon: Iconsax.medal_star,
                              title: l10n.qualityAndInnovation,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required ThemeProvider themeProvider,
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? AppColors.secondaryDark
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode
                      ? AppColors.primaryDark
                      : AppColors.primary.withAlpha(51),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: themeProvider.isDarkMode
                      ? AppColors.pureWhite
                      : Colors.black,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode
                        ? AppColors.pureWhite
                        : Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: GoogleFonts.cairo(
              fontSize: 15,
              height: 1.8,
              color: themeProvider.isDarkMode
                  ? AppColors.pureWhite
                  : Colors.black,
            ),
            textAlign: TextAlign.justify,
          ),
        ],
      ),
    );
  }

  Widget _buildServiceItem({
    required BuildContext context,
    required ThemeProvider themeProvider,
    required IconData icon,
    required String title,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? AppColors.primaryDark
            : AppColors.primary.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: themeProvider.isDarkMode ? AppColors.pureWhite : Colors.black,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: themeProvider.isDarkMode
                ? AppColors.pureWhite
                : Colors.black,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: themeProvider.isDarkMode
                  ? AppColors.pureWhite
                  : Colors.black,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
