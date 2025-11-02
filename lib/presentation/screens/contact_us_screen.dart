import 'package:QCEC/core/constants/app_colors.dart';
import 'package:QCEC/l10n/app_localizations.dart';
import 'package:QCEC/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({Key? key}) : super(key: key);

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
              l10n.contactUsTitle,
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
                          Iconsax.call,
                          size: 40,
                          color: themeProvider.isDarkMode
                              ? AppColors.pureWhite
                              : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.weAreHereToServe,
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
                        l10n.contactUsAnytime,
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

                // Contact Information
                _buildContactCard(
                  context: context,
                  themeProvider: themeProvider,
                  icon: Iconsax.call,
                  title: l10n.phone,
                  subtitle: l10n.callUsDirect,
                  value: '44811334 - 44814727',
                  onTap: () => _showPhoneOptions(context, themeProvider, l10n),
                ),

                const SizedBox(height: 16),

                _buildContactCard(
                  context: context,
                  themeProvider: themeProvider,
                  icon: Iconsax.sms,
                  title: l10n.email,
                  subtitle: l10n.emailUs,
                  value: 'info@qcec.online',
                  onTap: () => _sendEmail('info@qcec.online', l10n),
                ),

                const SizedBox(height: 16),

                _buildContactCard(
                  context: context,
                  themeProvider: themeProvider,
                  icon: Iconsax.location,
                  title: l10n.address,
                  subtitle: l10n.ourLocation,
                  value:
                      '790 شارع الكناري متفرع من شارع معيذر التجاري\nمبني العجلان، الدوحة، قطر',
                  onTap: () => _openMap(),
                ),

                const SizedBox(height: 16),

                _buildContactCard(
                  context: context,
                  themeProvider: themeProvider,
                  icon: Iconsax.clock,
                  title: l10n.workingHours,
                  subtitle: l10n.officialHours,
                  value:
                      '${l10n.saturdayToThursday}\n${l10n.morningShift} / ${l10n.eveningShift}',
                  onTap: null,
                ),

                const SizedBox(height: 24),

                // Social Media Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode
                        ? AppColors.secondaryDark
                        : AppColors.pureWhite,
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
                              color: AppColors.primary.withAlpha(51),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Iconsax.share,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            l10n.followUsOn,
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSocialButton(
                            icon: Iconsax.message,
                            label: l10n.whatsapp,
                            color: const Color(0xFF25D366),
                            onTap: () => _openWhatsApp('52022844'),
                          ),
                          _buildSocialButton(
                            icon: Iconsax.instagram,
                            label: l10n.instagram,
                            color: const Color(0xFFE4405F),
                            onTap: () => _openInstagram(),
                          ),
                          _buildSocialButton(
                            icon: Iconsax.global,
                            label: l10n.website,
                            color: AppColors.primary,
                            onTap: () => _openWebsite(),
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

  Widget _buildContactCard({
    required BuildContext context,
    required ThemeProvider themeProvider,
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    VoidCallback? onTap,
  }) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode
                              ? AppColors.pureWhite
                              : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        value,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Iconsax.arrow_left_2, color: Colors.grey[400], size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withAlpha(76), width: 1),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper methods
  void _showPhoneOptions(
    BuildContext context,
    ThemeProvider themeProvider,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.isDarkMode
          ? AppColors.secondaryDark
          : Colors.white,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: themeProvider.isDarkMode
              ? AppColors.secondaryDark
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.selectPhoneNumber,
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeProvider.isDarkMode
                    ? AppColors.pureWhite
                    : Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(
                Iconsax.call,
                color: themeProvider.isDarkMode
                    ? AppColors.pureWhite
                    : Colors.green,
              ),
              title: Text(
                '44811334',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  color: themeProvider.isDarkMode
                      ? AppColors.pureWhite
                      : Colors.black,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _makePhoneCall('44811334');
              },
            ),
            ListTile(
              leading: Icon(
                Iconsax.call,
                color: themeProvider.isDarkMode
                    ? AppColors.pureWhite
                    : Colors.green,
              ),
              title: Text(
                '44814727',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  color: themeProvider.isDarkMode
                      ? AppColors.pureWhite
                      : Colors.black,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _makePhoneCall('44814727');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  void _sendEmail(String email, AppLocalizations l10n) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${l10n.inquiryFromApp}',
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  void _openMap() async {
    const String googleMapsUrl =
        'https://maps.google.com/?q=790+شارع+الكناري+متفرع+من+شارع+معيذر+التجاري+مبني+العجلان+الدوحة+قطر';
    final Uri launchUri = Uri.parse(googleMapsUrl);
    if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $launchUri');
    }
  }

  void _openWhatsApp(String phoneNumber) async {
    final String whatsappUrl = 'https://wa.me/974$phoneNumber';
    final Uri launchUri = Uri.parse(whatsappUrl);
    if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $launchUri');
    }
  }

  void _openInstagram() async {
    const String instagramUrl = 'https://www.instagram.com/qcecqatar/';
    final Uri launchUri = Uri.parse(instagramUrl);
    if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $launchUri');
    }
  }

  void _openWebsite() async {
    const String websiteUrl = 'https://www.qcec.site/home';
    final Uri launchUri = Uri.parse(websiteUrl);
    if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $launchUri');
    }
  }
}
