import 'package:shared_preferences/shared_preferences.dart';

class PreferencesHelper {
  static const String _keywordKey = 'sms_keywords';
  
  static Future<List<String>> getKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    final keywords = prefs.getStringList(_keywordKey);
    
    // Default keywords
    if (keywords == null || keywords.isEmpty) {
      return [
        'debited',
        'credited',
        'INR',
        'Rs.',
        'Rs',
        'UPI',
        'transaction',
        'paid',
        'received',
        'sent'
      ];
    }
    return keywords;
  }
  
  static Future<void> saveKeywords(List<String> keywords) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keywordKey, keywords);
  }
}
