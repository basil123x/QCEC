import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  final AuthProvider authProvider;

  const ProfileScreen({
    Key? key,
    required this.authProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
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
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primary.withAlpha(51),
                    backgroundImage: authProvider.getUserImageUrl().isNotEmpty
                        ? NetworkImage(authProvider.getUserImageUrl())
                        : null,
                    child: authProvider.getUserImageUrl().isEmpty
                        ? Icon(Iconsax.user, color: AppColors.primary, size: 40)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authProvider.getUserName(),
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    authProvider.getUserTypeName(),
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'معرف المستخدم: ${authProvider.getUserId()}',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Logout button
            Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await authProvider.logout();
                },
                icon: Icon(Iconsax.logout, size: 20),
                label: Text(
                  'تسجيل الخروج',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
