import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/business/RoleAddPage.dart';
import 'package:inventory/business/RoleEditPage.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory/business/RolePermissionPage.dart';

class RoleListPage extends StatefulWidget {
  const RoleListPage({Key? key}) : super(key: key);

  @override
  State<RoleListPage> createState() => _RoleListPageState();
}

String langCode = 'en';

class _RoleListPageState extends State<RoleListPage> {
  List<IoRole> roles = [];
  List<IoRole> filteredRoles = [];
  bool loading = true;
  String? error;
  String currentTheme = ThemeConfig.defaultTheme;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('RoleListPage initState() called');
    debugPrint('Language code: $langCode');

    _loadLangCode();
    _loadCurrentTheme();
    fetchRoles();
    
    _searchController.addListener(() {
      print('Search query: ${_searchController.text}');
      filterRoles(_searchController.text);
    });
  }

  void _loadLangCode() async {
    print('Loading language code...');
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCode = prefs.getString('languageCode') ?? 'en';
      print('Language code loaded: $langCode');
    });
  }

  void _loadCurrentTheme() async {
    print('Loading current theme...');
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
      print('Theme loaded: $currentTheme');
    });
  }

  @override
  void dispose() {
    print('RoleListPage dispose() called');
    _searchController.dispose();
    super.dispose();
  }

  void filterRoles(String query) {
    print('Filtering roles with query: "$query"');
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredRoles = roles.where((role) {
        final nameLower = role.roleName.toLowerCase();
        final codeLower = role.roleCode?.toLowerCase() ?? '';
        final descLower = role.description?.toLowerCase() ?? '';
        bool matches = nameLower.contains(lowerQuery) || 
                      codeLower.contains(lowerQuery) || 
                      descLower.contains(lowerQuery);
        return matches;
      }).toList();
      print('Filtered roles count: ${filteredRoles.length}');
    });
  }

  Future<void> fetchRoles() async {
    print('Starting fetchRoles()');
    
    if (!mounted) {
      print('Widget not mounted, aborting fetchRoles()');
      return;
    }
    
    setState(() {
      loading = true;
      error = null;
    });

    final url = AppConfig.api('/api/iorole');
    print('API URL: $url');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      print('Token: ${token != null ? '${token.substring(0, 20)}...' : 'null'}');
      print('Company ID: $companyId');
      
      final queryParams = {
        if (companyId != null) 'company_id': companyId.toString(),
      };
      
      final uri = Uri.parse(url.toString()).replace(queryParameters: queryParams);
      print('Full URI: $uri');
      
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      print('Request headers: $headers');
      
      final response = await http.get(uri, headers: headers);

      print('Response Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');

      if (!mounted) {
        print('Widget not mounted after API call, aborting');
        return;
      }

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          print('Parsed JSON successfully');
          print('API Response structure: ${data.keys.toList()}');
          
          if (data['status'] == 'success') {
            final List<dynamic> rawRoles = data['data'] ?? [];
            print('Raw roles count: ${rawRoles.length}');
            
            if (rawRoles.isNotEmpty) {
              print('First role data: ${rawRoles[0]}');
            }
            
            roles = rawRoles.map((e) {
              try {
                return IoRole.fromJson(e);
              } catch (parseError) {
                print('Error parsing role: $parseError');
                print('Problem role data: $e');
                rethrow;
              }
            }).toList();
            
            filteredRoles = List.from(roles);
            
            print('Total roles loaded: ${roles.length}');
            print('Filtered roles: ${filteredRoles.length}');
            
            setState(() => loading = false);
          } else {
            print('API returned error status: ${data['status']}');
            print('API error message: ${data['message']}');
            setState(() {
              loading = false;
              error = data['message'] ?? 'Unknown error from API';
            });
          }
        } catch (jsonError) {
          print('JSON parsing error: $jsonError');
          print('Raw response that failed to parse: ${response.body}');
          setState(() {
            loading = false;
            error = 'Failed to parse server response: $jsonError';
          });
        }
      } else {
        print('HTTP Error ${response.statusCode}');
        print('Error response body: ${response.body}');
        setState(() {
          loading = false;
          error = 'Server error: ${response.statusCode}\n${response.body}';
        });
      }
    } catch (e, stackTrace) {
      print('Exception caught: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        loading = false;
        error = 'Failed to load data: $e';
      });
    }
  }

  void _onAddRole() async {
    print('Add Role button pressed');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RoleAddPage()),
    );

    print('Add Role result: $result');
    if (result == true) {
      print('Refreshing roles after add');
      fetchRoles();
    }
  }

  Color _getLevelColor(int level) {
    if (level >= 90) return Colors.purple;
    if (level >= 70) return Colors.blue;
    if (level >= 50) return Colors.green;
    if (level >= 30) return Colors.orange;
    return Colors.grey;
  }

  IconData _getLevelIcon(int level) {
    if (level >= 90) return Icons.stars;
    if (level >= 70) return Icons.workspace_premium;
    if (level >= 50) return Icons.verified;
    if (level >= 30) return Icons.badge;
    return Icons.person;
  }

  Widget _buildRoleIcon(IoRole role) {
    print('Building icon for role: ${role.roleName}');
    
    final levelColor = _getLevelColor(role.level);
    final levelIcon = _getLevelIcon(role.level);
    
    return CircleAvatar(
      radius: 25,
      backgroundColor: levelColor.withOpacity(0.1),
      child: Icon(
        levelIcon,
        color: levelColor,
        size: 30,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Building RoleListPage widget');
    print('Current state - loading: $loading, error: $error, roles: ${roles.length}');
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final horizontalPadding = isWideScreen ? 32.0 : 16.0;
    final cardMargin = isWideScreen ? 
        EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8) :
        EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    if (loading) {
      print('Showing loading indicator');
      return Scaffold(
        appBar: AppBar(
          title: Text('Roles'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  ThemeConfig.getPrimaryColor(currentTheme),
                ),
              ),
              SizedBox(height: 16),
              Text('Loading Roles...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      print('Showing error state: $error');
      return Scaffold(
        appBar: AppBar(
          title: Text('Roles'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        ),
        body: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: isWideScreen ? 600 : double.infinity),
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Error Loading Roles',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red,
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      print('Retry button pressed');
                      fetchRoles();
                    },
                    icon: Icon(Icons.refresh),
                    label: Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                      foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (roles.isEmpty) {
      print('Showing empty state');
      return Scaffold(
        appBar: AppBar(
          title: Text('Roles (0)'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          actions: [
            IconButton(
              onPressed: () {
                print('Refresh button pressed from empty state');
                fetchRoles();
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: isWideScreen ? 600 : double.infinity),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.work_off, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Roles found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _onAddRole,
                  icon: Icon(Icons.add),
                  label: Text('Add First Role'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                    foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: isWideScreen ? null : FloatingActionButton(
          onPressed: _onAddRole,
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          tooltip: 'Add Role',
          child: const Icon(Icons.add),
        ),
      );
    }

    print('Rendering main role list with ${filteredRoles.length} roles');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Roles (${filteredRoles.length})'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          if (isWideScreen) ...[
            IconButton(
              onPressed: _onAddRole,
              icon: const Icon(Icons.add),
              tooltip: 'Add Role',
            ),
          ],
          IconButton(
            onPressed: () {
              print('Refresh button pressed from app bar');
              fetchRoles();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isWideScreen ? 1200 : double.infinity),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search',
                    prefixIcon: Icon(
                      Icons.search,
                      color: ThemeConfig.getPrimaryColor(currentTheme),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              print('Clear search button pressed');
                              _searchController.clear();
                            },
                            icon: Icon(Icons.clear),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: ThemeConfig.getPrimaryColor(currentTheme),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: filteredRoles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No Roles match your search'
                                  : 'No Roles found',
                              style: const TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            if (_searchController.text.isNotEmpty) ...[
                              SizedBox(height: 8),
                              Text(
                                'Try a different search term',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: fetchRoles,
                        child: isWideScreen
                            ? _buildGridView(cardMargin)
                            : _buildListView(cardMargin),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: isWideScreen ? null : FloatingActionButton(
        onPressed: _onAddRole,
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        tooltip: 'Add Role',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildListView(EdgeInsets cardMargin) {
    return ListView.builder(
      itemCount: filteredRoles.length,
      itemBuilder: (ctx, i) {
        final role = filteredRoles[i];
        print('Building list item for role: ${role.roleName}');

        return Card(
          margin: cardMargin,
          elevation: 2,
          child: 
// Update the ListTile in the ListView.builder to include permission button:
ListTile(
  leading: CircleAvatar(
    backgroundColor: _getLevelColor(role.level).withOpacity(0.1),
    child: Icon(_getLevelIcon(role.level), color: _getLevelColor(role.level)),
  ),
  title: Row(
    children: [
      Expanded(child: Text(role.roleName, style: TextStyle(fontWeight: FontWeight.bold))),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _getLevelColor(role.level),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('Lvl ${role.level}', style: TextStyle(color: Colors.white, fontSize: 11)),
      ),
    ],
  ),
  subtitle: role.roleCode != null
      ? Text(role.roleCode!.toUpperCase(), style: TextStyle(fontSize: 12))
      : null,
  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: Icon(Icons.security, color: Colors.orange),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RolePermissionPage(roleData: role.toJson()),
            ),
          );
          if (result == true) fetchRoles();
        },
        tooltip: 'Manage Permissions',
      ),
      IconButton(
        icon: Icon(Icons.edit, color: ThemeConfig.getPrimaryColor(currentTheme)),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RoleEditPage(roleData: role.toJson())),
          );
          if (result == true || result == 'deleted') fetchRoles();
        },
        tooltip: 'Edit Role',
      ),
    ],
  ),
  onTap: () async {
    // Open permission page on tap
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RolePermissionPage(roleData: role.toJson()),
      ),
    );
    if (result == true) fetchRoles();
  },
)
        );
      },
    );
  }



  Widget _buildGridView(EdgeInsets cardMargin) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: cardMargin.horizontal / 2),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 2,
        childAspectRatio: 3.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: filteredRoles.length,
      itemBuilder: (ctx, i) {
        final role = filteredRoles[i];
        print('Building grid item for role: ${role.roleName}');

        return Card(
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _navigateToEdit(role),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildRoleIcon(role),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                role.roleName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getLevelColor(role.level),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Lvl ${role.level}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        _buildRoleSubtitle(role, compact: true),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.edit,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleSubtitle(IoRole role, {bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (role.roleCode != null && role.roleCode!.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              role.roleCode!.toUpperCase(),
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (!compact && role.description != null && role.description!.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              role.description!,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (!compact)
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Icon(
                  role.status == 'active' ? Icons.check_circle : Icons.pause_circle,
                  size: 12,
                  color: role.status == 'active' ? Colors.green : Colors.orange,
                ),
                SizedBox(width: 4),
                Text(
                  role.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: role.status == 'active' ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _navigateToEdit(IoRole role) async {
    print('Role tapped: ${role.roleName}');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoleEditPage(
          roleData: role.toJson(),
        ),
      ),
    );

    print('Edit Role result: $result');
    if (result == true || result == 'deleted') {
      print('Role operation completed, refreshing list...');
      fetchRoles();
      
      if (result == 'deleted') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role removed from list'),
            backgroundColor: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class IoRole {
  final int roleId;
  final String roleName;
  final String? roleCode;
  final String? description;
  final int level;
  final String status;
  final int? companyId;
  final String? createdAt;
  final String? updatedAt;
  
  IoRole({
    required this.roleId,
    required this.roleName,
    this.roleCode,
    this.description,
    required this.level,
    required this.status,
    this.companyId,
    this.createdAt,
    this.updatedAt,
  });
  
  factory IoRole.fromJson(Map<String, dynamic> json) {
    print('Converting JSON to IoRole');
    print('JSON keys: ${json.keys.toList()}');
    print('JSON data: $json');
    
    try {
      final role = IoRole(
        roleId: json['role_id'] ?? 0,
        roleName: json['role_name'] ?? '',
        roleCode: json['role_code'],
        description: json['description'],
        level: json['level'] ?? 0,
        status: json['status'] ?? 'active',
        companyId: json['company_id'],
        createdAt: json['created_at'],
        updatedAt: json['updated_at'],
      );
      print('Successfully created IoRole: ${role.roleName}');
      return role;
    } catch (e, stackTrace) {
      print('Error parsing IoRole JSON: $e');
      print('Stack trace: $stackTrace');
      print('Problem JSON: $json');
      rethrow;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'role_id': roleId,
      'role_name': roleName,
      'role_code': roleCode,
      'description': description,
      'level': level,
      'status': status,
      'company_id': companyId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}