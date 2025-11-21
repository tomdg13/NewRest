import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config/config.dart';
import '../config/theme.dart';
import '../utils/simple_translations.dart';
import 'ForgetPasswordPage.dart';

class LoginPage extends StatefulWidget {
  final Future<void> Function(Locale)? setLocale;

  const LoginPage({super.key, this.setLocale});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool rememberMe = false;
  bool loading = false;
  bool _obscurePassword = true;
  String msg = '';
  String currecntl = 'en';
  String currentTheme = ThemeConfig.defaultTheme;

  final Map<String, String> languages = {'en': '🇺🇸', 'la': '🇱🇦'};

  String _getText(String key) {
    return SimpleTranslations.get(currecntl, key);
  }

  // ========================================
  // UPDATED: Enhanced token decoding methods
  // ========================================
  
  /// Decode the full JWT token payload
  Map<String, dynamic>? _decodeTokenPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        print('TOKEN: Invalid token format - expected 3 parts, got ${parts.length}');
        return null;
      }
      
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = json.decode(payload) as Map<String, dynamic>;
      print('TOKEN: Successfully decoded payload: $decoded');
      return decoded;
    } catch (e, stackTrace) {
      print('TOKEN: Error decoding token: $e');
      print('TOKEN: Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get role_code from token (preferred method)
  String? _getRoleCode(String token) {
    final payload = _decodeTokenPayload(token);
    if (payload == null) return null;
    
    // Try role_code first (new structure)
    if (payload['role_code'] != null) {
      final roleCode = payload['role_code'].toString().toLowerCase();
      print('TOKEN: Found role_code: $roleCode');
      return roleCode;
    }
    
    // Fallback to old 'role' field for backward compatibility
    if (payload['role'] != null) {
      final role = payload['role'].toString().toLowerCase();
      print('TOKEN: Using fallback role field: $role');
      return role;
    }
    
    print('TOKEN: No role information found in token');
    return null;
  }

  /// Get role_id from token
  int? _getRoleId(String token) {
    final payload = _decodeTokenPayload(token);
    if (payload == null) return null;
    
    if (payload['role_id'] != null) {
      final roleId = payload['role_id'] is int 
          ? payload['role_id'] as int 
          : int.tryParse(payload['role_id'].toString());
      print('TOKEN: Found role_id: $roleId');
      return roleId;
    }
    
    return null;
  }

  /// Get role_name from token for display purposes
  String? _getRoleName(String token) {
    final payload = _decodeTokenPayload(token);
    if (payload == null) return null;
    
    if (payload['role_name'] != null) {
      final roleName = payload['role_name'].toString();
      print('TOKEN: Found role_name: $roleName');
      return roleName;
    }
    
    return null;
  }

  /// Get role_level from token (for permissions/hierarchy)
  int? _getRoleLevel(String token) {
    final payload = _decodeTokenPayload(token);
    if (payload == null) return null;
    
    if (payload['role_level'] != null) {
      final roleLevel = payload['role_level'] is int 
          ? payload['role_level'] as int 
          : int.tryParse(payload['role_level'].toString());
      print('TOKEN: Found role_level: $roleLevel');
      return roleLevel;
    }
    
    return null;
  }

  /// Get user_id from token
  int? _getUserId(String token) {
    final payload = _decodeTokenPayload(token);
    if (payload == null) return null;
    
    if (payload['user_id'] != null) {
      return payload['user_id'] is int 
          ? payload['user_id'] as int 
          : int.tryParse(payload['user_id'].toString());
    }
    
    return null;
  }

  /// Get company_id from token
  int? _getCompanyId(String token) {
    final payload = _decodeTokenPayload(token);
    if (payload == null) return null;
    
    if (payload['company_id'] != null) {
      return payload['company_id'] is int 
          ? payload['company_id'] as int 
          : int.tryParse(payload['company_id'].toString());
    }
    
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reloadTheme();
  }

  Future<void> _reloadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme =
        prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    if (mounted && currentTheme != savedTheme) {
      setState(() {
        currentTheme = savedTheme;
      });
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLangCode = prefs.getString('languageCode') ?? 'en';
    final savedTheme =
        prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;

    userCtrl.text = prefs.getString('user') ?? '';
    rememberMe = prefs.getBool('remember') ?? false;
    if (rememberMe) {
      passCtrl.text = prefs.getString('pass') ?? '';
    } else {
      passCtrl.text = '';
    }

    setState(() {
      currecntl = savedLangCode;
      currentTheme = savedTheme;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', userCtrl.text);
    await prefs.setString('phone', userCtrl.text);
    await prefs.setBool('remember', rememberMe);
    if (rememberMe) {
      await prefs.setString('pass', passCtrl.text);
    } else {
      await prefs.remove('pass');
    }
  }

  Future<void> _saveTheme(String themeKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedTheme', themeKey);

    setState(() {
      currentTheme = themeKey;
    });
  }

  Future<void> login() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      loading = true;
      msg = '';
    });

    try {
      final url = AppConfig.api('/api/auth/loginIOuser');
      print('LOGIN: Starting login process');
      print('LOGIN: API URL: $url');
      print('LOGIN: Username: ${userCtrl.text.trim()}');
      print('LOGIN: Password length: ${passCtrl.text.length}');

      final requestBody = {
        'userName': userCtrl.text.trim(),
        'password': passCtrl.text.trim(),
      };
      print('LOGIN: Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('LOGIN: Response status code: ${response.statusCode}');
      print('LOGIN: Response headers: ${response.headers}');
      print('LOGIN: Raw response body: ${response.body}');

      final data = jsonDecode(response.body);
      print('LOGIN: Parsed response data: $data');
      
      // Extract key fields
      final code = data['responseCode'];
      final message = data['message']?.toString().toLowerCase();
      final token = data['data']?['access_token'];
      final status = data['data']?['status']?.toString().toLowerCase();
      
      print('LOGIN: Response code: $code');
      print('LOGIN: Message: $message');
      print('LOGIN: Token received: ${token != null ? "Yes (${token.length} chars)" : "No"}');
      print('LOGIN: User status: $status');

      // ========================================
      // Check for password reset requirement
      // ========================================
      bool needsPasswordReset = false;

      // Scenario 1: 401 status with resetpassword message
      if (response.statusCode == 401 && message == 'resetpassword') {
        needsPasswordReset = true;
        print('LOGIN: Password reset required (401 response)');
      }
      // Scenario 2: Message field contains resetpassword
      else if (message == 'resetpassword') {
        needsPasswordReset = true;
        print('LOGIN: Password reset required (message field)');
      }
      // Scenario 3: Status field contains resetpassword
      else if (status == 'resetpassword') {
        needsPasswordReset = true;
        print('LOGIN: Password reset required (status field)');
      }

      // Handle password reset requirement
      if (needsPasswordReset) {
        print('LOGIN: Redirecting to ForgetPasswordPage');
        if (!mounted) return;
        
        print('LOGIN: Navigating to ForgetPasswordPage with phone: ${userCtrl.text.trim()}');
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ForgetPasswordPage(phone: userCtrl.text.trim()),
          ),
        );
        setState(() => loading = false);
        return;
      }

      // ========================================
      // Handle successful login
      // ========================================
      if (code == '00' && token != null) {
        print('LOGIN: Login successful - processing token');
        
        // Save access token
        await prefs.setString('access_token', token);
        print('LOGIN: Token saved to SharedPreferences');
        
        // Decode token and extract all role information
        final payload = _decodeTokenPayload(token);
        final roleCode = _getRoleCode(token);
        final roleId = _getRoleId(token);
        final roleName = _getRoleName(token);
        final roleLevel = _getRoleLevel(token);
        final userId = _getUserId(token);
        final companyId = _getCompanyId(token);
        
        print('LOGIN: ==========================================');
        print('LOGIN: Token payload: $payload');
        print('LOGIN: Decoded role_code: $roleCode');
        print('LOGIN: Decoded role_id: $roleId');
        print('LOGIN: Decoded role_name: $roleName');
        print('LOGIN: Decoded role_level: $roleLevel');
        print('LOGIN: Decoded user_id: $userId');
        print('LOGIN: Decoded company_id: $companyId');
        print('LOGIN: ==========================================');
        
        // Save all role information to SharedPreferences
        if (roleCode != null) {
          await prefs.setString('role_code', roleCode);
          print('LOGIN: Saved role_code to prefs');
        }
        if (roleId != null) {
          await prefs.setInt('role_id', roleId);
          print('LOGIN: Saved role_id to prefs');
        }
        if (roleName != null) {
          await prefs.setString('role_name', roleName);
          print('LOGIN: Saved role_name to prefs');
        }
        if (roleLevel != null) {
          await prefs.setInt('role_level', roleLevel);
          print('LOGIN: Saved role_level to prefs');
        }
        if (userId != null) {
          await prefs.setInt('user_id', userId);
          print('LOGIN: Saved user_id to prefs');
        }
        if (companyId != null) {
          await prefs.setInt('company_id', companyId);
          print('LOGIN: Saved company_id to prefs');
        }
        
        // Save user credentials if remember me is checked
        await _savePrefs();
        print('LOGIN: User preferences saved');

        if (!mounted) return;
        
        // Prepare arguments for menu navigation
        final menuArguments = {
          'role': roleCode ?? 'unknown',  // Use role_code as primary role
          'role_code': roleCode ?? 'unknown',
          'role_id': roleId,
          'role_name': roleName ?? 'Unknown',
          'role_level': roleLevel ?? 0,
          'user_id': userId,
          'company_id': companyId,
          'token': token,
        };
        print('LOGIN: Navigating to menu with arguments: $menuArguments');
        
        // Navigate to menu
        Navigator.pushReplacementNamed(
          context,
          '/menu',
          arguments: menuArguments,
        );
      } else {
        // ========================================
        // Handle login failure
        // ========================================
        print('LOGIN: Login failed');
        print('LOGIN: Error details - Code: $code, Data: ${data['data']}');
        
        final errorMessage = data['message'] ?? _getText('login_failed');
        print('LOGIN: Error message: $errorMessage');
        
        setState(() => msg = errorMessage);
      }
    } catch (e, stackTrace) {
      print('LOGIN: Exception caught: $e');
      print('LOGIN: Stack trace: $stackTrace');
      
      setState(() => msg = 'Network error: Please check your connection.');
    }

    print('LOGIN: Login process completed');
    setState(() => loading = false);
  }

  void _showThemeSelector() {
    final availableThemes = ThemeConfig.getAvailableThemes();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Select Theme',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: availableThemes.length,
              itemBuilder: (context, index) {
                return _buildThemeColorTile(availableThemes[index]);
              },
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: ThemeConfig.getPrimaryColor(
                  currentTheme,
                ).withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeColorTile(String themeKey) {
    final isSelected = currentTheme == themeKey;
    final primaryColor = ThemeConfig.getPrimaryColor(themeKey);
    final buttonTextColor = ThemeConfig.getButtonTextColor(themeKey);

    return GestureDetector(
      onTap: () async {
        await _saveTheme(themeKey);
        if (mounted) {
          Navigator.pop(context);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: isSelected
            ? Icon(Icons.check_circle, color: buttonTextColor, size: 28)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get theme colors using ThemeConfig
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final backgroundColor = ThemeConfig.getBackgroundColor(currentTheme);
    final textColor = ThemeConfig.getTextColor(currentTheme);
    final buttonTextColor = ThemeConfig.getButtonTextColor(currentTheme);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: buttonTextColor,
        elevation: 2,
        title: Text(
          _getText('loginTitle'),
          style: TextStyle(color: buttonTextColor, fontWeight: FontWeight.w600),
        ),
        actions: [
          // Theme selector button
          IconButton(
            icon: Icon(Icons.palette, color: buttonTextColor),
            onPressed: _showThemeSelector,
            tooltip: 'Select Theme',
          ),
          // Language selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: currecntl,
              dropdownColor: primaryColor,
              underline: const SizedBox(),
              iconEnabledColor: buttonTextColor,
              items: languages.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(
                    entry.value,
                    style: TextStyle(color: buttonTextColor, fontSize: 28),
                  ),
                );
              }).toList(),
              onChanged: (String? newLang) async {
                if (newLang == null) return;
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('languageCode', newLang);
                widget.setLocale?.call(Locale(newLang));
                setState(() => currecntl = newLang);
              },
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundColor, primaryColor.withOpacity(0.05)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // App logo/title area
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(Icons.devices_other, size: 64, color: primaryColor),
                ),

                const SizedBox(height: 40),

                // Phone input
                TextField(
                  controller: userCtrl,
                  style: TextStyle(color: textColor, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: _getText('phone'),
                    labelStyle: TextStyle(color: primaryColor),
                    prefixIcon: Icon(Icons.phone, color: primaryColor),
                    filled: true,
                    fillColor: backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: primaryColor.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: primaryColor.withOpacity(0.3),
                      ),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 16),

                // Password input
                TextField(
                  controller: passCtrl,
                  obscureText: _obscurePassword,
                  style: TextStyle(color: textColor, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: _getText('password'),
                    labelStyle: TextStyle(color: primaryColor),
                    prefixIcon: Icon(Icons.lock, color: primaryColor),
                    filled: true,
                    fillColor: backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: primaryColor.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: primaryColor.withOpacity(0.3),
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: primaryColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Remember me checkbox
                Row(
                  children: [
                    Checkbox(
                      value: rememberMe,
                      activeColor: primaryColor,
                      onChanged: (v) => setState(() => rememberMe = v!),
                    ),
                    Text(
                      _getText('rememberMe'),
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Login button
                loading
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: buttonTextColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: login,
                            child: Text(
                              _getText('login'),
                              style: TextStyle(
                                color: buttonTextColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),

                // Error message
                if (msg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              msg,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    userCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }
}