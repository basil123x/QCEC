import 'package:QCEC/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          backgroundColor: themeProvider.isDarkMode ? AppColors.primaryDark : Colors.grey[50],
          appBar: AppBar(
            title: Text(
              'من نحن',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: themeProvider.isDarkMode ? AppColors.secondaryDark :AppColors.primary,
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
                    color: themeProvider.isDarkMode ? AppColors.secondaryDark : Colors.white,
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
                          color: themeProvider.isDarkMode ? AppColors.primaryDark : AppColors.primary.withAlpha(51),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Iconsax.building_4,
                          size: 40,
                          color: themeProvider.isDarkMode ? AppColors.pureWhite : Colors.black
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'المركز القطري للاستشارات الهندسية',
                        style: GoogleFonts.cairo(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode ? AppColors.pureWhite : Colors.black
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'منذ عام 1998',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          color: Colors.grey[200],
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
                  title: 'من نحن',
                  content: 'منذ تأسيسه عام 1998 , قدم المركز القطري للاستشارات الهندسيه أعمالا متميزة ومبتكرة في تصميم المباني والإشراف علي تنفيذها محققا رضاء العملاء وتقديرهم\n\nالان ودائما , نتطلع الي المشاركة وتعزيز التنمية في قطر من خلال خدمة ومشاركة عملائنا والمجتمع والمساهمه في المستقبل وتحدياته .',
                  icon: Iconsax.info_circle,
                ),
                
                const SizedBox(height: 16),
                
                // Our Mission Section
                _buildSectionCard(
                  title: 'في البداية...',
                  content: 'نحن المركز القطري للاستشارات الهندسيه ملتزمون بتقديم افضل التصميمات جودة وابتكارا , الاشراف عليها سعيا لرضاء عملائنا وخدمتهم , بتقديم حلول عالية التقنيه وإبداع مستدام , والمحافظه علي الاصالة وإضافة الحداثة .',
                  icon: Iconsax.flag,
                ),
                
                const SizedBox(height: 24),
                
                // Services Grid
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode ? AppColors.secondaryDark : Colors.white,
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
                        'خدماتنا',
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode ? AppColors.pureWhite : Colors.black
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildServiceItem(
                              icon: Iconsax.home_2,
                              title: 'تصميم المباني',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildServiceItem(
                              icon: Iconsax.eye,
                              title: 'الإشراف على التنفيذ',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildServiceItem(
                              icon: Iconsax.setting_2,
                              title: 'حلول تقنية',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildServiceItem(
                              icon: Iconsax.medal_star,
                              title: 'جودة وابتكار',
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
      }
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode ? AppColors.secondaryDark : Colors.white,
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
                      color: themeProvider.isDarkMode ? AppColors.primaryDark : AppColors.primary.withAlpha(51),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: themeProvider.isDarkMode ? AppColors.pureWhite : Colors.black,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color:  themeProvider.isDarkMode ? AppColors.pureWhite : Colors.black
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
                  color: themeProvider.isDarkMode ? AppColors.pureWhite : Colors.black,
                ),
                textAlign: TextAlign.justify,
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildServiceItem({
    required IconData icon,
    required String title,
  }) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode ? AppColors.primaryDark : AppColors.primary.withAlpha(25),
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
                color: themeProvider.isDarkMode ? AppColors.pureWhite : Colors.black,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: themeProvider.isDarkMode ? AppColors.pureWhite : Colors.black
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
    );
  }
}
