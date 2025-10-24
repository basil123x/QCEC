import 'package:QCEC/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:QCEC/core/constants/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProjectCard extends StatefulWidget {
  final Map<String, dynamic> project;
  final int serialNumber;
  final Set<int> expandedProjects;
  final int? activeProjectId;
  final Map<int, GlobalKey> projectKeys;
  final Function(int?) onActiveProjectChange;
  final Function(Set<int>) onExpandedProjectsChange;

  const ProjectCard({
    Key? key,
    required this.project,
    required this.serialNumber,
    required this.expandedProjects,
    required this.activeProjectId,
    required this.projectKeys,
    required this.onActiveProjectChange,
    required this.onExpandedProjectsChange,
  }) : super(key: key);

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  Future<void> _saveActiveProject(int? projectId) async {
    final prefs = await SharedPreferences.getInstance();
    if (projectId != null) {
      await prefs.setInt('active_project_id', projectId);
    } else {
      await prefs.remove('active_project_id');
    }
  }

  Future<void> _saveExpandedProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final expandedList = widget.expandedProjects
        .map((id) => id.toString())
        .toList();
    await prefs.setStringList('expanded_projects', expandedList);
  }

  @override
  Widget build(BuildContext context) {
    final projectId = int.tryParse(widget.project['id'].toString()) ?? 0;
    bool isExpanded = widget.expandedProjects.contains(projectId);
    bool isActive = widget.activeProjectId == projectId;

    // Create or get GlobalKey for this project
    if (!widget.projectKeys.containsKey(projectId)) {
      widget.projectKeys[projectId] = GlobalKey();
    }
    final projectKey = widget.projectKeys[projectId]!;

    return GestureDetector(
      onTap: () {
        final newActiveId = isActive ? null : projectId;
        widget.onActiveProjectChange(newActiveId);

        // Save to SharedPreferences
        _saveActiveProject(newActiveId);
        debugPrint('💾 Active project saved: $newActiveId');
      },
      child: Container(
        key: projectKey,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(color: AppColors.primary, width: 3)
              : Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? AppColors.primary.withAlpha(76)
                  : Colors.black.withAlpha(25),
              blurRadius: isActive ? 15 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with serial number and expand button
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
                        '${widget.serialNumber}',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. اسم العميل
                        Row(
                          children: [
                            Icon(
                              Iconsax.user,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 170,
                              child: Text(
                                widget.project['cname'] ?? 'عميل غير محدد',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Expand/Collapse button
                  GestureDetector(
                    onTap: () {
                      Set<int> newExpandedProjects = Set.from(
                        widget.expandedProjects,
                      );
                      if (isExpanded) {
                        newExpandedProjects.remove(projectId);
                      } else {
                        newExpandedProjects.add(projectId);
                      }
                      widget.onExpandedProjectsChange(newExpandedProjects);
                      // Save expanded projects state
                      _saveExpandedProjects();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? AppColors.primary.withAlpha(51)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Iconsax.arrow_down_1,
                          color: isExpanded
                              ? AppColors.primary
                              : Colors.grey[600],
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Basic project info
              _buildBasicInfo(),

              // Expanded content
              if (isExpanded) ...[
                const SizedBox(height: 16),
                _buildExpandedContent(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Column(
      children: [
        // 2 & 3. رقم العميل ورقم البطاقة
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(Iconsax.call, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    widget.project['cphone'] ?? 'غير محدد',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Icon(Iconsax.card, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.project['cqid'] ?? 'غير محدد',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 4. المقاول
        if (widget.project['cnname'] != null) ...[
          Row(
            children: [
              Icon(Iconsax.building_4, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${AppLocalizations.of(context)!.contractor}: ${widget.project['cnname']}',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildExpandedContent() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تفاصيل إضافية',
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),

          // Additional project details can be added here
          if (widget.project['place'] != null) ...[
            Row(
              children: [
                Icon(Iconsax.location, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الموقع: ${widget.project['place']}',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],

          if (widget.project['ename'] != null) ...[
            Row(
              children: [
                Icon(Iconsax.user_octagon, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${AppLocalizations.of(context)!.engineer}: ${widget.project['ename']}',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
