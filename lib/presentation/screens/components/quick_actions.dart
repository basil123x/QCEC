import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../providers/auth_provider.dart';

class QuickActions extends StatelessWidget {
  final AuthProvider authProvider;
  final Function(int) onTabChange;
  final VoidCallback onComingSoon;

  const QuickActions({
    super.key,
    required this.authProvider,
    required this.onTabChange,
    required this.onComingSoon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الإجراءات السريعة',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: _buildQuickActionsList(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildQuickActionsList() {
    List<Widget> actions = [];

    // Common actions for all users
    actions.add(
      _buildActionCard(
        icon: Iconsax.folder_2,
        title: 'المشاريع',
        subtitle: 'عرض جميع المشاريع',
        color: Colors.blue,
        onTap: () => onTabChange(1),
      ),
    );

    actions.add(
      _buildActionCard(
        icon: Iconsax.calendar,
        title: 'الزيارات',
        subtitle: 'جدولة ومتابعة الزيارات',
        color: Colors.green,
        onTap: () => onTabChange(2),
      ),
    );

    // Engineer specific actions
    if (authProvider.isEngineer()) {
      actions.add(
        _buildActionCard(
          icon: Iconsax.camera,
          title: 'زيارة جديدة',
          subtitle: 'تسجيل زيارة جديدة',
          color: Colors.teal,
          onTap: onComingSoon,
        ),
      );
    }

    return actions;
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(51),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
