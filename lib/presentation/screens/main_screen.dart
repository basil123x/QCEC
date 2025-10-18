import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart' as intlx;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import 'login_screen.dart';

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
  final TextEditingController _searchController = TextEditingController();
  int? _activeProjectId;
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _projects = [];
  String _currentDate = '';
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

  @override
  void initState() {
    super.initState();
    _loadActiveProject();
    _loadProjectsOnce();
  }

  Future<void> _loadActiveProject() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getInt('active_project_id');
    if (activeId != null) {
      setState(() {
        _activeProjectId = activeId;
      });
    }
  }

  Future<void> _saveActiveProject(int? projectId) async {
    final prefs = await SharedPreferences.getInstance();
    if (projectId != null) {
      await prefs.setInt('active_project_id', projectId);
    } else {
      await prefs.remove('active_project_id');
    }
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

        // Auto scroll to active project after loading
        if (_activeProjectId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToActiveProject();
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

  void _scrollToActiveProject() {
    if (_activeProjectId == null || !_scrollController.hasClients) return;

    final activeIndex = _projects.indexWhere((project) {
      final projectId = int.tryParse(project['id'].toString()) ?? 0;
      return projectId == _activeProjectId;
    });

    if (activeIndex != -1) {
      final double cardHeight = 200.0;
      final double targetOffset = activeIndex * (cardHeight + 16);

      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
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

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(authProvider),
          body: _buildBody(authProvider),
          bottomNavigationBar: _buildBottomNavBar(authProvider),
          floatingActionButton: _buildFloatingActionButton(authProvider),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(AuthProvider authProvider) {
    // Show welcome message only on home screen
    if (_selectedIndex == 0) {
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'الرئيسية',
              style: GoogleFonts.cairo(
                fontSize: 16,
                color: Colors.grey[800],
                fontWeight: FontWeight.bold,
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
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
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
                      color: _showingStats ? Colors.green.withAlpha(51) : Colors.blue.withAlpha(51),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _showingStats ? Iconsax.chart_success : Iconsax.chart_2, 
                      color: _showingStats ? Colors.green : Colors.blue, 
                      size: 20
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  'الزيارات',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
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
    switch (_selectedIndex) {
      case 1:
        pageTitle = 'المشاريع';
        break;
      case 2:
        pageTitle = 'الكاميرا';
        break;
      case 3:
        pageTitle = 'الزيارات';
        break;
      case 4:
        pageTitle = 'الملف الشخصي';
        break;
    }

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: !_isSearching,
      title: _isSearching && _selectedIndex == 1
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'البحث في المشاريع...',
                hintStyle: GoogleFonts.cairo(
                  color: Colors.grey[500],
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey[800]),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            )
          : Text(
              pageTitle,
              style: GoogleFonts.cairo(
                fontSize: 20,
                color: Colors.grey[800],
                fontWeight: FontWeight.bold,
              ),
            ),
      leading: _isSearching
          ? IconButton(
              icon: Icon(Iconsax.arrow_right_3, color: Colors.grey[700]),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
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
          return _buildCamera(authProvider);
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً بك في تطبيق QCEC',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'المركز القطري للإستشارات الهندسية',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.white.withAlpha(229),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'نوع المستخدم: ${authProvider.getUserTypeName()}',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick Actions
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
            children: _buildQuickActions(authProvider),
          ),
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
        title: 'المشاريع',
        subtitle: 'عرض جميع المشاريع',
        color: Colors.blue,
        onTap: () => setState(() => _selectedIndex = 1),
      ),
    );

    actions.add(
      _buildActionCard(
        icon: Iconsax.calendar,
        title: 'الزيارات',
        subtitle: 'جدولة ومتابعة الزيارات',
        color: Colors.green,
        onTap: () => setState(() => _selectedIndex = 2),
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
          onTap: () {
            // TODO: Navigate to add visit screen
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

  Widget _buildProjects(AuthProvider authProvider) {
    return SafeArea(
      child: Column(
        children: [Expanded(child: _buildProjectsList(authProvider))],
      ),
    );
  }

  Widget _buildCamera(AuthProvider authProvider) {
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
            child: Icon(Iconsax.camera, color: Colors.white, size: 50),
          ),
          const SizedBox(height: 24),
          Text(
            'الكاميرا',
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'قيد التطوير',
            style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey[500]),
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
                ? _buildEngineersStatsFullScreen(authProvider)
                : _buildVisitsList(authProvider)
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(102),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white.withAlpha(51),
                    backgroundImage: authProvider.getUserImageUrl().isNotEmpty
                        ? NetworkImage(authProvider.getUserImageUrl())
                        : null,
                    child: authProvider.getUserImageUrl().isEmpty
                        ? Icon(Iconsax.user, color: Colors.white, size: 40)
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
                      color: Colors.white.withAlpha(51),
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
            ),

            const SizedBox(height: 24),

            // Settings Options
            _buildSettingsSection(authProvider),

            const SizedBox(height: 24),

            // Logout Button
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _logout(authProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[400],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Iconsax.logout, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      'تسجيل الخروج',
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
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(AuthProvider authProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
            title: 'تغيير اللغة',
            subtitle: 'العربية',
            onTap: () => _showLanguageDialog(),
            color: Colors.blue,
          ),
          _buildDivider(),
          _buildSettingsItem(
            icon: Iconsax.moon,
            title: 'الوضع المظلم',
            subtitle: 'قيد التطوير',
            onTap: () => _showComingSoon('الوضع المظلم'),
            color: Colors.purple,
          ),
          _buildDivider(),
          _buildSettingsItem(
            icon: Iconsax.info_circle,
            title: 'عن الشركة',
            subtitle: 'قيد التطوير',
            onTap: () => _showComingSoon('عن الشركة'),
            color: Colors.green,
          ),
          _buildDivider(),
          _buildSettingsItem(
            icon: Iconsax.call,
            title: 'اتصل بنا',
            subtitle: 'قيد التطوير',
            onTap: () => _showComingSoon('اتصل بنا'),
            color: Colors.orange,
          ),
          _buildDivider(),
          _buildSettingsItem(
            icon: Iconsax.trash,
            title: 'حذف حسابي',
            subtitle: 'قيد التطوير',
            onTap: () => _showComingSoon('حذف الحساب'),
            color: Colors.red,
          ),
        ],
      ),
    );
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
          color: Colors.grey[800],
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[600]),
      ),
      trailing: Icon(Iconsax.arrow_left_2, color: Colors.grey[400], size: 20),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey[200],
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

    return AnimatedBottomNavigationBar(
      icons: iconList,
      activeIndex: displayIndex,
      gapLocation: GapLocation.center,
      notchSmoothness: NotchSmoothness.verySmoothEdge,
      leftCornerRadius: 32,
      rightCornerRadius: 32,
      backgroundColor: Colors.white,
      activeColor: AppColors.primary,
      inactiveColor: Colors.grey[600],
      splashColor: AppColors.primary.withAlpha(51),
      onTap: (index) {
        int actualIndex = index >= 2 ? index + 1 : index;
        setState(() => _selectedIndex = actualIndex);
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

    return AnimatedBottomNavigationBar(
      icons: iconList,
      activeIndex: _selectedIndex,
      gapLocation: GapLocation.none,
      notchSmoothness: NotchSmoothness.verySmoothEdge,
      leftCornerRadius: 32,
      rightCornerRadius: 32,
      backgroundColor: Colors.white,
      activeColor: AppColors.primary,
      inactiveColor: Colors.grey[600],
      splashColor: AppColors.primary.withAlpha(51),
      onTap: (index) => setState(() => _selectedIndex = index),
    );
  }

  Widget? _buildFloatingActionButton(AuthProvider authProvider) {
    if (authProvider.isEngineer()) {
      return FloatingActionButton(
        onPressed: () => setState(() => _selectedIndex = 2),
        backgroundColor: AppColors.primary,
        child: Icon(Iconsax.camera, color: Colors.white),
      );
    }
    return null;
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

  String _formatDateTime(String? dateTimeString) {
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
      return count > 0 ? count : 5;
    }
    if (visit.containsKey('photos') && visit['photos'] is List) {
      final count = (visit['photos'] as List).length;
      return count > 0 ? count : 5;
    }
    return 5;
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

  void _toggleNotesExpansion(int visitId) {
    setState(() {
      if (_expandedNotes.contains(visitId)) {
        _expandedNotes.remove(visitId);
      } else {
        _expandedNotes.add(visitId);
      }
    });
  }

  Widget _buildExpandableText(String text, int visitId, StateSetter setLocalState) {
    final isExpanded = _expandedNotes.contains(visitId);
    final maxLines = isExpanded ? null : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: GoogleFonts.cairo(
            fontSize: 14,
            color: Colors.grey[800],
            height: 1.4,
          ),
          maxLines: maxLines,
          overflow: isExpanded ? null : TextOverflow.ellipsis,
        ),
        if (text.length > 100) ...[
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
      ],
    );
  }

  void _showEngineersStats() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(51),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Iconsax.chart_2, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'إحصائيات المهندسين',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEngineerStatItem(
                  'م/ أحمد محمد',
                  85,
                  'https://qcec.online/erp2025/assets/users/1/images/1.jpg',
                ),
                const SizedBox(height: 12),
                _buildEngineerStatItem(
                  'م/ سارة أحمد',
                  72,
                  'https://qcec.online/erp2025/assets/users/2/images/1.jpg',
                ),
                const SizedBox(height: 12),
                _buildEngineerStatItem(
                  'م/ محمد علي',
                  68,
                  'https://qcec.online/erp2025/assets/users/3/images/1.jpg',
                ),
                const SizedBox(height: 12),
                _buildEngineerStatItem(
                  'م/ فاطمة خالد',
                  45,
                  'https://qcec.online/erp2025/assets/users/4/images/1.jpg',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'إغلاق',
                style: GoogleFonts.cairo(color: Colors.grey[600]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEngineersStatsFullScreen(AuthProvider authProvider) {
    final dateKey = intlx.DateFormat('yyyy-MM-dd').format(_selectedDate);
    
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
                Icon(Iconsax.warning_2, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'حدث خطأ في جلب الإحصائيات',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: Colors.grey[600],
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
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'حدث خطأ في جلب الإحصائيات',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: Colors.grey[600],
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
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد إحصائيات في هذا التاريخ',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'جرب تاريخ آخر أو تأكد من وجود زيارات',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    color: Colors.grey[500],
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
              colors: [
                Colors.grey[50]!,
                Colors.white,
              ],
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
                      child: Icon(Iconsax.chart_success, color: Colors.blue, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إحصائيات المهندسين',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            intlx.DateFormat('yyyy-MM-dd').format(_selectedDate),
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              color: Colors.grey[600],
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
                    final stat = engineersStats[index] as Map<String, dynamic>;
                    return _buildEngineerStatCard(stat, index + 1);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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
        color: Colors.white,
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
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: rank == 1 
                    ? Colors.amber 
                    : rank == 2 
                    ? Colors.grey[400] 
                    : rank == 3 
                    ? Colors.orange[300]
                    : AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (rank == 1 
                        ? Colors.amber 
                        : rank == 2 
                        ? Colors.grey[400]! 
                        : rank == 3 
                        ? Colors.orange[300]!
                        : AppColors.primary).withAlpha(102),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Engineer photo
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primary.withAlpha(51),
              backgroundImage: NetworkImage(
                'https://qcec.online/erp2025/assets/users/$engineerId/images/1.jpg',
              ),
              child: Icon(
                Iconsax.user_octagon,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            // Engineer info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    engineerName,
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$visitsCount من $totalAssigned زيارة',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: Colors.grey[600],
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
                            color: Colors.grey[200],
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (percentage > 80
                              ? Colors.green
                              : percentage > 60
                              ? Colors.orange
                              : Colors.red).withAlpha(51),
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
        border: Border.all(color: Colors.grey[200]!),
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
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor: Colors.grey[300],
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(51),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Iconsax.language_circle,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'اختر اللغة',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageOption(
                'العربية',
                'https://cdn-icons-png.flaticon.com/512/197/197571.png',
                true,
              ),
              const SizedBox(height: 12),
              _buildLanguageOption(
                'English',
                'https://cdn-icons-png.flaticon.com/512/197/197374.png',
                false,
              ),
              _buildLanguageOption('हिंदी', '🇮🇳', false),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(color: Colors.grey[600]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageOption(
    String language,
    String flagUrl,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        _showComingSoon('تغيير اللغة إلى $language');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(51) : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
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
              width: 32,
              height: 32,
              decoration: BoxDecoration(
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
                child: Image.network(
                  flagUrl,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 32,
                      height: 32,
                      color: Colors.grey[300],
                      child: Icon(
                        Iconsax.flag,
                        color: Colors.grey[600],
                        size: 16,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                language,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primary : Colors.grey[800],
                ),
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Iconsax.tick_circle, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateNavigationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(51),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                // Clear cache for old date to ensure fresh data
                final oldDateKey = intlx.DateFormat('yyyy-MM-dd').format(_selectedDate.add(const Duration(days: 1)));
                _visitsCache.remove(oldDateKey);
              });
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
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
                Iconsax.arrow_right_3,
                color: AppColors.primary,
                size: 16,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
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
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
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
                      // Clear cache for old date to ensure fresh data
                      final oldDateKey = intlx.DateFormat('yyyy-MM-dd').format(_selectedDate.subtract(const Duration(days: 1)));
                      _visitsCache.remove(oldDateKey);
                    });
                  }
                : null,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isBeforeToday() ? Colors.white : Colors.grey[300],
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
                Iconsax.arrow_left_2,
                color: _isBeforeToday() ? AppColors.primary : Colors.grey[500],
                size: 16,
              ),
            ),
          ),
        ],
      ),
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
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'لا توجد مشاريع في هذا التاريخ'
                  : 'لا توجد نتائج للبحث عن "$_searchQuery"',
              style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey[600]),
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

    return GestureDetector(
      onTap: () {
        final newActiveId = isActive ? null : projectId;
        setState(() {
          _activeProjectId = newActiveId;
        });

        // Save to SharedPreferences
        _saveActiveProject(newActiveId);

        // No need to scroll here, will auto-scroll when loading
      },
      child: Container(
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
                        // 1. اسم العميل
                        Row(
                          children: [
                            Icon(
                              Iconsax.user,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                project['cname'] ?? 'عميل غير محدد',
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
                  const Spacer(),
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

              // 2 & 3. رقم العميل ورقم البطاقة
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Iconsax.call, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          project['cphone'] ?? 'غير محدد',
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
                            project['cqid'] ?? 'غير محدد',
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
              if (project['cnname'] != null) ...[
                Row(
                  children: [
                    Icon(Iconsax.building_4, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'المقاول: ${project['cnname']}',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 5. رقم المقاول
                Row(
                  children: [
                    Icon(Iconsax.call, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'رقم المقاول: ${project['cnphone'] ?? 'غير محدد'}',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: Colors.grey[700],
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
                      'الاستشاري: م/ ${project['ename']}',
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
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 7. اسم المشروع
                      _buildInfoRowWithIcon(
                        Iconsax.briefcase,
                        'المشروع:',
                        project['projx'] ?? 'غير محدد',
                      ),
                      const SizedBox(height: 8),

                      // 8. الموقع/المنطقة
                      _buildInfoRowWithIcon(
                        Iconsax.location,
                        'الموقع:',
                        project['place'] ?? 'غير محدد',
                      ),
                      const SizedBox(height: 8),

                      // 9. الرقم المساحي
                      _buildInfoRowWithIcon(
                        Iconsax.document_text,
                        'الرقم المساحي:',
                        project['pin'] ?? 'غير محدد',
                      ),
                      const SizedBox(height: 8),

                      // 10. تاريخ البدء
                      _buildInfoRowWithIcon(
                        Iconsax.calendar_1,
                        'تاريخ البدء:',
                        project['sdate'] ?? 'غير محدد',
                      ),
                      const SizedBox(height: 16),

                      // زر افتح الزيارات
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showComingSoon('افتح الزيارات'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'افتح الزيارات',
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
                    'آخر زيارة: ${project['ldate'] ?? 'غير محدد'}',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.grey[600],
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
                      'عدد الزيارات: ${project['cntx'] ?? 0}',
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
      ),
    );
  }

  Widget _buildInfoRowWithIcon(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[800]),
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
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.cairo(fontSize: 14, color: Colors.grey[800]),
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
      future: _loadVisitsData(authProvider, dateKey),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.warning_2, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'حدث خطأ في جلب الزيارات',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: Colors.grey[600],
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
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد زيارات في هذا التاريخ',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: Colors.grey[600],
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
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد زيارات في هذا التاريخ',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: Colors.grey[600],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                  backgroundImage: NetworkImage(
                    'https://qcec.online/erp2025/assets/users/${visit['eid']}/images/1.jpg',
                  ),
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
                          color: Colors.grey[800],
                        ),
                      ),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          _formatDateAndTime(visit['a10'] ?? ""),
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: Colors.grey[600],
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
                    onTap: () => _togglePhotosExpansion(int.tryParse(visit['vdid']?.toString() ?? '0') ?? 0),
                    child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _expandedPhotos.contains(int.tryParse(visit['vdid']?.toString() ?? '0') ?? 0)
                          ? AppColors.primary
                          : AppColors.primary.withAlpha(51),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
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
                          color: _expandedPhotos.contains(int.tryParse(visit['vdid']?.toString() ?? '0') ?? 0)
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
                color: Colors.grey[50],
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
                      Icon(Iconsax.building_4, size: 16, color: Colors.green),
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
            if (_expandedPhotos.contains(int.tryParse(visit['vdid']?.toString() ?? '0') ?? 0)) ...[
              const SizedBox(height: 12),
              _buildPhotosSection(visit),
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
                            color: Colors.grey[800],
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
                          color: Colors.grey[700],
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
                        'الوصف:',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    visit['a2'] ?? "",
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                        'الملاحظات:',
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
  }

  Future<Map<String, dynamic>> _loadVisitsData(AuthProvider authProvider, String dateKey) async {
    if (_isLoadingVisits) {
      // If already loading, wait and return cached data
      while (_isLoadingVisits) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _visitsCache[dateKey] ?? {'success': false};
    }
    
    _isLoadingVisits = true;
    try {
      final result = await authProvider.getFullVisitsData(selectedDate: dateKey);
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
            Icon(Iconsax.calendar_remove, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'لا توجد زيارات في هذا التاريخ',
              style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey[600]),
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
            Icon(Iconsax.calendar_remove, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'لا توجد زيارات في هذا التاريخ',
              style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey[600]),
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
  }

  Widget _buildPhotosSection(Map<String, dynamic> visit) {
    final visitId = int.tryParse(visit['vdid']?.toString() ?? '0') ?? 0;
    final photosCount = _getPhotosCount(visit);
    final currentIndex = _currentPhotoIndex[visitId] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
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
                  'صور الزيارة',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${currentIndex + 1} / $photosCount',
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
          // Photos PageView
          Container(
            height: 200,
            child: PageView.builder(
              itemCount: photosCount,
              onPageChanged: (index) {
                setState(() {
                  _currentPhotoIndex[visitId] = index;
                });
              },
              itemBuilder: (context, index) {
                // Build actual image URL from Amazon S3
                final imageUrl = 'https://visitsqcecs.s3.ap-south-1.amazonaws.com/visits/${visit['vdid']}/${index + 1}.jpg';
                
                return GestureDetector(
                  onTap: () => _showFullScreenImage(imageUrl, index + 1),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
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
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
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
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'جاري تحميل الصورة...',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: Colors.grey[600],
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
                              Icon(Iconsax.image, size: 40, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'لا توجد صورة',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                'صورة ${index + 1}',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Dots indicator
          if (photosCount > 1) ...[
            const SizedBox(height: 12),
            Container(
              height: 20,
              child: photosCount <= 15 
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(photosCount, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: currentIndex == index ? 12 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: currentIndex == index
                              ? AppColors.primary
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(photosCount, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: currentIndex == index ? 10 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: currentIndex == index
                                ? AppColors.primary
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
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
                style: GoogleFonts.cairo(color: Colors.grey[600]),
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
                              color: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'جاري تحميل الصورة...',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                color: Colors.white,
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
                                color: Colors.white,
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
                      color: Colors.white,
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
                      color: Colors.white,
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
}
