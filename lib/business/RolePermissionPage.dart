import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RolePermissionPage extends StatefulWidget {
  final Map<String, dynamic> roleData;

  const RolePermissionPage({Key? key, required this.roleData}) : super(key: key);

  @override
  State<RolePermissionPage> createState() => _RolePermissionPageState();
}

class _RolePermissionPageState extends State<RolePermissionPage> {
  List<ModulePermission> permissions = [];
  bool isLoading = true;
  String currentTheme = ThemeConfig.defaultTheme;
  bool hasChanges = false;

  // Access level options
  final List<AccessLevel> accessLevels = [
    AccessLevel('none', 'No Access', Icons.block, Colors.grey),
    AccessLevel('read_only', 'Read Only', Icons.visibility, Colors.blue),
    AccessLevel('write_only', 'Write Only', Icons.edit, Colors.orange),
    AccessLevel('read_write', 'Read & Write', Icons.edit_note, Colors.green),
    AccessLevel('approve_read', 'Approve & Read', Icons.check_circle, Colors.purple),
    AccessLevel('full_access', 'Full Access', Icons.admin_panel_settings, Colors.red),
  ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadPermissions();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  Future<void> _loadPermissions() async {
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final roleId = widget.roleData['role_id'];

      final response = await http.get(
        AppConfig.api('/api/permissions/role/$roleId'),
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
            permissions = permData.map((p) => ModulePermission.fromJson(p)).toList();
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading permissions: $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load permissions'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _savePermissions() async {
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final roleId = widget.roleData['role_id'];

      // Prepare permission data
      final permissionData = permissions.map((p) => {
        'permission_id': p.permissionId,
        'can_read': p.canRead,
        'can_write': p.canWrite,
        'can_approve': p.canApprove,
        'can_delete': p.canDelete,
        'access_level': p.accessLevel,
      }).toList();

      final response = await http.put(
        AppConfig.api('/api/permissions/role/$roleId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'permissions': permissionData}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() => hasChanges = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Permissions updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save permissions'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _updateAccessLevel(int index, String newLevel) {
    setState(() {
      permissions[index].setAccessLevel(newLevel);
      hasChanges = true;
    });
  }

  void _togglePermission(int index, String permissionType) {
    setState(() {
      final perm = permissions[index];
      switch (permissionType) {
        case 'read':
          perm.canRead = !perm.canRead;
          break;
        case 'write':
          perm.canWrite = !perm.canWrite;
          break;
        case 'approve':
          perm.canApprove = !perm.canApprove;
          break;
        case 'delete':
          perm.canDelete = !perm.canDelete;
          break;
      }
      perm.updateAccessLevel();
      hasChanges = true;
    });
  }

  Widget _buildAccessLevelChip(String currentLevel) {
    final level = accessLevels.firstWhere((l) => l.code == currentLevel,
        orElse: () => accessLevels[0]);
    
    return Chip(
      avatar: Icon(level.icon, size: 18, color: Colors.white),
      label: Text(level.name, style: TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: level.color,
    );
  }

  Widget _buildPermissionCard(ModulePermission permission, int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: Icon(Icons.folder, color: ThemeConfig.getPrimaryColor(currentTheme)),
        title: Text(
          permission.moduleName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: permission.description != null
            ? Text(permission.description!, style: TextStyle(fontSize: 12))
            : null,
        trailing: _buildAccessLevelChip(permission.accessLevel),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Quick Access Level Selector
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quick Set Access Level:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: accessLevels.map((level) {
                          final isSelected = permission.accessLevel == level.code;
                          return ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(level.icon, size: 16),
                                SizedBox(width: 4),
                                Text(level.name, style: TextStyle(fontSize: 12)),
                              ],
                            ),
                            selected: isSelected,
                            selectedColor: level.color.withOpacity(0.3),
                            onSelected: (selected) {
                              if (selected) {
                                _updateAccessLevel(index, level.code);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                // Individual Permission Toggles
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Individual Permissions:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: Text('Read', style: TextStyle(fontSize: 14)),
                              value: permission.canRead,
                              onChanged: (value) => _togglePermission(index, 'read'),
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: Text('Write', style: TextStyle(fontSize: 14)),
                              value: permission.canWrite,
                              onChanged: (value) => _togglePermission(index, 'write'),
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: Text('Approve', style: TextStyle(fontSize: 14)),
                              value: permission.canApprove,
                              onChanged: (value) => _togglePermission(index, 'approve'),
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: Text('Delete', style: TextStyle(fontSize: 14)),
                              value: permission.canDelete,
                              onChanged: (value) => _togglePermission(index, 'delete'),
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (hasChanges) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Unsaved Changes'),
              content: Text('You have unsaved changes. Do you want to discard them?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text('Discard'),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Permissions - ${widget.roleData['role_name']}'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          actions: [
            if (hasChanges)
              TextButton(
                onPressed: _savePermissions,
                child: Text('SAVE', style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(16),
                    color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: ThemeConfig.getPrimaryColor(currentTheme)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Configure permissions for ${widget.roleData['role_name']} role',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Permission List
                  Expanded(
                    child: ListView.builder(
                      itemCount: permissions.length,
                      itemBuilder: (context, index) {
                        return _buildPermissionCard(permissions[index], index);
                      },
                    ),
                  ),
                  // Save Button
                  if (hasChanges)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _savePermissions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text('SAVE PERMISSIONS', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

// Data Models
class ModulePermission {
  final int permissionId;
  final String moduleName;
  final String moduleCode;
  final String? description;
  bool canRead;
  bool canWrite;
  bool canApprove;
  bool canDelete;
  String accessLevel;

  ModulePermission({
    required this.permissionId,
    required this.moduleName,
    required this.moduleCode,
    this.description,
    this.canRead = false,
    this.canWrite = false,
    this.canApprove = false,
    this.canDelete = false,
    this.accessLevel = 'none',
  });

  factory ModulePermission.fromJson(Map<String, dynamic> json) {
    return ModulePermission(
      permissionId: json['permission_id'],
      moduleName: json['module_name'],
      moduleCode: json['module_code'],
      description: json['description'],
      canRead: json['can_read'] == 1 || json['can_read'] == true,
      canWrite: json['can_write'] == 1 || json['can_write'] == true,
      canApprove: json['can_approve'] == 1 || json['can_approve'] == true,
      canDelete: json['can_delete'] == 1 || json['can_delete'] == true,
      accessLevel: json['access_level'] ?? 'none',
    );
  }

  void setAccessLevel(String level) {
    accessLevel = level;
    switch (level) {
      case 'full_access':
        canRead = true;
        canWrite = true;
        canApprove = true;
        canDelete = true;
        break;
      case 'approve_read':
        canRead = true;
        canWrite = false;
        canApprove = true;
        canDelete = false;
        break;
      case 'read_write':
        canRead = true;
        canWrite = true;
        canApprove = false;
        canDelete = false;
        break;
      case 'read_only':
        canRead = true;
        canWrite = false;
        canApprove = false;
        canDelete = false;
        break;
      case 'write_only':
        canRead = false;
        canWrite = true;
        canApprove = false;
        canDelete = false;
        break;
      default: // 'none'
        canRead = false;
        canWrite = false;
        canApprove = false;
        canDelete = false;
    }
  }

  void updateAccessLevel() {
    if (canDelete && canApprove && canWrite && canRead) {
      accessLevel = 'full_access';
    } else if (canApprove && canRead && !canWrite && !canDelete) {
      accessLevel = 'approve_read';
    } else if (canRead && canWrite && !canApprove && !canDelete) {
      accessLevel = 'read_write';
    } else if (canRead && !canWrite && !canApprove && !canDelete) {
      accessLevel = 'read_only';
    } else if (canWrite && !canRead && !canApprove && !canDelete) {
      accessLevel = 'write_only';
    } else {
      accessLevel = 'none';
    }
  }
}

class AccessLevel {
  final String code;
  final String name;
  final IconData icon;
  final Color color;

  AccessLevel(this.code, this.name, this.icon, this.color);
}