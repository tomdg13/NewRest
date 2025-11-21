import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:http/http.dart' as http;
import 'package:inventory/business/vendorAddPage.dart';
import 'package:inventory/business/vendorEditPage.dart';
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VendorPage extends StatefulWidget {
  const VendorPage({Key? key}) : super(key: key);

  @override
  State<VendorPage> createState() => _VendorPageState();
}

String langCode = 'en';

class _VendorPageState extends State<VendorPage> {
  List<IoVendor> vendors = [];
  List<IoVendor> filteredVendors = [];
  bool loading = true;
  String? error;
  String currentTheme = ThemeConfig.defaultTheme;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('VendorPage initState() called');
    debugPrint('Language code: $langCode');

    _loadLangCode();
    _loadCurrentTheme();
    fetchVendors();
    
    _searchController.addListener(() {
      print('Search query: ${_searchController.text}');
      filterVendors(_searchController.text);
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
    print('VendorPage dispose() called');
    _searchController.dispose();
    super.dispose();
  }

  void filterVendors(String query) {
    print('Filtering vendors with query: "$query"');
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredVendors = vendors.where((vendor) {
        final nameLower = vendor.vendorName.toLowerCase();
        final codeLower = vendor.vendorCode.toLowerCase();
        final provinceLower = (vendor.provinceName ?? '').toLowerCase();
        final managerLower = (vendor.managerName ?? '').toLowerCase();
        
        bool matches = nameLower.contains(lowerQuery) || 
                      codeLower.contains(lowerQuery) ||
                      provinceLower.contains(lowerQuery) ||
                      managerLower.contains(lowerQuery);
        return matches;
      }).toList();
      print('Filtered vendors count: ${filteredVendors.length}');
    });
  }

  Future<void> fetchVendors() async {
    print('Starting fetchVendors()');
    
    if (!mounted) {
      print('Widget not mounted, aborting fetchVendors()');
      return;
    }
    
    setState(() {
      loading = true;
      error = null;
    });

    final url = AppConfig.api('/api/iovendor');
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
            final List<dynamic> rawVendors = data['data'] ?? [];
            print('Raw vendors count: ${rawVendors.length}');
            
            // Print first vendor for debugging
            if (rawVendors.isNotEmpty) {
              print('First vendor data: ${rawVendors[0]}');
            }
            
            vendors = rawVendors.map((e) {
              try {
                return IoVendor.fromJson(e);
              } catch (parseError) {
                print('Error parsing vendor: $parseError');
                print('Problem vendor data: $e');
                rethrow;
              }
            }).toList();
            
            filteredVendors = List.from(vendors);
            
            print('Total vendors loaded: ${vendors.length}');
            print('Filtered vendors: ${filteredVendors.length}');
            
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

  void _onAddVendor() async {
    print('Add Vendor button pressed');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VendorAddPage()),
    );

    print('Add Vendor result: $result');
    if (result == true) {
      print('Refreshing vendors after add');
      fetchVendors();
    }
  }

  Widget _buildVendorImage(IoVendor vendor) {
    print('Building image for vendor: ${vendor.vendorName}');
    print('Image URL: ${vendor.imageUrl}');
    
    // Check if we have a valid image URL
    if (vendor.imageUrl == null || vendor.imageUrl!.isEmpty) {
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
    String imageUrl = vendor.imageUrl!;
    
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
              print('Image loaded successfully for ${vendor.vendorName}');
              return child;
            }
            print('Loading image for ${vendor.vendorName}...');
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
            print('Error loading image for ${vendor.vendorName}: $error');
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
    print('Building VendorPage widget');
    print('Current state - loading: $loading, error: $error, vendors: ${vendors.length}');
    
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
          title: Text('Vendors'),
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
              Text('Loading Vendors...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      print('Showing error state: $error');
      return Scaffold(
        appBar: AppBar(
          title: Text('Vendors'),
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
                    'Error Loading Vendors',
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
                      fetchVendors();
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

    if (vendors.isEmpty) {
      print('Showing empty state');
      return Scaffold(
        appBar: AppBar(
          title: Text('Vendors (0)'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          actions: [
            IconButton(
              onPressed: () {
                print('Refresh button pressed from empty state');
                fetchVendors();
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
                  'No Vendors found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _onAddVendor,
                  icon: Icon(Icons.add),
                  label: Text('Add First Vendor'),
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
          onPressed: _onAddVendor,
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          tooltip: SimpleTranslations.get(langCode, 'add_Vendor'),
          child: const Icon(Icons.add),
        ),
      );
    }

    print('Rendering main vendor list with ${filteredVendors.length} vendors');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${SimpleTranslations.get(langCode, 'Vendors')} (${filteredVendors.length})'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          if (isWideScreen) ...[
            // Add button in app bar for wide screens
            IconButton(
              onPressed: _onAddVendor,
              icon: const Icon(Icons.add),
              tooltip: SimpleTranslations.get(langCode, 'add_Vendor'),
            ),
          ],
          IconButton(
            onPressed: () {
              print('Refresh button pressed from app bar');
              fetchVendors();
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
                    hintText: 'Search by name, code, province, or manager...',
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
                child: filteredVendors.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No Vendors match your search'
                                  : 'No Vendors found',
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
                        onRefresh: fetchVendors,
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
        onPressed: _onAddVendor,
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        tooltip: SimpleTranslations.get(langCode, 'add_Vendor'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildListView(EdgeInsets cardMargin) {
    return ListView.builder(
      itemCount: filteredVendors.length,
      itemBuilder: (ctx, i) {
        final vendor = filteredVendors[i];
        print('Building list item for vendor: ${vendor.vendorName}');

        return Card(
          margin: cardMargin,
          elevation: 2,
          child: ListTile(
            leading: _buildVendorImage(vendor),
            title: Text(
              vendor.vendorName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: _buildVendorSubtitle(vendor),
            trailing: Icon(
              Icons.edit,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            isThreeLine: true,
            onTap: () => _navigateToEdit(vendor),
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
        childAspectRatio: 3.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: filteredVendors.length,
      itemBuilder: (ctx, i) {
        final vendor = filteredVendors[i];
        print('Building grid item for vendor: ${vendor.vendorName}');

        return Card(
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _navigateToEdit(vendor),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildVendorImage(vendor),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          vendor.vendorName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        _buildVendorSubtitle(vendor, compact: true),
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

  Widget _buildVendorSubtitle(IoVendor vendor, {bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Code: ${vendor.vendorCode}',
          style: TextStyle(
            fontSize: compact ? 11 : 13,
            fontWeight: FontWeight.w500,
            color: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (!compact && vendor.provinceName != null && vendor.provinceName!.isNotEmpty)
          Text(
            'Province: ${vendor.provinceName}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (!compact && vendor.managerName != null && vendor.managerName!.isNotEmpty)
          Text(
            'Manager: ${vendor.managerName}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (compact && vendor.provinceName != null && vendor.provinceName!.isNotEmpty)
          Text(
            vendor.provinceName!,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  void _navigateToEdit(IoVendor vendor) async {
    print('Vendor tapped: ${vendor.vendorName}');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VendorEditPage(
          vendorData: vendor.toJson(),
        ),
      ),
    );

    print('Edit Vendor result: $result');
    if (result == true || result == 'deleted') {
      print('Vendor operation completed, refreshing list...');
      fetchVendors();
      
      if (result == 'deleted') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vendor removed from list'),
            backgroundColor: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

// Updated IoVendor model to match your io_vendor table structure
class IoVendor {
  final int vendorId;
  final int companyId;
  final String vendorName;
  final String vendorCode;
  final String? provinceName;
  final String? address;
  final String? phone;
  final String? email;
  final String? managerName;
  final String? vendorImage;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  IoVendor({
    required this.vendorId,
    required this.companyId,
    required this.vendorName,
    required this.vendorCode,
    this.provinceName,
    this.address,
    this.phone,
    this.email,
    this.managerName,
    this.vendorImage,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });
  
  factory IoVendor.fromJson(Map<String, dynamic> json) {
    print('Converting JSON to IoVendor');
    print('JSON keys: ${json.keys.toList()}');
    print('JSON data: $json');
    
    try {
      final vendor = IoVendor(
        vendorId: json['vendor_id'] ?? 0,
        companyId: json['company_id'] ?? CompanyConfig.getCompanyId(),
        vendorName: json['vendor_name'] ?? '',
        vendorCode: json['vendor_code'] ?? '',
        provinceName: json['province_name'],
        address: json['address'],
        phone: json['phone'],
        email: json['email'],
        managerName: json['manager_name'],
        vendorImage: json['vendor_image'],
        imageUrl: json['image_url'],
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      );
      print('Successfully created IoVendor: ${vendor.vendorName} (${vendor.vendorCode})');
      return vendor;
    } catch (e, stackTrace) {
      print('Error parsing IoVendor JSON: $e');
      print('Stack trace: $stackTrace');
      print('Problem JSON: $json');
      rethrow;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'vendor_id': vendorId,
      'company_id': companyId,
      'vendor_name': vendorName,
      'vendor_code': vendorCode,
      'province_name': provinceName,
      'address': address,
      'phone': phone,
      'email': email,
      'manager_name': managerName,
      'vendor_image': vendorImage,
      'image_url': imageUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}