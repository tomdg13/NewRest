import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';

class RoleEditPage extends StatefulWidget {
  final Map<String, dynamic> roleData;
  
  const RoleEditPage({Key? key, required this.roleData}) : super(key: key);

  @override
  State<RoleEditPage> createState() => _RoleEditPageState();
}

class _RoleEditPageState extends State<RoleEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isLoading = false;
  String _langCode = 'en';
  String _currentTheme = ThemeConfig.defaultTheme;
  
  int _selectedLevel = 50;
  String _selectedStatus = 'active';
  bool _isSystemRole = false;

  final List<Map<String, dynamic>> _statuses = [
    {'code': 'active', 'name': 'Active', 'icon': Icons.check_circle, 'color': Colors.green},
    {'code': 'inactive', 'name': 'Inactive', 'icon': Icons.pause_circle, 'color': Colors.orange},
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _initializeControllers();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _langCode = prefs.getString('languageCode') ?? 'en';
      _currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  void _initializeControllers() {
    _nameController.text = widget.roleData['role_name'] ?? '';
    _codeController.text = widget.roleData['role_code'] ?? '';
    _descriptionController.text = widget.roleData['description'] ?? '';
    _selectedLevel = widget.roleData['level'] ?? 50;
    _selectedStatus = widget.roleData['status'] ?? 'active';
    _isSystemRole = (widget.roleData['is_system'] == 1 || widget.roleData['is_system'] == true);

    print('=== INITIALIZING ROLE DATA ===');
    print('Role ID: ${widget.roleData['role_id']}');
    print('Role Name: ${_nameController.text}');
    print('Role Code: ${_codeController.text}');
    print('Level: $_selectedLevel');
    print('Status: $_selectedStatus');
    print('Is System: $_isSystemRole');
    print('===============================');
  }

  bool get _isWideScreen => MediaQuery.of(context).size.width > 800;
  double get _maxWidth => _isWideScreen ? 800.0 : double.infinity;

  Future<void> _updateRole() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSystemRole) {
      _showErrorSnackBar('Cannot modify system roles');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final roleId = widget.roleData['role_id'];
      
      // ✅ FIXED: Using correct endpoint
      final url = AppConfig.api('/api/iorole/$roleId');

      print('=== UPDATING ROLE ===');
      print('Role ID: $roleId');
      print('Role name: ${_nameController.text}');
      print('Level: $_selectedLevel');
      print('Status: $_selectedStatus');
      print('API URL: $url');
      print('=====================');

      final requestBody = {
        'role_name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        'level': _selectedLevel,
        'status': _selectedStatus,
      };

      print('Request body: ${jsonEncode(requestBody)}');

      final response = await http.put(
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
          _showSuccessSnackBar('Role updated successfully');
          Navigator.pop(context, true);
        } else {
          _showErrorSnackBar(data['message'] ?? 'Update failed');
        }
      } else if (response.statusCode == 403) {
        _showErrorSnackBar('Cannot modify system roles');
      } else if (response.statusCode == 404) {
        _showErrorSnackBar('Role not found');
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 
            errorData['error'] ?? 
            'Server error';
        _showErrorSnackBar('Error (${response.statusCode}): $errorMessage');
      }
    } catch (e) {
      print('Error updating role: $e');
      _showErrorSnackBar('Network error occurred: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRole() async {
    if (_isSystemRole) {
      _showErrorSnackBar('Cannot delete system roles');
      return;
    }

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('Confirm Delete'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete the role "${_nameController.text}"?\n\nThis action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
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
      final roleId = widget.roleData['role_id'];
      
      // ✅ FIXED: Using correct endpoint
      final url = AppConfig.api('/api/iorole/$roleId');

      print('=== DELETING ROLE ===');
      print('Role ID: $roleId');
      print('URL: $url');
      print('=====================');

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _showSuccessSnackBar('Role deleted successfully');
          Navigator.pop(context, 'deleted');
        } else {
          _showErrorSnackBar(data['message'] ?? 'Delete failed');
        }
      } else if (response.statusCode == 403) {
        _showErrorSnackBar('Cannot delete system roles');
      } else if (response.statusCode == 404) {
        _showErrorSnackBar('Role not found');
      } else if (response.statusCode == 409) {
        final errorData = jsonDecode(response.body);
        _showErrorSnackBar(errorData['message'] ?? 'Cannot delete role with assigned users');
      } else {
        final errorData = jsonDecode(response.body);
        _showErrorSnackBar(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting role: $e');
      _showErrorSnackBar('Failed to delete role: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
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
          fillColor: readOnly ? Colors.grey[100] : Colors.grey[50],
        ),
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
                onChanged: _isSystemRole ? null : (value) {
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
          fillColor: _isSystemRole ? Colors.grey[100] : Colors.grey[50],
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
        onChanged: _isSystemRole ? null : (value) {
          if (value != null) {
            setState(() => _selectedStatus = value);
          }
        },
      ),
    );
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
        backgroundColor: Colors.green,
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
        title: const Text('Edit Role'),
        backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
        elevation: 0,
        actions: [
          if (!_isSystemRole)
            IconButton(
              onPressed: _deleteRole,
              icon: const Icon(Icons.delete),
              tooltip: 'Delete Role',
            ),
        ],
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
                  if (_isSystemRole)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange, width: 2),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This is a system role and cannot be modified or deleted.',
                              style: TextStyle(
                                color: Colors.orange[900],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                            readOnly: _isSystemRole,
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
                            readOnly: true,
                          ),
                          _buildTextField(
                            controller: _descriptionController,
                            label: 'Description',
                            icon: Icons.description,
                            hint: 'Describe the role responsibilities',
                            maxLines: 3,
                            readOnly: _isSystemRole,
                          ),
                          _buildStatusDropdown(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildLevelSelector(),
                  const SizedBox(height: 30),
                  if (!_isSystemRole)
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateRole,
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
                                    'Updating Role...',
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
                                  const Icon(Icons.save, size: 24),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'UPDATE ROLE',
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
                      _isSystemRole ? 'CLOSE' : 'CANCEL',
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