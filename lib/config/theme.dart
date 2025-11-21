import 'package:flutter/material.dart';

class ThemeConfig {
  // Theme colors mapping - Final 10 themes
  static final Map<String, Map<String, Color>> themeColors = {
    'green': {
      'primary': Colors.green,
      'accent': Colors.green,
      'background': Colors.white,
      'text': Colors.black87,
      'buttonText': Colors.white,
    },
    'blue': {
      'primary': Colors.blue,
      'accent': Colors.blue,
      'background': Colors.white,
      'text': Colors.black87,
      'buttonText': Colors.white,
    },
    'oxfordBlue': {
      'primary': const Color(0xFF002147), // Oxford Blue
      'accent': const Color(0xFF001A35), // Darker Oxford Blue
      'background': Colors.white,
      'text': Colors.black87,
      'buttonText': Colors.white,
    },
    'purple': {
      'primary': Colors.purple,
      'accent': Colors.purple,
      'background': Colors.white,
      'text': Colors.black87,
      'buttonText': Colors.white,
    },
    'redOrange': {
      'primary': const Color(0xFFFF4500), // Red-Orange (OrangeRed)
      'accent': const Color(0xFFE63E00), // Darker red-orange
      'background': Colors.white,
      'text': Colors.black87,
      'buttonText': Colors.white,
    },
    'teal': {
      'primary': Colors.teal,
      'accent': Colors.teal,
      'background': Colors.white,
      'text': Colors.black87,
      'buttonText': Colors.white,
    },
    'dark': {
      'primary': Colors.grey.shade800,
      'accent': Colors.grey.shade800,
      'background': Colors.grey.shade100,
      'text': Colors.black87,
      'buttonText': Colors.white,
    },
    'targetRed': {
      'primary': const Color(0xFFCC0000), // Target Red
      'accent': const Color(0xFFB30000),
      'background': Colors.white,
      'text': Colors.black87,
      'buttonText': Colors.white,
    },
    'yellowGreen': {
      'primary': const Color(0xFFADFF2F), // YellowGreen (LimeGreen)
      'accent': const Color(0xFFCCFF90), // Light Lime (Material Lime[200])
      'background': Colors.white,
      'text': Colors.black87,
      'buttonText':
          Colors.black87, // Black text for better contrast on bright lime
    },
    'pink': {
      'primary': Colors.pink,
      'accent': Colors.pink,
      'background': Colors.white,
      'text': Colors.black87,
      'buttonText': Colors.white,
    },
  };

  // Default theme
  static const String defaultTheme = 'oxfordBlue';

  // Get theme colors for a specific theme
  static Map<String, Color> getThemeColors(String themeName) {
    return themeColors[themeName] ?? themeColors[defaultTheme]!;
  }

  // Get primary color for a theme
  static Color getPrimaryColor(String themeName) {
    return getThemeColors(themeName)['primary']!;
  }

  // Get background color for a theme
  static Color getBackgroundColor(String themeName) {
    return getThemeColors(themeName)['background']!;
  }

  // Get text color for a theme
  static Color getTextColor(String themeName) {
    return getThemeColors(themeName)['text']!;
  }

  // Get button text color for a theme
  static Color getButtonTextColor(String themeName) {
    return getThemeColors(themeName)['buttonText']!;
  }

  // Get all available theme names
  static List<String> getAvailableThemes() {
    return themeColors.keys.toList();
  }

  // Check if theme exists
  static bool isValidTheme(String themeName) {
    return themeColors.containsKey(themeName);
  }

  // Get red theme variations (simplified to 2)
  static List<String> getRedThemes() {
    return ['pennRed', 'redOrange'];
  }

  // Get theme category
  static String getThemeCategory(String themeName) {
    if (getRedThemes().contains(themeName)) return 'Red Variations';
    if (['green', 'yellowGreen', 'teal'].contains(themeName))
      return 'Green Variations';
    if (['blue', 'oxfordBlue', 'purple'].contains(themeName))
      return 'Cool Colors';
    if (['pink'].contains(themeName)) return 'Warm Colors';
    if (themeName == 'dark') return 'Dark Mode';
    return 'Other';
  }

  // Get theme display name
  static String getThemeDisplayName(String themeName) {
    final displayNames = {
      'green': 'Green',
      'blue': 'Blue',
      'oxfordBlue': 'Oxford Blue',
      'purple': 'Purple',
      'redOrange': 'Red Orange',
      'teal': 'Teal',
      'dark': 'Dark Mode',
      'pennRed': 'Penn Red',
      'yellowGreen': 'Yellow Green',
      'pink': 'Pink',
    };
    return displayNames[themeName] ?? themeName;
  }

  // Get all theme information
  static Map<String, dynamic> getThemeInfo(String themeName) {
    return {
      'name': themeName,
      'displayName': getThemeDisplayName(themeName),
      'category': getThemeCategory(themeName),
      'colors': getThemeColors(themeName),
      'primaryColor': getPrimaryColor(themeName),
    };
  }
}
