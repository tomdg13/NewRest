import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:inventory/config/theme.dart'; // Add theme import
import '../config/config.dart';
import '../utils/simple_translations.dart';
// Import your LoginPage here
import 'package:inventory/login/login_page.dart';

class ForgetPasswordPage extends StatefulWidget {
  final String phone;

  const ForgetPasswordPage({Key? key, required this.phone}) : super(key: key);

  @override
  State<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends State<ForgetPasswordPage> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? errorMessage;
  String? successMessage;
  String langCode = 'en';
  String currentTheme = ThemeConfig.defaultTheme; // Add theme state

  // Password strength variables
  bool _isPasswordStrong = false;
  double _passwordStrength = 0.0;
  Color _passwordStrengthColor = Colors.red;
  String _passwordStrengthLabel = '';

  // Confirm password strength variables
  double _confirmPasswordMatchStrength = 0.0;
  Color _confirmPasswordColor = Colors.red;
  String _confirmPasswordLabel = '';

  @override
  void initState() {
    super.initState();
    _loadLang();
    _loadTheme(); // Load current theme
    _newPasswordController.addListener(_onPasswordChanged);
    _confirmPasswordController.addListener(_onConfirmPasswordChanged);
  }

  Future<void> _loadLang() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCode = prefs.getString('languageCode') ?? 'en';
    });
  }

  // Add method to load current theme
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme =
          prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  void _onPasswordChanged() {
    setState(() {
      _calculatePasswordStrength(_newPasswordController.text);
      _onConfirmPasswordChanged();
    });
  }

  void _onConfirmPasswordChanged() {
    final confirmPassword = _confirmPasswordController.text;
    final newPassword = _newPasswordController.text;

    if (confirmPassword.isEmpty) {
      setState(() {
        _confirmPasswordMatchStrength = 0.0;
        _confirmPasswordColor = Colors.grey;
        _confirmPasswordLabel = '';
      });
      return;
    }

    if (confirmPassword == newPassword) {
      setState(() {
        _confirmPasswordMatchStrength = 1.0;
        _confirmPasswordColor = Colors.green;
        _confirmPasswordLabel = SimpleTranslations.get(
          langCode,
          'PasswordsMatch',
        );
      });
    } else {
      setState(() {
        _confirmPasswordMatchStrength = 0.5;
        _confirmPasswordColor = Colors.red;
        _confirmPasswordLabel = SimpleTranslations.get(
          langCode,
          'PasswordsDoNotMatch',
        );
      });
    }
  }

  void _calculatePasswordStrength(String password) {
    if (password.isEmpty) {
      _passwordStrength = 0.0;
      _passwordStrengthColor = Colors.grey;
      _passwordStrengthLabel = '';
      _isPasswordStrong = false;
      return;
    }

    double strength = 0.0;

    // Length check
    if (password.length >= 8) strength += 0.2;
    if (password.length >= 12) strength += 0.1;

    // Character variety checks
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.2;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.2;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.1;

    _passwordStrength = strength;
    _isPasswordStrong = strength >= 0.8;

    if (strength < 0.3) {
      _passwordStrengthColor = Colors.red;
      _passwordStrengthLabel = SimpleTranslations.get(langCode, 'WeakPassword');
    } else if (strength < 0.6) {
      _passwordStrengthColor = Colors.orange;
      _passwordStrengthLabel = SimpleTranslations.get(langCode, 'FairPassword');
    } else if (strength < 0.8) {
      _passwordStrengthColor = Colors.yellow[700]!;
      _passwordStrengthLabel = SimpleTranslations.get(langCode, 'GoodPassword');
    } else {
      _passwordStrengthColor = Colors.green;
      _passwordStrengthLabel = SimpleTranslations.get(
        langCode,
        'StrongPassword',
      );
    }
  }

  void _showError(String message) {
    setState(() {
      errorMessage = message;
      successMessage = null;
    });
  }

  Future<void> _submit() async {
    print('DEBUG: Update button clicked - Starting password reset process');

    if (!_formKey.currentState!.validate()) {
      print('DEBUG: Form validation failed');
      return;
    }

    // Password validation checks
    if (_newPasswordController.text != _confirmPasswordController.text) {
      print('DEBUG: Password mismatch validation failed');
      _showError(SimpleTranslations.get(langCode, 'PasswordsDoNotMatch'));
      return;
    }
    if (!_isPasswordStrong) {
      print('DEBUG: Password strength validation failed');
      _showError(SimpleTranslations.get(langCode, 'PasswordTooEasy'));
      return;
    }

    print('DEBUG: All validations passed, starting API call');

    setState(() {
      isLoading = true;
      errorMessage = null;
      successMessage = null;
    });

    // Hash password with MD5
    final bytes = utf8.encode(_newPasswordController.text.trim());
    final md5Hash = md5.convert(bytes).toString();
    print('DEBUG: Password hashed successfully');

    // Use AppConfig for API endpoint
    final Uri url = AppConfig.api(
      '/api/customer/update-iopassword/${widget.phone}',
    );
    print('DEBUG: API URL: $url');
    print('DEBUG: Phone number: ${widget.phone}');

    try {
      print('DEBUG: Sending HTTP PUT request...');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'password': md5Hash}),
      );

      print('DEBUG: API Response Status Code: ${response.statusCode}');
      print('DEBUG: API Response Body: ${response.body}');

      final data = jsonDecode(response.body);
      print('DEBUG: Parsed response data: $data');

      if (response.statusCode == 200 && data['status'] == 'success') {
        print('DEBUG: Password reset successful!');
        setState(() {
          successMessage = SimpleTranslations.get(
            langCode,
            'PasswordResetSuccess',
          );
          isLoading = false;
        });

        print('DEBUG: Navigating to LoginPage immediately...');
        // Navigate to LoginPage immediately after successful password reset
        if (mounted) {
          print('DEBUG: Navigating to LoginPage...');
          // Clear all previous routes and navigate to LoginPage
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
          );
          print('DEBUG: Navigation completed');
        } else {
          print('DEBUG: Widget not mounted, skipping navigation');
        }
      } else {
        print(
          'DEBUG: Password reset failed - Status: ${response.statusCode}, Success: ${data['success']}',
        );
        final errorMsg =
            data['message'] ??
            SimpleTranslations.get(langCode, 'PasswordResetFailed');
        print('DEBUG: Error message: $errorMsg');
        setState(() {
          errorMessage = errorMsg;
          isLoading = false;
        });
      }
    } catch (e) {
      print('DEBUG: Exception occurred during API call: $e');
      setState(() {
        errorMessage =
            '${SimpleTranslations.get(langCode, 'RequestFailed')}: $e';
        isLoading = false;
      });
    }
  }

  Widget _buildNewPasswordField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            style: TextStyle(color: ThemeConfig.getTextColor(currentTheme)),
            decoration: InputDecoration(
              labelText: SimpleTranslations.get(langCode, 'NewPassword'),
              labelStyle: TextStyle(
                color: ThemeConfig.getTextColor(currentTheme),
              ),
              prefixIcon: Icon(
                Icons.lock,
                color: ThemeConfig.getPrimaryColor(currentTheme),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                ),
                onPressed: () {
                  setState(() {
                    _obscureNewPassword = !_obscureNewPassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: ThemeConfig.getPrimaryColor(
                    currentTheme,
                  ).withOpacity(0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                  width: 2,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return SimpleTranslations.get(langCode, 'EnterNewPassword');
              }
              if (value.length < 6) {
                return SimpleTranslations.get(langCode, 'PasswordTooShort');
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          if (_newPasswordController.text.isNotEmpty) ...[
            LinearProgressIndicator(
              value: _passwordStrength,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
            ),
            const SizedBox(height: 4),
            Text(
              _passwordStrengthLabel,
              style: TextStyle(
                fontSize: 12,
                color: _passwordStrengthColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: TextStyle(color: ThemeConfig.getTextColor(currentTheme)),
            decoration: InputDecoration(
              labelText: SimpleTranslations.get(langCode, 'ConfirmPassword'),
              labelStyle: TextStyle(
                color: ThemeConfig.getTextColor(currentTheme),
              ),
              prefixIcon: Icon(
                Icons.lock_outline,
                color: ThemeConfig.getPrimaryColor(currentTheme),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: ThemeConfig.getPrimaryColor(
                    currentTheme,
                  ).withOpacity(0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                  width: 2,
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return SimpleTranslations.get(langCode, 'ConfirmYourPassword');
              }
              if (v != _newPasswordController.text) {
                return SimpleTranslations.get(langCode, 'PasswordsDoNotMatch');
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          if (_confirmPasswordController.text.isNotEmpty) ...[
            LinearProgressIndicator(
              value: _confirmPasswordMatchStrength,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(_confirmPasswordColor),
            ),
            const SizedBox(height: 4),
            Text(
              _confirmPasswordLabel,
              style: TextStyle(
                fontSize: 12,
                color: _confirmPasswordColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(
        currentTheme,
      ), // Use theme background
      appBar: AppBar(
        title: Text(
          SimpleTranslations.get(langCode, 'ResetPassword'),
          style: TextStyle(color: ThemeConfig.getButtonTextColor(currentTheme)),
        ),
        backgroundColor: ThemeConfig.getPrimaryColor(
          currentTheme,
        ), // Use theme primary color
        iconTheme: IconThemeData(
          color: ThemeConfig.getButtonTextColor(currentTheme),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            color: ThemeConfig.getBackgroundColor(
              currentTheme,
            ), // Use theme background for card
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_reset,
                    size: 60,
                    color: ThemeConfig.getPrimaryColor(
                      currentTheme,
                    ), // Use theme primary color
                  ),
                  const SizedBox(height: 16),
                  Text(
                    SimpleTranslations.get(langCode, 'CreateNewPassword'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: ThemeConfig.getTextColor(
                        currentTheme,
                      ), // Use theme text color
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.phone,
                        color: ThemeConfig.getPrimaryColor(currentTheme),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${SimpleTranslations.get(langCode, 'phone')}: ${widget.phone}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: ThemeConfig.getTextColor(
                            currentTheme,
                          ).withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildNewPasswordField(),
                        const SizedBox(height: 8),
                        _buildConfirmPasswordField(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: ThemeConfig.getButtonTextColor(
                                  currentTheme,
                                ),
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.check,
                              color: ThemeConfig.getButtonTextColor(
                                currentTheme,
                              ),
                            ),
                      label: Text(
                        SimpleTranslations.get(langCode, 'UpdatePassword'),
                        style: TextStyle(
                          color: ThemeConfig.getButtonTextColor(currentTheme),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeConfig.getPrimaryColor(
                          currentTheme,
                        ), // Use theme primary color
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: isLoading ? null : _submit,
                    ),
                  ),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (successMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          border: Border.all(color: Colors.green.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.green.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                successMessage!,
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onPasswordChanged);
    _confirmPasswordController.removeListener(_onConfirmPasswordChanged);
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
