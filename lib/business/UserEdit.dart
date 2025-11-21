import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

import '../utils/simple_translations.dart';

class UserEditPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  
  const UserEditPage({Key? key, required this.userData}) : super(key: key);

  @override
  State<UserEditPage> createState() => _UserEditPageState();
}

class _UserEditPageState extends State<UserEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = _Controllers();
  
  bool _isLoading = false;
  String _langCode = 'en';
  String _currentTheme = ThemeConfig.defaultTheme;
  
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  File? _selectedIdImage;
  String _base64Image = '';
  String _base64IdImage = '';

  // UPDATED: Role and Status data
  List<_Role> _roles = [];
  _Role? _selectedRole;
  bool _isLoadingRoles = false;
  
  List<_Status> _statuses = [];
  _Status? _selectedStatus;

  // Branch data
  List<Map<String, dynamic>> _branches = [];
  Map<String, dynamic>? _selectedBranch;
  bool _isLoadingBranches = false;

  @override
  void initState() {
    super.initState();
    _initializeStatuses();
    _initialize();
  }

  // NEW: Initialize status options
  void _initializeStatuses() {
    _statuses = [
      _Status(
        code: 'active',
        name: 'Active',
        description: 'User account is active and can login',
        icon: Icons.check_circle,
        color: Colors.green,
      ),
      _Status(
        code: 'inactive',
        name: 'Inactive',
        description: 'User account is temporarily disabled',
        icon: Icons.pause_circle,
        color: Colors.orange,
      ),
      _Status(
        code: 'resetpassword',
        name: 'Reset Password',
        description: 'User must reset password on next login',
        icon: Icons.lock_reset,
        color: Colors.blue,
      ),
      _Status(
        code: 'suspended',
        name: 'Suspended',
        description: 'User account is suspended',
        icon: Icons.block,
        color: Colors.red,
      ),
      _Status(
        code: 'delete',
        name: 'Deleted',
        description: 'User account is marked for deletion',
        icon: Icons.delete_forever,
        color: Colors.grey,
      ),
    ];
  }

  Future<void> _initialize() async {
    await _loadPreferences();
    _initializeControllers();
    await Future.wait([
      _loadRoles(),
      _loadBranches(),
    ]);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _langCode = prefs.getString('languageCode') ?? 'en';
      _currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  void _initializeControllers() {
    _controllers.name.text = widget.userData['name'] ?? '';
    _controllers.username.text = widget.userData['username'] ?? '';
    _controllers.email.text = widget.userData['email'] ?? '';
    _controllers.phone.text = widget.userData['phone'] ?? '';
    _controllers.documentId.text = widget.userData['document_id'] ?? '';
    _controllers.accountNo.text = widget.userData['account_no'] ?? '';
    _controllers.accountName.text = widget.userData['account_name'] ?? '';
    _controllers.bio.text = widget.userData['bio'] ?? '';
    
    // Initialize status
    final userStatus = widget.userData['status'] ?? 'active';
    _selectedStatus = _statuses.firstWhere(
      (status) => status.code == userStatus,
      orElse: () => _statuses.first,
    );
    
    print('=== INITIALIZING USER DATA ===');
    print('User role_id: ${widget.userData['role_id']}');
    print('User role_code: ${widget.userData['role_code']}');
    print('User role_name: ${widget.userData['role_name']}');
    print('User status: ${_selectedStatus?.code}');
    print('==============================');
  }

  Future<void> _loadRoles() async {
    print('Loading roles for edit page...');
    
    setState(() => _isLoadingRoles = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
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

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'success' && data['data'] != null) {
          final rolesList = (data['data'] as List)
              .map((role) => _Role.fromJson(role))
              .toList();
          
          print('Loaded ${rolesList.length} roles');
          
          setState(() {
            _roles = rolesList;
            
            final userRoleId = widget.userData['role_id'];
            final userRoleCode = widget.userData['role_code'];
            
            if (userRoleId != null) {
              _selectedRole = _roles.firstWhere(
                (role) => role.id == userRoleId,
                orElse: () => _roles.isNotEmpty ? _roles.first : _Role.empty(),
              );
              print('Selected role by ID: ${_selectedRole?.name}');
            } else if (userRoleCode != null) {
              _selectedRole = _roles.firstWhere(
                (role) => role.code.toLowerCase() == userRoleCode.toLowerCase(),
                orElse: () => _roles.isNotEmpty ? _roles.first : _Role.empty(),
              );
              print('Selected role by code: ${_selectedRole?.name}');
            } else if (_roles.isNotEmpty) {
              _selectedRole = _roles.first;
              print('No role set, defaulting to: ${_selectedRole?.name}');
            }
            
            _isLoadingRoles = false;
          });
        } else {
          setState(() => _isLoadingRoles = false);
          _showErrorSnackBar('No roles found');
        }
      } else {
        setState(() => _isLoadingRoles = false);
        _showErrorSnackBar('Failed to load roles: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('Error loading roles: $e');
      print('Stack trace: $stackTrace');
      setState(() => _isLoadingRoles = false);
      _showErrorSnackBar('Error loading roles: $e');
    }
  }

  Future<void> _loadBranches() async {
    setState(() => _isLoadingBranches = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
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
          final List<dynamic> branchList = data['data'];
          
          setState(() {
            _branches = branchList.map((branch) => {
              'id': branch['branch_id'],
              'branch_name': branch['branch_name'] ?? 'Unknown Branch',
              'branch_code': branch['branch_code'] ?? '',
              'address': branch['address'] ?? '',
              'image_url': branch['image_url'] ?? '',
            }).toList();
            
            final userBranchId = widget.userData['branch_id'];
            if (userBranchId != null) {
              _selectedBranch = _branches.firstWhere(
                (branch) => branch['id'].toString() == userBranchId.toString(),
                orElse: () => _branches.isNotEmpty ? _branches[0] : {},
              );
            } else if (_branches.isNotEmpty) {
              _selectedBranch = _branches[0];
            }
            
            _isLoadingBranches = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoadingBranches = false);
      _showErrorSnackBar('Error loading branches: $e');
    }
  }

  Future<void> _pickImage({bool isIdImage = false}) async {
    if (kIsWeb) {
      await _pickImageFromSource(ImageSource.gallery, isIdImage: isIdImage);
    } else {
      _showImageSourceBottomSheet(isIdImage);
    }
  }

  void _showImageSourceBottomSheet(bool isIdImage) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: ThemeConfig.getPrimaryColor(_currentTheme)),
              title: Text(_translate('gallery')),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.gallery, isIdImage: isIdImage);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: ThemeConfig.getPrimaryColor(_currentTheme)),
              title: Text(_translate('camera')),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.camera, isIdImage: isIdImage);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source, {bool isIdImage = false}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      final imageBytes = await image.readAsBytes();
      
      if (imageBytes.length > 500000) {
        _showErrorSnackBar(_translate('image_too_large'));
        return;
      }

      final base64String = base64Encode(imageBytes);
      final dataUrl = 'data:image/jpeg;base64,$base64String';

      setState(() {
        if (isIdImage) {
          _selectedIdImage = kIsWeb ? null : File(image.path);
          _base64IdImage = dataUrl;
        } else {
          _selectedImage = kIsWeb ? null : File(image.path);
          _base64Image = dataUrl;
        }
      });

      _showSuccessSnackBar(_translate('image_selected_successfully'));
    } catch (e) {
      _showErrorSnackBar(_translate('error_selecting_image'));
    }
  }

  bool get _isWebWideScreen => kIsWeb && MediaQuery.of(context).size.width > 600;
  
  Widget _buildResponsiveContainer({required Widget child}) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: kIsWeb && MediaQuery.of(context).size.width > 800 ? 800 : double.infinity,
        ),
        padding: EdgeInsets.all(kIsWeb ? 32 : 16),
        child: child,
      ),
    );
  }

  Widget _buildImagePicker({
    required String title,
    required String subtitle,
    required File? selectedImage,
    required String base64Image,
    required String? existingImageUrl,
    required VoidCallback onTap,
    IconData icon = Icons.add_a_photo,
  }) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
              border: Border.all(
                color: ThemeConfig.getPrimaryColor(_currentTheme),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: _buildImageContent(selectedImage, base64Image, existingImageUrl, icon),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildImageContent(File? selectedImage, String base64Image, String? existingImageUrl, IconData icon) {
    if (selectedImage != null || base64Image.isNotEmpty) {
      return ClipOval(
        child: kIsWeb && base64Image.isNotEmpty
            ? Image.memory(
                base64Decode(base64Image.split(',')[1]),
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              )
            : selectedImage != null
                ? Image.file(
                    selectedImage,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  )
                : const SizedBox(),
      );
    }

    if (existingImageUrl != null && existingImageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          existingImageUrl,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultImageContent(icon),
        ),
      );
    }

    return _buildDefaultImageContent(icon);
  }

  Widget _buildDefaultImageContent(IconData icon) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 30,
          color: ThemeConfig.getPrimaryColor(_currentTheme),
        ),
        const SizedBox(height: 4),
        Text(
          'Add',
          style: TextStyle(
            fontSize: 10,
            color: ThemeConfig.getPrimaryColor(_currentTheme),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    bool required = false,
    int maxLines = 1,
    IconData? icon,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        readOnly: readOnly,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: ThemeConfig.getPrimaryColor(_currentTheme),
              width: 2,
            ),
          ),
          prefixIcon: icon != null ? Icon(
            icon,
            color: ThemeConfig.getPrimaryColor(_currentTheme),
          ) : null,
          filled: true,
          fillColor: readOnly ? Colors.grey[100] : Colors.grey[50],
        ),
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'This field is required';
                }
                if (label.toLowerCase().contains('email')) {
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                    return 'Please enter a valid email address';
                  }
                }
                if (label.toLowerCase().contains('phone') && value.trim().length < 8) {
                  return 'Phone number must be at least 8 digits';
                }
                return null;
              }
            : null,
      ),
    );
  }

  // NEW: Beautiful status dropdown matching role dropdown style
  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${_translate('status')} *',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            if (_selectedStatus != null && _selectedStatus!.description.isNotEmpty)
              Expanded(
                child: Text(
                  '(${_selectedStatus!.description})',
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
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _selectedStatus == null ? Colors.red[300]! : Colors.grey[300]!
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<_Status>(
              value: _selectedStatus,
              hint: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Select status'),
              ),
              isExpanded: true,
              itemHeight: 48,
              menuMaxHeight: 300,
              items: _statuses.map((status) {
                return DropdownMenuItem<_Status>(
                  value: status,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: status.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            status.icon,
                            color: status.color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            status.name,
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
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedStatus = value);
                print('Selected status: ${value?.name} (${value?.code})');
              },
            ),
          ),
        ),
        if (_selectedStatus != null && _selectedStatus!.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8),
            child: Row(
              children: [
                Icon(
                  _selectedStatus!.icon,
                  size: 14,
                  color: _selectedStatus!.color,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _selectedStatus!.description,
                    style: TextStyle(
                      color: _selectedStatus!.color,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_selectedStatus == null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8),
            child: Text(
              'Status is required',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${_translate('role')} *',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _selectedRole == null ? Colors.red[300]! : Colors.grey[300]!
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _isLoadingRoles
              ? Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ThemeConfig.getPrimaryColor(_currentTheme),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Loading roles...'),
                    ],
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<_Role>(
                    value: _selectedRole != null && _roles.contains(_selectedRole) 
                        ? _selectedRole 
                        : null,
                    hint: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Select role'),
                    ),
                    isExpanded: true,
                    itemHeight: 48,
                    menuMaxHeight: 300,
                    items: _roles.map((role) {
                      return DropdownMenuItem<_Role>(
                        value: role,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: ThemeConfig.getPrimaryColor(_currentTheme).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.work,
                                  color: ThemeConfig.getPrimaryColor(_currentTheme),
                                  size: 18,
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
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedRole = value);
                      print('Selected role: ${value?.name} (ID: ${value?.id})');
                    },
                  ),
                ),
        ),
        if (_selectedRole != null && _selectedRole!.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8),
            child: Text(
              '📝 ${_selectedRole!.description}',
              style: TextStyle(
                color: ThemeConfig.getPrimaryColor(_currentTheme),
                fontSize: 12,
              ),
            ),
          ),
        if (_selectedRole == null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8),
            child: Text(
              'Role is required',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildBranchDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_translate('branch')} *',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _isLoadingBranches
              ? Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ThemeConfig.getPrimaryColor(_currentTheme),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Loading branches...'),
                    ],
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    value: _selectedBranch != null && _branches.contains(_selectedBranch) 
                        ? _selectedBranch 
                        : null,
                    hint: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Select branch'),
                    ),
                    isExpanded: true,
                    itemHeight: 56,
                    menuMaxHeight: 300,
                    items: _branches.map((branch) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: branch,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: branch['image_url'] != null &&
                                        branch['image_url'].toString().isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(5),
                                        child: Image.network(
                                          branch['image_url'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[100],
                                              child: Icon(
                                                Icons.location_on,
                                                color: Colors.grey[400],
                                                size: 16,
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                    : Container(
                                        color: Colors.grey[100],
                                        child: Icon(
                                          Icons.location_on,
                                          color: Colors.grey[400],
                                          size: 16,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  branch['branch_name'] ?? 'Unknown',
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
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedBranch = value),
                  ),
                ),
        ),
        if (_selectedBranch == null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8),
            child: Text(
              'Branch is required',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate() || _selectedBranch == null || _selectedRole == null || _selectedStatus == null) {
      if (_selectedBranch == null) {
        _showErrorSnackBar('Please select a branch');
      }
      if (_selectedRole == null) {
        _showErrorSnackBar('Please select a role');
      }
      if (_selectedStatus == null) {
        _showErrorSnackBar('Please select a status');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      final phone = widget.userData['phone'];
      final url = AppConfig.api('/api/iouser/update/$phone');

      print('=== UPDATING USER ===');
      print('Selected role: ${_selectedRole?.name}');
      print('Role ID: ${_selectedRole?.id}');
      print('Role Code: ${_selectedRole?.code}');
      print('Selected status: ${_selectedStatus?.code}');
      print('====================');

      final updateData = <String, dynamic>{
        'name': _controllers.name.text.trim(),
        'username': _controllers.phone.text.trim(),
        'email': _controllers.email.text.trim(),
        'phone': _controllers.phone.text.trim(),
        
        'role_id': _selectedRole!.id,
        'role_code': _selectedRole!.code,
        'role': _selectedRole!.code,
        
        'status': _selectedStatus!.code,
        'branch_id': _selectedBranch?['id'],
        'company_id': CompanyConfig.getCompanyId(),
        'document_id': _controllers.documentId.text.trim().isEmpty ? null : _controllers.documentId.text.trim(),
        'account_no': _controllers.accountNo.text.trim().isEmpty ? null : _controllers.accountNo.text.trim(),
        'account_name': _controllers.accountName.text.trim().isEmpty ? null : _controllers.accountName.text.trim(),
        'bio': _controllers.bio.text.trim().isEmpty ? null : _controllers.bio.text.trim(),
        'language': _langCode,
      };

      if (_base64Image.isNotEmpty) {
        updateData['photo'] = _base64Image;
      }
      if (_base64IdImage.isNotEmpty) {
        updateData['photo_id'] = _base64IdImage;
      }

      print('Update data: ${jsonEncode(updateData)}');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updateData),
      );

      print('Update response status: ${response.statusCode}');
      print('Update response body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _showSuccessSnackBar('User updated successfully');
          Navigator.pop(context, true);
        } else {
          _showErrorSnackBar(data['message'] ?? 'Update failed');
        }
      } else {
        _showErrorSnackBar('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating user: $e');
      _showErrorSnackBar('Failed to update user: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser() async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_translate('confirm_delete')),
          content: Text('Are you sure you want to delete this user?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_translate('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: ThemeConfig.getThemeColors(_currentTheme)['error'] ?? Colors.red,
              ),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      final phone = widget.userData['phone'];
      final url = AppConfig.api('/api/iouser/update/$phone');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': 'delete'}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _showSuccessSnackBar('User deleted successfully');
          Navigator.pop(context, 'deleted');
        } else {
          _showErrorSnackBar(data['message'] ?? 'Delete failed');
        }
      } else {
        _showErrorSnackBar('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to delete user: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _translate(String key) => SimpleTranslations.get(_langCode, key);

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ThemeConfig.getThemeColors(_currentTheme)['success'] ?? Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ThemeConfig.getThemeColors(_currentTheme)['error'] ?? Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_translate('edit_user')),
        backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _deleteUser,
            icon: const Icon(Icons.delete),
            tooltip: 'Delete User',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: _buildResponsiveContainer(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImagePicker(
                      title: 'Profile Photo',
                      subtitle: 'Tap to change profile image',
                      selectedImage: _selectedImage,
                      base64Image: _base64Image,
                      existingImageUrl: widget.userData['photo'],
                      onTap: () => _pickImage(isIdImage: false),
                      icon: Icons.person,
                    ),
                    _buildImagePicker(
                      title: 'ID Document',
                      subtitle: 'Tap to change ID photo',
                      selectedImage: _selectedIdImage,
                      base64Image: _base64IdImage,
                      existingImageUrl: widget.userData['photo_id'],
                      onTap: () => _pickImage(isIdImage: true),
                      icon: Icons.badge,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                if (_isWebWideScreen) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _controllers.name,
                          label: 'Full Name',
                          required: true,
                          icon: Icons.person,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _controllers.username,
                          label: 'Username',
                          hint: 'Auto-filled from phone',
                          icon: Icons.account_circle,
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _controllers.phone,
                          label: 'Phone Number',
                          keyboardType: TextInputType.phone,
                          required: true,
                          icon: Icons.phone,
                          onChanged: (value) => _controllers.username.text = value.trim(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _controllers.email,
                          label: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          required: true,
                          icon: Icons.email,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildRoleDropdown()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatusDropdown()),
                    ],
                  ),
                ] else ...[
                  _buildTextField(
                    controller: _controllers.name,
                    label: 'Full Name',
                    required: true,
                    icon: Icons.person,
                  ),
                  _buildTextField(
                    controller: _controllers.username,
                    label: 'Username',
                    hint: 'Auto-filled from phone',
                    icon: Icons.account_circle,
                    readOnly: true,
                  ),
                  _buildTextField(
                    controller: _controllers.phone,
                    label: 'Phone Number',
                    keyboardType: TextInputType.phone,
                    required: true,
                    icon: Icons.phone,
                    onChanged: (value) => _controllers.username.text = value.trim(),
                  ),
                  _buildTextField(
                    controller: _controllers.email,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    required: true,
                    icon: Icons.email,
                  ),
                  _buildRoleDropdown(),
                  _buildStatusDropdown(),
                ],

                const SizedBox(height: 8),
                _buildBranchDropdown(),

                const SizedBox(height: 8),
                _buildTextField(
                  controller: _controllers.documentId,
                  label: 'Document ID',
                  icon: Icons.badge,
                ),
                _buildTextField(
                  controller: _controllers.accountName,
                  label: 'Account Name',
                  icon: Icons.account_balance,
                ),
                _buildTextField(
                  controller: _controllers.accountNo,
                  label: 'Account Number',
                  icon: Icons.credit_card,
                ),
                _buildTextField(
                  controller: _controllers.bio,
                  label: 'Bio',
                  maxLines: 3,
                  icon: Icons.description,
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
                      foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                ThemeConfig.getButtonTextColor(_currentTheme),
                              ),
                            ),
                          )
                        : Text(
                            'UPDATE USER',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
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
          ),
        ),
      ),
    );
  }
}

class _Controllers {
  final phone = TextEditingController();
  final name = TextEditingController();
  final email = TextEditingController();
  final documentId = TextEditingController();
  final accountNo = TextEditingController();
  final accountName = TextEditingController();
  final username = TextEditingController();
  final bio = TextEditingController();

  void dispose() {
    phone.dispose();
    name.dispose();
    email.dispose();
    documentId.dispose();
    accountNo.dispose();
    accountName.dispose();
    username.dispose();
    bio.dispose();
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

  factory _Role.empty() {
    return const _Role(
      id: 0,
      name: '',
      code: '',
      description: '',
      level: 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Role && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// NEW: Status class with icon and color
class _Status {
  final String code;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const _Status({
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Status && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;
}