import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../config/config.dart';
import '../config/theme.dart';
import '../utils/simple_translations.dart';

class UserAddPage extends StatefulWidget {
  const UserAddPage({super.key});

  @override
  State<UserAddPage> createState() => _UserAddPageState();
}

class _UserAddPageState extends State<UserAddPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _controllers = _Controllers();
  
  _Role? _selectedRole;
  
  File? _selectedImage;
  Uint8List? _webImageBytes;
  String _base64Image = '';
  bool _isLoading = false;
  String _langCode = 'en';
  String _currentTheme = ThemeConfig.defaultTheme;

  _CompanyData? _companyData;
  _BranchData _branchData = const _BranchData();
  _RoleData _roleData = const _RoleData();

  final ImagePicker _picker = ImagePicker();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _documentIdFocus = FocusNode();
  final _accountNameFocus = FocusNode();
  final _accountNoFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initialize();
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

  Future<void> _initialize() async {
    await _loadPreferences();
    await _loadCompanyData();
    await _loadRoles();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _langCode = prefs.getString('languageCode') ?? 'en';
      _currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  Future<void> _loadCompanyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final companyId = CompanyConfig.getCompanyId();
      final companyName = prefs.getString('company_name') ?? 'Unknown Company';

      setState(() {
        _companyData = _CompanyData(id: companyId, name: companyName);
      });

      await _loadBranches();
    } catch (e) {
      setState(() {
        _companyData = const _CompanyData(id: null, name: '');
      });
      _showErrorSnackBar('Error loading company information');
    }
  }

  Future<void> _loadRoles() async {
    print('Loading roles from backend...');
    
    if (!mounted) return;
    
    setState(() {
      _roleData = _roleData.copyWith(isLoading: true);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = _companyData?.id;
      
      final uri = AppConfig.api('/api/iorole').replace(queryParameters: {
        'status': 'active',
        if (companyId != null) 'company_id': companyId.toString(),
      });

      print('Fetching roles from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('Roles response status: ${response.statusCode}');
      print('Roles response body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'success' && data['data'] != null) {
          final roles = (data['data'] as List)
              .map((role) => _Role.fromJson(role))
              .toList();
          
          print('Loaded ${roles.length} roles');
          
          setState(() {
            _roleData = _roleData.copyWith(
              roles: roles,
              isLoading: false,
            );
            
            if (roles.isNotEmpty && _selectedRole == null) {
              _selectedRole = roles.first;
              print('Auto-selected role: ${_selectedRole?.name}');
            }
          });
        } else {
          print('No roles found in response');
          setState(() {
            _roleData = _roleData.copyWith(isLoading: false);
          });
          _showErrorSnackBar('No roles found');
        }
      } else {
        print('Failed to load roles: ${response.statusCode}');
        setState(() {
          _roleData = _roleData.copyWith(isLoading: false);
        });
        _showErrorSnackBar('Failed to load roles: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Error loading roles: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _roleData = _roleData.copyWith(isLoading: false);
      });
      _showErrorSnackBar('Error loading roles: $e');
    }
  }

  Future<void> _loadBranches() async {
    if (!mounted) return;
    
    setState(() {
      _branchData = _branchData.copyWith(isLoading: true);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = _companyData?.id;
      
      final uri = AppConfig.api('/api/iobranch').replace(queryParameters: {
        'status': 'admin',
        'company_id': companyId.toString(),
      });

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'success' && data['data'] != null) {
          final branches = (data['data'] as List)
              .map((branch) => _Branch.fromJson(branch))
              .toList();
          
          setState(() {
            _branchData = _branchData.copyWith(
              branches: branches,
              isLoading: false,
            );
          });
        } else {
          setState(() {
            _branchData = _branchData.copyWith(isLoading: false);
          });
          _showErrorSnackBar('No branches found');
        }
      } else {
        setState(() {
          _branchData = _branchData.copyWith(isLoading: false);
        });
        _showErrorSnackBar('Failed to load branches: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _branchData = _branchData.copyWith(isLoading: false);
      });
      _showErrorSnackBar('Error loading branches: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      ImageSource? source;
      
      if (kIsWeb) {
        source = ImageSource.gallery;
      } else {
        source = await _showImageSourceBottomSheet();
      }

      if (source == null && !kIsWeb) return;

      final XFile? image = await _picker.pickImage(
        source: source!,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      final imageBytes = await image.readAsBytes();
      
      if (imageBytes.length > 500000) {
        _showErrorSnackBar('Image too large. Please select a smaller image.');
        return;
      }

      final base64String = base64Encode(imageBytes);
      final dataUrl = 'data:image/jpeg;base64,$base64String';

      setState(() {
        _webImageBytes = imageBytes;
        if (!kIsWeb) {
          _selectedImage = File(image.path);
        }
        _base64Image = dataUrl;
      });

      _showSuccessSnackBar('Image selected successfully');
    } catch (e) {
      _showErrorSnackBar('Error selecting image');
    }
  }

  Future<ImageSource?> _showImageSourceBottomSheet() async {
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
          color: ThemeConfig.getPrimaryColor(_currentTheme).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ThemeConfig.getPrimaryColor(_currentTheme).withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: ThemeConfig.getPrimaryColor(_currentTheme),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: ThemeConfig.getPrimaryColor(_currentTheme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addUser() async {
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate() || 
        _branchData.selectedBranch == null || 
        _selectedRole == null) {
      if (_branchData.selectedBranch == null) {
        _showErrorSnackBar('Please select a branch');
      }
      if (_selectedRole == null) {
        _showErrorSnackBar('Please select a role');
      }
      return;
    }

    _controllers.username.text = _controllers.phone.text.trim();

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final url = AppConfig.api('/api/iouser/add');

      print('=== ADDING USER ===');
      print('Selected role: ${_selectedRole?.name}');
      print('Role ID: ${_selectedRole?.id}');
      print('Role Code: ${_selectedRole?.code}');
      print('==================');

      final requestBody = {
        'phone': _controllers.phone.text.trim(),
        'name': _controllers.name.text.trim(),
        'email': _controllers.email.text.trim(),
        
        'role_id': _selectedRole!.id,
        'role_code': _selectedRole!.code,
        'role': _selectedRole!.code,
        
        'company_id': _companyData?.id,
        'branch_id': _branchData.selectedBranch!.id,
        'photo': _base64Image,
        'status': 'resetpassword',
        'document_id': _controllers.documentId.text.trim().nullIfEmpty,
        'username': _controllers.phone.text.trim(),
        'account_no': _controllers.accountNo.text.trim().nullIfEmpty,
        'account_name': _controllers.accountName.text.trim().nullIfEmpty,
        'language': _langCode,
      };

      print('Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _showSuccessDialog();
        } else {
          _showErrorSnackBar(data['message'] ?? 'Unknown error occurred');
        }
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 
            errorData['error'] ?? 
            'Server error';
        _showErrorSnackBar('Error (${response.statusCode}): $errorMessage');
      }
    } catch (e) {
      print('Error adding user: $e');
      _showErrorSnackBar('Network error occurred');
    } finally {
      setState(() => _isLoading = false);
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
            const SizedBox(width: 12),
            const Text('Success!'),
          ],
        ),
        content: Text('User "${_controllers.name.text}" has been created successfully with role "${_selectedRole?.name}" for ${_companyData?.name}.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
            },
            child: Text(
              'OK',
              style: TextStyle(
                color: ThemeConfig.getPrimaryColor(_currentTheme),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImageSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final imageSize = isWideScreen ? 140.0 : 120.0;

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: imageSize,
              height: imageSize,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: (_selectedImage != null || _webImageBytes != null)
                      ? ThemeConfig.getPrimaryColor(_currentTheme)
                      : Colors.grey[300]!,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: (_selectedImage != null || _webImageBytes != null)
                  ? ClipOval(
                      child: Stack(
                        children: [
                          _buildImageDisplay(imageSize),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo,
                          size: isWideScreen ? 48 : 40,
                          color: ThemeConfig.getPrimaryColor(_currentTheme),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add Photo',
                          style: TextStyle(
                            fontSize: isWideScreen ? 14 : 12,
                            color: ThemeConfig.getPrimaryColor(_currentTheme),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap to select profile image',
            style: TextStyle(
              color: Colors.grey[600], 
              fontSize: isWideScreen ? 14 : 12
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageDisplay(double size) {
    if (kIsWeb && _webImageBytes != null) {
      return Image.memory(
        _webImageBytes!,
        fit: BoxFit.cover,
        width: size,
        height: size,
      );
    } else if (!kIsWeb && _selectedImage != null) {
      return Image.file(
        _selectedImage!,
        fit: BoxFit.cover,
        width: size,
        height: size,
      );
    }
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Icon(
          Icons.person,
          color: Colors.grey[400],
          size: size * 0.4,
        ),
      ),
    );
  }

  Widget _buildBranchDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Branch *',
          style: TextStyle(
            fontSize: 12, 
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _branchData.selectedBranch == null 
                  ? Colors.red[300]!
                  : Colors.grey[300]!
            ),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[50],
          ),
          child: _branchData.isLoading
              ? _buildLoadingIndicator('Loading branches...')
              : _buildBranchDropdownButton(),
        ),
        if (_branchData.selectedBranch == null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              'Branch is required',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingIndicator(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                ThemeConfig.getPrimaryColor(_currentTheme),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }

Widget _buildBranchDropdownButton() {
  return DropdownButtonHideUnderline(
    child: DropdownButton<_Branch>(
      value: _branchData.selectedBranch,
      hint: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.location_on, color: Colors.grey[600]),
            const SizedBox(width: 12),
            const Text('Select branch'),
          ],
        ),
      ),
      isExpanded: true,
      itemHeight: 56, // ← Set consistent height
      menuMaxHeight: 300, // ← Limit menu height
      items: _branchData.branches.map(_buildBranchMenuItem).toList(),
      onChanged: (branch) => setState(() {
        _branchData = _branchData.copyWith(selectedBranch: branch);
      }),
    ),
  );
}


DropdownMenuItem<_Branch> _buildBranchMenuItem(_Branch branch) {
  return DropdownMenuItem<_Branch>(
    value: branch,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // ← Reduced padding
      child: Row(
        children: [
          _buildBranchImage(branch),
          const SizedBox(width: 12),
          Expanded(
            child: Text( // ← Changed from Column to just Text
              branch.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    ),
  );
}
  Widget _buildBranchImage(_Branch branch) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: branch.imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.network(
                branch.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultBranchIcon(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildLoadingBranchIcon();
                },
              ),
            )
          : _buildDefaultBranchIcon(),
    );
  }

  Widget _buildDefaultBranchIcon() {
    return Container(
      color: Colors.grey[100],
      child: Icon(
        Icons.location_on,
        color: Colors.grey[400],
        size: 20,
      ),
    );
  }

  Widget _buildLoadingBranchIcon() {
    return Container(
      color: Colors.grey[100],
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  // FIXED: Role dropdown with no overflow
  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Role *',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            if (_selectedRole != null && _selectedRole!.description.isNotEmpty)
              Expanded(
                child: Text(
                  '(${_selectedRole!.description})',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _selectedRole == null 
                  ? Colors.red[300]!
                  : Colors.grey[300]!
            ),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[50],
          ),
          child: _roleData.isLoading
              ? _buildLoadingIndicator('Loading roles...')
              : _buildRoleDropdownButton(),
        ),
        if (_selectedRole != null && _selectedRole!.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              '📝 ${_selectedRole!.description}',
              style: TextStyle(
                color: ThemeConfig.getPrimaryColor(_currentTheme),
                fontSize: 12,
              ),
            ),
          ),
        if (_selectedRole == null && _roleData.roles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              'Role is required',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
      ],
    );
  }

 Widget _buildRoleDropdownButton() {
  if (_roleData.roles.isEmpty) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange[600]),
          const SizedBox(width: 12),
          const Text('No roles available'),
        ],
      ),
    );
  }

  return DropdownButtonHideUnderline(
    child: DropdownButton<_Role>(
      value: _selectedRole,
      hint: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.work, color: Colors.grey[600]),
            const SizedBox(width: 12),
            const Text('Select role'),
          ],
        ),
      ),
      isExpanded: true,
      itemHeight: 48, // ← Changed from 56 to 48
      menuMaxHeight: 300, // ← Added: Limit menu height
      items: _roleData.roles.map(_buildRoleMenuItem).toList(),
      onChanged: (role) {
        setState(() {
          _selectedRole = role;
        });
        print('Selected role: ${role?.name} (ID: ${role?.id})');
      },
    ),
  );
}
  // FIXED: Simple dropdown item with no overflow
 DropdownMenuItem<_Role> _buildRoleMenuItem(_Role role) {
  return DropdownMenuItem<_Role>(
    value: role,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // ← Reduced padding
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6), // ← Smaller padding
            decoration: BoxDecoration(
              color: ThemeConfig.getPrimaryColor(_currentTheme).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.work,
              color: ThemeConfig.getPrimaryColor(_currentTheme),
              size: 18, // ← Smaller icon
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              role.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
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
    bool required = false,
    bool readOnly = false,
    TextInputAction? textInputAction,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        validator: validator,
        readOnly: readOnly,
        textInputAction: textInputAction ?? TextInputAction.next,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: ThemeConfig.getPrimaryColor(_currentTheme),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: ThemeConfig.getPrimaryColor(_currentTheme),
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          filled: true,
          fillColor: readOnly ? Colors.grey[100] : Colors.grey[50],
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      color: ThemeConfig.getPrimaryColor(_currentTheme),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ThemeConfig.getPrimaryColor(_currentTheme),
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

  Widget _buildFormContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          title: 'Profile Image',
          icon: Icons.person,
          children: [_buildProfileImageSection()],
        ),
        
        const SizedBox(height: 20),

        _buildSectionCard(
          title: 'Personal Information',
          icon: Icons.person_outline,
          children: [
            if (isWideScreen) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _controllers.name,
                      label: 'Full Name',
                      icon: Icons.person,
                      focusNode: _nameFocus,
                      hint: 'Enter full name',
                      required: true,
                      validator: _validateName,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _controllers.phone,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      focusNode: _phoneFocus,
                      keyboardType: TextInputType.phone,
                      hint: 'Enter phone number',
                      required: true,
                      validator: _validatePhone,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _controllers.email,
                      label: 'Email',
                      icon: Icons.email,
                      focusNode: _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      hint: 'Enter email address',
                      required: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildRoleDropdown()),
                ],
              ),
            ] else ...[
              _buildTextField(
                controller: _controllers.name,
                label: 'Full Name',
                icon: Icons.person,
                focusNode: _nameFocus,
                hint: 'Enter full name',
                required: true,
                validator: _validateName,
              ),
              _buildTextField(
                controller: _controllers.phone,
                label: 'Phone Number',
                icon: Icons.phone,
                focusNode: _phoneFocus,
                keyboardType: TextInputType.phone,
                hint: 'Enter phone number',
                required: true,
                validator: _validatePhone,
              ),
              _buildTextField(
                controller: _controllers.email,
                label: 'Email',
                icon: Icons.email,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                hint: 'Enter email address',
                required: true,
              ),
              _buildRoleDropdown(),
            ],
          ],
        ),

        const SizedBox(height: 20),

        _buildSectionCard(
          title: 'Additional Information',
          icon: Icons.info_outline,
          children: [
            if (isWideScreen) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _controllers.documentId,
                      label: 'Document ID',
                      icon: Icons.badge,
                      focusNode: _documentIdFocus,
                      hint: 'Enter document/ID number (optional)',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _controllers.username,
                      label: 'Username',
                      icon: Icons.account_circle,
                      hint: 'Auto-filled from phone number',
                      readOnly: true,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _controllers.accountName,
                      label: 'Account Name',
                      icon: Icons.account_balance,
                      focusNode: _accountNameFocus,
                      hint: 'Enter bank account name (optional)',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _controllers.accountNo,
                      label: 'Account Number',
                      icon: Icons.credit_card,
                      focusNode: _accountNoFocus,
                      hint: 'Enter bank account number (optional)',
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                ],
              ),
            ] else ...[
              _buildTextField(
                controller: _controllers.documentId,
                label: 'Document ID',
                icon: Icons.badge,
                focusNode: _documentIdFocus,
                hint: 'Enter document/ID number (optional)',
              ),
              _buildTextField(
                controller: _controllers.username,
                label: 'Username',
                icon: Icons.account_circle,
                hint: 'Auto-filled from phone number',
                readOnly: true,
              ),
              _buildTextField(
                controller: _controllers.accountName,
                label: 'Account Name',
                icon: Icons.account_balance,
                focusNode: _accountNameFocus,
                hint: 'Enter bank account name (optional)',
              ),
              _buildTextField(
                controller: _controllers.accountNo,
                label: 'Account Number',
                icon: Icons.credit_card,
                focusNode: _accountNoFocus,
                hint: 'Enter bank account number (optional)',
                textInputAction: TextInputAction.done,
              ),
            ],
          ],
        ),

        const SizedBox(height: 20),

        _buildSectionCard(
          title: 'Branch Assignment',
          icon: Icons.location_on,
          children: [_buildBranchDropdown()],
        ),

        const SizedBox(height: 30),

        _buildActionButtons(),
      ],
    );
  }

  Widget _buildActionButtons() {
    final isEnabled = !_isLoading && 
        _companyData?.id != null && 
        _branchData.selectedBranch != null &&
        _selectedRole != null;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Container(
            height: 56,
            child: ElevatedButton(
              onPressed: isEnabled ? _addUser : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isEnabled 
                    ? ThemeConfig.getPrimaryColor(_currentTheme) 
                    : Colors.grey,
                foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: ThemeConfig.getPrimaryColor(_currentTheme).withOpacity(0.3),
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
                              ThemeConfig.getButtonTextColor(_currentTheme),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Creating User...',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_add, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          isEnabled 
                              ? 'ADD USER'
                              : 'COMPLETE REQUIRED FIELDS',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _validateName(String? value) {
    if (value?.trim().isEmpty == true) {
      return 'Please enter name';
    }
    if (value!.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value?.trim().isEmpty == true) {
      return 'Please enter phone number';
    }
    if (value!.trim().length < 8) {
      return 'Phone number must be at least 8 digits';
    }
    
    if (mounted) {
      _controllers.username.text = value.trim();
    }
    
    return null;
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: ThemeConfig.getThemeColors(_currentTheme)['success'] ?? Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: ThemeConfig.getThemeColors(_currentTheme)['error'] ?? Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  void dispose() {
    _controllers.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _documentIdFocus.dispose();
    _accountNameFocus.dispose();
    _accountNoFocus.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final horizontalPadding = isWideScreen ? 32.0 : 16.0;
    final maxWidth = isWideScreen ? 800.0 : double.infinity;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Add User'),
        backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
        elevation: 0,
        actions: [
          if (_isLoading)
            Container(
              margin: const EdgeInsets.all(16),
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ThemeConfig.getButtonTextColor(_currentTheme),
                ),
              ),
            ),
        ],
      ),
      body: _companyData == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ThemeConfig.getPrimaryColor(_currentTheme),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Loading company information...'),
                ],
              ),
            )
          : Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
                    child: _buildFormContent(),
                  ),
                ),
              ),
            ),
    );
  }
}

// ========================================
// DATA CLASSES
// ========================================

class _Controllers {
  final phone = TextEditingController();
  final name = TextEditingController();
  final email = TextEditingController();
  final documentId = TextEditingController();
  final accountNo = TextEditingController();
  final accountName = TextEditingController();
  final username = TextEditingController();

  void dispose() {
    phone.dispose();
    name.dispose();
    email.dispose();
    documentId.dispose();
    accountNo.dispose();
    accountName.dispose();
    username.dispose();
  }
}

class _CompanyData {
  final int? id;
  final String name;

  const _CompanyData({required this.id, required this.name});
}

class _Branch {
  final int id;
  final String name;
  final String code;
  final String address;
  final String imageUrl;

  const _Branch({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.imageUrl,
  });

  factory _Branch.fromJson(Map<String, dynamic> json) {
    return _Branch(
      id: json['branch_id'] as int,
      name: json['branch_name'] ?? 'Unknown Branch',
      code: json['branch_code'] ?? '',
      address: json['address'] ?? '',
      imageUrl: json['image_url'] ?? '',
    );
  }
}

class _BranchData {
  final List<_Branch> branches;
  final _Branch? selectedBranch;
  final bool isLoading;

  const _BranchData({
    this.branches = const [],
    this.selectedBranch,
    this.isLoading = false,
  });

  _BranchData copyWith({
    List<_Branch>? branches,
    _Branch? selectedBranch,
    bool? isLoading,
  }) {
    return _BranchData(
      branches: branches ?? this.branches,
      selectedBranch: selectedBranch ?? this.selectedBranch,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class _Role {
  final int id;
  final String name;
  final String code;
  final String description;
  final int level;

  const _Role({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.level,
  });

  factory _Role.fromJson(Map<String, dynamic> json) {
    return _Role(
      id: json['role_id'] as int,
      name: json['role_name'] ?? 'Unknown Role',
      code: json['role_code'] ?? '',
      description: json['description'] ?? '',
      level: json['level'] ?? 0,
    );
  }
}

class _RoleData {
  final List<_Role> roles;
  final bool isLoading;

  const _RoleData({
    this.roles = const [],
    this.isLoading = false,
  });

  _RoleData copyWith({
    List<_Role>? roles,
    bool? isLoading,
  }) {
    return _RoleData(
      roles: roles ?? this.roles,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

extension StringExtensions on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}