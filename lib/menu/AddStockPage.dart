import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:Restaurant/config/company_config.dart';
import 'package:Restaurant/config/config.dart';
import 'package:Restaurant/config/theme.dart';
import 'package:Restaurant/menu/MenuWigetPage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../utils/simple_translations.dart';

class AddStockPage extends StatefulWidget {
  final String? currentTheme;

  const AddStockPage({super.key, this.currentTheme});

  @override
  State<AddStockPage> createState() => _AddStockPageState();
}

class _AddStockPageState extends State<AddStockPage> {
  // Authentication & Config
  String? _accessToken;
  String _langCode = 'en';
  late final int _companyId;
  String? _userId;
  String? _branchId;
  late Color _primaryColor;

  // Current Step (0 = location, 1 = product, 2 = form)
  int _currentStep = 0;

  // Form State
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{
    'productId': TextEditingController(),
    'productName': TextEditingController(),
    'barcode': TextEditingController(),
    'amount': TextEditingController(text: '0'),
    'price': TextEditingController(text: '0'),
  };

  // Data
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _vendors = [];

  // Selected Items
  Map<String, dynamic>? _selectedLocation;
  Map<String, dynamic>? _selectedProduct;
  Map<String, dynamic>? _selectedVendor;
  DateTime? _selectedExpireDate;

  // Form Values
  String _selectedCurrency = 'LAK';
  String _selectedStatus = 'active';

  // Loading States
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isLoadingLocations = false;
  bool _isLoadingProducts = false;
  bool _isLoadingVendors = false;

  @override
  void initState() {
    super.initState();
    _primaryColor = ThemeConfig.getPrimaryColor(
      widget.currentTheme ?? 'default',
    );
    _initializeAuth();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // INITIALIZATION & DATA LOADING
  Future<void> _initializeAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      _langCode = prefs.getString('languageCode') ?? 'en';
      _companyId = CompanyConfig.getCompanyId();
      _userId = prefs.getString('user');
      _branchId = prefs.getString('branch_id');

      if (_accessToken != null) {
        await Future.wait([
          _loadLocations(),
          _loadVendors(),
        ]);
      } else {
        _showMessage('Authentication token not found', isError: true);
      }
    } catch (e) {
      _showMessage('Failed to initialize: $e', isError: true);
    }
  }

  Future<void> _loadLocations() async {
    if (!mounted) return;
    setState(() => _isLoadingLocations = true);

    try {
      final response = await _apiRequest(
        'GET',
        '/api/iolocation',
        queryParams: {'status': 'admin', 'company_id': _companyId.toString()},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final rawLocations = data['data'] as List? ?? [];
          setState(() {
            _locations = rawLocations.map(_mapLocation).toList();
          });
        }
      }
    } catch (e) {
      _showMessage('Error loading locations: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingLocations = false);
    }
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() => _isLoadingProducts = true);

    try {
      final response = await _apiRequest(
        'GET',
        '/api/ioproduct',
        queryParams: {'company_id': _companyId.toString()},
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success' && data['data'] != null) {
        setState(() {
          _products = (data['data'] as List).map(_mapProduct).toList();
        });
      }
    } catch (e) {
      _showMessage('Error loading products: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _loadVendors() async {
    if (!mounted) return;
    setState(() => _isLoadingVendors = true);

    try {
      final response = await _apiRequest(
        'GET',
        '/api/iovendor',
        queryParams: {'status': 'admin', 'company_id': _companyId.toString()},
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        setState(() {
          _vendors = (data['data'] as List? ?? []).map(_mapVendor).toList();
        });
      }
    } catch (e) {
      _showMessage('Error loading vendors: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingVendors = false);
    }
  }

  // DATA MAPPING
  Map<String, dynamic> _mapLocation(dynamic location) => {
    'location_id': location['location_id'] ?? location['id'],
    'location':
        location['location'] ?? location['location_name'] ?? 'Unknown Location',
    'location_name': location['location_name'] ?? location['location'],
    'description': location['description'] ?? '',
    'address': location['address'] ?? '',
    'status': location['status'] ?? 'active',
    'company_id': location['company_id'],
    'image': location['image'] ?? '',
    'image_url': location['image_url'] ?? '',
  };

  Map<String, dynamic> _mapProduct(dynamic product) => {
    'product_id': product['product_id'] ?? product['id'],
    'product_name':
        product['product_name'] ?? product['name'] ?? 'Unknown Product',
    'barcode': product['barcode'] ?? '',
    'price': product['price'] ?? 0,
    'image_url': product['image_url'] ?? '',
    'stock_quantity': product['stock_quantity'] ?? 0,
    'category': product['category'] ?? '',
  };

  Map<String, dynamic> _mapVendor(dynamic vendor) => {
    'vendor_id': vendor['vendor_id'] ?? vendor['id'],
    'vendor_name': vendor['vendor_name'] ?? vendor['name'] ?? 'Unknown vendor',
    'name': vendor['name'] ?? vendor['vendor_name'],
    'description': vendor['description'] ?? '',
    'status': vendor['status'] ?? 'active',
    'image': vendor['image'] ?? '',
    'image_url': vendor['image_url'] ?? '',
  };

  // SELECTION HANDLERS
  void _onLocationSelected(Map<String, dynamic> location) {
    setState(() {
      _selectedLocation = location;
      _currentStep = 1; // Move to product selection
    });
    _showMessage('Selected: ${location['location']}');
    _loadProducts(); // Load products for this location
  }

  void _onProductSelected(Map<String, dynamic> product) {
    setState(() {
      _selectedProduct = product;
      _controllers['productId']!.text = product['product_id'].toString();
      _controllers['productName']!.text = product['product_name'] ?? '';
      _controllers['barcode']!.text = product['barcode'] ?? '';
      if (product['price'] != null && product['price'] > 0) {
        _controllers['price']!.text = product['price'].toString();
      }
      _currentStep = 2; // Move to form
    });
    _showMessage('Selected: ${product['product_name']}');
  }

  void _goBackToLocationSelection() {
    setState(() {
      _selectedLocation = null;
      _selectedProduct = null;
      _products = [];
      _currentStep = 0;
    });
  }

  void _goBackToProductSelection() {
    setState(() {
      _selectedProduct = null;
      _controllers['productId']!.clear();
      _controllers['productName']!.clear();
      _controllers['barcode']!.clear();
      _currentStep = 1;
    });
  }

  // FORM SUBMISSION
  Future<void> _addRestaurant() async {
    if (!_validateForm()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final body = _buildRequestBody();

      final response = await http.post(
        AppConfig.api('/api/Restaurant'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage('Stock added successfully');
        _clearForm();

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MenuPage(role: 'user', tabIndex: 1),
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData is Map
            ? (errorData['message'] ??
                  errorData['error'] ??
                  'Failed to add stock')
            : 'Failed to add stock';
        _showMessage(errorMessage, isError: true);
      }
    } catch (e) {
      _showMessage('Error adding stock: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Map<String, dynamic> _buildRequestBody() {
    final productId = int.parse(_controllers['productId']!.text.trim());
    final productName = _controllers['productName']!.text.trim();
    final amount = int.parse(_controllers['amount']!.text.trim());
    final price = double.parse(_controllers['price']!.text.trim());

    final body = <String, dynamic>{
      'product_id': productId,
      'product_name': productName,
      'location_id': _selectedLocation!['location_id'],
      'location':
          _selectedLocation!['location'] ?? _selectedLocation!['location_name'],
      'currency_primary': _selectedCurrency,
      'amount': amount,
      'price': price,
      'status': _selectedStatus,
      'user_id': _userId,
      'branch_id': _branchId != null ? int.tryParse(_branchId!) : null,
      'txntype': 'STOCK_IN',
      'company_id': _companyId,
    };

    if (_selectedVendor != null) {
      body['supplier_id'] = _selectedVendor!['vendor_id'];
    }

    final barcode = _controllers['barcode']!.text.trim();
    if (barcode.isNotEmpty) {
      body['barcode'] = barcode;
    }

    if (_selectedExpireDate != null) {
      final expireDateString = _selectedExpireDate!.toIso8601String().split('T')[0];
      body['expire_date'] = expireDateString;
    }

    return body;
  }

  bool _validateForm() {
    final isFormValid = _formKey.currentState!.validate();

    if (!isFormValid) {
      _showMessage('Please fill required fields', isError: true);
      return false;
    }

    if (_selectedLocation == null) {
      _showMessage('Please select location', isError: true);
      return false;
    }

    final amount = _controllers['amount']!.text.trim();
    final price = _controllers['price']!.text.trim();
    final productId = _controllers['productId']!.text.trim();

    if (int.tryParse(amount) == null || int.parse(amount) <= 0) {
      _showMessage('Please enter a valid amount greater than 0', isError: true);
      return false;
    }

    if (double.tryParse(price) == null || double.parse(price) < 0) {
      _showMessage('Please enter a valid price', isError: true);
      return false;
    }

    if (int.tryParse(productId) == null) {
      _showMessage('Please enter a valid product ID', isError: true);
      return false;
    }

    return true;
  }

  void _clearForm() {
    for (final controller in _controllers.values) {
      controller.clear();
    }
    setState(() {
      _selectedExpireDate = null;
      _selectedLocation = null;
      _selectedVendor = null;
      _selectedProduct = null;
      _selectedCurrency = 'LAK';
      _selectedStatus = 'active';
      _currentStep = 0;
    });
  }

  // API HELPER
  Future<http.Response> _apiRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final uri = AppConfig.api(endpoint).replace(queryParameters: queryParams);
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    };

    return switch (method) {
      'GET' => http.get(uri, headers: headers),
      'POST' => http.post(uri, headers: headers, body: jsonEncode(body)),
      _ => throw ArgumentError('Unsupported method: $method'),
    };
  }

  // UI HELPERS
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // BUILD METHODS
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: _currentStep > 0
            ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  if (_currentStep == 2) {
                    _goBackToProductSelection();
                  } else if (_currentStep == 1) {
                    _goBackToLocationSelection();
                  }
                },
              )
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),
      body: _buildBody(),
    );
  }

  String _getAppBarTitle() {
    switch (_currentStep) {
      case 0:
        return SimpleTranslations.get(_langCode, 'Select Location');
      case 1:
        return SimpleTranslations.get(_langCode, 'Select Product');
      case 2:
        return SimpleTranslations.get(_langCode, 'add_stock');
      default:
        return SimpleTranslations.get(_langCode, 'add_stock');
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    switch (_currentStep) {
      case 0:
        return _buildLocationGrid();
      case 1:
        return _buildProductGrid();
      case 2:
        return _buildForm();
      default:
        return _buildLocationGrid();
    }
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _primaryColor, strokeWidth: 3),
            const SizedBox(height: 16),
            Text(
              SimpleTranslations.get(_langCode, 'loading_data'),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // LOCATION GRID
  Widget _buildLocationGrid() {
    return Column(
      children: [
        _buildStepIndicator(0),
        Expanded(
          child: _isLoadingLocations
              ? Center(child: CircularProgressIndicator(color: _primaryColor))
              : _locations.isEmpty
              ? _buildEmptyState(
                  'No locations available',
                  Icons.location_off,
                  _loadLocations,
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _locations.length,
                  itemBuilder: (context, index) {
                    return _buildLocationCard(_locations[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> location) {
    return InkWell(
      onTap: () => _onLocationSelected(location),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: location['image_url'] != null && location['image_url'].isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        location['image_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.store,
                          color: Colors.blue,
                          size: 32,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.store,
                      color: Colors.blue,
                      size: 32,
                    ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                location['location'] ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (location['address']?.toString().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  location['address'],
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // PRODUCT GRID
  Widget _buildProductGrid() {
    return Column(
      children: [
        _buildStepIndicator(1),
        _buildSelectedLocationBanner(),
        Expanded(
          child: _isLoadingProducts
              ? Center(child: CircularProgressIndicator(color: _primaryColor))
              : _products.isEmpty
              ? _buildEmptyState(
                  'No products available',
                  Icons.inventory_2_outlined,
                  _loadProducts,
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    return _buildProductCard(_products[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSelectedLocationBanner() {
    if (_selectedLocation == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: Colors.blue[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${SimpleTranslations.get(_langCode, 'Location')}: ${_selectedLocation!['location']}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.blue[700],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final hasStock = product['stock_quantity'] != null && product['stock_quantity'] > 0;
    
    return InkWell(
      onTap: () => _onProductSelected(product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: product['image_url'] != null && product['image_url'].isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        child: Image.network(
                          product['image_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.inventory,
                            color: Colors.grey[400],
                            size: 40,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.inventory,
                        color: Colors.grey[400],
                        size: 40,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['product_name'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (product['price'] != null && product['price'] > 0)
                    Text(
                      '${product['price']} LAK',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: hasStock
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Stock: ${product['stock_quantity'] ?? 0}',
                      style: TextStyle(
                        fontSize: 10,
                        color: hasStock ? Colors.green[700] : Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // STEP INDICATOR
  Widget _buildStepIndicator(int currentStep) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          _buildStepCircle(0, 'Location', currentStep >= 0),
          Expanded(child: _buildStepLine(currentStep >= 1)),
          _buildStepCircle(1, 'Product', currentStep >= 1),
          Expanded(child: _buildStepLine(currentStep >= 2)),
          _buildStepCircle(2, 'Details', currentStep >= 2),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? _primaryColor : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? _primaryColor : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isActive) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isActive ? _primaryColor : Colors.grey[300],
    );
  }

  // EMPTY STATE
  Widget _buildEmptyState(String message, IconData icon, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // FORM (Step 3)
  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepIndicator(2),
            const SizedBox(height: 16),
            
            // Selected items summary
            _buildSelectionSummary(),
            const SizedBox(height: 24),

            Text(
              SimpleTranslations.get(_langCode, 'Stock Details'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            _buildTextField(
              'productId',
              SimpleTranslations.get(_langCode, 'product_id'),
              required: true,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'productName',
              SimpleTranslations.get(_langCode, 'product_name'),
              required: true,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'barcode',
              SimpleTranslations.get(_langCode, 'barcode'),
              required: false,
            ),
            const SizedBox(height: 16),
            _buildVendorDropdown(),
            const SizedBox(height: 16),
            _buildTextField(
              'amount',
              SimpleTranslations.get(_langCode, 'add_amount'),
              required: true,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'price',
              SimpleTranslations.get(_langCode, 'price'),
              required: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            _buildDatePicker(),
            const SizedBox(height: 16),
            _buildStatusDropdowns(),
            const SizedBox(height: 32),
            _buildSubmitButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            SimpleTranslations.get(_langCode, 'Your Selection'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.green[700], size: 20),
              const SizedBox(width: 8),
              Text(
                _selectedLocation!['location'] ?? 'N/A',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.inventory, color: Colors.green[700], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedProduct!['product_name'] ?? 'N/A',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String key,
    String label, {
    bool required = false,
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: _controllers[key]!,
      keyboardType: keyboardType,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey[100] : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return SimpleTranslations.get(
                  _langCode,
                  'This field is required',
                );
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildVendorDropdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            SimpleTranslations.get(_langCode, 'Vendor (Optional)'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_isLoadingVendors)
            const Center(child: CircularProgressIndicator())
          else if (_vendors.isEmpty)
            Text(
              'No vendors available',
              style: TextStyle(color: Colors.grey[600]),
            )
          else
            DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, dynamic>>(
                value: _selectedVendor,
                hint: Text(SimpleTranslations.get(_langCode, 'Select Vendor')),
                isExpanded: true,
                items: _vendors
                    .map(
                      (vendor) => DropdownMenuItem(
                        value: vendor,
                        child: Text(vendor['vendor_name'] ?? 'Unknown'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedVendor = value);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedExpireDate ?? DateTime.now().add(const Duration(days: 365)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
        );
        if (date != null) {
          setState(() => _selectedExpireDate = date);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedExpireDate != null
                  ? '${_selectedExpireDate!.day}/${_selectedExpireDate!.month}/${_selectedExpireDate!.year}'
                  : SimpleTranslations.get(_langCode, 'Expire Date (Optional)'),
              style: TextStyle(
                color: _selectedExpireDate != null ? Colors.black : Colors.grey[600],
              ),
            ),
            Icon(Icons.calendar_today, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdowns() {
    final currencies = [
      {'code': 'LAK', 'name': 'Lao Kip'},
      {'code': 'THB', 'name': 'Thai Baht'},
      {'code': 'USD', 'name': 'US Dollar'},
    ];

    final statuses = [
      {'value': 'active', 'name': 'Active'},
      {'value': 'inactive', 'name': 'Inactive'},
    ];

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SimpleTranslations.get(_langCode, 'Currency'),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCurrency,
                    isExpanded: true,
                    items: currencies
                        .map((c) => DropdownMenuItem(
                              value: c['code'],
                              child: Text('${c['code']} - ${c['name']}'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedCurrency = value!);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SimpleTranslations.get(_langCode, 'Status'),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    isExpanded: true,
                    items: statuses
                        .map((s) => DropdownMenuItem(
                              value: s['value'],
                              child: Text(s['name']!),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedStatus = value!);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _addRestaurant,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isSubmitting ? Colors.grey : Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: _isSubmitting ? 0 : 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    SimpleTranslations.get(_langCode, 'Adding Stock...'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_shopping_cart, size: 24),
                  SizedBox(width: 8),
                  Text(
                    SimpleTranslations.get(_langCode, 'Add Stock'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }
}