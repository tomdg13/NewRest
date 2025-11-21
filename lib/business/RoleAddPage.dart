import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';

class RoleAddPage extends StatefulWidget {
  const RoleAddPage({Key? key}) : super(key: key);

  @override
  State<RoleAddPage> createState() => _RoleAddPageState();
}

class _RoleAddPageState extends State<RoleAddPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isLoading = false;
  String _langCode = 'en';
  String _currentTheme = ThemeConfig.defaultTheme;
  
  int _selectedLevel = 50;
  String _selectedStatus = 'active';
  String _selectedPermissionTemplate = 'custom';
  
  // Available modules for permission management
  List<Map<String, dynamic>> _availableModules = [];
  Map<String, String> _modulePermissions = {};

  final List<Map<String, dynamic>> _statuses = [
    {'code': 'active', 'name': 'Active', 'icon': Icons.check_circle, 'color': Colors.green},
    {'code': 'inactive', 'name': 'Inactive', 'icon': Icons.pause_circle, 'color': Colors.orange},
  ];

  // Permission Templates
  final List<Map<String, dynamic>> _permissionTemplates = [
    {
      'code': 'full_access',
      'name': 'Full Access',
      'description': 'Complete control over all modules',
      'icon': Icons.admin_panel_settings,
      'color': Colors.red,
      'level': 90,
      'access_level': 'full_access'
    },
    {
      'code': 'manager',
      'name': 'Manager Access',
      'description': 'Read, write and approve for most modules',
      'icon': Icons.supervisor_account,
      'color': Colors.purple,
      'level': 70,
      'access_level': 'approve_read'
    },
    {
      'code': 'editor',
      'name': 'Editor Access',
      'description': 'Read and write access to content modules',
      'icon': Icons.edit,
      'color': Colors.blue,
      'level': 50,
      'access_level': 'read_write'
    },
    {
      'code': 'viewer',
      'name': 'Viewer Access',
      'description': 'Read-only access to permitted modules',
      'icon': Icons.visibility,
      'color': Colors.green,
      'level': 30,
      'access_level': 'read_only'
    },
    {
      'code': 'custom',
      'name': 'Custom Permissions',
      'description': 'Define permissions manually after creation',
      'icon': Icons.settings,
      'color': Colors.grey,
      'level': 50,
      'access_level': 'none'
    },
  ];

  // Department dropdown options
  final List<Map<String, dynamic>> _departments = [
    {'code': 'all', 'name': 'All Departments', 'icon': Icons.business},
    {'code': 'management', 'name': 'Management', 'icon': Icons.group_work},
    {'code': 'sales', 'name': 'Sales', 'icon': Icons.point_of_sale},
    {'code': 'inventory', 'name': 'Inventory', 'icon': Icons.inventory},
    {'code': 'warehouse', 'name': 'Warehouse', 'icon': Icons.warehouse},
    {'code': 'finance', 'name': 'Finance', 'icon': Icons.attach_money},
    {'code': 'hr', 'name': 'Human Resources', 'icon': Icons.people},
    {'code': 'it', 'name': 'Information Technology', 'icon': Icons.computer},
  ];

  String _selectedDepartment = 'all';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadAvailableModules();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _langCode = prefs.getString('languageCode') ?? 'en';
      _currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  Future<void> _loadAvailableModules() async {
    // Load available permission modules
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      final response = await http.get(
        AppConfig.api('/api/permissions'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _availableModules = List<Map<String, dynamic>>.from(data['data'] ?? []);
            // Initialize all modules with 'none' access by default
            for (var module in _availableModules) {
              _modulePermissions[module['module_code']] = 'none';
            }
          });
        }
      }
    } catch (e) {
      print('Error loading modules: $e');
    }
  }

  void _applyPermissionTemplate(String templateCode) {
    final template = _permissionTemplates.firstWhere(
      (t) => t['code'] == templateCode,
      orElse: () => _permissionTemplates.last,
    );

    setState(() {
      _selectedLevel = template['level'] as int;
      
      // Apply access level to all modules based on template
      if (templateCode != 'custom') {
        final accessLevel = template['access_level'] as String;
        for (var key in _modulePermissions.keys) {
          _modulePermissions[key] = accessLevel;
        }
      }
    });
  }

  bool get _isWideScreen => MediaQuery.of(context).size.width > 800;
  double get _maxWidth => _isWideScreen ? 800.0 : double.infinity;

  Future<void> _addRole() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      final url = AppConfig.api('/api/iorole');

      print('=== ADDING ROLE WITH PERMISSIONS ===');
      print('Role name: ${_nameController.text}');
      print('Role code: ${_codeController.text}');
      print('Level: $_selectedLevel');
      print('Status: $_selectedStatus');
      print('Department: $_selectedDepartment');
      print('Permission Template: $_selectedPermissionTemplate');
      print('Company ID: $companyId');
      print('===================================');

      final requestBody = {
        'role_name': _nameController.text.trim(),
        'role_code': _codeController.text.trim().toLowerCase(),
        'description': _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        'level': _selectedLevel,
        'status': _selectedStatus,
        'company_id': companyId,
        'department': _selectedDepartment,
        'permission_template': _selectedPermissionTemplate,
        'initial_permissions': _modulePermissions,
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

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          // If permissions were configured, also save them
          if (_selectedPermissionTemplate != 'custom' && data['data'] != null) {
            await _saveInitialPermissions(data['data']['role_id']);
          }
          _showSuccessDialog();
        } else {
          _showErrorSnackBar(data['message'] ?? 'Unknown error occurred');
        }
      } else if (response.statusCode == 409) {
        final errorData = jsonDecode(response.body);
        _showErrorSnackBar(errorData['message'] ?? 'Role code already exists');
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 
            errorData['error'] ?? 
            'Server error';
        _showErrorSnackBar('Error (${response.statusCode}): $errorMessage');
      }
    } catch (e) {
      print('Error adding role: $e');
      _showErrorSnackBar('Network error occurred: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveInitialPermissions(int roleId) async {
    if (_availableModules.isEmpty || _selectedPermissionTemplate == 'custom') {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      // Prepare permissions data
      final permissions = _availableModules.map((module) {
        final accessLevel = _modulePermissions[module['module_code']] ?? 'none';
        return {
          'permission_id': module['permission_id'],
          'access_level': accessLevel,
        };
      }).toList();

      final response = await http.put(
        AppConfig.api('/api/permissions/role/$roleId/access-levels'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'access_levels': permissions}),
      );

      if (response.statusCode == 200) {
        print('Initial permissions saved successfully');
      }
    } catch (e) {
      print('Error saving initial permissions: $e');
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
        content: Text(
          'Role "${_nameController.text}" has been created successfully.'
          '${_selectedPermissionTemplate != 'custom' ? '\n\nPermissions have been configured based on the ${_permissionTemplates.firstWhere((t) => t['code'] == _selectedPermissionTemplate)['name']} template.' : ''}',
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
                color: ThemeConfig.getPrimaryColor(_currentTheme),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(int level) {
    if (level >= 90) return Colors.purple;
    if (level >= 70) return Colors.blue;
    if (level >= 50) return Colors.green;
    if (level >= 30) return Colors.orange;
    return Colors.grey;
  }

  String _getLevelDescription(int level) {
    if (level >= 90) return 'Supreme Authority';
    if (level >= 70) return 'High Authority';
    if (level >= 50) return 'Medium Authority';
    if (level >= 30) return 'Basic Authority';
    return 'Limited Authority';
  }

  IconData _getLevelIcon(int level) {
    if (level >= 90) return Icons.stars;
    if (level >= 70) return Icons.workspace_premium;
    if (level >= 50) return Icons.verified;
    if (level >= 30) return Icons.badge;
    return Icons.person;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
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
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  Widget _buildPermissionTemplateDropdown() {
    final selectedTemplate = _permissionTemplates.firstWhere(
      (t) => t['code'] == _selectedPermissionTemplate,
      orElse: () => _permissionTemplates.last,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedPermissionTemplate,
            decoration: InputDecoration(
              labelText: 'Permission Template',
              prefixIcon: Icon(
                selectedTemplate['icon'] as IconData,
                color: selectedTemplate['color'] as Color,
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
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: _permissionTemplates.map((template) {
              return DropdownMenuItem<String>(
                value: template['code'] as String,
                child: Row(
                  children: [
                    Icon(
                      template['icon'] as IconData,
                      color: template['color'] as Color,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            template['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            template['description'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedPermissionTemplate = value;
                  _applyPermissionTemplate(value);
                });
              }
            },
            selectedItemBuilder: (BuildContext context) {
              return _permissionTemplates.map((template) {
                return Row(
                  children: [
                    Icon(
                      template['icon'] as IconData,
                      color: template['color'] as Color,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(template['name'] as String),
                  ],
                );
              }).toList();
            },
            isExpanded: true,
          ),
          if (_selectedPermissionTemplate != 'custom')
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (selectedTemplate['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (selectedTemplate['color'] as Color).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: selectedTemplate['color'] as Color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This template will configure initial permissions for all modules',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDepartmentDropdown() {
    final selectedDept = _departments.firstWhere(
      (d) => d['code'] == _selectedDepartment,
      orElse: () => _departments[0],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _selectedDepartment,
        decoration: InputDecoration(
          labelText: 'Department',
          prefixIcon: Icon(
            selectedDept['icon'] as IconData,
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
          filled: true,
          fillColor: Colors.grey[50],
        ),
        items: _departments.map((dept) {
          return DropdownMenuItem<String>(
            value: dept['code'] as String,
            child: Row(
              children: [
                Icon(
                  dept['icon'] as IconData,
                  color: ThemeConfig.getPrimaryColor(_currentTheme),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(dept['name'] as String),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedDepartment = value);
          }
        },
      ),
    );
  }

  Widget _buildLevelSelector() {
    final levelColor = _getLevelColor(_selectedLevel);
    final levelDescription = _getLevelDescription(_selectedLevel);
    final levelIcon = _getLevelIcon(_selectedLevel);

    return Card(
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
                Icon(
                  Icons.stairs,
                  color: ThemeConfig.getPrimaryColor(_currentTheme),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Authority Level',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getPrimaryColor(_currentTheme),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: levelColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: levelColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    levelIcon,
                    color: levelColor,
                    size: 40,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Level $_selectedLevel',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: levelColor,
                          ),
                        ),
                        Text(
                          levelDescription,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: levelColor,
                inactiveTrackColor: levelColor.withOpacity(0.2),
                thumbColor: levelColor,
                overlayColor: levelColor.withOpacity(0.2),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              ),
              child: Slider(
                value: _selectedLevel.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                label: _selectedLevel.toString(),
                onChanged: (value) {
                  setState(() {
                    _selectedLevel = value.round();
                  });
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  '50',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  '100',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    final selectedStatusData = _statuses.firstWhere(
      (s) => s['code'] == _selectedStatus,
      orElse: () => _statuses[0],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _selectedStatus,
        decoration: InputDecoration(
          labelText: 'Status *',
          prefixIcon: Icon(
            selectedStatusData['icon'] as IconData,
            color: selectedStatusData['color'] as Color,
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
          filled: true,
          fillColor: Colors.grey[50],
        ),
        items: _statuses.map((status) {
          return DropdownMenuItem<String>(
            value: status['code'] as String,
            child: Row(
              children: [
                Icon(
                  status['icon'] as IconData,
                  color: status['color'] as Color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(status['name'] as String),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedStatus = value);
          }
        },
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
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Add New Role'),
        backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: _maxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(_isWideScreen ? 32 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Basic Information Card
                  Card(
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
                              Icon(
                                Icons.work,
                                color: ThemeConfig.getPrimaryColor(_currentTheme),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Role Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeConfig.getPrimaryColor(_currentTheme),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _nameController,
                            label: 'Role Name',
                            icon: Icons.badge,
                            hint: 'e.g., Manager, Supervisor',
                            required: true,
                            validator: (value) {
                              if (value?.trim().isEmpty == true) {
                                return 'Please enter role name';
                              }
                              if (value!.trim().length < 2) {
                                return 'Role name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                          _buildTextField(
                            controller: _codeController,
                            label: 'Role Code',
                            icon: Icons.code,
                            hint: 'e.g., manager, supervisor (lowercase)',
                            required: true,
                            validator: (value) {
                              if (value?.trim().isEmpty == true) {
                                return 'Please enter role code';
                              }
                              if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value!.trim())) {
                                return 'Use only lowercase letters, numbers, and underscores';
                              }
                              return null;
                            },
                          ),
                          _buildTextField(
                            controller: _descriptionController,
                            label: 'Description',
                            icon: Icons.description,
                            hint: 'Describe the role responsibilities',
                            maxLines: 3,
                          ),
                          _buildDepartmentDropdown(),
                          _buildStatusDropdown(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Permissions Card
                  Card(
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
                              Icon(
                                Icons.security,
                                color: ThemeConfig.getPrimaryColor(_currentTheme),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Permission Settings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeConfig.getPrimaryColor(_currentTheme),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildPermissionTemplateDropdown(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Authority Level Card
                  _buildLevelSelector(),
                  const SizedBox(height: 30),
                  
                  // Action Buttons
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _addRole,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
                        foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
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
                                  'Creating Role...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_circle, size: 24),
                                const SizedBox(width: 12),
                                const Text(
                                  'CREATE ROLE',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
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
            ),
          ),
        ),
      ),
    );
  }
}