import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

class AuthProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late final Dio _dio;

  bool _isLoading = true; // Start with loading = true
  bool _isLoggedIn = false;
  Map<String, dynamic>? _userData;
  int? _userType; // 0=Admin, 1=Customer, 2=Engineer, 3=Contractor

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  Map<String, dynamic>? get userData => _userData;
  int? get userType => _userType;

  // API Base URL - Change this to your server URL
  static const String baseUrl = 'https://qcec.online/app2026/sql.php';

  AuthProvider() {
    _initializeDio();
    _checkLoginStatus();
  }

  /// Initialize Dio with proper configuration for release mode
  void _initializeDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        followRedirects: true,
        validateStatus: (status) {
          return status != null && status < 500;
        },
      ),
    );

    // Add interceptors for debugging (only in debug mode)
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: true,
          responseHeader: false,
          error: true,
        ),
      );
    }
  }

  /// Check if user is already logged in
  Future<void> _checkLoginStatus() async {
    try {
      final isLoggedInStr = await _secureStorage.read(key: 'is_logged_in');
      final userTypeStr = await _secureStorage.read(key: 'user_type');
      final userDataStr = await _secureStorage.read(key: 'user_data');
      final userIdStr = await _secureStorage.read(key: 'user_id');

      if (isLoggedInStr == 'true' &&
          userTypeStr != null &&
          userDataStr != null &&
          userIdStr != null) {
        _userType = int.parse(userTypeStr);
        _userData = json.decode(userDataStr);
        _isLoggedIn = true;
        debugPrint('User already logged in: ${_userData!['id']}');
      } else {
        debugPrint('No saved login found');
      }
    } catch (e) {
      debugPrint('Error checking login status: $e');
      // Clear corrupted data
      await logout();
    } finally {
      _isLoading = false; // Stop loading after check
      notifyListeners();
    }
  }

  /// Login function
  Future<Map<String, dynamic>> login(String phone, String password) async {
    _setLoading(true);

    try {
      debugPrint('Attempting login for phone: $phone');

      final response = await _dio.post(
        '', // baseUrl is already set in Dio configuration
        data: {'action': 'login', 'phone': phone, 'password': password},
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['success'] == true) {
          _userData = data['data']; // Changed from data['user'] to data['data']
          _userType = data['user_type']; // Get user_type directly from response
          _isLoggedIn = true;

          // Save to secure storage
          await _secureStorage.write(
            key: 'user_id',
            value: data['data']['id'].toString(),
          );
          await _secureStorage.write(
            key: 'user_data',
            value: json.encode(data['data']),
          );
          await _secureStorage.write(
            key: 'user_type',
            value: _userType.toString(),
          );
          await _secureStorage.write(key: 'is_logged_in', value: 'true');

          _setLoading(false);
          notifyListeners();

          return {
            'success': true,
            'message': 'تم تسجيل الدخول بنجاح',
            'user': data['data'],
          };
        } else {
          _setLoading(false);
          return {
            'success': false,
            'message': data['message'] ?? 'خطأ في تسجيل الدخول',
          };
        }
      } else {
        _setLoading(false);
        return {'success': false, 'message': 'خطأ في الاتصال بالخادم'};
      }
    } catch (e) {
      _setLoading(false);
      debugPrint('Login error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      return {
        'success': false,
        'message': 'حدث خطأ غير متوقع: ${e.toString()}',
      };
    }
  }

  /// Get user type name
  String getUserTypeName() {
    switch (_userType) {
      case 0:
        return 'الإدارة';
      case 1:
        return 'العميل';
      case 2:
        return 'المهندس';
      case 3:
        return 'المقاول';
      default:
        return 'غير محدد';
    }
  }

  /// Get user name from database
  String getUserName() {
    if (_userData == null) return 'المستخدم';

    // All user types use 'a1' column for name
    String name = _userData!['a1'] ?? getUserTypeName();

    // Add "م/" prefix for engineers
    if (isEngineer()) {
      return 'م/ $name';
    }

    return name;
  }

  /// Get user ID
  String getUserId() {
    if (_userData == null) return '0';
    return _userData!['id']?.toString() ?? '0';
  }

  /// Get user profile image URL
  String getUserImageUrl() {
    if (_userData == null) return '';

    final userId = _userData!['id'];
    return 'https://qcec.online/erp2025/assets/users/$userId/images/1.jpg';
  }

  /// Logout function
  Future<void> logout() async {
    try {
      await _secureStorage.delete(key: 'user_id');
      await _secureStorage.delete(key: 'user_type');
      await _secureStorage.delete(key: 'user_data');
      await _secureStorage.delete(key: 'is_logged_in');

      _userData = null;
      _userType = null;
      _isLoggedIn = false;

      notifyListeners();
    } catch (e) {
      debugPrint('Error during logout: $e');
    }
  }

  /// Check if user is admin
  bool isAdmin() => _userType == 0;

  /// Check if user is customer
  bool isCustomer() => _userType == 1;

  /// Check if user is engineer
  bool isEngineer() => _userType == 2;

  /// Check if user is contractor
  bool isContractor() => _userType == 3;

  /// Get projects for current user
  Future<Map<String, dynamic>> getProjects({String? selectedDate}) async {
    if (!_isLoggedIn || _userData == null) {
      return {'success': false, 'message': 'يجب تسجيل الدخول أولاً'};
    }

    try {
      // Determine x parameter based on user type
      String x = '0'; // Default for admin
      switch (_userType) {
        case 1:
          x = '1';
          break; // Customer
        case 2:
          x = '2';
          break; // Engineer
        case 3:
          x = '3';
          break; // Contractor
      }
      final requestData = {
        'action': 'get_all_transactions',
        'uid': _userData!['id'].toString(),
        'x': x,
      };

      // Add date filter if provided
      if (selectedDate != null && selectedDate.isNotEmpty) {
        requestData['xx'] = selectedDate;
      }

      debugPrint('Sending request: $requestData');

      final response = await _dio.post(
        baseUrl,
        data: requestData,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      debugPrint('Projects response: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'success': data['status'] == 'success',
          'message': 'تم جلب المشاريع بنجاح',
          'projects': data['transaction_data'] ?? [],
          'dayx': data['dayx'] ?? '',
        };
      } else {
        return {'success': false, 'message': 'خطأ في الاتصال بالخادم'};
      }
    } catch (e) {
      debugPrint('Error getting projects: $e');
      return {'success': false, 'message': 'حدث خطأ في جلب المشاريع'};
    }
  }

  /// Get visits for current user
  Future<Map<String, dynamic>> getVisits({String? projectId}) async {
    if (!_isLoggedIn || _userData == null) {
      return {'success': false, 'message': 'يجب تسجيل الدخول أولاً'};
    }

    try {
      final requestData = {
        'action': 'get_visits',
        'user_type': _userType,
        'user_id': _userData!['id'].toString(),
      };

      if (projectId != null) {
        requestData['project_id'] = projectId;
      }

      final response = await _dio.post(
        baseUrl,
        data: requestData,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'success': data['success'],
          'message': data['message'],
          'visits': data['data'] ?? [],
        };
      } else {
        return {'success': false, 'message': 'خطأ في الاتصال بالخادم'};
      }
    } catch (e) {
      return {'success': false, 'message': 'حدث خطأ في جلب الزيارات'};
    }
  }

  /// Reset contractor password
  Future<Map<String, dynamic>> resetContractorPassword(
    String phone,
    String newPassword,
  ) async {
    try {
      final response = await _dio.post(
        baseUrl,
        data: {
          'action': 'reset_contractor_password',
          'phone': phone,
          'new_password': newPassword,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? 'تم تغيير كلمة المرور بنجاح',
        };
      } else {
        return {'success': false, 'message': 'خطأ في الاتصال بالخادم'};
      }
    } catch (e) {
      return {'success': false, 'message': 'حدث خطأ غير متوقع'};
    }
  }

  /// Send WhatsApp password
  Future<Map<String, dynamic>> sendWhatsAppPassword(
    String phone,
    String password,
  ) async {
    try {
      final response = await _dio.post(
        baseUrl,
        data: {
          'action': 'send_whatsapp_password',
          'phone': phone,
          'password': password,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? 'تم إرسال كلمة المرور عبر واتساب',
        };
      } else {
        return {'success': false, 'message': 'خطأ في الاتصال بالخادم'};
      }
    } catch (e) {
      return {'success': false, 'message': 'حدث خطأ في إرسال الرسالة'};
    }
  }

  // Get full visits data
  Future<Map<String, dynamic>> getFullVisitsData({
    String? selectedDate,
    String? selectedId,
    String? selectedCust,
    String? proxId,
  }) async {
    if (!_isLoggedIn || _userData == null) {
      return {'success': false, 'message': 'يجب تسجيل الدخول أولاً'};
    }

    try {
      // Determine x parameter based on user type
      String x = '0'; // Default for admin
      switch (_userType) {
        case 1:
          x = '1';
          break; // Customer
        case 2:
          x = '2';
          break; // Engineer
        case 3:
          x = '3';
          break; // Contractor
      }

      final requestData = {
        'action': 'get_full_visits_data',
        'uid': _userData!['id'].toString(),
        'x': x,
        'xx': selectedDate ?? '',
        'prox': proxId,
      };

      debugPrint('Sending visits request with date: $selectedDate');

      // Add optional parameters
      if (selectedId != null && selectedId.isNotEmpty) {
        requestData['selectedId'] = selectedId;
      }
      if (selectedCust != null && selectedCust.isNotEmpty) {
        requestData['selectedCust'] = selectedCust;
      }

      debugPrint('Sending visits request: $requestData');

      final response = await _dio.post(
        baseUrl,
        data: requestData,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      debugPrint('Visits response: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        debugPrint('Visits data status: ${data['status']}');
        debugPrint(
          'Visits count: ${(data['get_visits_data'] as List?)?.length ?? 0}',
        );
        debugPrint('Debug info: ${data['debug_info']}');
        debugPrint('Raw visits data: ${data['get_visits_data']}');
        return {
          'success': data['status'] == 'success',
          'message': 'تم جلب الزيارات بنجاح',
          'visits': data['get_visits_data'] ?? [],
        };
      } else {
        return {'success': false, 'message': 'خطأ في الاتصال بالخادم'};
      }
    } catch (e) {
      debugPrint('Error getting visits: $e');
      return {
        'success': false,
        'message': 'حدث خطأ غير متوقع: ${e.toString()}',
      };
    }
  }

  // Get top stats for admin dashboard
  Future<Map<String, dynamic>> getTopStats({String? datexx}) async {
    if (!_isLoggedIn || _userData == null) {
      return {'success': false, 'message': 'يجب تسجيل الدخول أولاً'};
    }

    try {
      final requestData = {'action': 'get_top_stats'};

      // Add date if provided
      if (datexx != null && datexx.isNotEmpty) {
        requestData['datexx'] = datexx;
      }

      debugPrint('Sending top stats request: $requestData');

      final response = await _dio.post(
        baseUrl,
        data: requestData,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      debugPrint('Top stats response: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'success': data['status'] == 'success',
          'message': 'تم جلب الإحصائيات بنجاح',
          'stats': data['topstat_data'] ?? [],
        };
      } else {
        return {'success': false, 'message': 'خطأ في الاتصال بالخادم'};
      }
    } catch (e) {
      debugPrint('Error getting top stats: $e');
      return {
        'success': false,
        'message': 'حدث خطأ غير متوقع: ${e.toString()}',
      };
    }
  }

  // Get engineers statistics for a specific date
  Future<Map<String, dynamic>> getEngineersStats({String? datexx}) async {
    if (!_isLoggedIn || _userData == null) {
      return {'success': false, 'message': 'يجب تسجيل الدخول أولاً'};
    }

    try {
      final requestData = {'action': 'get_engineers_stats'};

      // Add date if provided
      if (datexx != null && datexx.isNotEmpty) {
        requestData['datexx'] = datexx;
      }

      debugPrint('Sending engineers stats request: $requestData');

      final response = await _dio.post(
        baseUrl,
        data: requestData,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      debugPrint('Engineers stats response: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'success': data['status'] == 'success',
          'message': 'تم جلب إحصائيات المهندسين بنجاح',
          'engineers_stats': data['engineers_stats'] ?? [],
          'date': data['date'] ?? '',
        };
      } else {
        return {'success': false, 'message': 'خطأ في الاتصال بالخادم'};
      }
    } catch (e) {
      debugPrint('Error getting engineers stats: $e');
      return {'success': false, 'message': 'خطأ في الشبكة: ${e.toString()}'};
    }
  }

  /// Get visit details (customer name, phone, contractor phone)
  Future<Map<String, dynamic>> getVisitDetails(String visitId) async {
    try {
      debugPrint('Getting visit details for visit: $visitId');

      final response = await _dio.post(
        baseUrl,
        data: json.encode({
          'action': 'get_visit_details',
          'visit_id': visitId.toString(),
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      debugPrint('Visit details response: ${response.data}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        return {'success': false, 'message': 'فشل في الاتصال بالخادم'};
      }
    } catch (e) {
      debugPrint('Error getting visit details: $e');
      return {'success': false, 'message': 'خطأ في الشبكة: ${e.toString()}'};
    }
  }

  /// Get engineer customers (all customers for current engineer)
  Future<Map<String, dynamic>> getEngineerCustomers() async {
    try {
      debugPrint('Getting customers for engineer: ${getUserId()}');

      final response = await _dio.post(
        baseUrl,
        data: json.encode({
          'action': 'get_engineer_customers',
          'engineer_id': getUserId(),
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      debugPrint('Engineer customers response: ${response.data}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        return {'success': false, 'message': 'فشل في الاتصال بالخادم'};
      }
    } catch (e) {
      debugPrint('Error getting engineer customers: $e');
      return {'success': false, 'message': 'خطأ في الشبكة: ${e.toString()}'};
    }
  }

  /// Delete visit from database
  Future<Map<String, dynamic>> deleteVisit(String visitId) async {
    try {
      debugPrint('Deleting visit: $visitId');

      final response = await _dio.post(
        baseUrl,
        data: json.encode({'action': 'delete_visit', 'visit_id': visitId}),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      debugPrint('Delete visit response: ${response.data}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        return {'success': false, 'message': 'فشل في الاتصال بالخادم'};
      }
    } catch (e) {
      debugPrint('Error deleting visit: $e');
      return {'success': false, 'message': 'خطأ في الشبكة: ${e.toString()}'};
    }
  }

  /// Update visit project ID
  Future<Map<String, dynamic>> updateVisitProject(
    String visitId,
    String projectId,
  ) async {
    try {
      debugPrint('Updating visit $visitId with project $projectId');

      final response = await _dio.post(
        baseUrl,
        data: json.encode({
          'action': 'update_visit_project',
          'visit_id': visitId,
          'project_id': projectId,
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      debugPrint('Update visit project response: ${response.data}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        return {'success': false, 'message': 'فشل في الاتصال بالخادم'};
      }
    } catch (e) {
      debugPrint('Error updating visit project: $e');
      return {'success': false, 'message': 'خطأ في الشبكة: ${e.toString()}'};
    }
  }

  /// Create new visit
  Future<Map<String, dynamic>> createNewVisit(
    String projectId,
    String engineerId,
  ) async {
    try {
      debugPrint('Creating new visit for project: $projectId');

      final response = await _dio.post(
        baseUrl,
        data: json.encode({
          'action': 'create_new_visit',
          'project_id': projectId.toString(),
          'engineer_id': getUserId(),
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      debugPrint('Create visit response: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'تم إنشاء الزيارة بنجاح',
            'visit_id': data['data']['visit_id'],
            'project_id': data['data']['project_id'],
            'engineer_id': data['data']['engineer_id'],
            'date': data['data']['date'],
            'datetime': data['data']['datetime'],
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'فشل في إنشاء الزيارة',
          };
        }
      } else {
        return {'success': false, 'message': 'خطأ في الاتصال بالخادم'};
      }
    } catch (e) {
      debugPrint('Error creating new visit: $e');
      return {
        'success': false,
        'message': 'حدث خطأ غير متوقع: ${e.toString()}',
      };
    }
  }

  /// Get total statistics for current user
  Future<Map<String, dynamic>> getTotalStats() async {
    if (!_isLoggedIn || _userData == null) {
      return {'success': false, 'message': 'يجب تسجيل الدخول أولاً'};
    }

    try {
      // Determine x parameter based on user type
      String x = '0'; // Default for admin
      switch (_userType) {
        case 1:
          x = '1';
          break; // Customer
        case 2:
          x = '2';
          break; // Engineer
        case 3:
          x = '3';
          break; // Contractor
      }

      final requestData = {
        'action': 'get_total',
        'uid': _userData!['id'].toString(),
        'x': x,
      };

      debugPrint('Sending total stats request: $requestData');

      final response = await _dio.post(
        baseUrl,
        data: requestData,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      debugPrint('Total stats response status: ${response.statusCode}');
      debugPrint('Total stats response data: ${response.data}');
      debugPrint('Total stats response type: ${response.data.runtimeType}');

      if (response.statusCode == 200) {
        // Handle both Map and String responses
        dynamic data;
        if (response.data is String) {
          try {
            data = json.decode(response.data);
          } catch (e) {
            debugPrint('JSON decode error: $e');
            debugPrint('Raw response: ${response.data}');
            return {
              'success': false,
              'message': 'خطأ في تحليل البيانات من الخادم',
            };
          }
        } else {
          data = response.data;
        }

        debugPrint('Parsed data: $data');

        if (data is Map && data['status'] == 'success') {
          return {
            'success': true,
            'message': 'تم جلب الإحصائيات بنجاح',
            'stats': data['trans_data'] ?? [],
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'خطأ في جلب الإحصائيات',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'خطأ في الاتصال بالخادم (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('Error getting total stats: $e');
      debugPrint('Error type: ${e.runtimeType}');
      return {
        'success': false,
        'message': 'حدث خطأ في الشبكة: ${e.toString()}',
      };
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
