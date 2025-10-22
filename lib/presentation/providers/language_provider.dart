import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  
  Locale _currentLocale = const Locale('ar'); // Default to Arabic
  
  Locale get currentLocale => _currentLocale;
  
  String get currentLanguageCode => _currentLocale.languageCode;
  
  String get currentLanguageName {
    switch (_currentLocale.languageCode) {
      case 'ar':
        return 'العربية';
      case 'en':
        return 'English';
      case 'ur':
        return 'اردو';
      case 'fa':
        return 'فارسی';
      case 'bn':
        return 'বাংলা';
      case 'hi':
        return 'हिंदी';
      default:
        return 'العربية';
    }
  }
  
  // Load saved language preference
  Future<void> loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_languageKey) ?? 'ar';
      _currentLocale = Locale(languageCode);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading language: $e');
    }
  }
  
  // Change language and save preference
  Future<void> changeLanguage(String languageCode) async {
    try {
      _currentLocale = Locale(languageCode);
      notifyListeners();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
      
      debugPrint('Language changed to: $languageCode');
    } catch (e) {
      debugPrint('Error changing language: $e');
    }
  }
  
  // Get all supported languages
  List<Map<String, String>> getSupportedLanguages() {
    return [
      {'code': 'ar', 'name': 'العربية', 'nativeName': 'العربية'},
      {'code': 'en', 'name': 'English', 'nativeName': 'English'},
      {'code': 'ur', 'name': 'اردو', 'nativeName': 'اردو'},
      {'code': 'fa', 'name': 'فارسی', 'nativeName': 'فارسی'},
      {'code': 'bn', 'name': 'বাংলা', 'nativeName': 'বাংলা'},
      {'code': 'hi', 'name': 'हिंदी', 'nativeName': 'हिंदी'},
    ];
  }
  
  // Check if language is RTL
  bool get isRTL {
    return ['ar', 'ur', 'fa'].contains(_currentLocale.languageCode);
  }
}
