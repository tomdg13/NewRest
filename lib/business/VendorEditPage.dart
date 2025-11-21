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

class VendorEditPage extends StatefulWidget {
  final Map<String, dynamic> vendorData;

  const VendorEditPage({Key? key, required this.vendorData}) : super(key: key);

  @override
  State<VendorEditPage> createState() => _VendorEditPageState();
}

class _VendorEditPageState extends State<VendorEditPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _vendorNameController;
  late final TextEditingController _vendorCodeController;
  late final TextEditingController _provinceNameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _managerNameController;

  String? _base64Image;
  String? _currentImageUrl;
  File? _imageFile;
  Uint8List? _webImageBytes; // For web platform
  bool _isLoading = false;
  bool _isDeleting = false;
  String currentTheme = ThemeConfig.defaultTheme;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
    _initializeControllers();
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

  void _initializeControllers() {
    _vendorNameController = TextEditingController(text: widget.vendorData['vendor_name'] ?? '');
    _vendorCodeController = TextEditingController(text: widget.vendorData['vendor_code'] ?? '');
    _provinceNameController = TextEditingController(text: widget.vendorData['province_name'] ?? '');
    _addressController = TextEditingController(text: widget.vendorData['address'] ?? '');
    _phoneController = TextEditingController(text: widget.vendorData['phone'] ?? '');
    _emailController = TextEditingController(text: widget.vendorData['email'] ?? '');
    _managerNameController = TextEditingController(text: widget.vendorData['manager_name'] ?? '');
    _currentImageUrl = widget.vendorData['image_url'];
    
    print('🔧 DEBUG: Initialized edit form with vendor: ${widget.vendorData['vendor_name']}');
    print('🔧 DEBUG: vendor ID: ${widget.vendorData['vendor_id']}');
    print('🔧 DEBUG: Company ID: ${widget.vendorData['company_id']}');
    print('🔧 DEBUG: vendor Code: ${widget.vendorData['vendor_code']}');
  }

  @override
  void dispose() {
    _vendorNameController.dispose();
    _vendorCodeController.dispose();
    _provinceNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _managerNameController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      // For web, show source selection; for mobile, show both options
      ImageSource? source;
      
      if (kIsWeb) {
        // On web, only gallery is available
        source = ImageSource.gallery;
      } else {
        // On mobile, show selection dialog
        source = await showModalBottomSheet<ImageSource>(
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
      }

      if (source == null && !kIsWeb) return;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source!,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final Uint8List imageBytes = await image.readAsBytes();
        final String base64String = base64Encode(imageBytes);
        
        setState(() {
          _webImageBytes = imageBytes;
          if (!kIsWeb) {
            _imageFile = File(image.path);
          }
          _base64Image = 'data:image/jpeg;base64,$base64String';
        });

        print('📷 DEBUG: New image selected for vendor update');
        
        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Image updated successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ DEBUG: Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error selecting image: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  Future<void> _updateVendor() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final vendorId = widget.vendorData['vendor_id'];

      final url = AppConfig.api('/api/iovendor/$vendorId');
      print('🌐 DEBUG: Updating vendor at: $url');

      final vendorData = <String, dynamic>{
        'company_id': CompanyConfig.getCompanyId(), // update company = 1
      };
      
      // Only include fields that have values or have been changed
      if (_vendorNameController.text.trim().isNotEmpty) {
        vendorData['vendor_name'] = _vendorNameController.text.trim();
      }
      
      if (_vendorCodeController.text.trim().isNotEmpty) {
        vendorData['vendor_code'] = _vendorCodeController.text.trim();
      }
      
      if (_provinceNameController.text.trim().isNotEmpty) {
        vendorData['province_name'] = _provinceNameController.text.trim();
      }
      
      if (_addressController.text.trim().isNotEmpty) {
        vendorData['address'] = _addressController.text.trim();
      }
      
      if (_phoneController.text.trim().isNotEmpty) {
        vendorData['phone'] = _phoneController.text.trim();
      }
      
      if (_emailController.text.trim().isNotEmpty) {
        vendorData['email'] = _emailController.text.trim();
      }
      
      if (_managerNameController.text.trim().isNotEmpty) {
        vendorData['manager_name'] = _managerNameController.text.trim();
      }
      
      if (_base64Image != null) {
        vendorData['image'] = _base64Image;
      }

      print('📝 DEBUG: Update data: ${vendorData.toString()}');

      final response = await http.put(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(vendorData),
      );

      print('📡 DEBUG: Update Response Status: ${response.statusCode}');
      print('📝 DEBUG: Update Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Vendor updated successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
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
      print('❌ DEBUG: Error updating vendor: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error updating vendor: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteVendor() async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Delete Vendor'),
            ],
          ),
          content: Text('Are you sure you want to delete "${_vendorNameController.text}" (${_vendorCodeController.text})? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final vendorId = widget.vendorData['vendor_id'];

      final url = AppConfig.api('/api/iovendor/$vendorId');
      print('🗑️ DEBUG: Deleting vendor at: $url');

      final response = await http.delete(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('📡 DEBUG: Delete Response Status: ${response.statusCode}');
      print('📝 DEBUG: Delete Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Vendor deleted successfully!'),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context, 'deleted'); // Return 'deleted' to indicate deletion
        } else {
          throw Exception(responseData['message'] ?? 'Unknown error');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ DEBUG: Error deleting vendor: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error deleting vendor: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  Widget _buildImageDisplay() {
    if (kIsWeb && _webImageBytes != null) {
      return Image.memory(
        _webImageBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (!kIsWeb && _imageFile != null) {
      return Image.file(
        _imageFile!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      return Image.network(
        _currentImageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildImagePlaceholder();
        },
      );
    }
    return _buildImagePlaceholder();
  }

  Widget _buildImageSection() {
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
            children: [
              Row(
                children: [
                  Icon(
                    Icons.image,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Vendor Image',
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
                  onTap: _pickImage,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (_imageFile != null || _webImageBytes != null || _currentImageUrl != null) 
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          _buildImageDisplay(),
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
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Tap to change image',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
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
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
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
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final horizontalPadding = isWideScreen ? 32.0 : 16.0;
    final maxWidth = isWideScreen ? 800.0 : double.infinity;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Edit Vendor'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isLoading || _isDeleting ? null : _deleteVendor,
            icon: _isDeleting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ThemeConfig.getButtonTextColor(currentTheme),
                      ),
                    ),
                  )
                : Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete Vendor',
          ),
          if (_isLoading)
            Container(
              margin: EdgeInsets.all(16),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ThemeConfig.getButtonTextColor(currentTheme),
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Vendor Image Section
                  _buildImageSection(),
                  
                  SizedBox(height: 20),

                  // Vendor Information
                  FadeTransition(
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
                                Icon(
                                  Icons.business,
                                  color: ThemeConfig.getPrimaryColor(currentTheme),
                                  size: 24,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Vendor Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: ThemeConfig.getPrimaryColor(currentTheme),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            
                            _buildTextField(
                              controller: _vendorNameController,
                              label: 'Vendor Name',
                              icon: Icons.business,
                              hint: 'Enter vendor name',
                              required: true,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Vendor name is required';
                                }
                                return null;
                              },
                            ),

                            _buildTextField(
                              controller: _vendorCodeController,
                              label: 'Vendor Code',
                              icon: Icons.qr_code,
                              hint: 'Enter vendor code',
                              required: true,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Vendor code is required';
                                }
                                return null;
                              },
                            ),

                            _buildTextField(
                              controller: _provinceNameController,
                              label: 'Province',
                              icon: Icons.location_city,
                              hint: 'Enter province name',
                            ),

                            _buildTextField(
                              controller: _addressController,
                              label: 'Address',
                              icon: Icons.location_on,
                              hint: 'Enter full address',
                            ),

                            _buildTextField(
                              controller: _phoneController,
                              label: 'Phone',
                              icon: Icons.phone,
                              hint: 'Enter phone number',
                              keyboardType: TextInputType.phone,
                            ),

                            _buildTextField(
                              controller: _emailController,
                              label: 'Email',
                              icon: Icons.email,
                              hint: 'Enter email address',
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  if (!value.contains('@') || !value.contains('.')) {
                                    return 'Please enter a valid email address';
                                  }
                                }
                                return null;
                              },
                            ),

                            _buildTextField(
                              controller: _managerNameController,
                              label: 'Manager Name',
                              icon: Icons.person,
                              hint: 'Enter manager name',
                            ),
                            
                            // Display read-only company ID
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.business_center,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Company ID: ${CompanyConfig.getCompanyId()}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 30),

                  // Update Button
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading || _isDeleting ? null : _updateVendor,
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
                                    'Updating Vendor...',
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
                                    'Update Vendor',
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