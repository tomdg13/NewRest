import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Role Permission Mapping Page
/// Allows administrators to assign/revoke permissions to roles
class RolePermissionMappingPage extends StatefulWidget {
  const RolePermissionMappingPage({Key? key}) : super(key: key);

  @override
  State<RolePermissionMappingPage> createState() => _RolePermissionMappingPageState();
}

class _RolePermissionMappingPageState extends State<RolePermissionMappingPage> {
  List<Role> _roles = [];
  List<Permission> _permissions = [];
  Map<int, List<int>> _rolePermissions = {}; // roleId -> List of permissionIds
  
  bool _isLoadingRoles = true;
  bool _isLoadingPermissions = true;
  bool _isSaving = false;
  
  int? _selectedRoleId;
  int? _companyId; // Store company_id from user session
  String _currentTheme = ThemeConfig.defaultTheme;
  String _searchQuery = '';
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🚀 Role Permission Mapping Page Initialized');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _loadTheme();
    _loadUserData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
    print('🔍 Search query changed: "$_searchQuery"');
    print('   Filtered results: ${_filteredPermissions.length} permissions');
  }

  List<Permission> get _filteredPermissions {
    if (_searchQuery.isEmpty) return _permissions;
    return _permissions.where((p) {
      return p.moduleName.toLowerCase().contains(_searchQuery) ||
             p.moduleCode.toLowerCase().contains(_searchQuery) ||
             (p.description?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  Future<void> _loadTheme() async {
    print('\n📱 Loading theme preferences...');
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
    print('   Current theme: $_currentTheme');
  }

  Future<void> _loadUserData() async {
    print('\n👤 Loading user data...');
    final prefs = await SharedPreferences.getInstance();
    
    // Get company_id from user session
    _companyId = prefs.getInt('company_id');
    print('   Company ID: $_companyId');
    
    // Load roles and permissions after getting company_id
    await Future.wait([
      _loadRoles(),
      _loadPermissions(),
    ]);
  }

  bool get _isWideScreen => MediaQuery.of(context).size.width > 800;
  double get _maxWidth => _isWideScreen ? 1200.0 : double.infinity;

  Future<void> _loadRoles() async {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📋 Loading Roles...');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    setState(() => _isLoadingRoles = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      print('🔑 Token present: ${token != null ? "Yes" : "No"}');
      
      // Build URL with company_id query parameter
      String apiUrl = '/api/iorole';
      if (_companyId != null) {
        apiUrl += '?company_id=$_companyId';
        print('🏢 Filtering by company_id: $_companyId');
      }
      
      print('🌐 API URL: ${AppConfig.api(apiUrl)}');

      final response = await http.get(
        AppConfig.api(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final List<dynamic> roleData = data['data'] ?? [];
          setState(() {
            _roles = roleData.map((r) => Role.fromJson(r)).toList();
            _isLoadingRoles = false;
            
            print('✅ Loaded ${_roles.length} roles successfully');
            for (var role in _roles) {
              print('   - ${role.roleName} (ID: ${role.roleId})${role.isSystem ? ' 🔒 SYSTEM' : ''} - Company: ${role.companyId}');
            }
            
            // Auto-select first role if available
            if (_roles.isNotEmpty && _selectedRoleId == null) {
              _selectedRoleId = _roles.first.roleId;
              print('🎯 Auto-selected role: ${_roles.first.roleName}');
              _loadRolePermissions(_selectedRoleId!);
            }
          });
        }
      } else {
        throw Exception('Failed to load roles: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ ERROR loading roles: $e');
      setState(() => _isLoadingRoles = false);
      _showErrorSnackBar('Failed to load roles: $e');
    }
  }

  Future<void> _loadPermissions() async {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔐 Loading Permissions...');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    setState(() => _isLoadingPermissions = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      print('🌐 API URL: ${AppConfig.api('/api/permissions')}');

      final response = await http.get(
        AppConfig.api('/api/permissions'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final List<dynamic> permData = data['data'] ?? [];
          setState(() {
            _permissions = permData.map((p) => Permission.fromJson(p)).toList();
            _isLoadingPermissions = false;
          });
          
          print('✅ Loaded ${_permissions.length} permissions successfully');
          if (_permissions.isNotEmpty) {
            print('   First 5 permissions:');
            for (var i = 0; i < (_permissions.length > 5 ? 5 : _permissions.length); i++) {
              print('   - ${_permissions[i].moduleName} (${_permissions[i].moduleCode})');
            }
          }
        }
      } else {
        throw Exception('Failed to load permissions: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ ERROR loading permissions: $e');
      setState(() => _isLoadingPermissions = false);
      _showErrorSnackBar('Failed to load permissions: $e');
    }
  }

  Future<void> _loadRolePermissions(int roleId) async {
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔗 Loading Role Permissions');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final role = _roles.firstWhere((r) => r.roleId == roleId);
      print('📌 Role ID: $roleId');
      print('📌 Role Name: ${role.roleName}');
      print('📌 Company ID: ${role.companyId}');
      print('📌 Is System: ${role.isSystem}');
      print('🌐 API URL: ${AppConfig.api('/api/iorole/$roleId/permissions')}');

      final response = await http.get(
        AppConfig.api('/api/iorole/$roleId/permissions'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final List<dynamic> permissions = data['data'] ?? [];
          setState(() {
            _rolePermissions[roleId] = permissions
                .map<int>((p) => p['permission_id'] as int)
                .toList();
          });
          print('✅ Loaded ${_rolePermissions[roleId]?.length ?? 0} permissions for this role');
          print('   Permission IDs: ${_rolePermissions[roleId]}');
        }
      } else if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        print('⚠️  Access denied: ${data['message']}');
        _showErrorSnackBar(data['message'] ?? 'Access denied to system role');
      } else if (response.statusCode == 404) {
        print('⚠️  Role not found');
        _showErrorSnackBar('Role not found');
      } else {
        throw Exception('Failed to load role permissions');
      }
    } catch (e) {
      print('❌ ERROR loading role permissions: $e');
      _showErrorSnackBar('Failed to load role permissions');
    }
  }

  Future<void> _saveRolePermissions() async {
    if (_selectedRoleId == null) return;

    final selectedRole = _roles.firstWhere((r) => r.roleId == _selectedRoleId);
    
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('💾 SAVING ROLE PERMISSIONS');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    // Check if it's a system role
    if (selectedRole.isSystem) {
      print('⚠️  Blocked: Cannot modify system role');
      _showErrorSnackBar('Cannot modify permissions of system roles');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final userId = prefs.getInt('user_id');

      final selectedPermissions = _rolePermissions[_selectedRoleId] ?? [];

      final requestBody = {
        'permission_ids': selectedPermissions,
        if (userId != null) 'updated_by': userId,
      };

      print('📌 Role ID: $_selectedRoleId');
      print('📌 Role Name: ${selectedRole.roleName}');
      print('📌 Company ID: ${selectedRole.companyId}');
      print('📊 Total Permissions Selected: ${selectedPermissions.length}');
      print('🔢 Permission IDs: $selectedPermissions');
      print('📤 Request Body: ${jsonEncode(requestBody)}');
      print('🌐 API URL: ${AppConfig.api('/api/iorole/$_selectedRoleId/permissions')}');

      final response = await http.put(
        AppConfig.api('/api/iorole/$_selectedRoleId/permissions'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          print('✅ SUCCESS: Permissions saved successfully');
          print('   Message: ${data['message']}');
          if (data['data'] != null) {
            print('   Data: ${data['data']}');
          }
          
          _showSuccessSnackBar(
            data['message'] ?? 'Permissions updated successfully'
          );
          
          // Reload permissions to ensure sync with server
          await _loadRolePermissions(_selectedRoleId!);
        } else {
          print('⚠️  Unexpected response status: ${data['status']}');
          _showErrorSnackBar(data['message'] ?? 'Update failed');
        }
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        print('❌ BAD REQUEST (400)');
        if (data['invalid_ids'] != null) {
          print('   Invalid IDs: ${data['invalid_ids']}');
          _showErrorSnackBar(
            'Invalid permission IDs: ${data['invalid_ids'].join(', ')}'
          );
        } else {
          print('   Message: ${data['message']}');
          _showErrorSnackBar(data['message'] ?? 'Invalid request');
        }
      } else if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        print('❌ FORBIDDEN (403): ${data['message']}');
        _showErrorSnackBar(data['message'] ?? 'Access denied');
      } else if (response.statusCode == 404) {
        print('❌ NOT FOUND (404): Role not found');
        _showErrorSnackBar('Role not found');
      } else {
        final errorData = jsonDecode(response.body);
        print('❌ ERROR (${response.statusCode}): ${errorData['message']}');
        _showErrorSnackBar(errorData['message'] ?? 'Server error');
      }
    } catch (e) {
      print('❌ EXCEPTION occurred while saving permissions');
      print('   Error: $e');
      print('   Stack trace: ${StackTrace.current}');
      if (!mounted) return;
      _showErrorSnackBar('Network error: Unable to save permissions');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        print('🏁 Save operation completed\n');
      }
    }
  }

  void _togglePermission(int permissionId) {
    if (_selectedRoleId == null) return;

    final selectedRole = _roles.firstWhere((r) => r.roleId == _selectedRoleId);
    if (selectedRole.isSystem) {
      print('⚠️  Blocked: Cannot toggle permission for system role');
      _showWarningSnackBar('Cannot modify permissions of system roles');
      return;
    }

    final permission = _permissions.firstWhere((p) => p.permissionId == permissionId);
    
    setState(() {
      if (_rolePermissions[_selectedRoleId] == null) {
        _rolePermissions[_selectedRoleId!] = [];
      }

      if (_rolePermissions[_selectedRoleId]!.contains(permissionId)) {
        _rolePermissions[_selectedRoleId]!.remove(permissionId);
        print('➖ Removed: ${permission.moduleName} (ID: $permissionId)');
      } else {
        _rolePermissions[_selectedRoleId]!.add(permissionId);
        print('➕ Added: ${permission.moduleName} (ID: $permissionId)');
      }
      
      print('   Total selected: ${_rolePermissions[_selectedRoleId]!.length}');
    });
  }

  void _selectAllPermissions() {
    if (_selectedRoleId == null) return;

    final selectedRole = _roles.firstWhere((r) => r.roleId == _selectedRoleId);
    if (selectedRole.isSystem) {
      print('⚠️  Blocked: Cannot select all for system role');
      _showWarningSnackBar('Cannot modify permissions of system roles');
      return;
    }

    print('\n🔘 Selecting ALL filtered permissions');
    print('   Filtered count: ${_filteredPermissions.length}');

    setState(() {
      _rolePermissions[_selectedRoleId!] = _filteredPermissions
          .map((p) => p.permissionId)
          .toList();
    });
    
    print('✅ Selected ${_rolePermissions[_selectedRoleId!]?.length} permissions');
  }

  void _deselectAllPermissions() {
    if (_selectedRoleId == null) return;

    final selectedRole = _roles.firstWhere((r) => r.roleId == _selectedRoleId);
    if (selectedRole.isSystem) {
      print('⚠️  Blocked: Cannot deselect all for system role');
      _showWarningSnackBar('Cannot modify permissions of system roles');
      return;
    }

    print('\n🔘 Deselecting ALL permissions');
    print('   Previously selected: ${_rolePermissions[_selectedRoleId!]?.length ?? 0}');

    setState(() {
      _rolePermissions[_selectedRoleId!] = [];
    });
    
    print('✅ All permissions cleared');
  }

  bool _isPermissionSelected(int permissionId) {
    if (_selectedRoleId == null) return false;
    return _rolePermissions[_selectedRoleId]?.contains(permissionId) ?? false;
  }

  int _getSelectedPermissionsCount() {
    if (_selectedRoleId == null) return 0;
    return _rolePermissions[_selectedRoleId]?.length ?? 0;
  }

  void _showCopyPermissionsDialog() {
    if (_selectedRoleId == null) return;

    final selectedRole = _roles.firstWhere((r) => r.roleId == _selectedRoleId);
    
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📋 Opening Copy Permissions Dialog');
    print('   Target Role: ${selectedRole.roleName} (ID: $_selectedRoleId)');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    if (selectedRole.isSystem) {
      print('⚠️  Blocked: Target is a system role');
      _showWarningSnackBar('Cannot modify permissions of system roles');
      return;
    }

    final availableRoles = _roles.where((r) => r.roleId != _selectedRoleId).toList();
    print('   Available source roles: ${availableRoles.length}');

    int? sourceRoleId;
    bool replaceExisting = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Copy Permissions'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Copy permissions from another role to ${selectedRole.roleName}',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: sourceRoleId,
                decoration: const InputDecoration(
                  labelText: 'Source Role',
                  border: OutlineInputBorder(),
                ),
                items: availableRoles.map((role) {
                  final permCount = _rolePermissions[role.roleId]?.length ?? 0;
                  return DropdownMenuItem(
                    value: role.roleId,
                    child: Text('${role.roleName} ($permCount permissions)'),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() => sourceRoleId = value);
                  if (value != null) {
                    final role = availableRoles.firstWhere((r) => r.roleId == value);
                    print('   📌 Selected source: ${role.roleName} (ID: $value)');
                  }
                },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Replace existing permissions'),
                subtitle: const Text('Uncheck to add to existing permissions'),
                value: replaceExisting,
                onChanged: (value) {
                  setDialogState(() => replaceExisting = value ?? true);
                  print('   🔄 Mode changed to: ${replaceExisting ? "REPLACE" : "ADD"}');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                print('   ❌ Copy dialog cancelled');
                Navigator.pop(context);
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: sourceRoleId == null
                  ? null
                  : () {
                      print('   ✅ Copy confirmed');
                      Navigator.pop(context);
                      _copyPermissions(sourceRoleId!, replaceExisting);
                    },
              child: const Text('COPY'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyPermissions(int sourceRoleId, bool replace) async {
    if (_selectedRoleId == null) return;

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final userId = prefs.getInt('user_id');

      final requestBody = {
        'source_role_id': sourceRoleId,
        'replace': replace,
        if (userId != null) 'created_by': userId,
      };

      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📋 COPYING PERMISSIONS');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📌 From Role ID: $sourceRoleId');
      print('📌 To Role ID: $_selectedRoleId');
      print('🔄 Replace Mode: $replace');
      print('📤 Request Body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        AppConfig.api('/api/iorole/$_selectedRoleId/permissions/copy'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📦 Response Body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          print('✅ SUCCESS: Permissions copied successfully');
          _showSuccessSnackBar(data['message'] ?? 'Permissions copied successfully');
          await _loadRolePermissions(_selectedRoleId!);
        }
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        print('❌ BAD REQUEST (400): ${data['message']}');
        _showErrorSnackBar(data['message'] ?? 'Invalid request');
      } else if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        print('❌ FORBIDDEN (403): ${data['message']}');
        _showErrorSnackBar(data['message'] ?? 'Access denied');
      } else if (response.statusCode == 404) {
        print('❌ NOT FOUND (404): Role not found');
        _showErrorSnackBar('Source role not found');
      } else {
        final data = jsonDecode(response.body);
        print('❌ ERROR (${response.statusCode}): ${data['message']}');
        _showErrorSnackBar(data['message'] ?? 'Failed to copy permissions');
      }
    } catch (e) {
      print('❌ EXCEPTION occurred while copying permissions');
      print('   Error: $e');
      if (!mounted) return;
      _showErrorSnackBar('Network error occurred');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        print('🏁 Copy operation completed\n');
      }
    }
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
        behavior: SnackBarBehavior.floating,
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
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Role Permission Mapping'),
            if (_companyId != null)
              Text(
                'Company ID: $_companyId',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
        elevation: 0,
        actions: [
          if (_selectedRoleId != null) ...[
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _showCopyPermissionsDialog,
              tooltip: 'Copy Permissions',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              print('\n🔄 Manual refresh triggered');
              print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              _loadRoles();
              _loadPermissions();
              if (_selectedRoleId != null) {
                _loadRolePermissions(_selectedRoleId!);
              } else {
                print('   No role selected to refresh');
              }
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoadingRoles || _isLoadingPermissions
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading data...'),
                ],
              ),
            )
          : Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: _maxWidth),
                child: _isWideScreen ? _buildWideLayout() : _buildMobileLayout(),
              ),
            ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: _buildRoleSelector(),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPermissionsSection(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildRoleDropdown(),
        Expanded(child: _buildPermissionsSection()),
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.work,
                  color: ThemeConfig.getPrimaryColor(_currentTheme),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Select Role',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getPrimaryColor(_currentTheme),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _roles.length,
              itemBuilder: (context, index) {
                final role = _roles[index];
                final isSelected = _selectedRoleId == role.roleId;
                final permCount = _rolePermissions[role.roleId]?.length ?? 0;

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: ThemeConfig.getPrimaryColor(_currentTheme).withOpacity(0.1),
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? ThemeConfig.getPrimaryColor(_currentTheme)
                        : Colors.grey[300],
                    child: Icon(
                      Icons.badge,
                      color: isSelected ? Colors.white : Colors.grey[600],
                      size: 20,
                    ),
                  ),
                  title: Text(
                    role.roleName,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '$permCount permissions',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: role.isSystem
                      ? const Icon(Icons.lock, size: 16, color: Colors.orange)
                      : null,
                  onTap: () {
                    print('\n🎯 Role selected from list');
                    print('   Role: ${role.roleName} (ID: ${role.roleId})');
                    print('   Is System: ${role.isSystem}');
                    
                    setState(() {
                      _selectedRoleId = role.roleId;
                    });
                    _loadRolePermissions(role.roleId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButton<int>(
        value: _selectedRoleId,
        isExpanded: true,
        underline: const SizedBox(),
        hint: const Text('Select a role'),
        items: _roles.map((role) {
          final permCount = _rolePermissions[role.roleId]?.length ?? 0;
          return DropdownMenuItem<int>(
            value: role.roleId,
            child: Row(
              children: [
                Icon(
                  Icons.badge,
                  size: 20,
                  color: ThemeConfig.getPrimaryColor(_currentTheme),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        role.roleName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$permCount permissions',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (role.isSystem)
                  const Icon(Icons.lock, size: 16, color: Colors.orange),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            final role = _roles.firstWhere((r) => r.roleId == value);
            print('\n🎯 Role selected from dropdown');
            print('   Role: ${role.roleName} (ID: $value)');
            print('   Is System: ${role.isSystem}');
            
            setState(() {
              _selectedRoleId = value;
            });
            _loadRolePermissions(value);
          }
        },
      ),
    );
  }

  Widget _buildPermissionsSection() {
    if (_selectedRoleId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.arrow_back,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Select a role to manage permissions',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    final selectedRole = _roles.firstWhere((r) => r.roleId == _selectedRoleId);

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ThemeConfig.getPrimaryColor(_currentTheme).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Permissions for ${selectedRole.roleName}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: ThemeConfig.getPrimaryColor(_currentTheme),
                                  ),
                                ),
                              ),
                              if (selectedRole.isSystem)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock, size: 12, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'SYSTEM',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            '${_getSelectedPermissionsCount()} of ${_permissions.length} selected',
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search permissions...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: selectedRole.isSystem ? null : _selectAllPermissions,
                      icon: const Icon(Icons.check_box, size: 18),
                      label: const Text('All'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: selectedRole.isSystem ? null : _deselectAllPermissions,
                      icon: const Icon(Icons.check_box_outline_blank, size: 18),
                      label: const Text('None'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredPermissions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
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
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _isWideScreen ? 3 : 1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: _isWideScreen ? 3 : 4,
                    ),
                    itemCount: _filteredPermissions.length,
                    itemBuilder: (context, index) {
                      final permission = _filteredPermissions[index];
                      final isSelected = _isPermissionSelected(permission.permissionId);

                      return InkWell(
                        onTap: selectedRole.isSystem 
                            ? null 
                            : () => _togglePermission(permission.permissionId),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ThemeConfig.getPrimaryColor(_currentTheme).withOpacity(0.1)
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? ThemeConfig.getPrimaryColor(_currentTheme)
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                onChanged: selectedRole.isSystem
                                    ? null
                                    : (value) => _togglePermission(permission.permissionId),
                                activeColor: ThemeConfig.getPrimaryColor(_currentTheme),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      permission.moduleName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isSelected
                                            ? ThemeConfig.getPrimaryColor(_currentTheme)
                                            : Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      permission.moduleCode,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (permission.description != null)
                                      Text(
                                        permission.description!,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_isSaving || selectedRole.isSystem) 
                    ? null 
                    : _saveRolePermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
                  foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isSaving
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                ThemeConfig.getButtonTextColor(_currentTheme),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Saving...',
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
                          const Icon(Icons.save, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            selectedRole.isSystem 
                                ? 'SYSTEM ROLE - READ ONLY'
                                : 'SAVE PERMISSIONS',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Role Model
class Role {
  final int roleId;
  final String roleName;
  final String roleCode;
  final String? description;
  final int companyId;
  final int level;
  final String status;
  final bool isSystem;

  Role({
    required this.roleId,
    required this.roleName,
    required this.roleCode,
    this.description,
    required this.companyId,
    required this.level,
    required this.status,
    this.isSystem = false,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      roleId: json['role_id'] ?? 0,
      roleName: json['role_name'] ?? '',
      roleCode: json['role_code'] ?? '',
      description: json['description'],
      companyId: json['company_id'] ?? 0,
      level: json['level'] ?? 50,
      status: json['status'] ?? 'active',
      isSystem: json['is_system'] == 1 || json['is_system'] == true,
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
}