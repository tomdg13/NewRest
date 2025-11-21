import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:http/http.dart' as http;
// ignore: unused_import
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
// ignore: unnecessary_import
import 'dart:typed_data';
// For web file handling
import 'package:universal_html/html.dart' as html;

class CompanyEditPage extends StatefulWidget {
  final Map<String, dynamic> CompanyData;

  const CompanyEditPage({Key? key, required this.CompanyData}) : super(key: key);

  @override
  State<CompanyEditPage> createState() => _CompanyEditPageState();
}

class _CompanyEditPageState extends State<CompanyEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _companyNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;

  String? _base64Logo;
  String? _currentLogoUrl;
  File? _logoFile; // For mobile
  Uint8List? _webLogoBytes; // For web
  // ignore: unused_field
  String? _webLogoName; // For web
  bool _isLoading = false;
  bool _isDeleting = false;
  String currentTheme = ThemeConfig.defaultTheme;

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
    _initializeControllers();
  }

  void _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  void _initializeControllers() {
    _companyNameController = TextEditingController(text: widget.CompanyData['company_name'] ?? '');
    _phoneController = TextEditingController(text: widget.CompanyData['phone'] ?? '');
    _emailController = TextEditingController(text: widget.CompanyData['email'] ?? '');
    _addressController = TextEditingController(text: widget.CompanyData['address'] ?? '');
    _currentLogoUrl = widget.CompanyData['logo_full_url'];
    
    print('🔧 DEBUG: Initialized edit form with Company: ${widget.CompanyData['company_name']}');
    print('🔧 DEBUG: Company ID: ${widget.CompanyData['company_id']}');
    print('🔧 DEBUG: Current Logo URL: $_currentLogoUrl');
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      if (kIsWeb) {
        await _pickLogoWeb();
      } else {
        await _pickLogoMobile();
      }
    } catch (e) {
      print('❌ DEBUG: Error picking logo: $e');
      _showSnackBar(
        message: 'Error selecting logo: $e',
        isError: true,
      );
    }
  }

  Future<void> _pickLogoWeb() async {
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
          _webLogoBytes = bytes;
          _webLogoName = file.name;
          _base64Logo = 'data:${file.type};base64,$base64String';
        });

        print('📷 DEBUG: New web logo selected for Company update');
        _showSnackBar(
          message: 'Logo selected successfully',
          isError: false,
        );
      });

      reader.readAsArrayBuffer(file);
    });
  }

  Future<void> _pickLogoMobile() async {
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
              'Select Logo Source',
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
      final File logoFile = File(image.path);
      final Uint8List logoBytes = await logoFile.readAsBytes();
      final String base64String = base64Encode(logoBytes);
      
      setState(() {
        _logoFile = logoFile;
        _base64Logo = 'data:image/jpeg;base64,$base64String';
      });

      print('📷 DEBUG: New mobile logo selected for Company update');
      _showSnackBar(
        message: 'Logo selected successfully',
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

  Widget _buildLogoDisplay() {
    // Priority order: new logo > existing logo > placeholder
    if (kIsWeb && _webLogoBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Image.memory(
              _webLogoBytes!,
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
    } else if (!kIsWeb && _logoFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Image.file(
              _logoFile!,
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
    } else if (_currentLogoUrl != null && _currentLogoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Image.network(
              _currentLogoUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return _buildLogoPlaceholder();
              },
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
      return _buildLogoPlaceholder();
    }
  }

Future<void> _updateCompany() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = widget.CompanyData['company_id'];

      // UPDATED: Use path parameter format instead of query parameter
      final url = AppConfig.api('/api/iocompany/$companyId');
      print('🌐 DEBUG: Updating Company at: $url');

      final companyData = <String, dynamic>{};
      
      // Only include fields that have values
      if (_companyNameController.text.trim().isNotEmpty) {
        companyData['company_name'] = _companyNameController.text.trim();
      }
      
      if (_phoneController.text.trim().isNotEmpty) {
        companyData['phone'] = _phoneController.text.trim();
      }
      
      if (_emailController.text.trim().isNotEmpty) {
        companyData['email'] = _emailController.text.trim();
      }
      
      if (_addressController.text.trim().isNotEmpty) {
        companyData['address'] = _addressController.text.trim();
      }
      
      if (_base64Logo != null) {
        companyData['logo'] = _base64Logo;
      }

      print('📝 DEBUG: Update data: ${companyData.toString()}');

      final response = await http.put(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(companyData),
      );

      print('📡 DEBUG: Update Response Status: ${response.statusCode}');
      print('📝 DEBUG: Update Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          _showSnackBar(
            message: 'Company updated successfully!',
            isError: false,
          );
          Navigator.pop(context, true); // Return true to indicate success
        } else {
          throw Exception(responseData['message'] ?? 'Unknown error');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ DEBUG: Error updating Company: $e');
      _showSnackBar(
        message: 'Error updating Company: $e',
        isError: true,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
 
  // Future<void> _deleteCompany() async {
  //   // Show confirmation dialog
  //   final bool? confirm = await showDialog<bool>(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //         title: Row(
  //           children: [
  //             Icon(Icons.warning, color: Colors.red, size: 28),
  //             SizedBox(width: 12),
  //             Text('Delete Company'),
  //           ],
  //         ),
  //         content: Text('Are you sure you want to delete "${_companyNameController.text}"? This action cannot be undone.'),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.of(context).pop(false),
  //             child: Text(
  //               'Cancel',
  //               style: TextStyle(color: Colors.grey[600]),
  //             ),
  //           ),
  //           ElevatedButton(
  //             onPressed: () => Navigator.of(context).pop(true),
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: Colors.red,
  //               foregroundColor: Colors.white,
  //             ),
  //             child: Text('Delete'),
  //           ),
  //         ],
  //       );
  //     },
  //   );

  //   if (confirm != true) return;

  //   setState(() {
  //     _isDeleting = true;
  //   });

  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final token = prefs.getString('access_token');
  //     final companyId = widget.CompanyData['company_id'];

  //     final url = AppConfig.api('/api/iocompany/$companyId');
  //     print('🗑️ DEBUG: Deleting Company at: $url');

  //     final response = await http.delete(
  //       Uri.parse(url.toString()),
  //       headers: {
  //         'Content-Type': 'application/json',
  //         if (token != null) 'Authorization': 'Bearer $token',
  //       },
  //     );

  //     print('📡 DEBUG: Delete Response Status: ${response.statusCode}');
  //     print('📝 DEBUG: Delete Response Body: ${response.body}');

  //     if (response.statusCode == 200) {
  //       final responseData = jsonDecode(response.body);
  //       if (responseData['status'] == 'success') {
  //         _showSnackBar(
  //           message: 'Company deleted successfully!',
  //           isError: false,
  //         );
  //         Navigator.pop(context, 'deleted'); // Return 'deleted' to indicate deletion
  //       } else {
  //         throw Exception(responseData['message'] ?? 'Unknown error');
  //       }
  //     } else {
  //       final errorData = jsonDecode(response.body);
  //       throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     print('❌ DEBUG: Error deleting Company: $e');
  //     _showSnackBar(
  //       message: 'Error deleting Company: $e',
  //       isError: true,
  //     );
  //   } finally {
  //     setState(() {
  //       _isDeleting = false;
  //     });
  //   }
  // }

  Widget _buildLogoSection() {
    // Get responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final logoSize = isWideScreen ? 200.0 : 180.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.business,
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Company Logo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: _pickLogo,
                child: Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (kIsWeb ? _webLogoBytes != null : _logoFile != null)
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
                  child: _buildLogoDisplay(),
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              kIsWeb ? 'Click to change logo' : 'Tap to change logo',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoPlaceholder() {
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
          kIsWeb ? 'Click to add logo' : 'Tap to add logo',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (kIsWeb) ...[
          SizedBox(height: 4),
          Text(
            'Browse files',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final horizontalPadding = isWideScreen ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Edit Company'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
        // actions: [
        //   IconButton(
        //     onPressed: _isLoading || _isDeleting ? null : _deleteCompany,
        //     icon: _isDeleting
        //         ? SizedBox(
        //             width: 20,
        //             height: 20,
        //             child: CircularProgressIndicator(
        //               strokeWidth: 2,
        //               valueColor: AlwaysStoppedAnimation<Color>(
        //                 ThemeConfig.getButtonTextColor(currentTheme),
        //               ),
        //             ),
        //           )
        //         : Icon(Icons.delete, color: Colors.red),
        //     tooltip: 'Delete Company',
        //   ),
        //   if (_isLoading)
        //     Container(
        //       margin: EdgeInsets.all(16),
        //       width: 20,
        //       height: 20,
        //       child: CircularProgressIndicator(
        //         strokeWidth: 2,
        //         valueColor: AlwaysStoppedAnimation<Color>(
        //           ThemeConfig.getButtonTextColor(currentTheme),
        //         ),
        //       ),
        //     ),
        // ],
      
      
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
                  // Company Logo Section
                  _buildLogoSection(),
                  
                  SizedBox(height: 20),

                  // Company Information
                  Card(
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
                              Icon(
                                Icons.business,
                                color: ThemeConfig.getPrimaryColor(currentTheme),
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Company Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeConfig.getPrimaryColor(currentTheme),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          
                          TextFormField(
                            controller: _companyNameController,
                            decoration: InputDecoration(
                              labelText: 'Company Name *',
                              hintText: 'Enter company name',
                              prefixIcon: Icon(
                                Icons.business,
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
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Company name is required';
                              }
                              return null;
                            },
                          ),
                          
                          SizedBox(height: 16),
                          
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Phone',
                              hintText: 'Enter phone number',
                              prefixIcon: Icon(
                                Icons.phone,
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
                          
                          SizedBox(height: 16),
                          
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'Enter email address',
                              prefixIcon: Icon(
                                Icons.email,
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
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(value.trim())) {
                                  return 'Please enter a valid email address';
                                }
                              }
                              return null;
                            },
                          ),
                          
                          SizedBox(height: 16),
                          
                          TextFormField(
                            controller: _addressController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Address',
                              hintText: 'Enter company address',
                              prefixIcon: Icon(
                                Icons.location_on,
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
                          
                          SizedBox(height: 16),
                          
                          // Display read-only company information
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.badge,
                                      color: Colors.grey[600],
                                    ),
                                    SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Company ID: ${widget.CompanyData['company_id']}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (widget.CompanyData['company_code'] != null) ...[
                                          SizedBox(height: 4),
                                          Text(
                                            'Code: ${widget.CompanyData['company_code']}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 30),

                  // Update Button
                  Container(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading || _isDeleting ? null : _updateCompany,
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
                                  'Updating Company...',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  'Update Company',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ],
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