import 'en.dart';
import 'la.dart';

class SimpleTranslations {
  static const Map<String, Map<String, String>> _translations = {
    'en': enTranslations,
    'la': laTranslations,
  };

  final String lang;
  const SimpleTranslations(this.lang);

  String t(String key) {
    return _translations[lang]?[key] ?? key;
  }

  static String get(String lang, String key) {
    return _translations[lang]?[key] ?? key;
  }
}