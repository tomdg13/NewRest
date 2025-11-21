import 'package:flutter/material.dart';
import 'package:inventory/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login/login_page.dart';
import 'menu/MenuWigetPage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  String currentTheme = ThemeConfig.defaultTheme;
  Locale currentLocale = const Locale('en');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedPreferences();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload theme when app resumes
      _loadSavedPreferences();
    }
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme =
        prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    final savedLangCode = prefs.getString('languageCode') ?? 'en';

    if (mounted) {
      setState(() {
        currentTheme = savedTheme;
        currentLocale = Locale(savedLangCode);
      });
    }
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', locale.languageCode);
    if (mounted) {
      setState(() {
        currentLocale = locale;
      });
    }
  }

  // Add theme changing functionality
  Future<void> setTheme(String themeName) async {
    if (!ThemeConfig.isValidTheme(themeName)) {
      return; // Invalid theme, don't change
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedTheme', themeName);
    
    if (mounted) {
      setState(() {
        currentTheme = themeName;
      });
    }
  }

  // Get current theme info for UI components
  String getCurrentTheme() => currentTheme;

  ThemeData _buildTheme() {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final buttonTextColor = ThemeConfig.getButtonTextColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);

    return ThemeData(
      primarySwatch: _createMaterialColor(primaryColor),
      primaryColor: primaryColor,
      
      // AppBar theme
      // appBarTheme: AppBarTheme(
      //   backgroundColor: primaryColor,
      //   elevation: 2,
      //   titleTextStyle: TextStyle(
      //     color: buttonTextColor,
      //     fontSize: 20,
      //     fontWeight: FontWeight.w600,
      //   ),
      //   iconTheme: IconThemeData(color: buttonTextColor),
      //   actionsIconTheme: IconThemeData(color: buttonTextColor),
      // ),
      
      // Button themes
      // elevatedButtonTheme: ElevatedButtonThemeData(
      //   style: ElevatedButton.styleFrom(
      //     backgroundColor: primaryColor,
      //     foregroundColor: buttonTextColor,
      //     textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      //     padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      //     shape: RoundedRectangleBorder(
      //       borderRadius: BorderRadius.circular(8),
      //     ),
      //   ),
      // ),
      
      // outlinedButtonTheme: OutlinedButtonThemeData(
      //   style: OutlinedButton.styleFrom(
      //     foregroundColor: primaryColor,
      //     side: BorderSide(color: primaryColor, width: 1.5),
      //     padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      //     shape: RoundedRectangleBorder(
      //       borderRadius: BorderRadius.circular(8),
      //     ),
      //   ),
      // ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        floatingLabelStyle: TextStyle(color: primaryColor),
      ),
      
      // Other component themes
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(buttonTextColor),
      ),
      
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.grey;
        }),
      ),
      
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withOpacity(0.3);
          }
          return Colors.grey.withOpacity(0.3);
        }),
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: buttonTextColor,
        elevation: 6,
      ),
      
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primaryColor),
      
      // Scaffold and text themes
      scaffoldBackgroundColor: backgroundColor,
      
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textColor),
        bodyMedium: TextStyle(color: textColor),
        bodySmall: TextStyle(color: textColor),
        headlineLarge: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textColor, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: textColor, fontWeight: FontWeight.w500),
      ),
      
      // Color scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        background: backgroundColor,
        surface: backgroundColor,
      ).copyWith(
        primary: primaryColor,
        secondary: ThemeConfig.getThemeColors(currentTheme)['accent'],
      ),
      
      // Card theme
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // Divider theme
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade300,
        thickness: 1,
      ),
    );
  }

  MaterialColor _createMaterialColor(Color color) {
    final List<double> strengths = <double>[.05];
    final swatch = <int, Color>{};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (double strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Main',
      theme: _buildTheme(),
      locale: currentLocale,
      initialRoute: '/',
      routes: {
        '/': (ctx) => LoginPage(setLocale: setLocale),
        '/menu': (ctx) {
          final args =
              ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
          final role = args?['role'] ?? 'customer';
          return MenuPage(
            role: role,
            setTheme: setTheme,
            getCurrentTheme: getCurrentTheme,
          );
        },
      },
    );
  }
}