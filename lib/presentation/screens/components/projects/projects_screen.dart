import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:qcec/presentation/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'project_card.dart';

class ProjectsScreen extends StatefulWidget {
  final AuthProvider authProvider;
  final List<Map<String, dynamic>> projects;
  final bool isLoadingProjects;
  final bool hasLoadedProjects;
  final String searchQuery;
  final ScrollController scrollController;
  final Set<int> expandedProjects;
  final int? activeProjectId;
  final Map<int, GlobalKey> projectKeys;
  final Function(int?) onActiveProjectChange;
  final Function(Set<int>) onExpandedProjectsChange;

  const ProjectsScreen({
    Key? key,
    required this.authProvider,
    required this.projects,
    required this.isLoadingProjects,
    required this.hasLoadedProjects,
    required this.searchQuery,
    required this.scrollController,
    required this.expandedProjects,
    required this.activeProjectId,
    required this.projectKeys,
    required this.onActiveProjectChange,
    required this.onExpandedProjectsChange,
  }) : super(key: key);

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(child: _buildProjectsList()),
        ],
      ),
    );
  }

  Widget _buildProjectsList() {
    // Use cached projects if available
    if (widget.isLoadingProjects) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.projects.isEmpty && widget.hasLoadedProjects) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.folder_minus, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'لا توجد مشاريع',
              style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final allProjects = widget.projects;

    // Filter projects based on search query
    final filteredProjects = widget.searchQuery.isEmpty
        ? allProjects
        : allProjects.where((project) {
            final searchLower = widget.searchQuery.toLowerCase();
            final projectMap = project as Map<String, dynamic>;

            return (projectMap['projx']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (projectMap['cname']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (projectMap['cphone']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (projectMap['place']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (projectMap['ename']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (projectMap['cnname']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (projectMap['pin']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false);
          }).toList();

    if (filteredProjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.searchQuery.isEmpty
                  ? Iconsax.folder_minus
                  : Iconsax.search_normal,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              widget.searchQuery.isEmpty
                  ? 'لا توجد مشاريع في هذا التاريخ'
                  : 'لا توجد نتائج للبحث عن "${widget.searchQuery}"',
              style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: filteredProjects.length,
      itemBuilder: (context, index) {
        final project = filteredProjects[index] as Map<String, dynamic>;
        return ProjectCard(
          project: project,
          serialNumber: index + 1,
          expandedProjects: widget.expandedProjects,
          activeProjectId: widget.activeProjectId,
          projectKeys: widget.projectKeys,
          onActiveProjectChange: widget.onActiveProjectChange,
          onExpandedProjectsChange: widget.onExpandedProjectsChange,
        );
      },
    );
  }
}
