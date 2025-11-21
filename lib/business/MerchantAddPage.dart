import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// Group model
class Group {
  final int id;
  final String groupName;
  final int companyId;
  final String? imageUrl;
  final String? groupCode;
  final String? phone;

  Group({
    required this.id,
    required this.groupName,
    required this.companyId,
    this.imageUrl,
    this.groupCode,
    this.phone,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['group_id'] ?? 0,
      groupName: json['group_name'] ?? '',
      companyId: json['company_id'] ?? 0,
      imageUrl: json['image_url'],
      groupCode: json['group_code'],
      phone: json['phone'],
    );
  }
}

class MerchantAddPage extends StatefulWidget {
  const MerchantAddPage({Key? key}) : super(key: key);

  @override
  State<MerchantAddPage> createState() => _MerchantAddPageState();
}

class _MerchantAddPageState extends State<MerchantAddPage> with TickerProviderStateMixin {
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _merchantNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _merchantNameFocus = FocusNode();
  final _phoneFocus = FocusNode();

  // State variables
  String? _base64Image;
  File? _imageFile;
  Uint8List? _webImage;
  String? _webImageName;
  bool _isLoading = false;
  bool _isLoadingGroups = false;
  String currentTheme = ThemeConfig.defaultTheme;
  List<Group> _groups = [];
  Group? _selectedGroup;

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _merchantNameController.dispose();
    _phoneController.dispose();
    _merchantNameFocus.dispose();
    _phoneFocus.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // INITIALIZATION
  void _initializeData() {
    _setupAnimations();
    _loadCurrentTheme();
    _loadUserPhone();
    _loadGroups();
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

  // DATA LOADING
  Future<void> _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  Future<void> _loadUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final userPhone = prefs.getString('user');
    if (userPhone != null && userPhone.isNotEmpty) {
      setState(() {
        _phoneController.text = userPhone;
      });
    }
  }

Future<void> _loadGroups() async {
  setState(() => _isLoadingGroups = true);

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final companyId = CompanyConfig.getCompanyId();

    final queryParams = {
      'company_id': companyId.toString(),
    };

    final uri = AppConfig.api('/api/iogroup').replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      if (response.body.trim().startsWith('{') || response.body.trim().startsWith('[')) {
        try {
          final responseData = jsonDecode(response.body);
          
          if (responseData['status'] == 'success' && responseData['data'] != null) {
            final List<dynamic> groupsJson = responseData['data'];
            setState(() {
              _groups = groupsJson.map((json) => Group.fromJson(json)).toList();
            });
          } else {
            throw Exception('Invalid response format');
          }
        } catch (jsonError) {
          throw Exception('Failed to parse server response');
        }
      } else {
        throw Exception('Server returned HTML instead of JSON data');
      }
    } else {
      throw Exception('Failed to load groups: ${response.statusCode}');
    }
  } catch (e) {
    _showSnackBar('Failed to load groups: $e', Colors.orange);
  } finally {
    setState(() => _isLoadingGroups = false);
  }
}
  // IMAGE HANDLING
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      
      ImageSource? source = ImageSource.gallery;
      
      if (!kIsWeb) {
        source = await _showImageSourceDialog();
        if (source == null) return;
      }

      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final Uint8List imageBytes = await image.readAsBytes();
        final String base64String = base64Encode(imageBytes);
        
        if (kIsWeb) {
          setState(() {
            _webImage = imageBytes;
            _webImageName = image.name;
            _base64Image = 'data:image/jpeg;base64,$base64String';
          });
        } else {
          final File imageFile = File(image.path);
          setState(() {
            _imageFile = imageFile;
            _base64Image = 'data:image/jpeg;base64,$base64String';
          });
        }

        _showSnackBar('Image selected successfully', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Error selecting image: $e', Colors.red);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() {
    if (kIsWeb) return Future.value(ImageSource.gallery);
    
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 20),
            const Text(
              'Select Image Source',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // MERCHANT CREATION
  Future<void> _createMerchant() async {
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill in all required fields', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();

      final merchantData = {
        'company_id': companyId,
        'merchant_name': _merchantNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'group_id': _selectedGroup?.id,
        if (_base64Image != null) 'image': _base64Image!,
      };

      final response = await http.post(
        Uri.parse(AppConfig.api('/api/iomerchant').toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(merchantData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          final merchantCode = _extractMerchantCode(responseData);
          _showSuccessDialog(merchantCode);
          return;
        }
      }
      
      _handleErrorResponse(response);
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _extractMerchantCode(Map<String, dynamic> responseData) {
    if (responseData['data']?['merchant_code'] != null) {
      return responseData['data']['merchant_code'];
    }
    if (responseData['message']?.toString().contains('G') == true) {
      return responseData['message'].toString().split('code: ').last;
    }
    return 'N/A';
  }

  void _handleErrorResponse(http.Response response) {
    final errorData = jsonDecode(response.body);
    String errorMessage;
    
    switch (response.statusCode) {
      case 409:
        errorMessage = 'Merchant already exists: ${errorData['details'] ?? errorData['message']}';
        break;
      case 400:
        if (errorData['message'] is List) {
          errorMessage = 'Validation error: ${(errorData['message'] as List).join(', ')}';
        } else {
          errorMessage = 'Validation error: ${errorData['message']}';
        }
        break;
      default:
        errorMessage = errorData['message'] ?? 'Server error: ${response.statusCode}';
    }
    
    throw Exception(errorMessage);
  }

  // UI HELPERS
  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              backgroundColor == Colors.green ? Icons.check_circle : 
              backgroundColor == Colors.orange ? Icons.warning : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccessDialog(String merchantCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
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
            Text('Merchant "${_merchantNameController.text}" has been created successfully!'),
            const SizedBox(height: 8),
            if (merchantCode != 'N/A') ...[
              Text('Merchant Code: $merchantCode', 
                   style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
            ],
            Text('Phone: ${_phoneController.text}'),
            if (_selectedGroup != null) ...[
              const SizedBox(height: 4),
              Text('Group: ${_selectedGroup!.groupName} (ID: ${_selectedGroup!.id})'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
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
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Error'),
          ],
        ),
        content: Text('Failed to create Merchant:\n$error'),
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

  // BUILD METHODS
  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 8),
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

  Widget _buildGroupDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_groups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Available Groups: ${_groups.length}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          DropdownButtonFormField<Group>(
            value: _selectedGroup,
            decoration: InputDecoration(
              labelText: 'Select Group',
              prefixIcon: Icon(
                Icons.group,
                color: ThemeConfig.getPrimaryColor(currentTheme),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            items: _buildDropdownItems(),
            onChanged: _isLoadingGroups || _groups.isEmpty 
                ? null 
                : (Group? newValue) => setState(() => _selectedGroup = newValue),
            validator: (value) => value == null ? 'Please select a group' : null,
            hint: _buildDropdownHint(),
            isExpanded: true,
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<Group>> _buildDropdownItems() {
    if (_isLoadingGroups) {
      return [
        const DropdownMenuItem<Group>(
          value: null,
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Loading groups...'),
            ],
          ),
        ),
      ];
    }

    if (_groups.isEmpty) {
      return [
        const DropdownMenuItem<Group>(
          value: null,
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Text('No groups available'),
            ],
          ),
        ),
      ];
    }

    return _groups.map((Group group) {
      return DropdownMenuItem<Group>(
        value: group,
        child: Row(
          children: [
            _buildGroupImage(group, 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                group.groupName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildDropdownHint() {
    return Row(
      children: [
        _buildGroupImage(null, 40),
        const SizedBox(width: 12),
        const Text('Choose a group'),
      ],
    );
  }

  Widget _buildGroupImage(Group? group, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.2),
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.grey[100],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.175),
        child: group?.imageUrl != null && group!.imageUrl!.isNotEmpty
            ? Image.network(
                group.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.group,
                  size: size * 0.5,
                  color: Colors.grey[400],
                ),
              )
            : Icon(
                Icons.group,
                size: size * 0.5,
                color: Colors.grey[400],
              ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? hint,
    TextInputAction? textInputAction,
    VoidCallback? onFieldSubmitted,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        validator: validator,
        textInputAction: textInputAction ?? TextInputAction.next,
        onFieldSubmitted: onFieldSubmitted != null ? (_) => onFieldSubmitted() : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: ThemeConfig.getPrimaryColor(currentTheme)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: ThemeConfig.getPrimaryColor(currentTheme), size: 24),
                    const SizedBox(width: 12),
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
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return _buildSectionCard(
      title: 'Merchant Image (Optional)',
      icon: Icons.image,
      children: [
        Center(
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: kIsWeb ? 200 : 180,
              height: kIsWeb ? 200 : 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (_imageFile != null || _webImage != null)
                      ? ThemeConfig.getPrimaryColor(currentTheme)
                      : Colors.grey[300]!,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: (_imageFile != null || _webImage != null) 
                  ? _buildSelectedImage() 
                  : _buildImagePlaceholder(),
            ),
          ),
        ),
        if (_imageFile != null || _webImage != null) ...[
          const SizedBox(height: 12),
          Text(
            kIsWeb 
                ? 'Image selected: ${_webImageName ?? 'Unknown'}'
                : 'Image selected successfully',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectedImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          if (kIsWeb && _webImage != null)
            Image.memory(
              _webImage!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          else if (!kIsWeb && _imageFile != null)
            Image.file(
              _imageFile!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() {
                _imageFile = null;
                _webImage = null;
                _webImageName = null;
                _base64Image = null;
              }),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text(
          kIsWeb ? 'Click to add image' : 'Tap to add image',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Optional',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFormSection() {
    return _buildSectionCard(
      title: 'Basic Information',
      icon: Icons.info,
      children: [
        _buildGroupDropdown(),
        _buildTextField(
          controller: _merchantNameController,
          focusNode: _merchantNameFocus,
          label: 'Merchant Name *',
          hint: 'Enter merchant name',
          icon: Icons.store,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: () => _phoneFocus.requestFocus(),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Merchant name is required';
            }
            if (value.trim().length < 2) {
              return 'Merchant name must be at least 2 characters';
            }
            return null;
          },
        ),
        // _buildTextField(
        //   controller: _phoneController,
        //   focusNode: _phoneFocus,
        //   label: 'Phone Number *',
        //   hint: 'Enter phone number',
        //   icon: Icons.phone,
        //   keyboardType: TextInputType.phone,
        //   textInputAction: TextInputAction.done,
        //   onFieldSubmitted: _createMerchant,
        //   validator: (value) {
        //     if (value == null || value.trim().isEmpty) {
        //       return 'Phone number is required';
        //     }
        //     if (value.trim().length < 8) {
        //       return 'Phone number must be at least 8 digits';
        //     }
        //     return null;
        //   },
        // ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _createMerchant,
          style: ElevatedButton.styleFrom(
            backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
            foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            disabledBackgroundColor: Colors.grey[300],
          ),
          icon: _isLoading
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
              : const Icon(Icons.add_business),
          label: Text(
            _isLoading ? 'Creating Merchant...' : 'Create Merchant',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 1200;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Add New Merchant'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoadingGroups ? null : _loadGroups,
            tooltip: 'Refresh Groups',
          ),
          if (_isLoading)
            Container(
              margin: const EdgeInsets.all(16),
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
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 800 : (isTablet ? 600 : double.infinity),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildImageSection(),
                  const SizedBox(height: 16),
                  _buildFormSection(),
                  const SizedBox(height: 24),
                  _buildCreateButton(),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'All fields marked with * are required. A unique merchant code will be automatically generated.',
                            style: TextStyle(color: Colors.blue[700], fontSize: 14),
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
      ),
    );
  }
}