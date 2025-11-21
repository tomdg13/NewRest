import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:http/http.dart' as http;
import 'package:Restaurant/business/BranchAddPage.dart';
import 'package:Restaurant/business/BranchEditPage.dart';
import 'package:Restaurant/config/company_config.dart';
import 'package:Restaurant/config/config.dart';
import 'package:Restaurant/config/theme.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class branchPage extends StatefulWidget {
  const branchPage({Key? key}) : super(key: key);

  @override
  State<branchPage> createState() => _branchPageState();
}

String langCode = 'en';

class _branchPageState extends State<branchPage> {
  List<Iobranch> branchs = [];
  List<Iobranch> filteredbranchs = [];
  bool loading = true;
  String? error;
  String currentTheme = ThemeConfig.defaultTheme;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('BranchPage initState() called');
    debugPrint('Language code: $langCode');

    _loadLangCode();
    _loadCurrentTheme();
    fetchbranchs();
    
    _searchController.addListener(() {
      print('Search query: ${_searchController.text}');
      filterbranchs(_searchController.text);
    });
  }

  void _loadLangCode() async {
    print('Loading language code...');
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        langCode = prefs.getString('languageCode') ?? 'en';
        print('Language code loaded: $langCode');
      });
    }
  }

  void _loadCurrentTheme() async {
    print('Loading current theme...');
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
        print('Theme loaded: $currentTheme');
      });
    }
  }

  @override
  void dispose() {
    print('BranchPage dispose() called');
    _searchController.dispose();
    super.dispose();
  }

  void filterbranchs(String query) {
    print('Filtering branches with query: "$query"');
    final lowerQuery = query.toLowerCase();
    if (mounted) {
      setState(() {
        filteredbranchs = branchs.where((branch) {
          final nameLower = branch.branchName.toLowerCase();
          final codeLower = branch.branchCode.toLowerCase();
          final provinceLower = (branch.provinceName ?? '').toLowerCase();
          
          bool matches = nameLower.contains(lowerQuery) || 
                        codeLower.contains(lowerQuery) ||
                        provinceLower.contains(lowerQuery);
          return matches;
        }).toList();
        print('Filtered branches count: ${filteredbranchs.length}');
      });
    }
  }

  Future<void> fetchbranchs() async {
    print('Starting fetchbranchs()');
    
    if (!mounted) {
      print('Widget not mounted, aborting fetchbranchs()');
      return;
    }
    
    setState(() {
      loading = true;
      error = null;
    });

    final url = AppConfig.api('/api/iobranch');
    print('API URL: $url');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      print('Token: ${token != null ? '${token.substring(0, 20)}...' : 'null'}');
      print('Company ID: $companyId');
      
      // Build query parameters
      final queryParams = {
        'status': 'admin', // Use admin to see all branches
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
            final List<dynamic> rawbranchs = data['data'] ?? [];
            print('Raw branches count: ${rawbranchs.length}');
            
            // Print first branch for debugging
            if (rawbranchs.isNotEmpty) {
              print('First branch data: ${rawbranchs[0]}');
            }
            
            branchs = rawbranchs.map((e) {
              try {
                return Iobranch.fromJson(e);
              } catch (parseError) {
                print('Error parsing branch: $parseError');
                print('Problem branch data: $e');
                rethrow;
              }
            }).toList();
            
            filteredbranchs = List.from(branchs);
            
            print('Total branches loaded: ${branchs.length}');
            print('Filtered branches: ${filteredbranchs.length}');
            
            if (mounted) {
              setState(() => loading = false);
            }
          } else {
            print('API returned error status: ${data['status']}');
            print('API error message: ${data['message']}');
            if (mounted) {
              setState(() {
                loading = false;
                error = data['message'] ?? 'Unknown error from API';
              });
            }
          }
        } catch (jsonError) {
          print('JSON parsing error: $jsonError');
          print('Raw response that failed to parse: ${response.body}');
          if (mounted) {
            setState(() {
              loading = false;
              error = 'Failed to parse server response: $jsonError';
            });
          }
        }
      } else {
        print('HTTP Error ${response.statusCode}');
        print('Error response body: ${response.body}');
        if (mounted) {
          setState(() {
            loading = false;
            error = 'Server error: ${response.statusCode}\n${response.body}';
          });
        }
      }
    } catch (e, stackTrace) {
      print('Exception caught: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Failed to load data: $e';
        });
      }
    }
  }

  void _onAddbranch() async {
    print('Add branch button pressed');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => branchAddPage()),
    );

    print('Add branch result: $result');
    if (result == true && mounted) {
      print('Refreshing branches after add');
      fetchbranchs();
    }
  }

  Widget _buildbranchImage(Iobranch branch) {
    print('Building image for branch: ${branch.branchName}');
    print('Image URL: ${branch.imageUrl}');
    
    // Check if we have a valid image URL
    if (branch.imageUrl == null || branch.imageUrl!.isEmpty) {
      print('No image URL, showing placeholder');
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[200],
        child: Icon(
          Icons.business,
          color: Colors.grey[600],
          size: 30,
        ),
      );
    }

    // Handle different image URL formats
    String imageUrl = branch.imageUrl!;
    
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
              print('Image loaded successfully for ${branch.branchName}');
              return child;
            }
            print('Loading image for ${branch.branchName}...');
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
            print('Error loading image for ${branch.branchName}: $error');
            print('Failed URL: $imageUrl');
            return Icon(
              Icons.business,
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
    print('Building BranchPage widget');
    print('Current state - loading: $loading, error: $error, branches: ${branchs.length}');
    
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
          title: Text('Branches'),
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
              Text('Loading Branches...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      print('Showing error state: $error');
      return Scaffold(
        appBar: AppBar(
          title: Text('Branches'),
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
                    'Error Loading Branches',
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
                      fetchbranchs();
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

    if (branchs.isEmpty) {
      print('Showing empty state');
      return Scaffold(
        appBar: AppBar(
          title: Text('Branches (0)'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          actions: [
            IconButton(
              onPressed: () {
                print('Refresh button pressed from empty state');
                fetchbranchs();
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
                Icon(Icons.business_outlined, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Branches found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _onAddbranch,
                  icon: Icon(Icons.add),
                  label: Text('Add First Branch'),
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
          onPressed: _onAddbranch,
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          tooltip: SimpleTranslations.get(langCode, 'add_branch'),
          child: const Icon(Icons.add),
        ),
      );
    }

    print('Rendering main branch list with ${filteredbranchs.length} branches');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${SimpleTranslations.get(langCode, 'branches')} (${filteredbranchs.length})'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          if (isWideScreen) ...[
            // Add button in app bar for wide screens
            IconButton(
              onPressed: _onAddbranch,
              icon: const Icon(Icons.add),
              tooltip: SimpleTranslations.get(langCode, 'add_branch'),
            ),
          ],
          IconButton(
            onPressed: () {
              print('Refresh button pressed from app bar');
              fetchbranchs();
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
                    hintText: 'Search by name, code, or province...',
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
                child: filteredbranchs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No Branches match your search'
                                  : 'No Branches found',
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
                        onRefresh: fetchbranchs,
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
        onPressed: _onAddbranch,
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        tooltip: SimpleTranslations.get(langCode, 'add_branch'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildListView(EdgeInsets cardMargin) {
    return ListView.builder(
      itemCount: filteredbranchs.length,
      itemBuilder: (ctx, i) {
        final branch = filteredbranchs[i];
        print('Building list item for branch: ${branch.branchName}');

        return Card(
          margin: cardMargin,
          elevation: 2,
          child: ListTile(
            leading: _buildbranchImage(branch),
            title: Text(
              branch.branchName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: _buildBranchSubtitle(branch),
            trailing: Icon(
              Icons.edit,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            isThreeLine: true,
            onTap: () => _navigateToEdit(branch),
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
        childAspectRatio: 2.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: filteredbranchs.length,
      itemBuilder: (ctx, i) {
        final branch = filteredbranchs[i];
        print('Building grid item for branch: ${branch.branchName}');

        return Card(
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _navigateToEdit(branch),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildbranchImage(branch),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          branch.branchName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        _buildBranchSubtitle(branch, compact: true),
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

  Widget _buildBranchSubtitle(Iobranch branch, {bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Code: ${branch.branchCode}',
          style: TextStyle(
            fontSize: compact ? 11 : 13,
            fontWeight: FontWeight.w500,
            color: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (!compact && branch.provinceName != null && branch.provinceName!.isNotEmpty)
          Text(
            'Province: ${branch.provinceName}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (!compact && branch.managerName != null && branch.managerName!.isNotEmpty)
          Text(
            'Manager: ${branch.managerName}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  void _navigateToEdit(Iobranch branch) async {
    print('Branch tapped: ${branch.branchName}');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BranchEditPage(
          branchData: branch.toJson(),
        ),
      ),
    );

    print('Edit Branch result: $result');
    if (result == true || result == 'deleted') {
      print('Branch operation completed, refreshing list...');
      fetchbranchs();
      
      if (result == 'deleted') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Branch removed from list'),
            backgroundColor: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

// Updated Iobranch model to match your io_branch table structure
class Iobranch {
  final int branchId;
  final int companyId;
  final String branchName;
  final String branchCode;
  final String? provinceName;
  final String? address;
  final String? phone;
  final String? email;
  final String? managerName;
  final String? branchImage;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  Iobranch({
    required this.branchId,
    required this.companyId,
    required this.branchName,
    required this.branchCode,
    this.provinceName,
    this.address,
    this.phone,
    this.email,
    this.managerName,
    this.branchImage,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });
  
  factory Iobranch.fromJson(Map<String, dynamic> json) {
    print('Converting JSON to Iobranch');
    print('JSON keys: ${json.keys.toList()}');
    print('JSON data: $json');
    
    try {
      final branch = Iobranch(
        branchId: json['branch_id'] ?? 0,
        companyId: CompanyConfig.getCompanyId(), // Use centralized config instead
        branchName: json['branch_name'] ?? '',
        branchCode: json['branch_code'] ?? '',
        provinceName: json['province_name'],
        address: json['address'],
        phone: json['phone'],
        email: json['email'],
        managerName: json['manager_name'],
        branchImage: json['branch_image'],
        imageUrl: json['image_url'],
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      );
      print('Successfully created Iobranch: ${branch.branchName} (${branch.branchCode})');
      return branch;
    } catch (e, stackTrace) {
      print('Error parsing Iobranch JSON: $e');
      print('Stack trace: $stackTrace');
      print('Problem JSON: $json');
      rethrow;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'branch_id': branchId,
      'company_id': companyId,
      'branch_name': branchName,
      'branch_code': branchCode,
      'province_name': provinceName,
      'address': address,
      'phone': phone,
      'email': email,
      'manager_name': managerName,
      'branch_image': branchImage,
      'image_url': imageUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}