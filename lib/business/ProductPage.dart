import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:http/http.dart' as http;
import 'package:Restaurant/config/company_config.dart';
import 'ProductAddPage.dart';
import 'ProductEditPage.dart';
import 'package:Restaurant/config/config.dart';
import 'package:Restaurant/config/theme.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({Key? key}) : super(key: key);

  @override
  State<ProductPage> createState() => _ProductPageState();
}

String langCode = 'en';

class _ProductPageState extends State<ProductPage> {
  List<Product> products = [];
  List<Product> filteredProducts = [];
  bool loading = true;
  String? error;
  String currentTheme = ThemeConfig.defaultTheme;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('ProductPage initState() called');
    debugPrint('Language code: $langCode');

    _loadLangCode();
    _loadCurrentTheme();
    fetchProducts();
    
    _searchController.addListener(() {
      print('Search query: ${_searchController.text}');
      filterProducts(_searchController.text);
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
    print('ProductPage dispose() called');
    _searchController.dispose();
    super.dispose();
  }

  void filterProducts(String query) {
    print('Filtering products with query: "$query"');
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredProducts = products.where((product) {
        // Filter out deleted products, then apply search filter
        if (product.status == 'deleted') return false;
        
        final nameLower = product.productName.toLowerCase();
        final categoryLower = (product.category ?? '').toLowerCase();
        final brandLower = (product.brand ?? '').toLowerCase();
        final codeLower = (product.productCode ?? '').toLowerCase();
        
        bool matches = nameLower.contains(lowerQuery) ||
            categoryLower.contains(lowerQuery) ||
            brandLower.contains(lowerQuery) ||
            codeLower.contains(lowerQuery);
            
        return matches;
      }).toList();
      print('Filtered products count: ${filteredProducts.length}');
    });
  }

  Future<void> fetchProducts() async {
    print('Starting fetchProducts()');
    
    if (!mounted) {
      print('Widget not mounted, aborting fetchProducts()');
      return;
    }
    
    setState(() {
      loading = true;
      error = null;
    });

    final url = AppConfig.api('/api/ioproduct');
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
            final List<dynamic> rawProducts = data['data'] ?? [];
            print('Raw products count: ${rawProducts.length}');
            
            // Print first product for debugging
            if (rawProducts.isNotEmpty) {
              print('First product data: ${rawProducts[0]}');
            }
            
            products = rawProducts.map((e) {
              try {
                return Product.fromJson(e);
              } catch (parseError) {
                print('Error parsing product: $parseError');
                print('Problem product data: $e');
                rethrow;
              }
            }).toList();
            
            // Filter out deleted products for display
            filteredProducts = products.where((product) => product.status != 'deleted').toList();
            
            print('Total products loaded: ${products.length}');
            print('Active products: ${filteredProducts.length}');
            
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

  void _onAddProduct() async {
    print('Add Product button pressed');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProductAddPage()),
    );

    print('Add Product result: $result');
    if (result == true) {
      print('Refreshing products after add');
      fetchProducts();
    }
  }

  Widget _buildProductImage(Product product) {
    print('Building image for product: ${product.productName}');
    print('Image URL: ${product.imageUrl}');
    
    // Check if we have a valid image URL
    if (product.imageUrl == null || product.imageUrl!.isEmpty) {
      print('No image URL, showing placeholder');
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[200],
        child: Icon(
          Icons.inventory_2,
          color: Colors.grey[600],
          size: 30,
        ),
      );
    }

    // Handle different image URL formats
    String imageUrl = product.imageUrl!;
    
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
              print('Image loaded successfully for ${product.productName}');
              return child;
            }
            print('Loading image for ${product.productName}...');
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
            print('Error loading image for ${product.productName}: $error');
            print('Failed URL: $imageUrl');
            return Icon(
              Icons.inventory_2,
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
    print('Building ProductPage widget');
    print('Current state - loading: $loading, error: $error, products: ${products.length}');
    
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
          title: Text('Products'),
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
              Text('Loading Products...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      print('Showing error state: $error');
      return Scaffold(
        appBar: AppBar(
          title: Text('Products'),
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
                    'Error Loading Products',
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
                      fetchProducts();
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

    if (products.isEmpty) {
      print('Showing empty state');
      return Scaffold(
        appBar: AppBar(
          title: Text('Products (0)'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          actions: [
            IconButton(
              onPressed: () {
                print('Refresh button pressed from empty state');
                fetchProducts();
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
                Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Products found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _onAddProduct,
                  icon: Icon(Icons.add),
                  label: Text('Add First Product'),
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
          onPressed: _onAddProduct,
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          tooltip: SimpleTranslations.get(langCode, 'add_product'),
          child: const Icon(Icons.add),
        ),
      );
    }

    print('Rendering main product list with ${filteredProducts.length} products');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${SimpleTranslations.get(langCode, 'products')} (${filteredProducts.length})'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          if (isWideScreen) ...[
            // Add button in app bar for wide screens
            IconButton(
              onPressed: _onAddProduct,
              icon: const Icon(Icons.add),
              tooltip: SimpleTranslations.get(langCode, 'add_product'),
            ),
          ],
          IconButton(
            onPressed: () {
              print('Refresh button pressed from app bar');
              fetchProducts();
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
                child: filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No Products match your search'
                                  : 'No Products found',
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
                        onRefresh: fetchProducts,
                        child: _buildGridView(cardMargin), // ✅ Always use grid view
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: isWideScreen ? null : FloatingActionButton(
        onPressed: _onAddProduct,
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        tooltip: SimpleTranslations.get(langCode, 'add_product'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGridView(EdgeInsets cardMargin) {
    // ✅ Responsive columns: 4 on mobile, 10 on desktop
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 10 : 4;
    
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount, // ✅ 4 on mobile, 10 on desktop
        childAspectRatio: 0.7, // ✅ Changed from 0.8 to 0.7 (taller cards for more image)
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (ctx, i) {
        final product = filteredProducts[i];
        print('Building grid card for product: ${product.productName}');

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _navigateToEdit(product),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Product Image at top - ✅ BIGGER: Takes more space now
                Expanded(
                  flex: 5, // ✅ Increased from 3 to 5 (more image space)
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    child: _buildCardImage(product),
                  ),
                ),
                
                // Product details at bottom - Compact info area
                Container(
                  padding: EdgeInsets.all(8),
                  constraints: BoxConstraints(
                    minHeight: 50, // ✅ Reduced from 60 to 50
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✅ PRICE FIRST (on top)
                      if (product.price != null && product.price! > 0)
                        Text(
                          '${_formatPrice(product.price!)} LAK',
                          style: TextStyle(
                            fontSize: 12, // ✅ Slightly bigger for emphasis
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      
                      SizedBox(height: 2),
                      
                      // ✅ PRODUCT NAME SECOND (below)
                      Text(
                        product.productName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500, // ✅ Medium weight
                          fontSize: 11, // ✅ Slightly smaller
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
    );
  }

  // ✅ NEW: Separate method for card image
  Widget _buildCardImage(Product product) {
    if (product.imageUrl == null || product.imageUrl!.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Icon(
            Icons.inventory_2,
            color: Colors.grey[400],
            size: 48,
          ),
        ),
      );
    }

    // Handle different image URL formats
    String imageUrl = product.imageUrl!;
    if (!imageUrl.startsWith('http')) {
      final baseUrl = AppConfig.api('').toString().replaceAll('/api', '');
      if (imageUrl.startsWith('/')) {
        imageUrl = '$baseUrl$imageUrl';
      } else {
        imageUrl = '$baseUrl/$imageUrl';
      }
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey[200],
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ThemeConfig.getPrimaryColor(currentTheme),
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[200],
          child: Center(
            child: Icon(
              Icons.inventory_2,
              color: Colors.grey[400],
              size: 48,
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductSubtitle(Product product, {bool compact = false}) {
    // Only show price
    if (product.price != null && product.price! > 0) {
      return Text(
        '${_formatPrice(product.price!)} LAK', // ✅ Using formatted price
        style: TextStyle(
          fontSize: compact ? 12 : 14,
          fontWeight: FontWeight.bold,
          color: Colors.green[700],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    
    // If no price, show nothing (or you can show a placeholder)
    return SizedBox.shrink();
  }

  void _navigateToEdit(Product product) async {
    print('Product tapped: ${product.productName}');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductEditPage(
          productData: product.toJson(),
        ),
      ),
    );

    print('Edit Product result: $result');
    if (result == true || result == 'deleted') {
      print('Product operation completed, refreshing list...');
      fetchProducts();
      
      if (result == 'deleted') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product removed from list'),
            backgroundColor: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'deleted':
        return Colors.red;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // ✅ NEW: Format price with thousand separators (no decimals)
  String _formatPrice(double price) {
    // Convert to integer (remove decimals)
    int priceInt = price.round();
    
    // Convert to string
    String priceStr = priceInt.toString();
    
    // Add thousand separators
    String formatted = '';
    int count = 0;
    
    for (int i = priceStr.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        formatted = ',$formatted';
      }
      formatted = priceStr[i] + formatted;
      count++;
    }
    
    return formatted;
  }
}

// ✅ UPDATED: Product model with price field
class Product {
  final int productId;
  final int companyId;
  final String productName;
  final String? productCode;
  final String? description;
  final String? category;
  final String? brand;
  final String? barcode;
  final double? price; // ✅ ADDED: Price field
  final int? supplierId;
  final DateTime createdDate;
  final DateTime updatedDate;
  final String? notes;
  final int? unit;
  final String? imageUrl;
  final String status;
  
  Product({
    required this.productId,
    required this.companyId,
    required this.productName,
    this.productCode,
    this.description,
    this.category,
    this.brand,
    this.barcode,
    this.price, // ✅ ADDED: Price parameter
    this.supplierId,
    required this.createdDate,
    required this.updatedDate,
    this.notes,
    this.unit,
    this.imageUrl,
    required this.status,
  });
  
  factory Product.fromJson(Map<String, dynamic> json) {
    print('Converting JSON to Product');
    print('JSON keys: ${json.keys.toList()}');
    print('JSON data: $json');
    
    try {
      // Handle different date formats
      DateTime parseDate(dynamic dateValue) {
        if (dateValue == null) return DateTime.now();
        if (dateValue is String) {
          try {
            return DateTime.parse(dateValue);
          } catch (e) {
            print('Error parsing date string "$dateValue": $e');
            return DateTime.now();
          }
        }
        return DateTime.now();
      }

      // ✅ ADDED: Parse price field
      double? parsePrice(dynamic priceValue) {
        if (priceValue == null) return null;
        if (priceValue is double) return priceValue;
        if (priceValue is int) return priceValue.toDouble();
        if (priceValue is String) {
          try {
            return double.parse(priceValue);
          } catch (e) {
            print('Error parsing price "$priceValue": $e');
            return null;
          }
        }
        return null;
      }

      final product = Product(
        productId: json['product_id'] ?? 0,
        companyId: json['company_id'] ?? CompanyConfig.getCompanyId(),
        productName: json['product_name'] ?? '',
        productCode: json['product_code'],
        description: json['description'],
        category: json['category'],
        brand: json['brand'],
        barcode: json['barcode'],
        price: parsePrice(json['price']), // ✅ ADDED: Parse price
        supplierId: json['supplier_id'],
        createdDate: parseDate(json['created_date']),
        updatedDate: parseDate(json['updated_date']),
        notes: json['notes'],
        unit: json['unit'],
        imageUrl: json['image_url'],
        status: json['status'] ?? 'active',
      );
      
      print('Successfully created Product: ${product.productName} (Price: ${product.price})');
      return product;
    } catch (e, stackTrace) {
      print('Error parsing Product JSON: $e');
      print('Stack trace: $stackTrace');
      print('Problem JSON: $json');
      rethrow;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'company_id': companyId,
      'product_name': productName,
      'product_code': productCode,
      'description': description,
      'category': category,
      'brand': brand,
      'barcode': barcode,
      'price': price, // ✅ ADDED: Include price in JSON
      'supplier_id': supplierId,
      'created_date': createdDate.toIso8601String(),
      'updated_date': updatedDate.toIso8601String(),
      'notes': notes,
      'unit': unit,
      'image_url': imageUrl,
      'status': status,
    };
  }
}