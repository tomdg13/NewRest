import 'package:flutter/material.dart';
import 'package:inventory/config/theme.dart';
import 'package:inventory/menu/AddStockPage.dart';
import 'package:inventory/menu/DeductStockPage.dart';
// import 'package:inventory/menu/MenuHomePage_with_permissions.dart';
import 'package:inventory/menu/MenuHomePage.dart' show MenuHomePage;
import 'package:inventory/menu/MenuSettingsPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';

class MenuPage extends StatefulWidget {
  final String role;
  final int tabIndex;
  final Function(String)? setTheme;
  final String Function()? getCurrentTheme;

  const MenuPage({
    Key? key,
    required this.role,
    this.tabIndex = 0,
    this.setTheme,
    this.getCurrentTheme,
  }) : super(key: key);

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _TabItem {
  final String label;
  final IconData icon;
  final Widget? widget;
  _TabItem(this.label, this.icon, this.widget);
}

class _MenuPageState extends State<MenuPage> {
  int _idx = 0;
  List<_TabItem> tabs = [];
  String langCode = 'en';
  String currentTheme = ThemeConfig.defaultTheme;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeMenuPage();
  }

  Future<void> _initializeMenuPage() async {
    await _loadTheme();
    await _getLanguage();
    _buildTabs();
    setState(() {
      _idx = widget.tabIndex;
      isLoading = false;
    });
  }

  Future<void> _getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    langCode = prefs.getString('languageCode') ?? 'en';
    debugPrint('Language code: $langCode');
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme =
        prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    if (mounted) {
      setState(() {
        currentTheme = savedTheme;
      });
    }
  }

  void _buildTabs() {
    setState(() {
      tabs = [_homeTab(), ..._getTabs(widget.role)];
    });
  }

  _TabItem _homeTab() {
    return _TabItem(
      SimpleTranslations.get(langCode, 'dashboard'),
      Icons.dashboard,
      const MenuHomePage(),
    );
  }

  List<_TabItem> _getTabs(String role) {
    switch (role.toLowerCase()) {
      case 'driver':
      default:
        return [
        

          _TabItem(
            SimpleTranslations.get(langCode, 'deduct'),
            Icons.cached,
            const DeductStockPage(),
          ), 

          _TabItem(
            SimpleTranslations.get(langCode, 'increase'),
            Icons.loyalty,
            const AddStockPage(),
          ),

          _TabItem(
            SimpleTranslations.get(langCode, 'settings'),
            Icons.settings,
            const MenuSettingsPage(),
          ),
        ];
    }
  }

  Future<void> _updateTheme(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedTheme', themeName);

    if (widget.setTheme != null) {
      await widget.setTheme!(themeName);
    }

    setState(() {
      currentTheme = themeName;
    });
  }

  // ignore: unused_element
  Future<void> _showLogoutDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
        final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
        final textColor = ThemeConfig.getTextColor(currentTheme);

        return AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: primaryColor, size: 24),
              const SizedBox(width: 8),
              Text(
                SimpleTranslations.get(langCode, 'logout'),
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            SimpleTranslations.get(langCode, 'logout_confirmation'),
            style: TextStyle(color: textColor, fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                SimpleTranslations.get(langCode, 'cancel'),
                style: TextStyle(color: textColor.withOpacity(0.7)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final prefs = await SharedPreferences.getInstance();
                
                // Clear user session data but preserve settings
                await prefs.remove('access_token');
                await prefs.remove('user_token');
                await prefs.remove('user_id');
                await prefs.remove('user_email');
                await prefs.remove('is_logged_in');
                
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(SimpleTranslations.get(langCode, 'logout')),
            ),
          ],
        );
      },
    );
  }

  // ignore: unused_element
  Future<void> _showThemeSelector() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
        final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
        final textColor = ThemeConfig.getTextColor(currentTheme);

        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.palette, color: primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      SimpleTranslations.get(langCode, 'select_theme'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Theme list
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  child: Column(
                    children: ThemeConfig.getAvailableThemes().map((themeName) {
                      final isSelected = currentTheme == themeName;
                      return ListTile(
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: ThemeConfig.getPrimaryColor(themeName),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? primaryColor
                                  : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  color: ThemeConfig.getButtonTextColor(
                                    themeName,
                                  ),
                                  size: 18,
                                )
                              : null,
                        ),
                        title: Text(
                          ThemeConfig.getThemeDisplayName(themeName),
                          style: TextStyle(
                            color: textColor,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          ThemeConfig.getThemeCategory(themeName),
                          style: TextStyle(
                            color: textColor.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: primaryColor)
                            : null,
                        onTap: () async {
                          await _updateTheme(themeName);
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);

    if (isLoading || tabs.isEmpty) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        color: backgroundColor,
        child: tabs[_idx].widget ?? const SizedBox.shrink(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _idx,
          onTap: (i) {
            setState(() => _idx = i);
          },
          selectedItemColor: primaryColor,
          unselectedItemColor: textColor.withOpacity(0.5),
          backgroundColor: backgroundColor,
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: primaryColor,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: textColor.withOpacity(0.5),
          ),
          items: tabs
              .map(
                (t) => BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Icon(
                      t.icon,
                      size: tabs.indexOf(t) == _idx ? 26 : 24,
                    ),
                  ),
                  activeIcon: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(t.icon, size: 26, color: primaryColor),
                  ),
                  label: t.label,
                ),
              )
              .toList(),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
      ),
    );
  }
}