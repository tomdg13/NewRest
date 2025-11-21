import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
// For web file handling
import 'package:universal_html/html.dart' as html;

class branchAddPage extends StatefulWidget {
  const branchAddPage({Key? key}) : super(key: key);

  @override
  State<branchAddPage> createState() => _branchAddPageState();
}

class _branchAddPageState extends State<branchAddPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _branchNameController = TextEditingController();
  final _branchCodeController = TextEditingController();
  final _provinceNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _managerNameController = TextEditingController();

  String? _base64Image;
  File? _imageFile; // For mobile
  Uint8List? _webImageBytes; // For web
  // ignore: unused_field
  String? _webImageName; // For web
  bool _isLoading = false;
  String currentTheme = ThemeConfig.defaultTheme;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Focus nodes for better keyboard navigation
  final _branchNameFocus = FocusNode();
  final _branchCodeFocus = FocusNode();
  final _provinceNameFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _managerNameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
    _setupAnimations();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  void _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  @override
  void dispose() {
    _branchNameController.dispose();
    _branchCodeController.dispose();
    _provinceNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _managerNameController.dispose();
    
    _branchNameFocus.dispose();
    _branchCodeFocus.dispose();
    _provinceNameFocus.dispose();
    _addressFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _managerNameFocus.dispose();
    
    _fadeController.dispose();
    super.dispose();
  }

  // Cross-platform image picking
  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        // Web-specific image picking
        await _pickImageWeb();
      } else {
        // Mobile-specific image picking
        await _pickImageMobile();
      }
    } catch (e) {
      print('Error picking image: $e');
      _showSnackBar(
        message: 'Error selecting image: $e',
        isError: true,
      );
    }
  }

  Future<void> _pickImageWeb() async {
    final html.FileUploadInputElement input = html.FileUploadInputElement();
    input.accept = 'image/*';
    input.click();

    input.onChange.listen((e) async {
      final files = input.files;
      if (files!.isEmpty) return;

      final file = files[0];
      final reader = html.FileReader();

      reader.onLoadEnd.listen((e) async {
        final Uint8List bytes = reader.result as Uint8List;
        final String base64String = base64Encode(bytes);
        
        setState(() {
          _webImageBytes = bytes;
          _webImageName = file.name;
          _base64Image = 'data:${file.type};base64,$base64String';
        });

        print('Web image selected and converted to base64');
        _showSnackBar(
          message: 'Image selected successfully',
          isError: false,
        );
      });

      reader.readAsArrayBuffer(file);
    });
  }

  Future<void> _pickImageMobile() async {
    // Show image source selection dialog for mobile
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Select Image Source',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageSourceOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                _buildImageSourceOption(
                  icon: Icons.photo_camera,
                  label: 'Camera',
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );

    if (source == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image != null) {
      final File imageFile = File(image.path);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64String = base64Encode(imageBytes);
      
      setState(() {
        _imageFile = imageFile;
        _base64Image = 'data:image/jpeg;base64,$base64String';
      });

      print('Mobile image selected and converted to base64');
      _showSnackBar(
        message: 'Image selected successfully',
        isError: false,
      );
    }
  }

  void _showSnackBar({required String message, required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
            ),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: ThemeConfig.getPrimaryColor(currentTheme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageDisplay() {
    if (kIsWeb && _webImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Image.memory(
              _webImageBytes!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (!kIsWeb && _imageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Image.file(
              _imageFile!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo,
            size: 48,
            color: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          SizedBox(height: 12),
          Text(
            'Tap to add image',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Recommended: 800x800px',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          if (kIsWeb) ...[
            SizedBox(height: 8),
            Text(
              'Click to browse files',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      );
    }
  }

  Future<void> _createbranch() async {
    print('Create branch button pressed');
    
    // Dismiss keyboard
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate()) {
      print('Form validation failed');
      _showSnackBar(
        message: 'Please fill in all required fields',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();

      final url = AppConfig.api('/api/iobranch');
      print('Creating branch at: $url');
      print('Company ID: $companyId');
      print('Token: ${token != null ? '${token.substring(0, 20)}...' : 'null'}');

      // Use the exact field names that your backend DTO expects
      final branchData = <String, dynamic>{
        'company_id': companyId,
        'branch_name': _branchNameController.text.trim(),
        'branch_code': _branchCodeController.text.trim(),
      };

      // Add province_name as required field
      branchData['province_name'] = _provinceNameController.text.trim();
      
      // Add optional fields only if they have values
      if (_addressController.text.trim().isNotEmpty) {
        branchData['address'] = _addressController.text.trim();
      }
      
      if (_phoneController.text.trim().isNotEmpty) {
        branchData['phone'] = _phoneController.text.trim();
      }
      
      if (_emailController.text.trim().isNotEmpty) {
        branchData['email'] = _emailController.text.trim();
      }
      
      if (_managerNameController.text.trim().isNotEmpty) {
        branchData['manager_name'] = _managerNameController.text.trim();
      }
      
      if (_base64Image != null) {
        branchData['image'] = _base64Image;
      }

      print('Branch data: ${branchData.toString()}');

      final response = await http.post(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(branchData),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          print('Branch created successfully');
          _showSuccessDialog();
        } else {
          print('API returned error status: ${responseData['status']}');
          throw Exception(responseData['message'] ?? 'Unknown error');
        }
      } else {
        print('HTTP Error ${response.statusCode}');
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception caught: $e');
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Branch "${_branchNameController.text}" has been created successfully!'),
            SizedBox(height: 8),
            Text('Branch Code: ${_branchCodeController.text}', 
                 style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Province: ${_provinceNameController.text}'),
            if (_addressController.text.trim().isNotEmpty)
              Text('Address: ${_addressController.text}'),
            if (_managerNameController.text.trim().isNotEmpty)
              Text('Manager: ${_managerNameController.text}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(true); // Return to branch list
            },
            child: Text(
              'OK',
              style: TextStyle(
                color: ThemeConfig.getPrimaryColor(currentTheme),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Failed to create branch:'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                error,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: Colors.red[800],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Try Again',
              style: TextStyle(
                color: ThemeConfig.getPrimaryColor(currentTheme),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? hint,
    bool required = false,
    TextInputAction? textInputAction,
    VoidCallback? onFieldSubmitted,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        textInputAction: textInputAction ?? TextInputAction.next,
        onFieldSubmitted: onFieldSubmitted != null ? (_) => onFieldSubmitted() : null,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: ThemeConfig.getPrimaryColor(currentTheme),
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      color: ThemeConfig.getPrimaryColor(currentTheme),
                      size: 24,
                    ),
                    SizedBox(width: 12),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ThemeConfig.getPrimaryColor(currentTheme),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final imageSize = isWideScreen ? 200.0 : 180.0;
    final horizontalPadding = isWideScreen ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Add New Branch'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
        actions: [
          if (_isLoading)
            Container(
              margin: EdgeInsets.all(16),
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ThemeConfig.getButtonTextColor(currentTheme),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: isWideScreen ? 800 : double.infinity),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Branch Image Section
                  _buildSectionCard(
                    title: 'Branch Image (Optional)',
                    icon: Icons.image,
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: imageSize,
                            height: imageSize,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (kIsWeb ? _webImageBytes != null : _imageFile != null)
                                    ? ThemeConfig.getPrimaryColor(currentTheme)
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _buildImageDisplay(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 20),

                  // Required Information
                  _buildSectionCard(
                    title: 'Required Information',
                    icon: Icons.business,
                    children: [
                      _buildEnhancedTextField(
                        controller: _branchNameController,
                        label: 'Branch Name',
                        icon: Icons.business,
                        focusNode: _branchNameFocus,
                        hint: 'Enter branch name',
                        required: true,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: () => FocusScope.of(context).requestFocus(_branchCodeFocus),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Branch name is required';
                          }
                          if (value.trim().length < 2) {
                            return 'Branch name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      
                      _buildEnhancedTextField(
                        controller: _branchCodeController,
                        label: 'Branch Code',
                        icon: Icons.qr_code,
                        focusNode: _branchCodeFocus,
                        hint: 'Enter unique branch code (e.g., VTE001)',
                        required: true,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: () => FocusScope.of(context).requestFocus(_provinceNameFocus),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Branch code is required';
                          }
                          if (value.trim().length < 3) {
                            return 'Branch code must be at least 3 characters';
                          }
                          return null;
                        },
                      ),

                      _buildEnhancedTextField(
                        controller: _provinceNameController,
                        label: 'Province',
                        icon: Icons.location_city,
                        focusNode: _provinceNameFocus,
                        hint: 'Enter province name',
                        required: true,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: () => FocusScope.of(context).requestFocus(_addressFocus),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Province name is required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Optional Information
                  _buildSectionCard(
                    title: 'Additional Information (Optional)',
                    icon: Icons.info_outline,
                    children: [
                      _buildEnhancedTextField(
                        controller: _addressController,
                        label: 'Address',
                        icon: Icons.location_on,
                        focusNode: _addressFocus,
                        hint: 'Enter full address',
                        maxLines: 2,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: () => FocusScope.of(context).requestFocus(_phoneFocus),
                      ),
                      
                      _buildEnhancedTextField(
                        controller: _phoneController,
                        label: 'Phone',
                        icon: Icons.phone,
                        focusNode: _phoneFocus,
                        hint: 'Enter phone number',
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: () => FocusScope.of(context).requestFocus(_emailFocus),
                      ),
                      
                      _buildEnhancedTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email,
                        focusNode: _emailFocus,
                        hint: 'Enter email address',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: () => FocusScope.of(context).requestFocus(_managerNameFocus),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (!value.contains('@') || !value.contains('.')) {
                              return 'Please enter a valid email address';
                            }
                          }
                          return null;
                        },
                      ),
                      
                      _buildEnhancedTextField(
                        controller: _managerNameController,
                        label: 'Manager Name',
                        icon: Icons.person,
                        focusNode: _managerNameFocus,
                        hint: 'Enter manager name',
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: () => FocusScope.of(context).unfocus(),
                      ),
                    ],
                  ),

                  SizedBox(height: 30),

                  // Create Button
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createbranch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.3),
                        ),
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        ThemeConfig.getButtonTextColor(currentTheme),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Text(
                                    'Creating Branch...',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_circle, size: 24),
                                  SizedBox(width: 12),
                                  Text(
                                    'Create Branch',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}