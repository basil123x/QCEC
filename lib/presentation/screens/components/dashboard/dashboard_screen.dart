import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:QCEC/presentation/providers/auth_provider.dart';
import '../quick_actions.dart';
import 'top_stats.dart';

class DashboardScreen extends StatelessWidget {
  final AuthProvider authProvider;
  final DateTime selectedDate;
  final Function(int) onTabChange;
  final VoidCallback onComingSoon;

  const DashboardScreen({
    super.key,
    required this.authProvider,
    required this.selectedDate,
    required this.onTabChange,
    required this.onComingSoon,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
            _buildWelcomeSection(),
            
            // Top stats (only for admin)
            if (authProvider.isAdmin()) 
              TopStats(
                authProvider: authProvider,
                selectedDate: selectedDate,
              ),
            
            // Quick actions
            QuickActions(
              authProvider: authProvider,
              onTabChange: onTabChange,
              onComingSoon: onComingSoon,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مرحباً، ${authProvider.getUserName()}',
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            authProvider.getUserTypeName(),
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
