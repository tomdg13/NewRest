import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'CompanyAddPage.dart';
import 'CompanyEditPage.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompanyPage extends StatefulWidget {
  const CompanyPage({Key? key}) : super(key: key);

  @override
  State<CompanyPage> createState() => _CompanyPageState();
}

String langCode = 'en';

class _CompanyPageState extends State<CompanyPage> {
  List<IoCompany> companys = [];
  List<IoCompany> filteredCompanys = [];
  bool loading = true;
  String? error;
  String currentTheme = ThemeConfig.defaultTheme;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('CompanyPage initState() called');
    debugPrint('Language code: $langCode');

    _loadLangCode();
    _loadCurrentTheme();
    fetchCompanys();
    
    _searchController.addListener(() {
      print('Search query: ${_searchController.text}');
      filterCompanys(_searchController.text);
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
    print('CompanyPage dispose() called');
    _searchController.dispose();
    super.dispose();
  }

  void filterCompanys(String query) {
    print('Filtering companys with query: "$query"');
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredCompanys = companys.where((company) {
        final nameLower = company.companyName.toLowerCase();
        final codeLower = company.companyCode?.toLowerCase() ?? '';
        final phoneLower = company.phone?.toLowerCase() ?? '';
        bool matches = nameLower.contains(lowerQuery) || 
                      codeLower.contains(lowerQuery) || 
                      phoneLower.contains(lowerQuery);
        return matches;
      }).toList();
      print('Filtered companys count: ${filteredCompanys.length}');
    });
  }

  Future<void> fetchCompanys() async {
    print('Starting fetchCompanys()');
    
    if (!mounted) {
      print('Widget not mounted, aborting fetchCompanys()');
      return;
    }
    
    setState(() {
      loading = true;
      error = null;
    });

    final url = AppConfig.api('/api/iocompany');
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
            final List<dynamic> rawCompanys = data['data'] ?? [];
            print('Raw companys count: ${rawCompanys.length}');
            
            // Print first company for debugging
            if (rawCompanys.isNotEmpty) {
              print('First company data: ${rawCompanys[0]}');
            }
            
            companys = rawCompanys.map((e) {
              try {
                return IoCompany.fromJson(e);
              } catch (parseError) {
                print('Error parsing company: $parseError');
                print('Problem company data: $e');
                rethrow;
              }
            }).toList();
            
            filteredCompanys = List.from(companys);
            
            print('Total companys loaded: ${companys.length}');
            print('Filtered companys: ${filteredCompanys.length}');
            
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

  void _onAddCompany() async {
    print('Add Company button pressed');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CompanyAddPage()),
    );

    print('Add Company result: $result');
    if (result == true) {
      print('Refreshing companys after add');
      fetchCompanys();
    }
  }

  Widget _buildCompanyImage(IoCompany company) {
    print('Building image for company: ${company.companyName}');
    print('Image URL: ${company.imageUrl}');
    
    // Check if we have a valid image URL
    if (company.imageUrl == null || company.imageUrl!.isEmpty) {
      print('No image URL, showing placeholder');
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[200],
        child: Icon(
          Icons.grass,
          color: Colors.grey[600],
          size: 30,
        ),
      );
    }

    // Handle different image URL formats
    String imageUrl = company.imageUrl!;
    
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
              print('Image loaded successfully for ${company.companyName}');
              return child;
            }
            print('Loading image for ${company.companyName}...');
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
            print('Error loading image for ${company.companyName}: $error');
            print('Failed URL: $imageUrl');
            return Icon(
              Icons.grass,
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
    print('Building CompanyPage widget');
    print('Current state - loading: $loading, error: $error, companys: ${companys.length}');
    
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
          title: Text('Companys'),
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
              Text('Loading Companys...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      print('Showing error state: $error');
      return Scaffold(
        appBar: AppBar(
          title: Text('Companys'),
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
                    'Error Loading Companys',
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
                      fetchCompanys();
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

    if (companys.isEmpty) {
      print('Showing empty state');
      return Scaffold(
        appBar: AppBar(
          title: Text('Companys (0)'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          actions: [
            IconButton(
              onPressed: () {
                print('Refresh button pressed from empty state');
                fetchCompanys();
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
                Icon(Icons.grass, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Companys found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _onAddCompany,
                  icon: Icon(Icons.add),
                  label: Text('Add First Company'),
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
          onPressed: _onAddCompany,
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          tooltip: SimpleTranslations.get(langCode, 'add_Company'),
          child: const Icon(Icons.add),
        ),
      );
    }

    print('Rendering main company list with ${filteredCompanys.length} companys');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${SimpleTranslations.get(langCode, 'Companys')} (${filteredCompanys.length})'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          if (isWideScreen) ...[
            // Add button in app bar for wide screens
            IconButton(
              onPressed: _onAddCompany,
              icon: const Icon(Icons.add),
              tooltip: SimpleTranslations.get(langCode, 'add_Company'),
            ),
          ],
          IconButton(
            onPressed: () {
              print('Refresh button pressed from app bar');
              fetchCompanys();
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
                child: filteredCompanys.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No Companys match your search'
                                  : 'No Companys found',
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
                        onRefresh: fetchCompanys,
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
        onPressed: _onAddCompany,
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        tooltip: SimpleTranslations.get(langCode, 'add_Company'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildListView(EdgeInsets cardMargin) {
    return ListView.builder(
      itemCount: filteredCompanys.length,
      itemBuilder: (ctx, i) {
        final company = filteredCompanys[i];
        print('Building list item for company: ${company.companyName}');

        return Card(
          margin: cardMargin,
          elevation: 2,
          child: ListTile(
            leading: _buildCompanyImage(company),
            title: Text(
              company.companyName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: _buildCompanySubtitle(company),
            trailing: Icon(
              Icons.edit,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            onTap: () => _navigateToEdit(company),
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
      itemCount: filteredCompanys.length,
      itemBuilder: (ctx, i) {
        final company = filteredCompanys[i];
        print('Building grid item for company: ${company.companyName}');

        return Card(
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _navigateToEdit(company),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildCompanyImage(company),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          company.companyName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        _buildCompanySubtitle(company, compact: true),
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

  Widget _buildCompanySubtitle(IoCompany company, {bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (company.companyCode != null && company.companyCode!.isNotEmpty)
          Text(
            'Code: ${company.companyCode}',
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w500,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (!compact && company.phone != null && company.phone!.isNotEmpty)
          Text(
            'Phone: ${company.phone}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (!compact)
          Text(
            'Company ID: ${company.companyId}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  void _navigateToEdit(IoCompany company) async {
    print('Company tapped: ${company.companyName}');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyEditPage(
          CompanyData: company.toJson(),
        ),
      ),
    );

    print('Edit Company result: $result');
    if (result == true || result == 'deleted') {
      print('Company operation completed, refreshing list...');
      fetchCompanys();
      
      if (result == 'deleted') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Company removed from list'),
            backgroundColor: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

// Fixed IoCompany model with proper create_by handling
class IoCompany {
  final int companyId;
  final String companyName;
  final String? companyCode;
  final String? phone;
  final String? imageUrl;
  final int? createBy;
  final String? createdDate;
  final String? updatedDate;
  
  IoCompany({
    required this.companyId,
    required this.companyName,
    this.companyCode,
    this.phone,
    this.imageUrl,
    this.createBy,
    this.createdDate,
    this.updatedDate,
  });
  
  factory IoCompany.fromJson(Map<String, dynamic> json) {
    print('Converting JSON to IoCompany');
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

      final company = IoCompany(
      
        companyId: json['company_id'] ?? CompanyConfig.getCompanyId(),
        companyName: json['company_name'] ?? '',
        companyCode: json['company_code'],
        phone: json['phone'],
        imageUrl: json['logo_full_url'],
        createBy: parseCreateBy(json['create_by']), // Safe parsing for string/int conversion
        createdDate: json['created_date'],
        updatedDate: json['updated_date'],
      );
      print('Successfully created IoCompany: ${company.companyName}');
      return company;
    } catch (e, stackTrace) {
      print('Error parsing IoCompany JSON: $e');
      print('Stack trace: $stackTrace');
      print('Problem JSON: $json');
      rethrow;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'company_id': companyId,
      'company_name': companyName,
      'company_code': companyCode,
      'phone': phone,
      'logo_full_url': imageUrl,
      'create_by': createBy,
      'created_date': createdDate,
      'updated_date': updatedDate,
    };
  }
}