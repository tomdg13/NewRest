import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:http/http.dart' as http;
import 'package:inventory/business/StoreAddPage.dart';
import 'package:inventory/business/StoreEditPage.dart';
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorePage extends StatefulWidget {
  const StorePage({Key? key}) : super(key: key);

  @override
  State<StorePage> createState() => _StorePageState();
}

String langCode = 'en';

class _StorePageState extends State<StorePage> {
  List<Iostore> stores = [];
  List<Iostore> filteredstores = [];
  bool loading = true;
  String? error;
  String currentTheme = ThemeConfig.defaultTheme;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('StorePage initState() called');
    debugPrint('Language code: $langCode');

    _loadLangCode();
    _loadCurrentTheme();
    fetchstores();
    
    _searchController.addListener(() {
      print('Search query: ${_searchController.text}');
      filterstores(_searchController.text);
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
    print('StorePage dispose() called');
    _searchController.dispose();
    super.dispose();
  }

  void filterstores(String query) {
    print('Filtering stores with query: "$query"');
    final lowerQuery = query.toLowerCase();
    if (mounted) {
      setState(() {
        filteredstores = stores.where((store) {
          final nameLower = store.storeName.toLowerCase();
          bool matches = nameLower.contains(lowerQuery);
          return matches;
        }).toList();
        print('Filtered stores count: ${filteredstores.length}');
      });
    }
  }

  Future<void> fetchstores() async {
    print('Starting fetchstores()');
    
    if (!mounted) {
      print('Widget not mounted, aborting fetchstores()');
      return;
    }
    
    setState(() {
      loading = true;
      error = null;
    });

    final url = AppConfig.api('/api/iostore');
    print('API URL: $url');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      print('Token: ${token != null ? '${token.substring(0, 20)}...' : 'null'}');
      print('Company ID: $companyId');
      
      // Build query parameters
      final queryParams = {
        'status': 'admin', // Use admin to see all stores
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
            final List<dynamic> rawstores = data['data'] ?? [];
            print('Raw stores count: ${rawstores.length}');
            
            // Print first store for debugging
            if (rawstores.isNotEmpty) {
              print('First store data: ${rawstores[0]}');
            }
            
            stores = rawstores.map((e) {
              try {
                return Iostore.fromJson(e);
              } catch (parseError) {
                print('Error parsing store: $parseError');
                print('Problem store data: $e');
                rethrow;
              }
            }).toList();
            
            // Client-side sorting as fallback (in case backend doesn't support ordering)
            stores.sort((a, b) => b.storeId.compareTo(a.storeId));
            
            filteredstores = List.from(stores);
            
            print('Total stores loaded: ${stores.length}');
            print('Filtered stores: ${filteredstores.length}');
            
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

  void _onAddstore() async {
    print('Add store button pressed');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StoreAddPage()),
    );

    print('Add store result: $result');
    if (result == true && mounted) {
      print('Refreshing stores after add');
      fetchstores();
    }
  }

  Widget _buildstoreImage(Iostore store) {
    print('Building image for store: ${store.storeName}');
    print('Image URL: ${store.imageUrl}');
    
    // Check if we have a valid image URL
    if (store.imageUrl == null || store.imageUrl!.isEmpty) {
      print('No image URL, showing placeholder');
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[200],
        child: Icon(
          Icons.store,
          color: Colors.grey[600],
          size: 30,
        ),
      );
    }

    // Handle different image URL formats
    String imageUrl = store.imageUrl!;
    
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
              print('Image loaded successfully for ${store.storeName}');
              return child;
            }
            print('Loading image for ${store.storeName}...');
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
            print('Error loading image for ${store.storeName}: $error');
            print('Failed URL: $imageUrl');
            return Icon(
              Icons.store,
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
    print('Building StorePage widget');
    print('Current state - loading: $loading, error: $error, stores: ${stores.length}');
    
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
          title: Text('Stores'),
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
              Text('Loading Stores...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      print('Showing error state: $error');
      return Scaffold(
        appBar: AppBar(
          title: Text('Stores'),
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
                    'Error Loading Stores',
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
                      fetchstores();
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

    if (stores.isEmpty) {
      print('Showing empty state');
      return Scaffold(
        appBar: AppBar(
          title: Text('Stores (0)'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          actions: [
            IconButton(
              onPressed: () {
                print('Refresh button pressed from empty state');
                fetchstores();
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
                Icon(Icons.store, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Stores found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _onAddstore,
                  icon: Icon(Icons.add),
                  label: Text('Add First Store'),
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
          onPressed: _onAddstore,
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          tooltip: SimpleTranslations.get(langCode, 'add_store'),
          child: const Icon(Icons.add),
        ),
      );
    }

    print('Rendering main store list with ${filteredstores.length} stores');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${SimpleTranslations.get(langCode, 'stores')} (${filteredstores.length})'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          if (isWideScreen) ...[
            // Add button in app bar for wide screens
            IconButton(
              onPressed: _onAddstore,
              icon: const Icon(Icons.add),
              tooltip: SimpleTranslations.get(langCode, 'add_store'),
            ),
          ],
          IconButton(
            onPressed: () {
              print('Refresh button pressed from app bar');
              fetchstores();
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
              // Warning banner for stores without approvers
              _buildApprovalWarningBanner(),
              
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
                child: filteredstores.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No Stores match your search'
                                  : 'No Stores found',
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
                        onRefresh: fetchstores,
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
        onPressed: _onAddstore,
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        tooltip: SimpleTranslations.get(langCode, 'add_store'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildListView(EdgeInsets cardMargin) {
    return ListView.builder(
      itemCount: filteredstores.length,
      itemBuilder: (ctx, i) {
        final store = filteredstores[i];
        print('Building list item for store: ${store.storeName}');

        return Card(
          margin: cardMargin,
          elevation: 2,
          child: ListTile(
            leading: _buildstoreImage(store),
            title: Text(
              store.storeName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: _buildStoreSubtitle(store),
            trailing: Icon(
              Icons.edit,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            onTap: () => _navigateToEdit(store),
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
      itemCount: filteredstores.length,
      itemBuilder: (ctx, i) {
        final store = filteredstores[i];
        print('Building grid item for store: ${store.storeName}');

        return Card(
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _navigateToEdit(store),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildstoreImage(store),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          store.storeName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        _buildStoreSubtitle(store, compact: true),
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

  Widget _buildApprovalWarningBanner() {
    // Count stores without approvers
    final storesNeedingApproval = filteredstores.where(
      (store) => store.approve1 == null && store.approve2 == null
    ).length;

    if (storesNeedingApproval == 0) {
      return SizedBox.shrink(); // Don't show banner if all stores have approvers
    }

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange[700],
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Approval Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '$storesNeedingApproval store${storesNeedingApproval > 1 ? 's' : ''} without approvers assigned',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSubtitle(Iostore store, {bool compact = false}) {
    bool hasApprovers = store.approve1 != null || store.approve2 != null;
    int approverCount = (store.approve1 != null ? 1 : 0) + (store.approve2 != null ? 1 : 0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Code: ${store.storeCode}',
          style: TextStyle(
            fontSize: compact ? 11 : 13,
            fontWeight: FontWeight.w500,
            color: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (!compact)
          Text(
            'Company ID: ${store.companyId}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        SizedBox(height: 4),
        if (hasApprovers)
          Row(
            children: [
              Icon(
                Icons.verified_user,
                size: compact ? 12 : 14,
                color: Colors.green,
              ),
              SizedBox(width: 4),
              Text(
                '$approverCount Approver${approverCount > 1 ? 's' : ''} assigned',
                style: TextStyle(
                  fontSize: compact ? 10 : 12,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: compact ? 12 : 14,
                color: Colors.orange[700],
              ),
              SizedBox(width: 4),
              Text(
                'No approvers assigned',
                style: TextStyle(
                  fontSize: compact ? 10 : 12,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _navigateToEdit(Iostore store) async {
    print('Store tapped: ${store.storeName}');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreEditPage(
          storeData: store.toJson(),
        ),
      ),
    );

    print('Edit Store result: $result');
    if (result == true || result == 'deleted') {
      print('Store operation completed, refreshing list...');
      fetchstores();
      
      if (result == 'deleted') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Store removed from list'),
            backgroundColor: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class Iostore {
  final int storeId;
  final int companyId;
  final String storeName;
  final String storeCode;
  final String? imageUrl;
  final String? storeManager;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final String? storeType;
  final String? status;
  final String? openingHours;
  final double? squareFootage;
  final String? notes;
  final double? upiPercentage;
  final double? visaPercentage;
  final double? masterPercentage;
  final String? account;
  final String? account2;
  final String? accountName;
  final String? storeMode;
  final String? web;
  final String? email1;
  final String? email2;
  final String? email3;
  final String? email4;
  final String? email5;
  final String? mcc;
  final String? cif;
  final int? approve1;  // User ID for first approver
  final int? approve2;  // User ID for second approver
  
  Iostore({
    required this.storeId,
    required this.companyId,
    required this.storeName,
    required this.storeCode,
    this.imageUrl,
    this.storeManager,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.storeType,
    this.status,
    this.openingHours,
    this.squareFootage,
    this.notes,
    this.upiPercentage,
    this.visaPercentage,
    this.masterPercentage,
    this.account,
    this.account2,
    this.accountName,
    this.storeMode,
    this.web,
    this.email1,
    this.email2,
    this.email3,
    this.email4,
    this.email5,
    this.mcc,
    this.cif,
    this.approve1,
    this.approve2,
  });
  
  factory Iostore.fromJson(Map<String, dynamic> json) {
    print('Converting JSON to Iostore');
    print('JSON keys: ${json.keys.toList()}');
    print('JSON data: $json');
    
    try {
      final store = Iostore(
        storeId: json['store_id'] ?? 0,
        companyId: CompanyConfig.getCompanyId(),
        storeName: json['store_name'] ?? '',
        storeCode: json['store_code'] ?? '',
        imageUrl: json['image_url'],
        storeManager: json['store_manager'],
        email: json['email'],
        phone: json['phone'],
        address: json['address'],
        city: json['city'],
        state: json['state'],
        country: json['country'],
        postalCode: json['postal_code'],
        storeType: json['store_type'],
        status: json['status'],
        openingHours: json['opening_hours'],
        squareFootage: json['square_footage'] != null 
            ? double.tryParse(json['square_footage'].toString()) 
            : null,
        notes: json['notes'],
        upiPercentage: json['upi_percentage'] != null 
            ? double.tryParse(json['upi_percentage'].toString()) 
            : null,
        visaPercentage: json['visa_percentage'] != null 
            ? double.tryParse(json['visa_percentage'].toString()) 
            : null,
        masterPercentage: json['master_percentage'] != null 
            ? double.tryParse(json['master_percentage'].toString()) 
            : null,
        account: json['account'],
        account2: json['account2'],
        accountName: json['account_name'],
        storeMode: json['store_mode'],
        web: json['web'],
        email1: json['email1'],
        email2: json['email2'],
        email3: json['email3'],
        email4: json['email4'],
        email5: json['email5'],
        mcc: json['mcc'],
        cif: json['cif'],
        approve1: json['approve1'] != null ? int.tryParse(json['approve1'].toString()) : null,
        approve2: json['approve2'] != null ? int.tryParse(json['approve2'].toString()) : null,
      );
      print('Successfully created Iostore: ${store.storeName}');
      return store;
    } catch (e, stackTrace) {
      print('Error parsing Iostore JSON: $e');
      print('Stack trace: $stackTrace');
      print('Problem JSON: $json');
      rethrow;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'store_id': storeId,
      'company_id': companyId,
      'store_name': storeName,
      'store_code': storeCode,
      'image_url': imageUrl,
      'store_manager': storeManager,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'country': country,
      'postal_code': postalCode,
      'store_type': storeType,
      'status': status,
      'opening_hours': openingHours,
      'square_footage': squareFootage,
      'notes': notes,
      'upi_percentage': upiPercentage,
      'visa_percentage': visaPercentage,
      'master_percentage': masterPercentage,
      'account': account,
      'account2': account2,
      'account_name': accountName,
      'store_mode': storeMode,
      'web': web,
      'email1': email1,
      'email2': email2,
      'email3': email3,
      'email4': email4,
      'email5': email5,
      'mcc': mcc,
      'cif': cif,
      'approve1': approve1,
      'approve2': approve2,
    };
  }
}