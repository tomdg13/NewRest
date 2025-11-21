import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:inventory/business/BranchPage.dart';
import 'package:inventory/business/CompanyPage.dart';
import 'package:inventory/business/GroupPage.dart' show GroupPage;
import 'package:inventory/business/LocationPage.dart';
import 'package:inventory/business/MerchantPage.dart';
import 'package:inventory/business/PermissionManagementPage.dart';
import 'package:inventory/business/ProductPage.dart';
import 'package:inventory/business/RoleList.dart';
import 'package:inventory/business/RolePermissionPage.dart';
import 'package:inventory/business/StorePage.dart';
import 'package:inventory/business/TerminalPage.dart';
import 'package:inventory/business/UserPage.dart';
import 'package:inventory/business/VendorPage.dart';
import 'package:inventory/csv_upload/csv_upload_page.dart';
import 'package:inventory/login/login_page.dart' show LoginPage;
import 'package:inventory/upload/settlement_upload_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../business/RolePermissionMappingPage.dart';
import '../services/menu_permission_service.dart';
import '../config/theme.dart';
import '../utils/simple_translations.dart';

class MenuSettingsPage extends StatefulWidget {
  const MenuSettingsPage({Key? key}) : super(key: key);

  @override
  State<MenuSettingsPage> createState() => _MenuSettingsPageState();
}

class _MenuSettingsPageState extends State<MenuSettingsPage> {
  String selectedLanguage = 'English';
  String selectedTheme = ThemeConfig.defaultTheme;
  String currentTheme = ThemeConfig.defaultTheme;
  bool isLoading = true;
  
  String _langCode = 'en';
  Color get _primaryColor => Theme.of(context).primaryColor;

  final List<String> languages = ['English', 'Lao'];
  List<String> get themes => ThemeConfig.getAvailableThemes();

  // Responsive design helpers
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
    _loadSavedSettings();
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

  Future<void> _handleLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove('access_token');
      await prefs.remove('user_token');
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      await prefs.remove('is_logged_in');
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      _showErrorSnackBar(SimpleTranslations.get(_langCode, 'error_logout'));
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.logout, color: Colors.red),
              const SizedBox(width: 8),
              Text(SimpleTranslations.get(_langCode, 'logout')),
            ],
          ),
          content: Text(SimpleTranslations.get(_langCode, 'logout_confirmation')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(SimpleTranslations.get(_langCode, 'cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(SimpleTranslations.get(_langCode, 'logout')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: _maxWidth),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(_isWebDesktop ? 24.0 : 16.0),
          child: Column(
            children: [
              if (_isWebDesktop) _buildHeaderSection(),
              _buildMainGrid(),
            ],
          ),
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
          Text(
            SimpleTranslations.get(_langCode, 'settings_management'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            SimpleTranslations.get(_langCode, 'manage_system_settings'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: _crossAxisCount,
      crossAxisSpacing: _isWebDesktop ? 24 : 16,
      mainAxisSpacing: _isWebDesktop ? 24 : 16,
      childAspectRatio: _childAspectRatio,
      children: [
        // Business Management Section
        ..._buildBusinessGridItems(),
        
        // Settings Section
        ..._buildSettingsGridItems(),
        
        // Additional Features
        ..._buildAdditionalGridItems(),
      ],
    );
  }

  List<Widget> _buildBusinessGridItems() {
    return [
      
      
      _buildGridItem(
        icon: Icons.group,
        title: SimpleTranslations.get(_langCode, 'group'),
        color: Colors.blue,
        onTap: _navigateToGroupPage,
      ),
      _buildGridItem(
        icon: Icons.business,
        title: SimpleTranslations.get(_langCode, 'merchant'),
        color: Colors.green,
        onTap: _navigateToMerchantPage,
      ),
      _buildGridItem(
        icon: Icons.storefront,
        title: SimpleTranslations.get(_langCode, 'store'),
        color: Colors.orange,
        onTap: _navigateToStorePage,
      ),
      _buildGridItem(
        icon: Icons.computer,
        title: SimpleTranslations.get(_langCode, 'terminal'),
        color: Colors.purple,
        onTap: _navigateToTerminalPage,
      ),
      _buildGridItem(
        icon: Icons.account_tree,
        title: SimpleTranslations.get(_langCode, 'branch'),
        color: Colors.teal,
        onTap: _navigateToBranchPage,
      ),
      _buildGridItem(
        icon: Icons.location_on,
        title: SimpleTranslations.get(_langCode, 'location'),
        color: Colors.green.shade600,
        onTap: _navigateToLocationPage,
      ),
      _buildGridItem(
        icon: Icons.local_shipping,
        title: SimpleTranslations.get(_langCode, 'vendor'),
        color: Colors.indigo,
        onTap: _navigateToVenderPage,
      ),
      _buildGridItem(
        icon: Icons.inventory,
        title: SimpleTranslations.get(_langCode, 'product'),
        color: Colors.amber.shade700,
        onTap: _navigateToProductPage,
      ),
      

      _buildGridItem(
        icon: Icons.upload,
        title: SimpleTranslations.get(_langCode, 'uploadSettle'),
        color: Colors.green,
        onTap: _navigateTosettleupload,
      ),
      _buildGridItem(
        icon: Icons.upload,
        title: SimpleTranslations.get(_langCode, 'uploadCSV'),
        color: Colors.green,
        onTap: _navigateTouploadCSV,
      ),
      _buildGridItem(
        icon: Icons.person,
        title: SimpleTranslations.get(_langCode, 'User'),
        color: Colors.cyan,
        onTap: _navigateToUserPage,
      ),

      _buildGridItem(
        icon: Icons.keyboard_option_key,
        title: SimpleTranslations.get(_langCode, 'Role'),
        color: Colors.indigo,
        onTap: _navigateToRoleListPage,
      ),
//

      _buildGridItem(
        icon: Icons.key,
        title: SimpleTranslations.get(_langCode, 'Permission'),
        color: Colors.lightGreenAccent.shade700,
        onTap: _navigateToRolePermissionPage,
      ),

      _buildGridItem(
        icon: Icons.mediation,
        title: SimpleTranslations.get(_langCode, 'Role Permission Map'),
        color: Colors.purple,
        // onTap: _navigateToRolePermissionPage,
        onTap: _navigateToMenuPermission,
      ),
      

       
      
      _buildGridItem(
        icon: Icons.grass,
        title: SimpleTranslations.get(_langCode, 'Company'),
        color: Colors.lightGreenAccent.shade700,
        onTap: _navigateToCompanyPage,
      ),

     
    ];
  }

  List<Widget> _buildSettingsGridItems() {
    return [
      _buildLanguageGridItem(),
      _buildThemeGridItem(),
    ];
  }

  List<Widget> _buildAdditionalGridItems() {
    return [
      _buildLogoutGridItem(),
      _buildPlaceholderGridItem(
        SimpleTranslations.get(_langCode, 'help'), 
        Icons.help_outline
      ),
    ];
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

  Widget _buildLanguageGridItem() {
    final isLargeScreen = _isWebDesktop || _isTablet;
    
    return Card(
      elevation: _isWebDesktop ? 4 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_isWebDesktop ? 20 : 16),
      ),
      child: InkWell(
        onTap: _showLanguageDialog,
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
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 12),
                ),
                child: Icon(
                  Icons.language,
                  color: Colors.teal,
                  size: isLargeScreen ? 40 : 28,
                ),
              ),
              SizedBox(height: isLargeScreen ? 8 : 4),
              Text(
                SimpleTranslations.get(_langCode, 'language'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isLargeScreen ? 14 : 11,
                ),
              ),
              SizedBox(height: isLargeScreen ? 4 : 2),
              Flexible(
                child: Text(
                  selectedLanguage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isLargeScreen ? 12 : 9,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeGridItem() {
    final isLargeScreen = _isWebDesktop || _isTablet;
    
    return Card(
      elevation: _isWebDesktop ? 4 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_isWebDesktop ? 20 : 16),
      ),
      child: InkWell(
        onTap: _showThemeDialog,
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
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 12),
                ),
                child: Icon(
                  Icons.palette,
                  color: Colors.indigo,
                  size: isLargeScreen ? 40 : 28,
                ),
              ),
              SizedBox(height: isLargeScreen ? 8 : 4),
              Text(
                SimpleTranslations.get(_langCode, 'theme'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isLargeScreen ? 14 : 11,
                ),
              ),
              SizedBox(height: isLargeScreen ? 4 : 2),
              Flexible(
                child: Text(
                  ThemeConfig.getThemeDisplayName(selectedTheme),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isLargeScreen ? 12 : 9,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutGridItem() {
    final isLargeScreen = _isWebDesktop || _isTablet;
    
    return Card(
      elevation: _isWebDesktop ? 4 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_isWebDesktop ? 20 : 16),
      ),
      child: InkWell(
        onTap: _showLogoutDialog,
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
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 12),
                ),
                child: Icon(
                  Icons.logout,
                  color: Colors.red,
                  size: isLargeScreen ? 40 : 28,
                ),
              ),
              SizedBox(height: isLargeScreen ? 12 : 6),
              Flexible(
                child: Text(
                  SimpleTranslations.get(_langCode, 'logout'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isLargeScreen ? 14 : 11,
                    color: Colors.red,
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

  Widget _buildPlaceholderGridItem(String title, IconData icon) {
    final isLargeScreen = _isWebDesktop || _isTablet;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(_isWebDesktop ? 20 : 16),
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      child: InkWell(
        onTap: () => _showSnackBar('$title ${SimpleTranslations.get(_langCode, 'coming_soon')}'),
        borderRadius: BorderRadius.circular(_isWebDesktop ? 20 : 16),
        child: Padding(
          padding: EdgeInsets.all(isLargeScreen ? 16 : 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isLargeScreen ? 20 : 12),
                child: Icon(
                  icon,
                  color: Colors.grey.withOpacity(0.6),
                  size: isLargeScreen ? 40 : 24,
                ),
              ),
              SizedBox(height: isLargeScreen ? 8 : 4),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.withOpacity(0.6),
                  fontSize: isLargeScreen ? 14 : 10,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Navigation methods remain the same
  void _navigateToBranchPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => branchPage()),
    );
  }

  void _navigateToUserPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserPage()),
    );
  }

  void _navigateToRoleListPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RoleListPage()),
    );
  }

  
  void _navigateToRolePermissionPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PermissionManagementPage()),
    );
  }

  void _navigateToMenuPermission() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RolePermissionMappingPage()),
    );
  }

  

   void _navigateTosettleupload() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettlementUploadPage()),
    );
  }

  void _navigateTouploadCSV() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CSVUploadPage()),
    );
  }

  void _navigateToProductPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProductPage()),
    );
  }

  void _navigateToLocationPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPage()),
    );
  }

  void _navigateToVenderPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VendorPage()),
    );
  }

  void _navigateToStorePage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StorePage()),
    );
  }

  void _navigateToGroupPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GroupPage()),
    );
  }

  void _navigateToMerchantPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MerchantPage()),
    );
  }

  void _navigateToTerminalPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TerminalPage()),
    );
  }

  void _navigateToCompanyPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CompanyPage()),
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
        SimpleTranslations.get(_langCode, 'settings_management'),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    );
  }
}