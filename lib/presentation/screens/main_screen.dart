import 'dart:convert';
import 'dart:io';
import 'package:QCEC/presentation/screens/about_us_screen.dart';
import 'package:QCEC/presentation/screens/contact_us_screen.dart';
import 'package:QCEC/services/translation_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart' as intlx;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'login_screen.dart';
import 'camera_working.dart';
import '../widgets/stats_section.dart';
import '../widgets/full_screen_video_player.dart';
import '../../services/app_lifecycle_service.dart';
import '../../widgets/incomplete_visit_dialog.dart';
import 'add_visit_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  DateTime _selectedDate = DateTime.now();
  Set<int> _expandedProjects = {};
  bool _isSearching = false;
  String _searchQuery = '';
  String prox = "";
  final TextEditingController _searchController = TextEditingController();

  // Search for visits
  bool _isSearchingVisits = false;
  String _searchQueryVisits = '';
  final TextEditingController _searchControllerVisits = TextEditingController();
  int? _activeProjectId;
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _projects = [];
  String _currentDate = '';
  final Map<int, GlobalKey> _projectKeys = {};
  bool _isLoadingProjects = false;
  bool _hasLoadedProjects = false;

  // Cache for visits data
  Map<String, Map<String, dynamic>> _visitsCache = {};
  bool _isLoadingVisits = false;

  // For expandable text and photos
  Set<int> _expandedNotes = {};
  Set<int> _expandedPhotos = {};
  Map<int, int> _currentPhotoIndex = {};

  bool _showingStats = false; // Toggle between visits and statistics

  // Current visit ID for camera session
  int? _currentVisitId;

  @override
  void initState() {
    super.initState();
    _loadActiveProject();
    _loadProjectsOnce();
    _checkIncompleteVisits();
  }

  int _getMediaCount(Map<String, dynamic> visit) {
    // For now, assume same count as photos
    // In future, this should check both images and videos folders
    return _getPhotosCount(visit);
  }

  void _logout(AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'تسجيل الخروج',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'هل أنت متأكد من تسجيل الخروج؟',
            style: GoogleFonts.cairo(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textSecondaryDark
                      : Colors.grey[600],
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await authProvider.logout();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: Text(
                'تسجيل الخروج',
                style: GoogleFonts.cairo(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFullScreenImage(String imageUrl, int imageNumber) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(0),
          child: Stack(
            children: [
              // Full screen image
              Center(
                child: InteractiveViewer(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              color: Theme.of(context).cardColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'جاري تحميل الصورة...',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                color: Theme.of(context).cardColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.image,
                              size: 80,
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا يمكن تحميل الصورة',
                              style: GoogleFonts.cairo(
                                fontSize: 18,
                                color: Theme.of(context).cardColor,
                              ),
                            ),
                            Text(
                              'صورة رقم $imageNumber',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 50,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Iconsax.close_circle,
                      color: Theme.of(context).cardColor,
                      size: 24,
                    ),
                  ),
                ),
              ),
              // Image info
              Positioned(
                bottom: 50,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'صورة رقم $imageNumber',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      color: Theme.of(context).cardColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Scroll to active project if it exists when widget updates
    if (_activeProjectId != null && _projects.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollToActiveProject();
        });
      });
    }
  }

  Future<void> _loadActiveProject() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getInt('active_project_id');
    if (activeId != null) {
      setState(() {
        _activeProjectId = activeId;
      });
      debugPrint('📂 Active project loaded: $activeId');
    } else {
      debugPrint('📂 No active project found in storage');
    }

    // Load expanded projects state
    final expandedList = prefs.getStringList('expanded_projects') ?? [];
    final expandedIds = expandedList.map((id) => int.tryParse(id) ?? 0).toSet();
    setState(() {
      _expandedProjects = expandedIds;
    });
    debugPrint('📂 Expanded projects loaded: $expandedIds');
  }

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
    final expandedList = _expandedProjects.map((id) => id.toString()).toList();
    await prefs.setStringList('expanded_projects', expandedList);
  }

  Future<void> _loadProjectsOnce() async {
    if (_hasLoadedProjects || _isLoadingProjects) return;

    setState(() {
      _isLoadingProjects = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.getProjects();

      if (result['success'] && mounted) {
        setState(() {
          _projects = List<Map<String, dynamic>>.from(result['projects'] ?? []);
          _currentDate = result['dayx'] ?? '';
          _hasLoadedProjects = true;
        });

        // Clean up old project keys that are no longer in the projects list
        final currentProjectIds = _projects
            .map((p) => int.tryParse(p['id'].toString()) ?? 0)
            .toSet();
        _projectKeys.removeWhere(
          (key, value) => !currentProjectIds.contains(key),
        );

        // Auto scroll to active project after loading
        if (_activeProjectId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Add a delay to ensure the UI is fully rendered and keys are available
            Future.delayed(const Duration(milliseconds: 500), () {
              _scrollToActiveProject();
            });
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading projects: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProjects = false;
        });
      }
    }
  }

  Future<void> _refreshProjects(AuthProvider authProvider) async {
    try {
      final result = await authProvider.getProjects();

      if (result['success'] && mounted) {
        setState(() {
          _projects = List<Map<String, dynamic>>.from(result['projects'] ?? []);
          _currentDate = result['dayx'] ?? '';
        });

        // Clean up old project keys that are no longer in the projects list
        final currentProjectIds = _projects
            .map((p) => int.tryParse(p['id'].toString()) ?? 0)
            .toSet();
        _projectKeys.removeWhere(
          (key, value) => !currentProjectIds.contains(key),
        );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تحديث المشاريع بنجاح',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error refreshing projects: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في تحديث المشاريع', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _refreshVisits(AuthProvider authProvider) async {
    try {
      final dateKey = intlx.DateFormat('yyyy-MM-dd').format(_selectedDate);

      // Clear cache for current date to force reload
      _visitsCache.remove(dateKey);

      prox = "";

      // Reload visits data
      final result = await _loadVisitsData(authProvider, dateKey);

      if (result['success'] && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تحديث الزيارات بنجاح',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        // Trigger rebuild
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error refreshing visits: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في تحديث الزيارات', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _refreshEngineersStats(AuthProvider authProvider) async {
    try {
      // Force refresh of engineers stats
      // This will depend on how the stats are loaded - for now just show success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحديث إحصائيات المهندسين بنجاح',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // Trigger rebuild
      setState(() {});
    } catch (e) {
      debugPrint('Error refreshing engineers stats: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل في تحديث إحصائيات المهندسين',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _scrollToActiveProject() {
    if (_activeProjectId == null || _projects.isEmpty) return;

    // Wait for ScrollController to be ready
    if (!_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToActiveProject();
      });
      return;
    }

    // Try using GlobalKey approach first
    final projectKey = _projectKeys[_activeProjectId];
    if (projectKey != null && projectKey.currentContext != null) {
      try {
        Scrollable.ensureVisible(
          projectKey.currentContext!,
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOutCubic,
          alignment: 0.2, // Position at 20% from top of viewport
        );
        debugPrint('✅ Using ensureVisible for project $_activeProjectId');
        return;
      } catch (e) {
        debugPrint(
          '⚠️ ensureVisible failed, falling back to manual calculation: $e',
        );
      }
    }

    // Fallback to manual calculation
    final activeIndex = _projects.indexWhere((project) {
      final projectId = int.tryParse(project['id'].toString()) ?? 0;
      return projectId == _activeProjectId;
    });

    if (activeIndex != -1) {
      try {
        // Use a more accurate approach by calculating cumulative heights
        double totalOffset = 0.0;

        // Calculate the offset by summing up heights of all cards before the target
        for (int i = 0; i < activeIndex; i++) {
          final projectId = int.tryParse(_projects[i]['id'].toString()) ?? 0;

          // More accurate base card height measurement
          double cardHeight =
              160.0; // Increased base height to match actual card

          // Add expanded content height if this project is expanded
          if (_expandedProjects.contains(projectId)) {
            cardHeight += 220.0; // Height for expanded content (visits list)
          }

          // Add margin
          cardHeight += 16.0;

          totalOffset += cardHeight;
        }

        // Add some padding to center the target card better
        final double viewportHeight =
            _scrollController.position.viewportDimension;
        final double centeredOffset = totalOffset - (viewportHeight * 0.15);

        final double maxScrollExtent =
            _scrollController.position.maxScrollExtent;
        final double finalOffset = centeredOffset.clamp(0.0, maxScrollExtent);

        _scrollController.animateTo(
          finalOffset,
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOutCubic,
        );

        debugPrint(
          '✅ Manual scroll to project $_activeProjectId (index: $activeIndex)',
        );
        debugPrint(
          '📏 Calculated offset: $totalOffset, Final offset: $finalOffset',
        );
        debugPrint(
          '📋 Total projects: ${_projects.length}, Expanded: ${_expandedProjects.length}',
        );
      } catch (e) {
        debugPrint('❌ Error scrolling to active project: $e');
      }
    } else {
      debugPrint(
        '⚠️ Active project $_activeProjectId not found in projects list',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isLoggedIn) {
          return const LoginScreen();
        }

        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return Scaffold(
              backgroundColor: themeProvider.isDarkMode
                  ? AppColors.primaryDark
                  : AppColors.pureWhite,
              appBar: _buildAppBar(authProvider, themeProvider),
              body: _buildBody(authProvider),
              bottomNavigationBar: _buildBottomNavBar(authProvider),
              floatingActionButton: _buildFloatingActionButton(authProvider),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerDocked,
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    AuthProvider authProvider,
    ThemeProvider themeProvider,
  ) {
    // Show welcome message only on home screen
    if (_selectedIndex == 0) {
      return AppBar(
        backgroundColor: themeProvider.isDarkMode
            ? AppColors.secondaryDark
            : AppColors.pureWhite,
        elevation: 0,
        centerTitle: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              child: Text(
                AppLocalizations.of(context)!.home,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withAlpha(51),
              backgroundImage: authProvider.getUserImageUrl().isNotEmpty
                  ? NetworkImage(authProvider.getUserImageUrl())
                  : null,
              child: authProvider.getUserImageUrl().isEmpty
                  ? Icon(Iconsax.user, color: AppColors.primary, size: 20)
                  : null,
            ),
          ),
        ],
      );
    } else if (_selectedIndex == 2) {
      return AppBar(
        backgroundColor: themeProvider.isDarkMode
            ? AppColors.secondaryDark
            : AppColors.pureWhite,
        elevation: 0,
        centerTitle: true,
        title: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withAlpha(13),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (authProvider.isAdmin())
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showingStats = !_showingStats;
                    });
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _showingStats
                          ? Colors.green.withAlpha(51)
                          : Colors.blue.withAlpha(51),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _showingStats ? Iconsax.chart_success : Iconsax.chart_2,
                      color: _showingStats ? Colors.green : Colors.blue,
                      size: 20,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.allVisits,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _showComingSoon('البحث في الزيارات'),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Iconsax.search_normal,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // For other screens, show page title and search (for projects only)
    String pageTitle = '';

    if (authProvider.isEngineer()) {
      // For engineers: 0=Home, 1=Projects, 2=Camera, 3=Visits, 4=Profile
      switch (_selectedIndex) {
        case 0:
          pageTitle = AppLocalizations.of(context)!.home;
          break;
        case 1:
          pageTitle = AppLocalizations.of(context)!.allProjects;
          break;
        case 3:
          pageTitle = AppLocalizations.of(context)!.visits;
          break;
        case 4:
          pageTitle = AppLocalizations.of(context)!.profile;
          break;
      }
    } else {
      // For others: 0=Home, 1=Projects, 2=Visits, 3=Profile
      switch (_selectedIndex) {
        case 1:
          pageTitle = AppLocalizations.of(context)!.allProjects;
          break;
        case 3:
          pageTitle = AppLocalizations.of(context)!.profile;
          break;
      }
    }

    return AppBar(
      backgroundColor: themeProvider.isDarkMode
          ? AppColors.secondaryDark
          : AppColors.pureWhite,
      elevation: 0,
      centerTitle: !_isSearching && !_isSearchingVisits,
      title: _isSearching && _selectedIndex == 1
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchProjects,
                hintStyle: GoogleFonts.cairo(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              style: GoogleFonts.cairo(
                fontSize: 16,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            )
          : _isSearchingVisits &&
                (_selectedIndex == 3 ||
                    (_selectedIndex == 2 && authProvider.isEngineer()))
          ? TextField(
              controller: _searchControllerVisits,
              autofocus: true,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchVisits,
                hintStyle: GoogleFonts.cairo(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              style: GoogleFonts.cairo(
                fontSize: 16,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQueryVisits = value;
                });
              },
            )
          : Text(
              pageTitle,
              style: GoogleFonts.cairo(
                fontSize: 20,
                color: Theme.of(context).textTheme.titleLarge?.color,
                fontWeight: FontWeight.bold,
              ),
            ),
      leading: _isSearching
          ? IconButton(
              icon: Icon(
                Iconsax.arrow_right_3,
                color: Theme.of(context).iconTheme.color,
              ),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            )
          : _isSearchingVisits
          ? IconButton(
              icon: Icon(
                Iconsax.arrow_right_3,
                color: Theme.of(context).iconTheme.color,
              ),
              onPressed: () {
                setState(() {
                  _isSearchingVisits = false;
                  _searchQueryVisits = '';
                  _searchControllerVisits.clear();
                });
              },
            )
          : null,
      actions: [
        if (_selectedIndex == 1) // Only show search in projects tab
          IconButton(
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isSearching ? Iconsax.close_square : Iconsax.search_normal,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
        if (_selectedIndex == 3 ||
            (_selectedIndex == 2 &&
                authProvider.isEngineer())) // Show search in visits tab
          IconButton(
            onPressed: () {
              setState(() {
                if (_isSearchingVisits) {
                  _isSearchingVisits = false;
                  _searchQueryVisits = '';
                  _searchControllerVisits.clear();
                } else {
                  _isSearchingVisits = true;
                }
              });
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isSearchingVisits
                    ? Iconsax.close_square
                    : Iconsax.search_normal,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
        if (_selectedIndex == 0) // Only show profile pic on home screen
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withAlpha(51),
              backgroundImage: authProvider.getUserImageUrl().isNotEmpty
                  ? NetworkImage(authProvider.getUserImageUrl())
                  : null,
              child: authProvider.getUserImageUrl().isEmpty
                  ? Icon(Iconsax.user, color: AppColors.primary, size: 20)
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _buildBody(AuthProvider authProvider) {
    if (authProvider.isEngineer()) {
      // For engineers: 0=Home, 1=Projects, 2=Camera, 3=Visits, 4=Profile
      switch (_selectedIndex) {
        case 0:
          return _buildDashboard(authProvider);
        case 1:
          return _buildProjects(authProvider);
        case 2:
          return _buildComingSoonScreen(
            'الكاميرا',
            'يتم فتح الكاميرا تلقائياً عند الضغط على الزر',
          );
        case 3:
          return _buildVisits(authProvider);
        case 4:
          return _buildProfile(authProvider);
        default:
          return _buildDashboard(authProvider);
      }
    } else {
      // For others: 0=Home, 1=Projects, 2=Visits, 3=Profile
      switch (_selectedIndex) {
        case 0:
          return _buildDashboard(authProvider);
        case 1:
          return _buildProjects(authProvider);
        case 2:
          return _buildVisits(authProvider);
        case 3:
          return _buildProfile(authProvider);
        default:
          return _buildDashboard(authProvider);
      }
    }
  }

  Widget _buildDashboard(AuthProvider authProvider) {
    print(ThemeProvider().isDarkMode);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      themeProvider.isDarkMode
                          ? AppColors.primaryDark
                          : AppColors.primary,
                      themeProvider.isDarkMode
                          ? AppColors.secondaryDark
                          : AppColors.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.welcome,
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.companyName,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor.withAlpha(51),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${AppLocalizations.of(context)!.userType}: ${authProvider.getUserTypeName()}',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Quick Actions
          Text(
            AppLocalizations.of(context)!.quickActions,
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textPrimaryDark
                  : Colors.grey[800],
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
            children: _buildQuickActions(authProvider),
          ),

          const SizedBox(height: 32),

          // Statistics Section
          const StatsSection(),
        ],
      ),
    );
  }

  List<Widget> _buildQuickActions(AuthProvider authProvider) {
    List<Widget> actions = [];

    // Common actions for all users
    actions.add(
      _buildActionCard(
        icon: Iconsax.folder_2,
        title: AppLocalizations.of(context)!.projects,
        subtitle: AppLocalizations.of(context)!.viewAllProjects,
        color: Colors.blue,
        onTap: () => setState(() => _selectedIndex = 1),
      ),
    );

    actions.add(
      _buildActionCard(
        icon: Iconsax.calendar,
        title: AppLocalizations.of(context)!.visits,
        subtitle: AppLocalizations.of(context)!.scheduleVisits,
        color: Colors.green,
        onTap: () => setState(() => _selectedIndex = 2),
      ),
    );

    // Engineer specific actions
    if (authProvider.isEngineer()) {
      actions.add(
        _buildActionCard(
          icon: Iconsax.camera,
          title: AppLocalizations.of(context)!.newVisit,
          subtitle: AppLocalizations.of(context)!.recordNewVisit,
          color: Colors.teal,
          onTap: () {
            _showComingSoon('تسجيل زيارة جديدة');
          },
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
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode
                  ? AppColors.secondaryDark
                  : AppColors.pureWhite,
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
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textPrimaryDark
                        : Colors.grey[800],
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondaryDark
                        : Colors.grey[600],
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProjects(AuthProvider authProvider) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refreshProjects(authProvider),
              color: AppColors.primary,
              child: _buildProjectsList(authProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonScreen(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(102),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Iconsax.camera,
              color: Theme.of(context).cardColor,
              size: 50,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textPrimaryDark
                  : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVisits(AuthProvider authProvider) {
    return SafeArea(
      child: Column(
        children: [
          // Date Navigation Bar
          _buildDateNavigationBar(),
          // Content - either visits or statistics
          Expanded(
            child: _showingStats
                ? RefreshIndicator(
                    onRefresh: () => _refreshEngineersStats(authProvider),
                    color: AppColors.primary,
                    child: _buildEngineersStatsFullScreen(authProvider),
                  )
                : RefreshIndicator(
                    onRefresh: () => _refreshVisits(authProvider),
                    color: AppColors.primary,
                    child: _buildVisitsList(authProvider),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile(AuthProvider authProvider) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        themeProvider.isDarkMode
                            ? AppColors.primaryDark
                            : AppColors.primary,
                        themeProvider.isDarkMode
                            ? AppColors.secondaryDark
                            : AppColors.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: themeProvider.isDarkMode
                            ? AppColors.primaryDark.withAlpha(102)
                            : AppColors.primary.withAlpha(102),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(
                          context,
                        ).cardColor.withAlpha(51),
                        backgroundImage:
                            authProvider.getUserImageUrl().isNotEmpty
                            ? NetworkImage(authProvider.getUserImageUrl())
                            : null,
                        child: authProvider.getUserImageUrl().isEmpty
                            ? Icon(
                                Iconsax.user,
                                color: Theme.of(context).cardColor,
                                size: 40,
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        authProvider.getUserName(),
                        style: GoogleFonts.cairo(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor.withAlpha(51),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Text(
                          authProvider.getUserTypeName(),
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Settings Options
            _buildSettingsSection(authProvider),

            const SizedBox(height: 24),

            // Logout Button
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _logout(authProvider);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Iconsax.logout, color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)!.logout,
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(AuthProvider authProvider) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Consumer<LanguageProvider>(
          builder: (context, languageProvider, child) {
            final localizations = AppLocalizations.of(context)!;
            return Container(
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode
                    ? AppColors.secondaryDark
                    : AppColors.pureWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSettingsItem(
                    icon: Iconsax.language_circle,
                    title: localizations.changeLanguage,
                    subtitle: languageProvider.currentLanguageName,
                    onTap: () => _showLanguageDialog(),
                    color: Colors.blue,
                  ),
                  _buildDivider(),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return _buildThemeToggleItem(themeProvider);
                    },
                  ),
                  _buildDivider(),
                  _buildSettingsItem(
                    icon: Iconsax.info_circle,
                    title: localizations.aboutUs,
                    subtitle: localizations.learnAboutQCEC,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutUsScreen(),
                        ),
                      );
                    },
                    color: Colors.orange,
                  ),
                  _buildDivider(),
                  _buildSettingsItem(
                    icon: Iconsax.call,
                    title: localizations.contactUs,
                    subtitle:
                        "${localizations.contactMethods}\n ${localizations.contactInfo}",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContactUsScreen(),
                        ),
                      );
                    },
                    color: Colors.green,
                  ),
                  _buildDivider(),
                  _buildSettingsItem(
                    icon: Iconsax.trash,
                    title: localizations.deleteAccount,
                    subtitle: localizations.deleteAccountPermanently,
                    onTap: () =>
                        _showDeleteAccountDialog(context, localizations),
                    color: Colors.red,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteAccountDialog(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.bottomSlide,
      title: localizations.warning,
      desc: localizations.disableAccountConfirmationMessage,
      btnCancelText: localizations.cancel,
      btnOkText: localizations.disableAccount,
      btnCancelOnPress: () {},
      btnOkOnPress: () {
        _confirmDeleteAccount(context, localizations);
      },
      btnOkColor: Colors.red,
      btnCancelColor: Colors.grey,
      titleTextStyle: GoogleFonts.cairo(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.red,
      ),
      descTextStyle: GoogleFonts.cairo(
        fontSize: 16,
        color: Colors.grey[700],
        height: 1.5,
      ),
      buttonsTextStyle: GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      headerAnimationLoop: false,
      showCloseIcon: true,
    ).show();
  }

  void _confirmDeleteAccount(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    TextEditingController deleteController = TextEditingController();
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.scale,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              localizations.confirmDisable,
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              localizations.typeDisableMyAccount,
              style: GoogleFonts.cairo(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 16),
              controller: deleteController,
              decoration: InputDecoration(
                hintText: localizations.disableMyAccount,
                hintStyle: GoogleFonts.cairo(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red, width: 2),
                ),
              ),
              onChanged: (value) {
                // يمكن إضافة منطق التحقق هنا
              },
            ),
          ],
        ),
      ),
      btnCancelText: localizations.cancel,
      btnOkText: localizations.permanentDisable,
      btnCancelOnPress: () {},
      btnOkOnPress: () {
        if (deleteController.text.trim() == localizations.disableMyAccount) {
          _deleteAccount(context, localizations);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations.disableNotConfirmed,
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      btnOkColor: Colors.red,
      btnCancelColor: Colors.grey,
      buttonsTextStyle: GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      headerAnimationLoop: false,
      showCloseIcon: true,
    ).show();
  }

  void _deleteAccount(
    BuildContext context,
    AppLocalizations localizations,
  ) async {
    try {
      // Show loading dialog
      AwesomeDialog(
        context: context,
        dialogType: DialogType.info,
        animType: AnimType.scale,
        title: localizations.disablingAccount,
        desc: localizations.pleaseWaitDisablingAccount,
        dismissOnTouchOutside: false,
        dismissOnBackKeyPress: false,
        showCloseIcon: false,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
        descTextStyle: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[600]),
      ).show();

      // Prepare API request
      final dio = Dio();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final requestData = {
        'action': 'disable_user_account',
        'user_id': authProvider.getUserId(),
        'user_type': authProvider.getUserTypeName(),
      };

      // Make API call to delete account
      final response = await dio.post(
        'https://qcec.online/app2026/sql.php',
        data: requestData,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData['success'] == true) {
          // Account deleted successfully
          AwesomeDialog(
            context: context,
            dialogType: DialogType.success,
            animType: AnimType.topSlide,
            title: localizations.accountDisabledSuccessfully,
            desc: localizations.accountDisabledMessage,
            btnOkText: localizations.ok,
            btnOkOnPress: () async {
              // Logout and clear all data
              await authProvider.logout();
            },
            btnOkColor: Colors.green,
            titleTextStyle: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
            descTextStyle: GoogleFonts.cairo(
              fontSize: 16,
              color: Colors.grey[700],
              height: 1.5,
            ),
            buttonsTextStyle: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            headerAnimationLoop: false,
            showCloseIcon: false,
            dismissOnTouchOutside: false,
            dismissOnBackKeyPress: false,
          ).show();
        } else {
          // Server returned error
          _showErrorDialogx(
            context,
            responseData['message'] ?? 'خطأ في تعطيل الحساب',
          );
        }
      } else {
        _showErrorDialogx(context, 'خطأ في الاتصال بالخادم');
      }
    } catch (e) {
      // Close loading dialog if still open
      Navigator.of(context).pop();

      print('Error disabling account: $e');
      _showErrorDialogx(
        context,
        'حدث خطأ أثناء تعطيل الحساب. يرجى المحاولة مرة أخرى.',
      );
    }
  }

  void _showErrorDialogx(BuildContext context, String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.scale,
      title: 'خطأ',
      desc: message,
      btnOkText: 'موافق',
      btnOkOnPress: () {},
      btnOkColor: Colors.red,
      titleTextStyle: GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.red,
      ),
      descTextStyle: GoogleFonts.cairo(
        fontSize: 14,
        color: Colors.grey[700],
        height: 1.5,
      ),
      buttonsTextStyle: GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ).show();
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(51),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.titleLarge?.color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.cairo(
          fontSize: 14,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
        maxLines: 1,
      ),
      trailing: Icon(
        Iconsax.arrow_left_2,
        color: Theme.of(context).iconTheme.color?.withOpacity(0.6),
        size: 20,
      ),
    );
  }

  Widget _buildThemeToggleItem(ThemeProvider themeProvider) {
    final localizations = AppLocalizations.of(context)!;

    return ListTile(
      onTap: () async {
        await themeProvider.toggleTheme();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.themeChanged,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.purple.withAlpha(51),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          themeProvider.isDarkMode ? Iconsax.sun_1 : Iconsax.moon,
          color: Colors.purple,
          size: 24,
        ),
      ),
      title: Text(
        themeProvider.isDarkMode
            ? localizations.lightMode
            : localizations.darkMode,
        style: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.titleLarge?.color,
        ),
      ),
      subtitle: Text(
        themeProvider.isDarkMode
            ? localizations.enableLightMode
            : localizations.enableDarkMode,
        style: GoogleFonts.cairo(
          fontSize: 14,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
      trailing: Switch(
        value: themeProvider.isDarkMode,
        onChanged: (value) async {
          await themeProvider.toggleTheme();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations.themeChanged,
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceDark.withOpacity(0.8)
          : Colors.grey[200],
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildBottomNavBar(AuthProvider authProvider) {
    if (authProvider.isEngineer()) {
      return _buildEngineerBottomNavBar();
    } else {
      return _buildRegularBottomNavBar();
    }
  }

  Widget _buildEngineerBottomNavBar() {
    List<IconData> iconList = [
      Iconsax.home_2,
      Iconsax.folder_2,
      Iconsax.calendar,
      Iconsax.profile_circle,
    ];

    int displayIndex = _selectedIndex;
    if (_selectedIndex > 2) displayIndex = _selectedIndex - 1;
    if (displayIndex >= iconList.length) displayIndex = 0;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return AnimatedBottomNavigationBar(
          icons: iconList,
          activeIndex: displayIndex,
          gapLocation: GapLocation.center,
          notchSmoothness: NotchSmoothness.verySmoothEdge,
          leftCornerRadius: 32,
          rightCornerRadius: 32,
          backgroundColor: themeProvider.isDarkMode
              ? AppColors.secondaryDark
              : AppColors.pureWhite,
          activeColor: AppColors.primary,
          inactiveColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.textSecondaryDark
              : Colors.grey[600],
          splashColor: AppColors.primary.withAlpha(51),
          onTap: (index) {
            int actualIndex = index >= 2 ? index + 1 : index;
            setState(() => _selectedIndex = actualIndex);

            // If switching to projects tab and there's an active project, scroll to it
            if (actualIndex == 1 &&
                _activeProjectId != null &&
                _projects.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Future.delayed(const Duration(milliseconds: 400), () {
                  _scrollToActiveProject();
                });
              });
            }
          },
        );
      },
    );
  }

  Widget _buildRegularBottomNavBar() {
    List<IconData> iconList = [
      Iconsax.home_2,
      Iconsax.folder_2,
      Iconsax.calendar,
      Iconsax.profile_circle,
    ];

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return AnimatedBottomNavigationBar(
          icons: iconList,
          activeIndex: _selectedIndex,
          gapLocation: GapLocation.none,
          notchSmoothness: NotchSmoothness.verySmoothEdge,
          leftCornerRadius: 32,
          rightCornerRadius: 32,
          backgroundColor: themeProvider.isDarkMode
              ? AppColors.secondaryDark
              : AppColors.pureWhite,
          activeColor: AppColors.primary,
          inactiveColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.textSecondaryDark
              : Colors.grey[600],
          splashColor: AppColors.primary.withAlpha(51),
          onTap: (index) {
            setState(() => _selectedIndex = index);

            // If switching to projects tab and there's an active project, scroll to it
            if (index == 1 &&
                _activeProjectId != null &&
                _projects.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Future.delayed(const Duration(milliseconds: 400), () {
                  _scrollToActiveProject();
                });
              });
            }
          },
        );
      },
    );
  }

  Widget? _buildFloatingActionButton(AuthProvider authProvider) {
    if (authProvider.isEngineer()) {
      return FloatingActionButton(
        onPressed: () => _handleCameraButtonPress(authProvider),
        backgroundColor: AppColors.primary,
        child: Icon(Iconsax.camera, color: Theme.of(context).cardColor),
      );
    }
    return null;
  }

  void _handleCameraButtonPress(AuthProvider authProvider) async {
    // Check if there's an active project selected
    if (_activeProjectId == null) {
      _showErrorDialog(
        'لا يوجد مشروع محدد',
        'يرجى اختيار مشروع من قائمة المشاريع أولاً لبدء زيارة جديدة',
      );
      return;
    }

    // Show loading dialog
    _showLoadingDialog('جاري إنشاء زيارة جديدة...');

    try {
      // Create new visit via API
      final result = await authProvider.createNewVisit(
        _activeProjectId.toString(),
        authProvider.getUserId(),
      );

      // Hide loading dialog
      Navigator.of(context).pop();

      if (result['success'] == true) {
        // Save the visit ID for the camera session
        setState(() {
          _currentVisitId = result['visit_id'];
        });

        // Navigate directly to camera screen
        _openCameraScreen(result['visit_id']);

        debugPrint('✅ Visit created successfully: ${result['visit_id']}');
      } else {
        _showErrorDialog(
          'فشل في إنشاء الزيارة',
          result['message'] ?? 'حدث خطأ غير متوقع',
        );
      }
    } catch (e) {
      // Hide loading dialog
      Navigator.of(context).pop();

      _showErrorDialog(
        'خطأ في الاتصال',
        'تأكد من اتصالك بالإنترنت وحاول مرة أخرى',
      );

      debugPrint('❌ Error creating visit: $e');
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                message,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textPrimaryDark
                      : Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Iconsax.warning_2, color: Colors.red, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textPrimaryDark
                  : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'حسناً',
                style: GoogleFonts.cairo(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openCameraScreen(int visitId) async {
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (context) =>
            CameraWorking(visitId: visitId, projectId: _activeProjectId!),
      ),
    );

    if (result != null && result.isNotEmpty) {
      // Photos were captured successfully
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حفظ ${result.length} صورة للزيارة رقم $visitId',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // Reset visit ID after successful completion
      setState(() {
        _currentVisitId = null;
      });

      debugPrint('✅ Visit $visitId completed with ${result.length} photos');
    } else {
      // User cancelled or no photos taken
      setState(() {
        _currentVisitId = null;
      });
      debugPrint('❌ Visit $visitId cancelled or no photos taken');
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature قيد التطوير', style: GoogleFonts.cairo()),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDateAndTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) {
      return 'تاريخ غير محدد';
    }

    try {
      final dateTime = DateTime.parse(dateTimeString);
      final dateFormat = intlx.DateFormat('yyyy-MM-dd');
      final timeFormat = intlx.DateFormat('h:mm a');

      return '${dateFormat.format(dateTime)} - ${timeFormat.format(dateTime)}';
    } catch (e) {
      return dateTimeString;
    }
  }

  int _getPhotosCount(Map<String, dynamic> visit) {
    if (visit.containsKey('a8')) {
      final count = int.tryParse(visit['a8'].toString()) ?? 0;
      return count > 0 ? count : 0;
    }
    if (visit.containsKey('photos') && visit['photos'] is List) {
      final count = (visit['photos'] as List).length;
      return count > 0 ? count : 0;
    }
    return 0;
  }

  void _togglePhotosExpansion(int visitId) {
    setState(() {
      if (_expandedPhotos.contains(visitId)) {
        // إذا كانت الزيارة مفتوحة، أقفلها
        _expandedPhotos.remove(visitId);
      } else {
        // أقفل جميع الزيارات الأخرى أولاً
        _expandedPhotos.clear();
        // ثم افتح الزيارة الجديدة
        _expandedPhotos.add(visitId);
        _currentPhotoIndex[visitId] = 0;
      }
    });
  }

  Widget _buildExpandableText(
    String text,
    int visitId,
    StateSetter setLocalState,
  ) {
    final isExpanded = _expandedNotes.contains(visitId);
    final maxLines = isExpanded ? null : 2;

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (text.isEmpty || text == "لا توجد ملاحظات") {
          return Text(
            "لا توجد ملاحظات",
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          );
        }

        return FutureBuilder<String>(
          future: TranslationService().translateText(
            text: text,
            targetLanguage: languageProvider.currentLocale.toString(),
            sourceLanguage: 'ar',
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.amber[700]!,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.translatingNotes,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.amber[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              );
            }

            final translatedText = snapshot.data ?? text;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translatedText,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textPrimaryDark
                        : Colors.grey[800],
                    height: 1.4,
                  ),
                  maxLines: maxLines,
                  overflow: isExpanded ? null : TextOverflow.ellipsis,
                ),
                if (translatedText.length > 100) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      setLocalState(() {
                        if (_expandedNotes.contains(visitId)) {
                          _expandedNotes.remove(visitId);
                        } else {
                          _expandedNotes.add(visitId);
                        }
                      });
                    },
                    child: Text(
                      isExpanded ? 'عرض أقل' : 'اقرأ المزيد',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
                // Show translation indicator if text was translated
                if (languageProvider.currentLocale != 'ar' &&
                    translatedText != text) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.translate, size: 12, color: Colors.blue[600]),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)!.translated,
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          color: Colors.blue[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEngineersStatsFullScreen(AuthProvider authProvider) {
    final dateKey = intlx.DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Check user type and show appropriate content
    if (authProvider.isAdmin()) {
      // Show full statistics for admin
      return FutureBuilder<Map<String, dynamic>>(
        future: authProvider.getEngineersStats(datexx: dateKey),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Iconsax.warning_2,
                    size: 48,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textHintDark
                        : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'حدث خطأ في جلب الإحصائيات',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textSecondaryDark
                          : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          final result = snapshot.data;
          if (result == null || result['success'] != true) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Iconsax.chart_fail,
                    size: 48,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textHintDark
                        : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'حدث خطأ في جلب الإحصائيات',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textSecondaryDark
                          : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          final engineersStats = result['engineers_stats'] as List<dynamic>;

          if (engineersStats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Iconsax.chart_fail,
                    size: 48,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textHintDark
                        : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد إحصائيات في هذا التاريخ',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textSecondaryDark
                          : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'جرب تاريخ آخر أو تأكد من وجود زيارات',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textSecondaryDark
                          : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.grey[50]!, Colors.white],
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(51),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Iconsax.chart_success,
                          color: Colors.blue,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.engineersStats,
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.textPrimaryDark
                                    : Colors.grey[800],
                              ),
                            ),
                            Text(
                              intlx.DateFormat(
                                'yyyy-MM-dd',
                              ).format(_selectedDate),
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.textSecondaryDark
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Statistics List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: engineersStats.length,
                    itemBuilder: (context, index) {
                      final stat =
                          engineersStats[index] as Map<String, dynamic>;
                      return _buildEngineerStatCard(stat, index + 1);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else if (authProvider.isEngineer()) {
      // Show a circle with number for engineers
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.7),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${authProvider.getUserId()}',
                  style: GoogleFonts.cairo(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).cardColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'معرف المهندس',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textPrimaryDark
                    : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              authProvider.getUserName(),
              style: GoogleFonts.cairo(
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    } else {
      // For customers and contractors, show empty space
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[50],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Iconsax.chart,
                size: 64,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.borderDark
                    : Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'الإحصائيات غير متاحة',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textSecondaryDark
                      : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildEngineerStatCard(Map<String, dynamic> stat, int rank) {
    final percentage = stat['percentage'] ?? 0;
    final engineerName = stat['engineer_name'] ?? 'مهندس غير محدد';
    final visitsCount = stat['visits_count'] ?? 0;
    final totalAssigned = stat['total_assigned'] ?? 0;
    final engineerId = stat['engineer_id'] ?? '1';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Engineer photo
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primary.withAlpha(51),
              backgroundImage: NetworkImage(
                'https://qcec.online/erp2025/assets/users/$engineerId/images/1.jpg',
              ),
            ),
            const SizedBox(width: 16),
            // Engineer info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "م/ $engineerName",
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textPrimaryDark
                          : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$visitsCount من $totalAssigned زيارة',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textSecondaryDark
                          : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Progress bar
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppColors.surfaceDark.withOpacity(0.8)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: percentage / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                color: percentage > 80
                                    ? Colors.green
                                    : percentage > 60
                                    ? Colors.orange
                                    : Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (percentage > 80
                                      ? Colors.green
                                      : percentage > 60
                                      ? Colors.orange
                                      : Colors.red)
                                  .withAlpha(51),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$percentage%',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: percentage > 80
                                ? Colors.green
                                : percentage > 60
                                ? Colors.orange
                                : Colors.red,
                          ),
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

  Widget _buildEngineerStatItem(String name, int progress, String imageUrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.surfaceDark.withOpacity(0.8)
              : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.primary.withAlpha(51),
            backgroundImage: NetworkImage(imageUrl),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textPrimaryDark
                        : Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? AppColors.borderDark
                            : Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress > 80
                              ? Colors.green
                              : progress > 60
                              ? Colors.orange
                              : Colors.red,
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$progress%',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: progress > 80
                            ? Colors.green
                            : progress > 60
                            ? Colors.orange
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final localizations = AppLocalizations.of(context)!;

    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.scale,
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Iconsax.language_circle,
                    color: Colors.blue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    localizations.changeLanguage,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textPrimaryDark
                          : Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Language Options
            ...languageProvider.getSupportedLanguages().map((language) {
              final isSelected =
                  languageProvider.currentLanguageCode == language['code'];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: _buildLanguageOption(
                  language['name']!,
                  language['nativeName']!,
                  language['code']!,
                  isSelected,
                  languageProvider,
                ),
              );
            }).toList(),
          ],
        ),
      ),
    ).show();
  }

  Widget _buildLanguageOption(
    String displayName,
    String nativeName,
    String languageCode,
    bool isSelected,
    LanguageProvider languageProvider,
  ) {
    return GestureDetector(
      onTap: () async {
        Navigator.of(context).pop();

        await languageProvider.changeLanguage(languageCode);

        final localizations = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.languageChanged,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withAlpha(51)
                  : themeProvider.isDarkMode
                  ? AppColors.primaryDark
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : Theme.of(context).brightness == Brightness.dark
                    ? AppColors.borderDark
                    : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _getLanguageFlag(languageCode),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nativeName,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textPrimaryDark
                              : Colors.grey[800],
                        ),
                      ),
                      if (displayName != nativeName)
                        Text(
                          displayName,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppColors.textSecondaryDark
                                : Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Iconsax.tick_circle,
                      color: Theme.of(context).cardColor,
                      size: 16,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getLanguageFlag(String languageCode) {
    switch (languageCode) {
      case 'ar':
        return '🇸🇦';
      case 'en':
        return '🇺🇸';
      case 'ur':
        return '🇵🇰';
      case 'fa':
        return '🇮🇷';
      case 'bn':
        return '🇧🇩';
      case 'hi':
        return '🇮🇳';
      default:
        return '🌐';
    }
  }

  Widget _buildDateNavigationBar() {
    return Consumer<LanguageProvider>(
      builder: (context, localization, child) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: AppColors.primary.withAlpha(51)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.subtract(
                          const Duration(days: 1),
                        );

                        prox = "";

                        final oldDateKey = intlx.DateFormat(
                          'yyyy-MM-dd',
                        ).format(_selectedDate.add(const Duration(days: 1)));
                        _visitsCache.remove(oldDateKey);
                      });
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: themeProvider.isDarkMode
                            ? AppColors.primaryDark
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        AppLocalizations.of(context)?.localeName == 'ar' ||
                                AppLocalizations.of(context)?.localeName ==
                                    'ur' ||
                                AppLocalizations.of(context)?.localeName == 'fa'
                            ? Iconsax.arrow_right_4
                            : Iconsax.arrow_left_14,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: themeProvider.isDarkMode
                            ? AppColors.primaryDark
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getArabicDayName(_selectedDate.weekday),
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isBeforeToday()
                        ? () {
                            setState(() {
                              _selectedDate = _selectedDate.add(
                                const Duration(days: 1),
                              );
                              prox = "";

                              final oldDateKey = intlx.DateFormat('yyyy-MM-dd')
                                  .format(
                                    _selectedDate.subtract(
                                      const Duration(days: 1),
                                    ),
                                  );
                              _visitsCache.remove(oldDateKey);
                            });
                          }
                        : null,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isBeforeToday()
                            ? themeProvider.isDarkMode
                                  ? AppColors.secondaryDark
                                  : AppColors.primary
                            : Theme.of(context).brightness == Brightness.dark
                            ? AppColors.borderDark
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _isBeforeToday()
                            ? [
                                BoxShadow(
                                  color: Colors.black.withAlpha(25),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        AppLocalizations.of(context)?.localeName == 'ar' ||
                                AppLocalizations.of(context)?.localeName ==
                                    'ur' ||
                                AppLocalizations.of(context)?.localeName == 'fa'
                            ? Iconsax.arrow_left_1
                            : Iconsax.arrow_right_4,
                        color: _isBeforeToday()
                            ? Colors.white
                            : Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondaryDark
                            : Colors.grey[500],
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool _isBeforeToday() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selectedDateOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return selectedDateOnly.isBefore(todayDate);
  }

  String _getArabicDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'الإثنين';
      case 2:
        return 'الثلاثاء';
      case 3:
        return 'الأربعاء';
      case 4:
        return 'الخميس';
      case 5:
        return 'الجمعة';
      case 6:
        return 'السبت';
      case 7:
        return 'الأحد';
      default:
        return '';
    }
  }

  Widget _buildProjectsList(AuthProvider authProvider) {
    // Use cached projects if available
    if (_isLoadingProjects) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_projects.isEmpty && _hasLoadedProjects) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.folder_minus,
              size: 48,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textHintDark
                  : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد مشاريع',
              style: GoogleFonts.cairo(
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    final allProjects = _projects;

    // Filter projects based on search query
    final filteredProjects = _searchQuery.isEmpty
        ? allProjects
        : allProjects.where((project) {
            final searchLower = _searchQuery.toLowerCase();
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
              _searchQuery.isEmpty
                  ? Iconsax.folder_minus
                  : Iconsax.search_normal,
              size: 48,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textHintDark
                  : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'لا توجد مشاريع في هذا التاريخ'
                  : 'لا توجد نتائج للبحث عن "$_searchQuery"',
              style: GoogleFonts.cairo(
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: filteredProjects.length,
      itemBuilder: (context, index) {
        final project = filteredProjects[index] as Map<String, dynamic>;
        return _buildProjectCard(project, index + 1);
      },
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project, int serialNumber) {
    final projectId = int.tryParse(project['id'].toString()) ?? 0;
    bool isExpanded = _expandedProjects.contains(projectId);
    bool isActive = _activeProjectId == projectId;

    // Create or get GlobalKey for this project
    if (!_projectKeys.containsKey(projectId)) {
      _projectKeys[projectId] = GlobalKey();
    }
    final projectKey = _projectKeys[projectId]!;

    return GestureDetector(
      onTap: () {
        final newActiveId = isActive ? null : projectId;
        setState(() {
          _activeProjectId = newActiveId;
        });

        // Save to SharedPreferences
        _saveActiveProject(newActiveId);
        debugPrint('💾 Active project saved: $newActiveId');

        // No need to scroll here, will auto-scroll when loading
      },
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Container(
            key: projectKey,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode
                  ? AppColors.secondaryDark
                  : AppColors.pureWhite,
              borderRadius: BorderRadius.circular(16),
              border: isActive
                  ? Border.all(color: AppColors.primary, width: 3)
                  : Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.surfaceDark.withOpacity(0.8)
                          : Colors.grey[200]!,
                      width: 1,
                    ),
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
                            '$serialNumber',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).cardColor,
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
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.textSecondaryDark
                                      : Colors.grey[600],
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 170,
                                  child: Text(
                                    project['cname'] ?? 'عميل غير محدد',
                                    style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.textPrimaryDark
                                          : Colors.grey[800],
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
                          setState(() {
                            if (isExpanded) {
                              _expandedProjects.remove(projectId);
                            } else {
                              _expandedProjects.add(projectId);
                            }
                          });
                          // Save expanded projects state
                          _saveExpandedProjects();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isExpanded
                                ? AppColors.primary.withAlpha(51)
                                : Theme.of(context).brightness ==
                                      Brightness.dark
                                ? AppColors.surfaceDark
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
                                  : Theme.of(context).brightness ==
                                        Brightness.dark
                                  ? AppColors.textSecondaryDark
                                  : Colors.grey[600],
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2 & 3. رقم العميل ورقم البطاقة
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.call,
                              size: 16,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.textSecondaryDark
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              project['cphone'] ?? 'غير محدد',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.textPrimaryDark
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.card,
                              size: 16,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.textSecondaryDark
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                project['cqid'] ?? 'غير محدد',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.textPrimaryDark
                                      : Colors.grey[700],
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
                  if (project['cnname'] != null) ...[
                    Row(
                      children: [
                        Icon(
                          Iconsax.building_4,
                          size: 16,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textSecondaryDark
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${AppLocalizations.of(context)!.contractorName}: ${project['cnname']}',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.textPrimaryDark
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 5. رقم المقاول
                    Row(
                      children: [
                        Icon(
                          Iconsax.call,
                          size: 16,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textSecondaryDark
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${AppLocalizations.of(context)!.contractorPhone}: ${project['cnphone'] ?? 'غير محدد'}',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppColors.textPrimaryDark
                                : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // 6. الاستشاري/المهندس
                  if (project['ename'] != null) ...[
                    Row(
                      children: [
                        Icon(
                          Iconsax.user_octagon,
                          size: 16,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${AppLocalizations.of(context)!.engineerName}: م/ ${project['ename']}',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Expanded details (7-10)
                  if (isExpanded) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: themeProvider.isDarkMode
                            ? AppColors.primaryDark
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.surfaceDark.withOpacity(0.8)
                              : Colors.grey[200]!,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 7. اسم المشروع
                          _buildInfoRowWithIcon(
                            Iconsax.briefcase,
                            '${AppLocalizations.of(context)!.projectType}:',
                            project['projx'] ?? 'غير محدد',
                          ),
                          const SizedBox(height: 8),

                          // 8. الموقع/المنطقة
                          _buildInfoRowWithIcon(
                            Iconsax.location,
                            '${AppLocalizations.of(context)!.location}:',
                            project['place'] ?? 'غير محدد',
                          ),
                          const SizedBox(height: 8),

                          // 9. الرقم المساحي
                          _buildInfoRowWithIcon(
                            Iconsax.document_text,
                            '${AppLocalizations.of(context)!.surveyNumber}:',
                            project['pin'] ?? 'غير محدد',
                          ),
                          const SizedBox(height: 8),

                          // 10. تاريخ البدء
                          _buildInfoRowWithIcon(
                            Iconsax.calendar_1,
                            '${AppLocalizations.of(context)!.startDate}:',
                            project['sdate'] ?? 'غير محدد',
                          ),
                          const SizedBox(height: 16),

                          // زر افتح الزيارات
                          // الكود المُعدّل لزر "افتح الزيارات"
                          // ضع هذا الكود مكان الكود القديم (السطور 3609-3642)

                          // زر افتح الزيارات
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                final authProvider = Provider.of<AuthProvider>(
                                  context,
                                  listen: false,
                                );
                                // 1️⃣ مسح الـ cache القديم عشان نحمل الداتا من جديد
                                _visitsCache.clear();

                                // 2️⃣ الانتقال لصفحة الزيارات
                                setState(() {
                                  if (authProvider.isEngineer()) {
                                    _selectedIndex = 3;
                                  } else {
                                    _selectedIndex = 2;
                                  }
                                  prox = project['id'];
                                  _showingStats =
                                      false; // نتأكد إننا في صفحة الزيارات مش الإحصائيات
                                });

                                // 3️⃣ تحميل البيانات فوراً بعد الانتقال

                                final dateKey = intlx.DateFormat(
                                  'yyyy-MM-dd',
                                ).format(_selectedDate);

                                await _loadVisitsData(
                                  authProvider,
                                  dateKey,
                                  proxId: prox,
                                );

                                // 4️⃣ تحديث الواجهة بعد تحميل البيانات
                                if (mounted) {
                                  setState(() {});
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeProvider.isDarkMode
                                    ? AppColors.secondaryDark
                                    : AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.openVisits,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Visit info (always visible) - 11 & 12
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${AppLocalizations.of(context)!.lastVisit}: ${project['ldate'] ?? 'غير محدد'}',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textSecondaryDark
                              : Colors.grey[600],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(51),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${AppLocalizations.of(context)!.visitCount}: ${project['cntx'] ?? 0}',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRowWithIcon(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.textSecondaryDark
              : Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textSecondaryDark
                : Colors.grey[600],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textPrimaryDark
                  : Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textSecondaryDark
                : Colors.grey[600],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textPrimaryDark
                  : Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  void _scrollToActiveCard(int index) {
    if (_scrollController.hasClients) {
      final double cardHeight = 200.0; // Approximate card height
      final double targetOffset = index * (cardHeight + 16); // 16 is margin

      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildVisitsList(AuthProvider authProvider) {
    final dateKey = intlx.DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Check if we have cached data for this date
    if (_visitsCache.containsKey(dateKey)) {
      return _buildVisitsListFromCache(dateKey, authProvider);
    }

    // If no cache, load from API
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadVisitsData(authProvider, dateKey, proxId: prox),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.warning_2,
                  size: 48,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textHintDark
                      : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'حدث خطأ في جلب الزيارات',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondaryDark
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }

        final result = snapshot.data;
        if (result == null || result['success'] != true) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.calendar_remove,
                  size: 48,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textHintDark
                      : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد زيارات في هذا التاريخ',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondaryDark
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final visits = result['visits'] as List<dynamic>;

        if (visits.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.calendar_remove,
                  size: 48,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textHintDark
                      : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد زيارات في هذا التاريخ',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondaryDark
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: visits.length,
          itemBuilder: (context, index) {
            final visit = visits[index] as Map<String, dynamic>;
            return _buildVisitCard(visit, index + 1, authProvider);
          },
        );
      },
    );
  }

  Widget _buildVisitCard(
    Map<String, dynamic> visit,
    int serialNumber,
    AuthProvider? authProvider,
  ) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with serial number and engineer info
                Row(
                  children: [
                    // Engineer image or logo
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withAlpha(51),
                      backgroundImage: (authProvider?.isAdmin() ?? false)
                          ? NetworkImage(
                              'https://qcec.online/erp2025/assets/users/${visit['eid']}/images/1.jpg',
                            )
                          : null,
                      child: (authProvider?.isAdmin() ?? false)
                          ? null
                          : Icon(
                              Iconsax.user_octagon,
                              color: AppColors.primary,
                              size: 16,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "م/ ${visit['ename']}",
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.textPrimaryDark
                                  : Colors.grey[800],
                            ),
                          ),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              _formatDateAndTime(visit['a10'] ?? ""),
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.textSecondaryDark
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Photos count - also clickable
                    Tooltip(
                      message: 'اضغط لعرض الصور',
                      child: GestureDetector(
                        onTap: () => _togglePhotosExpansion(
                          int.tryParse(visit['vdid']?.toString() ?? '0') ?? 0,
                        ),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                _expandedPhotos.contains(
                                  int.tryParse(
                                        visit['vdid']?.toString() ?? '0',
                                      ) ??
                                      0,
                                )
                                ? AppColors.primary
                                : AppColors.primary.withAlpha(51),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withAlpha(102),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${_getPhotosCount(visit)}',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color:
                                    _expandedPhotos.contains(
                                      int.tryParse(
                                            visit['vdid']?.toString() ?? '0',
                                          ) ??
                                          0,
                                    )
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Visit info in organized sections
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer section
                      GestureDetector(
                        onTap: () {
                          launchUrl(Uri.parse('tel:${visit['cmob'] ?? ''}'));
                        },
                        child: Row(
                          children: [
                            Icon(Iconsax.user, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                visit['cname'] ?? 'عميل غير محدد',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                  textStyle: TextStyle(
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.blue.withAlpha(102),
                                    decorationThickness: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Contractor section
                      GestureDetector(
                        onTap: () {
                          launchUrl(Uri.parse('tel:${visit['cnmob'] ?? ''}'));
                        },
                        child: Row(
                          children: [
                            Icon(
                              Iconsax.building_4,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                visit['cn_name'] ?? 'عميل غير محدد',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                  textStyle: TextStyle(
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.blue.withAlpha(102),
                                    decorationThickness: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                // Photos section (expandable)
                if (_expandedPhotos.contains(
                  int.tryParse(visit['vdid']?.toString() ?? '0') ?? 0,
                )) ...[
                  const SizedBox(height: 12),
                  _buildMediaSection(visit),
                ],
                const SizedBox(height: 12),

                // Project info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Iconsax.building,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              visit['proj'] ?? 'مشروع غير محدد',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.textPrimaryDark
                                    : Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Iconsax.location,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            visit['place'] ?? 'موقع غير محدد',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.textPrimaryDark
                                  : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Notes section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withAlpha(102)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Iconsax.note_text,
                            size: 16,
                            color: Colors.amber[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${AppLocalizations.of(context)!.description}:',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Consumer<LanguageProvider>(
                        builder: (context, languageProvider, child) {
                          final description = visit['a2'] ?? "";
                          if (description.isEmpty) {
                            return Text(
                              "لا يوجد وصف",
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            );
                          }

                          return FutureBuilder<String>(
                            future: TranslationService().translateText(
                              text: description,
                              targetLanguage: languageProvider.currentLocale
                                  .toString(),
                              sourceLanguage: 'ar',
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Row(
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.amber[700]!,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppLocalizations.of(context)!.translating,
                                      style: GoogleFonts.cairo(
                                        fontSize: 12,
                                        color: Colors.amber[700],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                );
                              }

                              final translatedText =
                                  snapshot.data ?? description;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    translatedText,
                                    style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.textPrimaryDark
                                          : Colors.grey[800],
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // Show translation indicator if text was translated
                                  if (languageProvider.currentLocale != 'ar' &&
                                      translatedText != description) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.translate,
                                          size: 12,
                                          color: Colors.blue[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.translated,
                                          style: GoogleFonts.cairo(
                                            fontSize: 10,
                                            color: Colors.blue[600],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Iconsax.note_text,
                            size: 16,
                            color: Colors.amber[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${AppLocalizations.of(context)!.notes}:',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      StatefulBuilder(
                        builder: (context, setLocalState) {
                          return _buildExpandableText(
                            visit['a4'] ?? "لا توجد ملاحظات",
                            int.tryParse(visit['vdid']?.toString() ?? '0') ?? 0,
                            setLocalState,
                          );
                        },
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

  Future<Map<String, dynamic>> _loadVisitsData(
    AuthProvider authProvider,
    String dateKey, {
    String? proxId,
  }) async {
    if (_isLoadingVisits) {
      // If already loading, wait and return cached data
      while (_isLoadingVisits) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _visitsCache[dateKey] ?? {'success': false};
    }

    _isLoadingVisits = true;
    try {
      final result = await authProvider.getFullVisitsData(
        selectedDate: dateKey,
        proxId: proxId,
      );
      if (result['success'] == true) {
        _visitsCache[dateKey] = result;
      }
      return result;
    } finally {
      _isLoadingVisits = false;
    }
  }

  Widget _buildVisitsListFromCache(String dateKey, AuthProvider authProvider) {
    final result = _visitsCache[dateKey];
    if (result == null || result['success'] != true) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.calendar_remove,
              size: 48,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textHintDark
                  : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد زيارات في هذا التاريخ',
              style: GoogleFonts.cairo(
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    final visits = result['visits'] as List<dynamic>;

    // Filter visits based on search query
    final filteredVisits = _searchQueryVisits.isEmpty
        ? visits
        : visits.where((visit) {
            final visitMap = visit as Map<String, dynamic>;
            final searchLower = _searchQueryVisits.toLowerCase();

            return (visitMap['cname']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (visitMap['ename']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (visitMap['cn_name']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (visitMap['proj']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (visitMap['place']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (visitMap['a2']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false) ||
                (visitMap['a4']?.toString().toLowerCase().contains(
                      searchLower,
                    ) ??
                    false);
          }).toList();

    if (filteredVisits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQueryVisits.isEmpty
                  ? Iconsax.calendar_remove
                  : Iconsax.search_normal,
              size: 48,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textHintDark
                  : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQueryVisits.isEmpty
                  ? 'لا توجد زيارات في هذا التاريخ'
                  : 'لا توجد نتائج للبحث عن "$_searchQueryVisits"',
              style: GoogleFonts.cairo(
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredVisits.length,
      itemBuilder: (context, index) {
        final visit = filteredVisits[index] as Map<String, dynamic>;
        return _buildVisitCard(visit, index + 1, authProvider);
      },
    );
  }

  Widget _buildMediaSection(Map<String, dynamic> visit) {
    final visitId = int.tryParse(visit['vdid']?.toString() ?? '0') ?? 0;
    final mediaCount = _getMediaCount(visit);
    final currentIndex = _currentPhotoIndex[visitId] ?? 0;
    print(mediaCount);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.surfaceDark.withOpacity(0.8)
              : Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          // Photos header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Iconsax.gallery, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'وسائط الزيارة',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textPrimaryDark
                        : Colors.grey[800],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${currentIndex + 1} / $mediaCount',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Media PageView
          Container(
            height: 200,
            child: PageView.builder(
              itemCount: mediaCount,
              onPageChanged: (index) {
                setState(() {
                  _currentPhotoIndex[visitId] = index;
                });
              },
              itemBuilder: (context, index) {
                return _buildMediaItem(visit, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper functions for media handling
  Future<bool> _checkIfVideoExists(String videoUrl) async {
    try {
      final response = await http.head(Uri.parse(videoUrl));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Widget _buildVideoThumbnail(String videoUrl) {
    return FutureBuilder<String?>(
      future: _generateVideoThumbnail(videoUrl),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.file(
            File(snapshot.data!),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        }
        return Container(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.borderDark
              : Colors.grey[300],
          child: Center(
            child: Icon(
              Iconsax.video,
              size: 40,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : Colors.grey[600],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _generateVideoThumbnail(String videoUrl) async {
    try {
      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: videoUrl,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 200,
        quality: 75,
      );
      return thumbnail;
    } catch (e) {
      debugPrint('Error generating video thumbnail: $e');
      return null;
    }
  }

  void _showFullScreenVideo(String videoUrl, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FullScreenVideoPlayer(videoUrl: videoUrl, title: 'فيديو $index'),
      ),
    );
  }

  // void _showFullScreenImage(String imageUrl, int index) {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => Scaffold(
  //         backgroundColor: Colors.black,
  //         appBar: AppBar(
  //           backgroundColor: Colors.black,
  //           title: Text(
  //             'صورة $index',
  //             style: GoogleFonts.cairo(color: Theme.of(context).cardColor),
  //           ),
  //           iconTheme: const IconThemeData(color: Theme.of(context).cardColor),
  //         ),
  //         body: Center(
  //           child: InteractiveViewer(
  //             child: Image.network(
  //               imageUrl,
  //               fit: BoxFit.contain,
  //               loadingBuilder: (context, child, loadingProgress) {
  //                 if (loadingProgress == null) return child;
  //                 return const Center(
  //                   child: CircularProgressIndicator(color: Theme.of(context).cardColor),
  //                 );
  //               },
  //               errorBuilder: (context, error, stackTrace) {
  //                 return const Center(
  //                   child: Icon(Iconsax.image, color: Theme.of(context).cardColor, size: 64),
  //                 );
  //               },
  //             ),
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildMediaItem(Map<String, dynamic> visit, int index) {
    final visitId = visit['vdid'];

    // Try both image and video URLs in the same folder
    final imageUrl =
        'https://visitsqcecs.s3.ap-south-1.amazonaws.com/visits/$visitId/${index + 1}.jpg';
    final videoUrl =
        'https://visitsqcecs.s3.ap-south-1.amazonaws.com/visits/$visitId/${index + 1}.mp4';

    return FutureBuilder<bool>(
      future: _checkIfVideoExists(videoUrl),
      builder: (context, snapshot) {
        final isVideo = snapshot.data == true;

        return GestureDetector(
          onTap: () {
            if (isVideo) {
              _showFullScreenVideo(videoUrl, index + 1);
            } else {
              _showFullScreenImage(imageUrl, index + 1);
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.surfaceDark
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  // Display image or video thumbnail
                  if (isVideo)
                    _buildVideoThumbnail(videoUrl)
                  else
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'جاري تحميل ${isVideo ? "الفيديو" : "الصورة"}...',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.textSecondaryDark
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isVideo ? Iconsax.video : Iconsax.image,
                                size: 40,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.textHintDark
                                    : Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'لا توجد ${isVideo ? "فيديو" : "صورة"}',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.textSecondaryDark
                                      : Colors.grey[600],
                                ),
                              ),
                              Text(
                                '${isVideo ? "فيديو" : "صورة"} ${index + 1}',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.textSecondaryDark
                                      : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  // Video play icon overlay
                  if (isVideo)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).cardColor.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Iconsax.play,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// التحقق من وجود زيارات غير مكتملة عند فتح التطبيق
  void _checkIncompleteVisits() async {
    try {
      // تأخير بسيط للسماح بتحميل الشاشة
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // التحقق من وجود زيارة غير مكتملة
      final appService = AppLifecycleService();
      bool hasIncomplete = await appService.hasIncompleteVisit();

      if (hasIncomplete && mounted) {
        // عرض نافذة التنبيه
        IncompleteVisitDialog.show(
          context,
          onResume: () async {
            // الحصول على معلومات الزيارة النشطة
            Map<String, dynamic>? visitInfo = await appService
                .getActiveVisitInfo();
            if (visitInfo != null && mounted) {
              int visitId = visitInfo['visitId'];

              // البحث عن معرف المشروع من البيانات المحفوظة
              final draftService = appService.draftService;
              var draft = await draftService.getDraft(visitId);

              if (draft != null && mounted) {
                // الانتقال لشاشة الزيارة مع البيانات المحفوظة
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddVisitScreen(
                      visitId: visitId,
                      projectId: draft.projectId,
                      capturedImages: draft.images,
                    ),
                  ),
                );
              }
            }
          },
          onCancel: () async {
            // حذف الزيارة المعلقة
            await appService.cancelIncompleteVisit();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم حذف الزيارة غير المكتملة',
                    style: GoogleFonts.cairo(),
                  ),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          },
        );
      }
    } catch (e) {
      debugPrint('❌ Error checking incomplete visits: $e');
    }
  }
}
