import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'GroupAddPage.dart';
import 'GroupEditPage.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupPage extends StatefulWidget {
  const GroupPage({Key? key}) : super(key: key);

  @override
  State<GroupPage> createState() => _GroupPageState();
}

String langCode = 'en';

class _GroupPageState extends State<GroupPage> {
  List<IoGroup> groups = [];
  List<IoGroup> filteredGroups = [];
  bool loading = true;
  String? error;
  String currentTheme = ThemeConfig.defaultTheme;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('GroupPage initState() called');
    debugPrint('Language code: $langCode');

    _loadLangCode();
    _loadCurrentTheme();
    fetchGroups();
    
    _searchController.addListener(() {
      print('Search query: ${_searchController.text}');
      filterGroups(_searchController.text);
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
    print('GroupPage dispose() called');
    _searchController.dispose();
    super.dispose();
  }

  void filterGroups(String query) {
    print('Filtering groups with query: "$query"');
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredGroups = groups.where((group) {
        final nameLower = group.groupName.toLowerCase();
        final codeLower = group.groupCode?.toLowerCase() ?? '';
        final phoneLower = group.phone?.toLowerCase() ?? '';
        final mobileLower = group.mobile?.toLowerCase() ?? '';
        bool matches = nameLower.contains(lowerQuery) || 
                      codeLower.contains(lowerQuery) || 
                      phoneLower.contains(lowerQuery) ||
                      mobileLower.contains(lowerQuery);
        return matches;
      }).toList();
      print('Filtered groups count: ${filteredGroups.length}');
    });
  }

  Future<void> fetchGroups() async {
    print('Starting fetchGroups()');
    
    if (!mounted) {
      print('Widget not mounted, aborting fetchGroups()');
      return;
    }
    
    setState(() {
      loading = true;
      error = null;
    });

    final url = AppConfig.api('/api/iogroup');
    print('API URL: $url');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      print('Token: ${token != null ? '${token.substring(0, 20)}...' : 'null'}');
      print('Company ID: $companyId');
      
      // Build query parameters
      final queryParams = {
        'company_id': companyId.toString(),
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
            final List<dynamic> rawGroups = data['data'] ?? [];
            print('Raw groups count: ${rawGroups.length}');
            
            // Print first group for debugging
            if (rawGroups.isNotEmpty) {
              print('First group data: ${rawGroups[0]}');
            }
            
            groups = rawGroups.map((e) {
              try {
                return IoGroup.fromJson(e);
              } catch (parseError) {
                print('Error parsing group: $parseError');
                print('Problem group data: $e');
                rethrow;
              }
            }).toList();
            
            filteredGroups = List.from(groups);
            
            print('Total groups loaded: ${groups.length}');
            print('Filtered groups: ${filteredGroups.length}');
            
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

  void _onAddGroup() async {
    print('Add Group button pressed');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GroupAddPage()),
    );

    print('Add Group result: $result');
    if (result == true) {
      print('Refreshing groups after add');
      fetchGroups();
    }
  }

  Widget _buildGroupImage(IoGroup group) {
    print('Building image for group: ${group.groupName}');
    print('Image URL: ${group.imageUrl}');
    
    // Check if we have a valid image URL
    if (group.imageUrl == null || group.imageUrl!.isEmpty) {
      print('No image URL, showing placeholder');
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[200],
        child: Icon(
          Icons.group,
          color: Colors.grey[600],
          size: 30,
        ),
      );
    }

    // Handle different image URL formats
    String imageUrl = group.imageUrl!;
    
    // If it's a relative URL, make it absolute
    if (!imageUrl.startsWith('http')) {
      // Get base URL from your config
      final baseUrl = AppConfig.api('').toString().replaceAll('/api', '');
      
      // Handle different path formats
      if (imageUrl.startsWith('/')) {
        imageUrl = '$baseUrl$imageUrl';
      } else {
        imageUrl = '$baseUrl/$imageUrl';
      }
    }
    
    print('Final image URL: $imageUrl');

    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              print('Image loaded successfully for ${group.groupName}');
              return child;
            }
            print('Loading image for ${group.groupName}...');
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Error loading image for ${group.groupName}: $error');
            print('Failed URL: $imageUrl');
            return Icon(
              Icons.group,
              color: Colors.grey[600],
              size: 30,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Building GroupPage widget');
    print('Current state - loading: $loading, error: $error, groups: ${groups.length}');
    
    // Get responsive dimensions
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
          title: Text('Groups'),
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
              Text('Loading Groups...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      print('Showing error state: $error');
      return Scaffold(
        appBar: AppBar(
          title: Text('Groups'),
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
                    'Error Loading Groups',
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
                      fetchGroups();
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

    if (groups.isEmpty) {
      print('Showing empty state');
      return Scaffold(
        appBar: AppBar(
          title: Text('Groups (0)'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          actions: [
            IconButton(
              onPressed: () {
                print('Refresh button pressed from empty state');
                fetchGroups();
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
                Icon(Icons.group_add, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Groups found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _onAddGroup,
                  icon: Icon(Icons.add),
                  label: Text('Add First Group'),
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
          onPressed: _onAddGroup,
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          tooltip: SimpleTranslations.get(langCode, 'add_Group'),
          child: const Icon(Icons.add),
        ),
      );
    }

    print('Rendering main group list with ${filteredGroups.length} groups');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${SimpleTranslations.get(langCode, 'Groups')} (${filteredGroups.length})'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          if (isWideScreen) ...[
            // Add button in app bar for wide screens
            IconButton(
              onPressed: _onAddGroup,
              icon: const Icon(Icons.add),
              tooltip: SimpleTranslations.get(langCode, 'add_Group'),
            ),
          ],
          IconButton(
            onPressed: () {
              print('Refresh button pressed from app bar');
              fetchGroups();
            },
            icon: const Icon(Icons.refresh),
            tooltip: SimpleTranslations.get(langCode, 'refresh'),
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
                    labelText: SimpleTranslations.get(langCode, 'search'),
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
                child: filteredGroups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No Groups match your search'
                                  : 'No Groups found',
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
                        onRefresh: fetchGroups,
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
        onPressed: _onAddGroup,
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        tooltip: SimpleTranslations.get(langCode, 'add_Group'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildListView(EdgeInsets cardMargin) {
    return ListView.builder(
      itemCount: filteredGroups.length,
      itemBuilder: (ctx, i) {
        final group = filteredGroups[i];
        print('Building list item for group: ${group.groupName}');

        return Card(
          margin: cardMargin,
          elevation: 2,
          child: ListTile(
            leading: _buildGroupImage(group),
            title: Text(
              group.groupName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: _buildGroupSubtitle(group),
            trailing: Icon(
              Icons.edit,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            onTap: () => _navigateToEdit(group),
          ),
        );
      },
    );
  }

  Widget _buildGridView(EdgeInsets cardMargin) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: cardMargin.horizontal / 2),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 2,
        childAspectRatio: 3.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: filteredGroups.length,
      itemBuilder: (ctx, i) {
        final group = filteredGroups[i];
        print('Building grid item for group: ${group.groupName}');

        return Card(
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _navigateToEdit(group),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildGroupImage(group),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          group.groupName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        _buildGroupSubtitle(group, compact: true),
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

  Widget _buildGroupSubtitle(IoGroup group, {bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (group.groupCode != null && group.groupCode!.isNotEmpty)
          Text(
            'Code: ${group.groupCode}',
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w500,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (!compact && group.mobile != null && group.mobile!.isNotEmpty)
          Row(
            children: [
              Icon(Icons.phone_android, size: 14, color: Colors.grey[600]),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  group.mobile!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (!compact)
          Text(
            'Company ID: ${group.companyId}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  void _navigateToEdit(IoGroup group) async {
    print('Group tapped: ${group.groupName}');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupEditPage(
          GroupData: group.toJson(),
        ),
      ),
    );

    print('Edit Group result: $result');
    if (result == true || result == 'deleted') {
      print('Group operation completed, refreshing list...');
      fetchGroups();
      
      if (result == 'deleted') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group removed from list'),
            backgroundColor: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

// Updated IoGroup model with mobile field
class IoGroup {
  final int groupId;
  final int companyId;
  final String groupName;
  final String? groupCode;
  final String? phone;
  final String? mobile; // NEW: Added mobile field
  final String? imageUrl;
  final int? createBy;
  final String? createdDate;
  final String? updatedDate;
  
  IoGroup({
    required this.groupId,
    required this.companyId,
    required this.groupName,
    this.groupCode,
    this.phone,
    this.mobile, // NEW: Added to constructor
    this.imageUrl,
    this.createBy,
    this.createdDate,
    this.updatedDate,
  });
  
  factory IoGroup.fromJson(Map<String, dynamic> json) {
    print('Converting JSON to IoGroup');
    print('JSON keys: ${json.keys.toList()}');
    print('JSON data: $json');
    
    try {
      // Helper function to safely parse create_by field
      int? parseCreateBy(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is String) {
          if (value.isEmpty || value.toLowerCase() == 'null') return null;
          return int.tryParse(value);
        }
        return null;
      }

      final group = IoGroup(
        groupId: json['group_id'] ?? 0,
        companyId: json['company_id'] ?? CompanyConfig.getCompanyId(),
        groupName: json['group_name'] ?? json['group'] ?? '',
        groupCode: json['group_code'],
        phone: json['phone'],
        mobile: json['mobile'] ?? json['mobile_number'], // NEW: Handle both field names
        imageUrl: json['image_url'],
        createBy: parseCreateBy(json['create_by']),
        createdDate: json['created_date'],
        updatedDate: json['updated_date'],
      );
      print('Successfully created IoGroup: ${group.groupName}');
      return group;
    } catch (e, stackTrace) {
      print('Error parsing IoGroup JSON: $e');
      print('Stack trace: $stackTrace');
      print('Problem JSON: $json');
      rethrow;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'company_id': companyId,
      'group': groupName, // Use 'group' for consistency with edit page
      'group_code': groupCode,
      'phone': phone,
      'mobile_number': mobile, // NEW: Added to JSON output
      'image_url': imageUrl,
      'create_by': createBy,
      'created_date': createdDate,
      'updated_date': updatedDate,
    };
  }
}