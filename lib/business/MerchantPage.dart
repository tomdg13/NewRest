import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'MerchantAddPage.dart';
import 'MerchantEditPage.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MerchantPage extends StatefulWidget {
  const MerchantPage({Key? key}) : super(key: key);

  @override
  State<MerchantPage> createState() => _MerchantPageState();
}

String langCode = 'en';

class _MerchantPageState extends State<MerchantPage> {
  List<IoMerchant> merchants = [];
  List<IoMerchant> filteredMerchants = [];
  bool loading = true;
  String? error;
  String currentTheme = ThemeConfig.defaultTheme;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('MerchantPage initState() called');
    debugPrint('Language code: $langCode');

    _loadLangCode();
    _loadCurrentTheme();
    fetchMerchants();
    
    _searchController.addListener(() {
      print('Search query: ${_searchController.text}');
      filterMerchants(_searchController.text);
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
    print('MerchantPage dispose() called');
    _searchController.dispose();
    super.dispose();
  }

  void filterMerchants(String query) {
    print('Filtering merchants with query: "$query"');
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredMerchants = merchants.where((merchant) {
        final nameLower = merchant.merchantName.toLowerCase();
        final codeLower = merchant.merchantCode?.toLowerCase() ?? '';
        final phoneLower = merchant.phone?.toLowerCase() ?? '';
        bool matches = nameLower.contains(lowerQuery) || 
                      codeLower.contains(lowerQuery) || 
                      phoneLower.contains(lowerQuery);
        return matches;
      }).toList();
      print('Filtered merchants count: ${filteredMerchants.length}');
    });
  }

  Future<void> fetchMerchants() async {
    print('Starting fetchMerchants()');
    
    if (!mounted) {
      print('Widget not mounted, aborting fetchMerchants()');
      return;
    }
    
    setState(() {
      loading = true;
      error = null;
    });

    final url = AppConfig.api('/api/iomerchant');
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
            final List<dynamic> rawMerchants = data['data'] ?? [];
            print('Raw merchants count: ${rawMerchants.length}');
            
            // Print first merchant for debugging
            if (rawMerchants.isNotEmpty) {
              print('First merchant data: ${rawMerchants[0]}');
            }
            
            merchants = rawMerchants.map((e) {
              try {
                return IoMerchant.fromJson(e);
              } catch (parseError) {
                print('Error parsing merchant: $parseError');
                print('Problem merchant data: $e');
                rethrow;
              }
            }).toList();
            
            filteredMerchants = List.from(merchants);
            
            print('Total merchants loaded: ${merchants.length}');
            print('Filtered merchants: ${filteredMerchants.length}');
            
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

  void _onAddMerchant() async {
    print('Add Merchant button pressed');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MerchantAddPage()),
    );

    print('Add Merchant result: $result');
    if (result == true) {
      print('Refreshing merchants after add');
      fetchMerchants();
    }
  }

  Widget _buildMerchantImage(IoMerchant merchant) {
    print('Building image for merchant: ${merchant.merchantName}');
    print('Image URL: ${merchant.imageUrl}');
    
    // Check if we have a valid image URL
    if (merchant.imageUrl == null || merchant.imageUrl!.isEmpty) {
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
    String imageUrl = merchant.imageUrl!;
    
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
              print('Image loaded successfully for ${merchant.merchantName}');
              return child;
            }
            print('Loading image for ${merchant.merchantName}...');
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
            print('Error loading image for ${merchant.merchantName}: $error');
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
    print('Building MerchantPage widget');
    print('Current state - loading: $loading, error: $error, merchants: ${merchants.length}');
    
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
          title: Text('Merchants'),
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
              Text('Loading Merchants...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      print('Showing error state: $error');
      return Scaffold(
        appBar: AppBar(
          title: Text('Merchants'),
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
                    'Error Loading Merchants',
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
                      fetchMerchants();
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

    if (merchants.isEmpty) {
      print('Showing empty state');
      return Scaffold(
        appBar: AppBar(
          title: Text('Merchants (0)'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          actions: [
            IconButton(
              onPressed: () {
                print('Refresh button pressed from empty state');
                fetchMerchants();
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
                Icon(Icons.domain_add, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Merchants found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _onAddMerchant,
                  icon: Icon(Icons.add),
                  label: Text('Add First Merchant'),
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
          onPressed: _onAddMerchant,
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          tooltip: SimpleTranslations.get(langCode, 'add_Merchant'),
          child: const Icon(Icons.add),
        ),
      );
    }

    print('Rendering main merchant list with ${filteredMerchants.length} merchants');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${SimpleTranslations.get(langCode, 'Merchants')} (${filteredMerchants.length})'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          if (isWideScreen) ...[
            // Add button in app bar for wide screens
            IconButton(
              onPressed: _onAddMerchant,
              icon: const Icon(Icons.add),
              tooltip: SimpleTranslations.get(langCode, 'add_Merchant'),
            ),
          ],
          IconButton(
            onPressed: () {
              print('Refresh button pressed from app bar');
              fetchMerchants();
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
                child: filteredMerchants.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No Merchants match your search'
                                  : 'No Merchants found',
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
                        onRefresh: fetchMerchants,
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
        onPressed: _onAddMerchant,
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        tooltip: SimpleTranslations.get(langCode, 'add_Merchant'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildListView(EdgeInsets cardMargin) {
    return ListView.builder(
      itemCount: filteredMerchants.length,
      itemBuilder: (ctx, i) {
        final merchant = filteredMerchants[i];
        print('Building list item for merchant: ${merchant.merchantName}');

        return Card(
          margin: cardMargin,
          elevation: 2,
          child: ListTile(
            leading: _buildMerchantImage(merchant),
            title: Text(
              merchant.merchantName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: _buildMerchantSubtitle(merchant),
            trailing: Icon(
              Icons.edit,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            onTap: () => _navigateToEdit(merchant),
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
      itemCount: filteredMerchants.length,
      itemBuilder: (ctx, i) {
        final merchant = filteredMerchants[i];
        print('Building grid item for merchant: ${merchant.merchantName}');

        return Card(
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _navigateToEdit(merchant),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildMerchantImage(merchant),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          merchant.merchantName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        _buildMerchantSubtitle(merchant, compact: true),
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

  Widget _buildMerchantSubtitle(IoMerchant merchant, {bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (merchant.merchantCode != null && merchant.merchantCode!.isNotEmpty)
          Text(
            'Code: ${merchant.merchantCode}',
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w500,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (!compact && merchant.phone != null && merchant.phone!.isNotEmpty)
          Text(
            'Phone: ${merchant.phone}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (!compact)
          Text(
            'Company ID: ${merchant.companyId}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  void _navigateToEdit(IoMerchant merchant) async {
    print('Merchant tapped: ${merchant.merchantName}');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MerchantEditPage(
          MerchantData: merchant.toJson(),
        ),
      ),
    );

    print('Edit Merchant result: $result');
    if (result == true || result == 'deleted') {
      print('Merchant operation completed, refreshing list...');
      fetchMerchants();
      
      if (result == 'deleted') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Merchant removed from list'),
            backgroundColor: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

// Fixed IoMerchant model with proper create_by handling
class IoMerchant {
  final int merchantId;
  final int companyId;
  final String merchantName;
  final String? merchantCode;
  final String? phone;
  final String? imageUrl;
  final int? createBy;
  final String? createdDate;
  final String? updatedDate;
  
  IoMerchant({
    required this.merchantId,
    required this.companyId,
    required this.merchantName,
    this.merchantCode,
    this.phone,
    this.imageUrl,
    this.createBy,
    this.createdDate,
    this.updatedDate,
  });
  
  factory IoMerchant.fromJson(Map<String, dynamic> json) {
    print('Converting JSON to IoMerchant');
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

      final merchant = IoMerchant(
        merchantId: json['merchant_id'] ?? 0,
        companyId: json['company_id'] ?? CompanyConfig.getCompanyId(),
        merchantName: json['merchant_name'] ?? '',
        merchantCode: json['merchant_code'],
        phone: json['phone'],
        imageUrl: json['image_url'],
        createBy: parseCreateBy(json['create_by']), // Safe parsing for string/int conversion
        createdDate: json['created_date'],
        updatedDate: json['updated_date'],
      );
      print('Successfully created IoMerchant: ${merchant.merchantName}');
      return merchant;
    } catch (e, stackTrace) {
      print('Error parsing IoMerchant JSON: $e');
      print('Stack trace: $stackTrace');
      print('Problem JSON: $json');
      rethrow;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'merchant_id': merchantId,
      'company_id': companyId,
      'merchant_name': merchantName,
      'merchant_code': merchantCode,
      'phone': phone,
      'image_url': imageUrl,
      'create_by': createBy,
      'created_date': createdDate,
      'updated_date': updatedDate,
    };
  }
}