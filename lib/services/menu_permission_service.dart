// menu_permission_service.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config/config.dart';

class MenuPermissionService {
  static final MenuPermissionService _instance = MenuPermissionService._internal();
  factory MenuPermissionService() => _instance;
  MenuPermissionService._internal();

  Map<String, bool> _cachedPermissions = {};
  DateTime? _lastFetch;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  // Menu permission codes mapping
  static const Map<String, String> menuPermissionCodes = {
    // Home Menu Items
    'Store': 'store_reports',
    'Approve': 'approval_management',
    'Terminal': 'terminal_view',
    'expiry': 'expiry_management',
    'stock': 'stock_management',
    'location': 'location_view',
    'product': 'product_view',
    'Settle': 'settlement_view',
    
    // Settings Menu Items
    'group': 'group_management',
    'merchant': 'merchant_management',
    'store': 'store_management',
    'terminal': 'terminal_management',
    'branch': 'branch_management',
    'location_settings': 'location_management',
    'vendor': 'vendor_management',
    'product_settings': 'product_management',
    'uploadSettle': 'settlement_upload',
    'uploadCSV': 'csv_upload',
    'User': 'user_management',
    'Role': 'role_management',
    'Permission': 'permission_management',
    'Role Permission Map': 'role_permission_mapping',
    'Company': 'company_management',
  };

  // Check if cache is still valid
  bool _isCacheValid() {
    if (_lastFetch == null) return false;
    return DateTime.now().difference(_lastFetch!) < _cacheValidDuration;
  }

  // Load permissions from server
  Future<void> loadUserPermissions({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid()) {
      return; // Use cached permissions
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final userId = prefs.getInt('user_id') ?? prefs.getString('user_id');

      if (token == null || userId == null) {
        print('No authentication token or user ID found');
        return;
      }

      final response = await http.get(
        AppConfig.api('/api/permissions/my-permissions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          _processPermissions(data['data']);
          _lastFetch = DateTime.now();
          await _savePermissionsToCache(data['data']);
        }
      } else {
        print('Failed to load permissions: ${response.statusCode}');
        await _loadPermissionsFromCache();
      }
    } catch (e) {
      print('Error loading permissions: $e');
      await _loadPermissionsFromCache();
    }
  }

  // Process permissions from API response
  void _processPermissions(List<dynamic> permissions) {
    _cachedPermissions.clear();
    
    for (var permission in permissions) {
      final moduleCode = permission['module_code']?.toString() ?? '';
      final canRead = permission['can_read'] == true || permission['can_read'] == 1;
      
      // Store permission state
      _cachedPermissions[moduleCode] = canRead;
    }

    print('Loaded ${_cachedPermissions.length} permissions');
  }

  // Save permissions to local cache
  Future<void> _savePermissionsToCache(List<dynamic> permissions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final permissionsJson = jsonEncode(permissions);
      await prefs.setString('cached_permissions', permissionsJson);
      await prefs.setString('permissions_cache_time', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error saving permissions to cache: $e');
    }
  }

  // Load permissions from local cache
  Future<void> _loadPermissionsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final permissionsJson = prefs.getString('cached_permissions');
      final cacheTimeStr = prefs.getString('permissions_cache_time');

      if (permissionsJson != null && cacheTimeStr != null) {
        final cacheTime = DateTime.parse(cacheTimeStr);
        if (DateTime.now().difference(cacheTime) < Duration(hours: 24)) {
          final permissions = jsonDecode(permissionsJson) as List;
          _processPermissions(permissions);
          _lastFetch = cacheTime;
        }
      }
    } catch (e) {
      print('Error loading permissions from cache: $e');
    }
  }

  // Check if user has permission for a menu item
  bool hasPermission(String menuKey) {
    // Get the permission code for this menu key
    final permissionCode = menuPermissionCodes[menuKey];
    
    if (permissionCode == null) {
      // If no permission code is defined, allow access
      return true;
    }

    // Check if user has permission
    return _cachedPermissions[permissionCode] ?? false;
  }

  // Check multiple permissions
  bool hasAnyPermission(List<String> menuKeys) {
    for (String key in menuKeys) {
      if (hasPermission(key)) return true;
    }
    return false;
  }

  // Check if user has all permissions
  bool hasAllPermissions(List<String> menuKeys) {
    for (String key in menuKeys) {
      if (!hasPermission(key)) return false;
    }
    return true;
  }

  // Clear cached permissions
  void clearCache() {
    _cachedPermissions.clear();
    _lastFetch = null;
  }

  // Get all user permissions
  Map<String, bool> getAllPermissions() {
    return Map.from(_cachedPermissions);
  }

  // Check if user is super admin (has all permissions)
  Future<bool> isSuperAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    final roleCode = prefs.getString('user_role_code');
    return roleCode == 'super_admin';
  }
}

// Widget for permission-based visibility
class PermissionVisibility extends StatelessWidget {
  final String permissionKey;
  final Widget child;
  final Widget? placeholder;

  const PermissionVisibility({
    Key? key,
    required this.permissionKey,
    required this.child,
    this.placeholder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasPermission = MenuPermissionService().hasPermission(permissionKey);
    
    if (hasPermission) {
      return child;
    }
    
    return placeholder ?? const SizedBox.shrink();
  }
}

// Menu Item Model with Permission
class MenuItem {
  final IconData icon;
  final String title;
  final String permissionKey;
  final Color color;
  final VoidCallback onTap;
  final bool requiresPermission;

  MenuItem({
    required this.icon,
    required this.title,
    required this.permissionKey,
    required this.color,
    required this.onTap,
    this.requiresPermission = true,
  });

  bool get isVisible {
    if (!requiresPermission) return true;
    return MenuPermissionService().hasPermission(permissionKey);
  }
}