import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Main Permission Management Page
class PermissionManagementPage extends StatefulWidget {
  const PermissionManagementPage({Key? key}) : super(key: key);

  @override
  State<PermissionManagementPage> createState() => _PermissionManagementPageState();
}

class _PermissionManagementPageState extends State<PermissionManagementPage> {
  List<Permission> permissions = [];
  List<Permission> filteredPermissions = [];
  bool isLoading = true;
  String currentTheme = ThemeConfig.defaultTheme;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadPermissions();
    _searchController.addListener(_filterPermissions);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  void _filterPermissions() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredPermissions = permissions.where((permission) {
        return permission.moduleName.toLowerCase().contains(query) ||
               permission.moduleCode.toLowerCase().contains(query) ||
               (permission.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  Future<void> _loadPermissions() async {
    setState(() => isLoading = true);

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
          final List<dynamic> permData = data['data'] ?? [];
          setState(() {
            permissions = permData.map((p) => Permission.fromJson(p)).toList();
            filteredPermissions = List.from(permissions);
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading permissions: $e');
      setState(() => isLoading = false);
      _showErrorMessage('Failed to load permissions');
    }
  }

  Future<void> _deletePermission(Permission permission) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Confirm Delete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this permission?'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    permission.moduleName,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    permission.moduleCode,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              '⚠️ This will remove the permission from all roles',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final response = await http.delete(
        AppConfig.api('/api/permissions/${permission.permissionId}'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _showSuccessMessage('Permission deleted successfully');
        _loadPermissions();
      } else {
        _showErrorMessage('Failed to delete permission');
      }
    } catch (e) {
      _showErrorMessage('Network error occurred');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildPermissionCard(Permission permission) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
          child: Icon(
            Icons.security,
            color: ThemeConfig.getPrimaryColor(currentTheme),
          ),
        ),
        title: Text(
          permission.moduleName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              permission.moduleCode,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (permission.description != null)
              Text(
                permission.description!,
                style: TextStyle(fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PermissionEditPage(permission: permission),
                  ),
                );
                if (result == true) _loadPermissions();
              },
              tooltip: 'Edit',
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deletePermission(permission),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('Permission Management'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadPermissions,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search Permissions',
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: ThemeConfig.getPrimaryColor(currentTheme),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${filteredPermissions.length} permissions found',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredPermissions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.security_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No permissions found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredPermissions.length,
                          itemBuilder: (context, index) {
                            return _buildPermissionCard(filteredPermissions[index]);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PermissionAddPage()),
          );
          if (result == true) _loadPermissions();
        },
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        icon: Icon(Icons.add),
        label: Text('Add Permission'),
      ),
    );
  }
}

// Add Permission Page
class PermissionAddPage extends StatefulWidget {
  const PermissionAddPage({Key? key}) : super(key: key);

  @override
  State<PermissionAddPage> createState() => _PermissionAddPageState();
}

class _PermissionAddPageState extends State<PermissionAddPage> {
  final _formKey = GlobalKey<FormState>();
  final _moduleNameController = TextEditingController();
  final _moduleCodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _displayOrderController = TextEditingController(text: '0');
  
  bool _isLoading = false;
  String _currentTheme = ThemeConfig.defaultTheme;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  Future<void> _savePermission() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final requestBody = {
        'module_name': _moduleNameController.text.trim(),
        'module_code': _moduleCodeController.text.trim().toLowerCase(),
        'description': _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        'display_order': int.tryParse(_displayOrderController.text) ?? 0,
        'is_active': _isActive,
      };

      final response = await http.post(
        AppConfig.api('/api/permissions'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _showSuccessDialog();
        } else {
          _showErrorSnackBar(data['message'] ?? 'Failed to create permission');
        }
      } else {
        final errorData = jsonDecode(response.body);
        _showErrorSnackBar(errorData['message'] ?? 'Server error');
      }
    } catch (e) {
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
            SizedBox(width: 12),
            Text('Success!'),
          ],
        ),
        content: Text('Permission has been created successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _moduleNameController.dispose();
    _moduleCodeController.dispose();
    _descriptionController.dispose();
    _displayOrderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;
    final maxWidth = isWideScreen ? 800.0 : double.infinity;

    return Scaffold(
      appBar: AppBar(
        title: Text('Add New Permission'),
        backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isWideScreen ? 32 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                                Icons.security,
                                color: ThemeConfig.getPrimaryColor(_currentTheme),
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Permission Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeConfig.getPrimaryColor(_currentTheme),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          TextFormField(
                            controller: _moduleNameController,
                            decoration: InputDecoration(
                              labelText: 'Module Name *',
                              prefixIcon: Icon(Icons.folder),
                              hintText: 'e.g., User Management, Reports',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value?.trim().isEmpty == true) {
                                return 'Please enter module name';
                              }
                              if (value!.trim().length < 2) {
                                return 'Module name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _moduleCodeController,
                            decoration: InputDecoration(
                              labelText: 'Module Code *',
                              prefixIcon: Icon(Icons.code),
                              hintText: 'e.g., user_management, reports',
                              helperText: 'Use lowercase letters, numbers, and underscores',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value?.trim().isEmpty == true) {
                                return 'Please enter module code';
                              }
                              if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value!.trim())) {
                                return 'Use only lowercase letters, numbers, underscores';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              prefixIcon: Icon(Icons.description),
                              hintText: 'Describe what this permission controls',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _displayOrderController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Display Order',
                              prefixIcon: Icon(Icons.sort),
                              hintText: 'Order in list (0 = first)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value?.isNotEmpty == true) {
                                final order = int.tryParse(value!);
                                if (order == null) {
                                  return 'Please enter a valid number';
                                }
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          SwitchListTile(
                            title: Text('Active Status'),
                            subtitle: Text(
                              _isActive ? 'Permission is active' : 'Permission is inactive',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _isActive,
                            onChanged: (value) {
                              setState(() => _isActive = value);
                            },
                            activeColor: ThemeConfig.getPrimaryColor(_currentTheme),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _savePermission,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
                        foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle),
                                SizedBox(width: 12),
                                Text(
                                  'CREATE PERMISSION',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
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
}

// Edit Permission Page
class PermissionEditPage extends StatefulWidget {
  final Permission permission;

  const PermissionEditPage({Key? key, required this.permission}) : super(key: key);

  @override
  State<PermissionEditPage> createState() => _PermissionEditPageState();
}

class _PermissionEditPageState extends State<PermissionEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _moduleNameController;
  late TextEditingController _moduleCodeController;
  late TextEditingController _descriptionController;
  late TextEditingController _displayOrderController;
  
  bool _isLoading = false;
  String _currentTheme = ThemeConfig.defaultTheme;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initializeControllers();
  }

  void _initializeControllers() {
    _moduleNameController = TextEditingController(text: widget.permission.moduleName);
    _moduleCodeController = TextEditingController(text: widget.permission.moduleCode);
    _descriptionController = TextEditingController(text: widget.permission.description ?? '');
    _displayOrderController = TextEditingController(
      text: widget.permission.displayOrder?.toString() ?? '0'
    );
    _isActive = widget.permission.isActive;
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  Future<void> _updatePermission() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final requestBody = {
        'module_name': _moduleNameController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        'display_order': int.tryParse(_displayOrderController.text) ?? 0,
        'is_active': _isActive,
      };

      final response = await http.put(
        AppConfig.api('/api/permissions/${widget.permission.permissionId}'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _showSuccessMessage('Permission updated successfully');
          Navigator.pop(context, true);
        } else {
          _showErrorMessage(data['message'] ?? 'Failed to update permission');
        }
      } else {
        _showErrorMessage('Server error occurred');
      }
    } catch (e) {
      _showErrorMessage('Network error occurred');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _moduleNameController.dispose();
    _moduleCodeController.dispose();
    _descriptionController.dispose();
    _displayOrderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;
    final maxWidth = isWideScreen ? 800.0 : double.infinity;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Permission'),
        backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isWideScreen ? 32 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                                Icons.security,
                                color: ThemeConfig.getPrimaryColor(_currentTheme),
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Edit Permission Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeConfig.getPrimaryColor(_currentTheme),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          TextFormField(
                            controller: _moduleNameController,
                            decoration: InputDecoration(
                              labelText: 'Module Name *',
                              prefixIcon: Icon(Icons.folder),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value?.trim().isEmpty == true) {
                                return 'Please enter module name';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _moduleCodeController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Module Code',
                              prefixIcon: Icon(Icons.code),
                              helperText: 'Module code cannot be changed',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              fillColor: Colors.grey[100],
                              filled: true,
                            ),
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              prefixIcon: Icon(Icons.description),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _displayOrderController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Display Order',
                              prefixIcon: Icon(Icons.sort),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value?.isNotEmpty == true) {
                                final order = int.tryParse(value!);
                                if (order == null) {
                                  return 'Please enter a valid number';
                                }
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          SwitchListTile(
                            title: Text('Active Status'),
                            subtitle: Text(
                              _isActive ? 'Permission is active' : 'Permission is inactive',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: _isActive,
                            onChanged: (value) {
                              setState(() => _isActive = value);
                            },
                            activeColor: ThemeConfig.getPrimaryColor(_currentTheme),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updatePermission,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
                        foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save),
                                SizedBox(width: 12),
                                Text(
                                  'UPDATE PERMISSION',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
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
}

// Permission Model
class Permission {
  final int permissionId;
  final String moduleName;
  final String moduleCode;
  final String? description;
  final int? displayOrder;
  final bool isActive;

  Permission({
    required this.permissionId,
    required this.moduleName,
    required this.moduleCode,
    this.description,
    this.displayOrder,
    this.isActive = true,
  });

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      permissionId: json['permission_id'] ?? 0,
      moduleName: json['module_name'] ?? '',
      moduleCode: json['module_code'] ?? '',
      description: json['description'],
      displayOrder: json['display_order'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'permission_id': permissionId,
      'module_name': moduleName,
      'module_code': moduleCode,
      'description': description,
      'display_order': displayOrder,
      'is_active': isActive,
    };
  }
}