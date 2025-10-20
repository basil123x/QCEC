import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:QCEC/core/constants/app_colors.dart';
import 'package:QCEC/presentation/providers/auth_provider.dart';

class VisitCard extends StatelessWidget {
  final Map<String, dynamic> visit;
  final int serialNumber;
  final AuthProvider authProvider;

  const VisitCard({
    Key? key,
    required this.visit,
    required this.serialNumber,
    required this.authProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with serial number
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '$serialNumber',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer name
                      Text(
                        visit['cname'] ?? 'عميل غير محدد',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      // Project name
                      if (visit['proj'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          visit['proj'],
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Visit details
            _buildVisitDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitDetails() {
    return Column(
      children: [
        // Engineer and place
        Row(
          children: [
            Expanded(
              child: _buildDetailRow(
                icon: Iconsax.user_octagon,
                label: 'المهندس',
                value: visit['ename'] ?? 'غير محدد',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDetailRow(
                icon: Iconsax.location,
                label: 'المكان',
                value: visit['place'] ?? 'غير محدد',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Contractor if available
        if (visit['cn_name'] != null) ...[
          _buildDetailRow(
            icon: Iconsax.building_4,
            label: 'المقاول',
            value: visit['cn_name'],
          ),
          const SizedBox(height: 8),
        ],

        // Visit notes if available
        if (visit['a2'] != null && visit['a2'].toString().isNotEmpty) ...[
          _buildDetailRow(
            icon: Iconsax.note_1,
            label: 'ملاحظات',
            value: visit['a2'],
            isMultiline: true,
          ),
          const SizedBox(height: 8),
        ],

        // Additional info if available
        if (visit['a4'] != null && visit['a4'].toString().isNotEmpty) ...[
          _buildDetailRow(
            icon: Iconsax.info_circle,
            label: 'معلومات إضافية',
            value: visit['a4'],
            isMultiline: true,
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label:',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                maxLines: isMultiline ? null : 1,
                overflow: isMultiline ? null : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
