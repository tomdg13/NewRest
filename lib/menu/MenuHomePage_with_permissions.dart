// MenuHomePage_with_permissions.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:inventory/business/ApprovalPage.dart';
import 'package:inventory/business/ListTerminalPage.dart';
import 'package:inventory/monitor/ProductPage.dart';
import 'package:inventory/monitor/StockPage.dart';
import 'package:inventory/monitor/ExpirePage.dart' show ExpirePage;
import 'package:inventory/monitor/locationPage.dart';
import 'package:inventory/report/StoreReportPage.dart' show StoreReportPage;
import 'package:inventory/upload/SettlementViewPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../utils/simple_translations.dart';
import '../services/menu_permission_service.dart'; // Import the permission service

class MenuHomePage extends StatefulWidget {
  const MenuHomePage({Key? key}) : super(key: key);

  @override
  State<MenuHomePage> createState() => _MenuHomePageState();
}

class _MenuHomePageState extends State<MenuHomePage> {
  String selectedLanguage = 'English';
  String selectedTheme = ThemeConfig.defaultTheme;
  String currentTheme = ThemeConfig.defaultTheme;
  bool isLoading = true;
  bool isLoadingPermissions = true;
  
  String _langCode = 'en';
  Color get _primaryColor => Theme.of(context).primaryColor;

  final List<String> languages = ['English', 'Lao'];
  List<String> get themes => ThemeConfig.getAvailableThemes();
  
  List<MenuItem> _menuItems = [];
  List<MenuItem> _visibleMenuItems = [];

  // Responsive design helpers (matching MenuSettingsPage)
  bool get _isWebDesktop => kIsWeb && MediaQuery.of(context).size.width > 1000;
  bool get _isTablet => MediaQuery.of(context).size.width > 600 && MediaQuery.of(context).size.width <= 1000;
  
  int get _crossAxisCount {
    if (_isWebDesktop) return 5;
    if (_isTablet) return 4;
    return 3; // Mobile
  }
  
  double get _childAspectRatio {
    if (_isWebDesktop) return 1.1;
    if (_isTablet) return 1.0;
    return 0.9; // Mobile
  }
  
  double get _maxWidth {
    if (_isWebDesktop) return 1400;
    return double.infinity;
  }

  @override
  void initState() {
    super.initState();
    _initializeMenuItems();
    _loadSavedSettings();
    _loadPermissions();
  }

  void _initializeMenuItems() {
    _menuItems = [
      MenuItem(
        icon: Icons.storefront,
        title: 'Store',
        permissionKey: 'Store',
        color: const Color.fromARGB(255, 211, 23, 198),
        onTap: _navigateToStoreReportService,
      ),
      MenuItem(
        icon: Icons.library_add_check,
        title: 'Approve',
        permissionKey: 'Approve',
        color: Colors.green,
        onTap: _navigateToApprovePage,
      ),
      MenuItem(
        icon: Icons.computer,
        title: 'Terminal',
        permissionKey: 'Terminal',
        color: Colors.blue,
        onTap: _navigateToTerminalPage,
      ),
      MenuItem(
        icon: Icons.schedule,
        title: 'expiry',
        permissionKey: 'expiry',
        color: Colors.red,
        onTap: _navigateToExpiryPage,
      ),
      MenuItem(
        icon: Icons.inventory_2,
        title: 'stock',
        permissionKey: 'stock',
        color: Colors.orange,
        onTap: _navigateToStockPage,
      ),
      MenuItem(
        icon: Icons.location_on,
        title: 'location',
        permissionKey: 'location',
        color: Colors.teal,
        onTap: _navigateToLocationPage,
      ),
      MenuItem(
        icon: Icons.shopping_bag,
        title: 'product',
        permissionKey: 'product',
        color: Colors.amber.shade700,
        onTap: _navigateToProductsPage,
      ),
      MenuItem(
        icon: Icons.account_balance_wallet,
        title: 'Settle',
        permissionKey: 'Settle',
        color: Colors.indigo,
        onTap: _navigateToSettlementViewPage,
      ),
    ];
  }

  Future<void> _loadPermissions() async {
    setState(() => isLoadingPermissions = true);

    try {
      // Check if user is super admin
      final isSuperAdmin = await MenuPermissionService().isSuperAdmin();
      
      if (isSuperAdmin) {
        // Super admin sees everything
        setState(() {
          _visibleMenuItems = _menuItems;
          isLoadingPermissions = false;
        });
      } else {
        // Load user permissions
        await MenuPermissionService().loadUserPermissions();
        
        // Filter menu items based on permissions
        setState(() {
          _visibleMenuItems = _menuItems.where((item) => item.isVisible).toList();
          isLoadingPermissions = false;
        });
      }
      
      // Show message if no menu items are visible
      if (_visibleMenuItems.isEmpty && mounted) {
        _showNoPermissionsDialog();
      }
    } catch (e) {
      print('Error loading permissions: $e');
      setState(() {
        isLoadingPermissions = false;
        // Show all items if permissions fail to load (or show none based on your security preference)
        _visibleMenuItems = []; // Empty for security
      });
    }
  }

  void _showNoPermissionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Limited Access'),
          ],
        ),
        content: Text(
          'You do not have permission to access any modules in this menu. '
          'Please contact your administrator to request access.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to previous screen
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reloadThemeIfChanged();
  }

  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
      final validTheme = ThemeConfig.isValidTheme(savedTheme) ? savedTheme : ThemeConfig.defaultTheme;

      final savedLanguage = prefs.getString('selectedLanguage') ?? 'English';
      final validLanguage = languages.contains(savedLanguage) ? savedLanguage : 'English';

      _langCode = prefs.getString('languageCode') ?? 'en';

      if (mounted) {
        setState(() {
          selectedTheme = validTheme;
          currentTheme = validTheme;
          selectedLanguage = validLanguage;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) {
        setState(() {
          selectedTheme = ThemeConfig.defaultTheme;
          currentTheme = ThemeConfig.defaultTheme;
          selectedLanguage = 'English';
          _langCode = 'en';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _reloadThemeIfChanged() async {
    if (isLoading) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;

      if (mounted && currentTheme != savedTheme) {
        setState(() {
          currentTheme = savedTheme;
          selectedTheme = savedTheme;
        });
      }
    } catch (e) {
      debugPrint('Error reloading theme: $e');
    }
  }

  Future<void> _saveTheme(String theme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedTheme', theme);

      if (mounted) {
        setState(() {
          selectedTheme = theme;
          currentTheme = theme;
        });
      }
    } catch (e) {
      debugPrint('Error saving theme: $e');
      _showErrorSnackBar(SimpleTranslations.get(_langCode, 'error_save_theme'));
    }
  }

  Future<void> _saveLanguage(String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedLanguage', language);

      String langCode = language == 'Lao' ? 'la' : 'en';
      await prefs.setString('languageCode', langCode);
      
      if (mounted) {
        setState(() {
          selectedLanguage = language;
          _langCode = langCode;
        });
      }
    } catch (e) {
      debugPrint('Error saving language: $e');
      _showErrorSnackBar(SimpleTranslations.get(_langCode, 'error_save_language'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || isLoadingPermissions) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(isLoadingPermissions ? 'Loading permissions...' : 'Loading settings...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_visibleMenuItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No accessible modules',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Contact your administrator for access',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadPermissions(),
              icon: Icon(Icons.refresh),
              label: Text('Refresh Permissions'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: _maxWidth),
        padding: EdgeInsets.all(_isWebDesktop ? 24.0 : 16.0),
        child: Column(
          children: [
            if (_isWebDesktop) _buildHeaderSection(),
            Expanded(child: _buildMainGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  SimpleTranslations.get(_langCode, 'welcome_inventory'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              if (_visibleMenuItems.length < _menuItems.length)
                Chip(
                  label: Text(
                    '${_visibleMenuItems.length} of ${_menuItems.length} modules',
                    style: TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.orange.withOpacity(0.2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            SimpleTranslations.get(_langCode, 'inventory_description'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainGrid() {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _crossAxisCount,
        crossAxisSpacing: _isWebDesktop ? 24 : 16,
        mainAxisSpacing: _isWebDesktop ? 24 : 16,
        childAspectRatio: _childAspectRatio,
      ),
      itemCount: _visibleMenuItems.length,
      itemBuilder: (context, index) {
        final item = _visibleMenuItems[index];
        return _buildGridItem(
          icon: item.icon,
          title: SimpleTranslations.get(_langCode, item.title),
          color: item.color,
          onTap: item.onTap,
        );
      },
    );
  }

  Widget _buildGridItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isLargeScreen = _isWebDesktop || _isTablet;
    
    return Card(
      elevation: _isWebDesktop ? 4 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_isWebDesktop ? 20 : 16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_isWebDesktop ? 20 : 16),
        child: Container(
          padding: EdgeInsets.all(isLargeScreen ? 16 : 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(isLargeScreen ? 20 : 12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isLargeScreen ? 40 : 28,
                ),
              ),
              SizedBox(height: isLargeScreen ? 12 : 6),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isLargeScreen ? 14 : 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Navigation methods
  void _navigateToTerminalPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ListterminalPage()),
    );
  }

  void _navigateToApprovePage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ApprovalPage()),
    );
  }

  void _navigateToStoreReportService() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StoreReportPage()),
    );
  }

  void _navigateToExpiryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ExpirePage()),
    );
  }

  void _navigateToStockPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StockPage()),
    );
  }

  void _navigateToLocationPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPage()),
    );
  }

  void _navigateToProductsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProductPage()),
    );
  }

  void _navigateToSettlementViewPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettlementViewPage()),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(SimpleTranslations.get(_langCode, 'select_language')),
          content: SizedBox(
            width: _isWebDesktop ? 400 : double.minPositive,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: languages.length,
              itemBuilder: (context, index) {
                final language = languages[index];
                return ListTile(
                  title: Text(language),
                  leading: Radio<String>(
                    value: language,
                    groupValue: selectedLanguage,
                    onChanged: (String? value) async {
                      if (value != null) {
                        await _saveLanguage(value);
                        if (mounted) {
                          Navigator.of(context).pop();
                          _showSnackBar('${SimpleTranslations.get(_langCode, 'language_changed')} $value');
                        }
                      }
                    },
                  ),
                  onTap: () async {
                    await _saveLanguage(language);
                    if (mounted) {
                      Navigator.of(context).pop();
                      _showSnackBar('${SimpleTranslations.get(_langCode, 'language_changed')} $language');
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(SimpleTranslations.get(_langCode, 'cancel')),
            ),
          ],
        );
      },
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(SimpleTranslations.get(_langCode, 'select_theme')),
          content: SizedBox(
            width: _isWebDesktop ? 400 : double.minPositive,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: themes.map((theme) {
                final displayName = ThemeConfig.getThemeDisplayName(theme);
                final primaryColor = ThemeConfig.getPrimaryColor(theme);

                return ListTile(
                  title: Text(displayName),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<String>(
                        value: theme,
                        groupValue: selectedTheme,
                        onChanged: (String? value) async {
                          if (value != null) {
                            await _saveTheme(value);
                            if (mounted) {
                              Navigator.of(context).pop();
                              _showSnackBar(
                                '${SimpleTranslations.get(_langCode, 'theme_changed')} ${ThemeConfig.getThemeDisplayName(value)}',
                              );
                            }
                          }
                        },
                      ),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                      ),
                    ],
                  ),
                  onTap: () async {
                    await _saveTheme(theme);
                    if (mounted) {
                      Navigator.of(context).pop();
                      _showSnackBar(
                        '${SimpleTranslations.get(_langCode, 'theme_changed')} ${ThemeConfig.getThemeDisplayName(theme)}',
                      );
                    }
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(SimpleTranslations.get(_langCode, 'cancel')),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.green.shade600,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        SimpleTranslations.get(_langCode, 'home_menu'),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        // Permission refresh button
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () async {
            await _loadPermissions();
            _showSnackBar('Permissions refreshed');
          },
          tooltip: 'Refresh Permissions',
        ),
        IconButton(
          icon: const Icon(Icons.language),
          onPressed: _showLanguageDialog,
          tooltip: SimpleTranslations.get(_langCode, 'language'),
        ),
        IconButton(
          icon: const Icon(Icons.palette),
          onPressed: _showThemeDialog,
          tooltip: SimpleTranslations.get(_langCode, 'theme'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}