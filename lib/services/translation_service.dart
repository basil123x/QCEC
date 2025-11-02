import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart'; // Use this instead!

class TranslationService {
  // Singleton instance
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  // Google Translator instance
  final _translator = GoogleTranslator();

  // Cache for translations to avoid repeated API calls
  static final Map<String, Map<String, String>> _translationCache = {};

  /// Get language code from locale
  static String _getLanguageCode(String locale) {
    switch (locale) {
      case 'ar':
        return 'ar'; // Arabic
      case 'en':
        return 'en'; // English
      case 'ur':
        return 'ur'; // Urdu
      case 'fa':
        return 'fa'; // Persian/Farsi
      case 'hi':
        return 'hi'; // Hindi
      case 'bn':
        return 'bn'; // Bengali
      default:
        return 'ar'; // Default to Arabic
    }
  }

  /// Translate text to target language
  Future<String> translateText({
    required String text,
    required String targetLanguage,
    String sourceLanguage = 'ar', // Default source is Arabic
  }) async {
    try {
      // Return original text if it's empty or target is same as source
      if (text.trim().isEmpty || targetLanguage == sourceLanguage) {
        return text;
      }

      // Check cache first
      final cacheKey = '${text}_${sourceLanguage}_$targetLanguage';
      if (_translationCache.containsKey(cacheKey)) {
        return _translationCache[cacheKey]!['translation'] ?? text;
      }

      // Get language codes
      final targetLangCode = _getLanguageCode(targetLanguage);
      final sourceLangCode = _getLanguageCode(sourceLanguage);

      // Perform translation
      final translation = await _translator.translate(
        text,
        from: sourceLangCode,
        to: targetLangCode,
      );

      // Cache the result
      _translationCache[cacheKey] = {
        'translation': translation.text,
        'timestamp': DateTime.now().toIso8601String(),
      };

      debugPrint(
        '🌐 Translated: "$text" -> "${translation.text}" ($sourceLangCode -> $targetLangCode)',
      );

      return translation.text;
    } catch (e) {
      debugPrint('🌐 Translation error: $e');
      // Return original text if translation fails
      return text;
    }
  }

  /// Translate visit description and notes based on current locale
  Future<Map<String, String>> translateVisitContent({
    required String description,
    required String notes,
    required String currentLocale,
  }) async {
    try {
      // If current locale is Arabic, return original content
      if (currentLocale == 'ar') {
        return {'description': description, 'notes': notes};
      }

      // Translate both description and notes concurrently
      final results = await Future.wait([
        translateText(
          text: description,
          targetLanguage: currentLocale,
          sourceLanguage: 'ar',
        ),
        translateText(
          text: notes,
          targetLanguage: currentLocale,
          sourceLanguage: 'ar',
        ),
      ]);

      return {'description': results[0], 'notes': results[1]};
    } catch (e) {
      debugPrint('🌐 Error translating visit content: $e');
      // Return original content if translation fails
      return {'description': description, 'notes': notes};
    }
  }

  /// Translate a list of texts
  Future<List<String>> translateBatch({
    required List<String> texts,
    required String targetLanguage,
    String sourceLanguage = 'ar',
  }) async {
    try {
      final results = await Future.wait(
        texts.map((text) => translateText(
          text: text,
          targetLanguage: targetLanguage,
          sourceLanguage: sourceLanguage,
        )),
      );
      return results;
    } catch (e) {
      debugPrint('🌐 Batch translation error: $e');
      return texts; // Return original texts if translation fails
    }
  }

  /// Clear translation cache (useful for memory management)
  static void clearCache() {
    _translationCache.clear();
    debugPrint('🌐 Translation cache cleared');
  }

  /// Get cache size for debugging
  static int getCacheSize() {
    return _translationCache.length;
  }

  /// Clean old cache entries (older than 1 hour)
  static void cleanOldCache() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    _translationCache.forEach((key, value) {
      final timestamp = DateTime.tryParse(value['timestamp'] ?? '');
      if (timestamp != null) {
        final difference = now.difference(timestamp);
        if (difference.inHours > 1) {
          keysToRemove.add(key);
        }
      }
    });

    for (final key in keysToRemove) {
      _translationCache.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      debugPrint('🌐 Cleaned ${keysToRemove.length} old cache entries');
    }
  }

  /// Check if translation is available (test connectivity)
  Future<bool> isTranslationAvailable() async {
    try {
      await _translator.translate('test', from: 'en', to: 'ar');
      return true;
    } catch (e) {
      debugPrint('🌐 Translation service unavailable: $e');
      return false;
    }
  }
}