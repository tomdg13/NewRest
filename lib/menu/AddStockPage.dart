import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'package:inventory/menu/MenuWigetPage.dart';
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
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _vendors = [];

  // Selected Items
  Map<String, dynamic>? _selectedProduct;
  Map<String, dynamic>? _selectedLocation;
  Map<String, dynamic>? _selectedVendor;
  Map<String, dynamic>? _scannedProduct;
  DateTime? _selectedExpireDate;

  // Form Values
  String _selectedCurrency = 'LAK';
  String _selectedStatus = 'active';

  // Loading States
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isLoadingProducts = false;
  bool _isLoadingLocations = false;
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
          if (kIsWeb) _loadProducts(),
        ]);
      } else {
        _showMessage('Authentication token not found', isError: true);
      }
    } catch (e) {
      _showMessage('Failed to initialize: $e', isError: true);
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
        } else {
          throw Exception(data['message'] ?? 'Failed to load locations');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showMessage('Error loading locations: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingLocations = false);
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

  Map<String, dynamic> _mapVendor(dynamic vendor) => {
    'vendor_id': vendor['vendor_id'] ?? vendor['id'],
    'vendor_name': vendor['vendor_name'] ?? vendor['name'] ?? 'Unknown vendor',
    'name': vendor['name'] ?? vendor['vendor_name'],
    'description': vendor['description'] ?? '',
    'status': vendor['status'] ?? 'active',
    'image': vendor['image'] ?? '',
    'image_url': vendor['image_url'] ?? '',
  };

  // PRODUCT OPERATIONS
  void _onProductSelected(Map<String, dynamic> product) {
    setState(() {
      _selectedProduct = product;
      _controllers['productId']!.text = product['product_id'].toString();
      _controllers['productName']!.text = product['product_name'] ?? '';
      _controllers['barcode']!.text = product['barcode'] ?? '';
      if (product['price'] != null && product['price'] > 0) {
        _controllers['price']!.text = product['price'].toString();
      }
    });
    _showMessage('Selected: ${product['product_name']}');
  }

  Future<void> _scanBarcode() async {
    if (kIsWeb) {
      _showBarcodeInputDialog();
      return;
    }

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerPage(
          langCode: _langCode,
          primaryColor: _primaryColor,
        ),
      ),
    );

    if (result != null) {
      await _lookupProductByBarcode(result);
    }
  }

  void _showBarcodeInputDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(SimpleTranslations.get(_langCode, 'enter_barcode')),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter product barcode',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(SimpleTranslations.get(_langCode, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final barcode = controller.text.trim();
              if (barcode.isNotEmpty) {
                Navigator.pop(context);
                _lookupProductByBarcode(barcode);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _lookupProductByBarcode(String barcode) async {
    setState(() => _isLoading = true);

    try {
      final response = await _apiRequest(
        'GET',
        '/api/ioproduct/barcode/$barcode',
        queryParams: {'company_id': _companyId.toString()},
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        final product = data['data'];
        setState(() {
          _scannedProduct = product;
          _controllers['barcode']!.text = product['barcode'] ?? '';
          _controllers['productId']!.text = product['product_id'].toString();
          _controllers['productName']!.text = product['product_name'] ?? '';
        });
        _showMessage('Product found successfully');
      } else {
        _showMessage('Product not found', isError: true);
      }
    } catch (e) {
      _showMessage('Error looking up product: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // FORM SUBMISSION
  Future<void> _addInventory() async {
    if (!_validateForm()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final body = _buildRequestBody();

      final response = await http.post(
        AppConfig.api('/api/inventory'),
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

    // Add vendor if selected
    if (_selectedVendor != null) {
      body['supplier_id'] = _selectedVendor!['vendor_id'];
    }

    // Add optional fields
    final barcode = _controllers['barcode']!.text.trim();
    if (barcode.isNotEmpty) {
      body['barcode'] = barcode;
    }

    if (_selectedExpireDate != null) {
      final expireDateString = _selectedExpireDate!.toIso8601String().split(
        'T',
      )[0];
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
      _scannedProduct = null;
      _selectedCurrency = 'LAK';
      _selectedStatus = 'active';
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

  // IMAGE BUILDERS
  Widget _buildImage(
    String? imageUrl,
    IconData fallbackIcon, {
    double size = 40,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.2),
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.grey[50],
      ),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.2 - 1),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(fallbackIcon, color: _primaryColor, size: size * 0.6),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: size * 0.4,
                      height: size * 0.4,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(_primaryColor),
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
              ),
            )
          : Icon(fallbackIcon, color: _primaryColor, size: size * 0.6),
    );
  }

  // BUILD METHODS
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          SimpleTranslations.get(_langCode, 'add_stock'),
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),
      body: _isLoading
          ? _buildLoadingScreen()
          : Column(
              children: [
                if (kIsWeb) _buildWebProductSelector(),
                if (_scannedProduct != null) _buildScannedProductInfo(),
                Expanded(child: _buildForm()),
              ],
            ),
    );
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

  Widget _buildWebProductSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add_circle, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                SimpleTranslations.get(_langCode, 'select_product'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: _isLoadingProducts
                ? _buildLoadingIndicator(
                    SimpleTranslations.get(_langCode, 'loading_products'),
                  )
                : _products.isEmpty
                ? _buildEmptyState(
                    SimpleTranslations.get(_langCode, 'products'),
                    _loadProducts,
                  )
                : _buildProductDropdown(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildActionButton(
                SimpleTranslations.get(_langCode, 'Refresh'),
                Icons.refresh,
                Colors.green,
                _loadProducts,
              ),
              const Spacer(),
              _buildCountBadge(
                '${_products.length} products available',
                Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScannedProductInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[300]!),
              color: Colors.green[100],
            ),
            child: Icon(
              Icons.qr_code_scanner,
              color: Colors.green[600],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SimpleTranslations.get(_langCode, 'Scanned Product'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Product: ${_scannedProduct!['product_name'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  SimpleTranslations.get(
                    _langCode,
                    'ID: ${_scannedProduct!['product_id']}',
                  ),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.grey[600]),
            onPressed: () => setState(() {
              _scannedProduct = null;
              _controllers['productId']!.clear();
              _controllers['productName']!.clear();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              SimpleTranslations.get(_langCode, 'add_stock_item'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            _buildBarcodeField(),
            const SizedBox(height: 16),
            _buildTextField(
              'productId',
              SimpleTranslations.get(_langCode, 'product_id'),
              required: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'productName',
              SimpleTranslations.get(_langCode, 'product_name'),
              required: true,
            ),
            const SizedBox(height: 16),
            _buildLocationDropdown(),
            const SizedBox(height: 16),
            _buildVendorDropdown(),
            const SizedBox(height: 16),
            _buildTextField(
              'amount',
              SimpleTranslations.get(_langCode, 'add_amount'),
              required: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'price',
              SimpleTranslations.get(_langCode, 'price'),
              required: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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

  Widget _buildBarcodeField() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            'barcode',
            SimpleTranslations.get(_langCode, 'barcode'),
            required: true,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          height: 56,
          child: ElevatedButton(
            onPressed: _scanBarcode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Icon(Icons.qr_code_scanner),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String key,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: _controllers[key]!,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
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

  Widget _buildLocationDropdown() {
    return _buildDropdownSection(
      title: SimpleTranslations.get(_langCode, 'Location'),
      icon: Icons.location_on,
      value: _selectedLocation,
      items: _locations,
      isLoading: _isLoadingLocations,
      onRefresh: _loadLocations,
      onChanged: (value) {
        setState(() => _selectedLocation = value);
      },
      itemBuilder: (item) => _buildLocationItem(item),
    );
  }

  Widget _buildVendorDropdown() {
    return _buildDropdownSection(
      title: SimpleTranslations.get(_langCode, 'vendor'),
      icon: Icons.local_shipping,
      value: _selectedVendor,
      items: _vendors,
      isLoading: _isLoadingVendors,
      onRefresh: _loadVendors,
      onChanged: (value) {
        setState(() => _selectedVendor = value);
      },
      itemBuilder: (item) => _buildVendorItem(item),
    );
  }

  Widget _buildDropdownSection<T>({
    required String title,
    required IconData icon,
    required T? value,
    required List<T> items,
    required bool isLoading,
    required VoidCallback onRefresh,
    required ValueChanged<T?> onChanged,
    required Widget Function(T) itemBuilder,
  }) {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: _primaryColor, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                title.toLowerCase() == 'location'
                    ? SimpleTranslations.get(_langCode, 'select_location')
                    : title.toLowerCase() == 'vendor'
                    ? SimpleTranslations.get(_langCode, 'select_vendor')
                    : SimpleTranslations.get(_langCode, 'select_product'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            _buildLoadingIndicator(
              title.toLowerCase() == 'location'
                  ? SimpleTranslations.get(_langCode, 'loading_locations')
                  : title.toLowerCase() == 'vendor'
                  ? SimpleTranslations.get(_langCode, 'loading_vendors')
                  : SimpleTranslations.get(_langCode, 'loading_products'),
            )
          else if (items.isEmpty)
            _buildEmptyState(title.toLowerCase(), onRefresh)
          else
            DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                hint: Text(
                  title.toLowerCase() == 'location'
                      ? SimpleTranslations.get(_langCode, 'choose_location')
                      : title.toLowerCase() == 'vendor'
                      ? SimpleTranslations.get(_langCode, 'choose_vendor')
                      : SimpleTranslations.get(_langCode, 'choose_product'),
                ),
                isExpanded: true,
                items: items
                    .map(
                      (item) => DropdownMenuItem<T>(
                        value: item,
                        child: itemBuilder(item),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          if (value != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    SimpleTranslations.get(
                      _langCode,
                      'Selected: ${_getItemDisplayName(value)}',
                    ),
                    style: TextStyle(color: Colors.green[700], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _buildActionButton(
                SimpleTranslations.get(_langCode, 'Refresh'),
                Icons.refresh,
                _primaryColor,
                onRefresh,
              ),
              const Spacer(),
              _buildCountBadge(
                '${items.length} ${title.toLowerCase()}s',
                _primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationItem(Map<String, dynamic> item) {
    return Row(
      children: [
        _buildImage(item['image_url'], Icons.location_on),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['location'] ??
                    item['location_name'] ??
                    SimpleTranslations.get(_langCode, 'Unknown'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (item['description']?.toString().isNotEmpty == true)
                Text(
                  item['description'],
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        _buildStatusBadge(item['status']),
      ],
    );
  }

  Widget _buildVendorItem(Map<String, dynamic> item) {
    return Row(
      children: [
        _buildImage(item['image_url'], Icons.local_shipping),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['vendor_name'] ??
                    item['name'] ??
                    SimpleTranslations.get(_langCode, 'Unknown vendor'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (item['description']?.toString().isNotEmpty == true)
                Text(
                  item['description'],
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        _buildStatusBadge(item['status']),
      ],
    );
  }

  Widget _buildProductDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<Map<String, dynamic>>(
        value:
            _selectedProduct != null &&
                _products.any(
                  (p) => p['product_id'] == _selectedProduct!['product_id'],
                )
            ? _selectedProduct
            : null,
        hint: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(SimpleTranslations.get(_langCode, 'select_product')),
        ),
        isExpanded: true,
        items: _products
            .map(
              (product) => DropdownMenuItem<Map<String, dynamic>>(
                value: product,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _buildImage(
                        product['image_url'],
                        Icons.inventory,
                        size: 48,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          product['product_name'] ??
                              SimpleTranslations.get(
                                _langCode,
                                'Unknown Product',
                              ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (product['stock_quantity'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: product['stock_quantity'] > 0
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            SimpleTranslations.get(
                              _langCode,
                              'Stock: ${product['stock_quantity']}',
                            ),
                            style: TextStyle(
                              fontSize: 10,
                              color: product['stock_quantity'] > 0
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) _onProductSelected(value);
        },
      ),
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          SimpleTranslations.get(_langCode, 'expire_date_optional'), 
          style: TextStyle(fontSize: 12, color: Colors.grey)
        ),
        const SizedBox(height: 4),
        InkWell(
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
                    : SimpleTranslations.get(_langCode, 'select_expire_date'),
                  style: TextStyle(color: _selectedExpireDate != null ? Colors.black : Colors.grey[600]),
                ),
                Icon(Icons.calendar_today, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildStatusDropdowns() {
    final currencies = [
      {
        'code': 'LAK',
        'name': 'Lao Kip',
        'image_url': 'https://flagcdn.com/w40/la.png',
      },
      {
        'code': 'THB',
        'name': 'Thai Baht',
        'image_url': 'https://flagcdn.com/w40/th.png',
      },
      {
        'code': 'USD',
        'name': 'US Dollar',
        'image_url': 'https://flagcdn.com/w40/us.png',
      },
    ];

    final statuses = [
      {
        'value': 'active',
        'name': 'Active',
        'image_url': 'https://img.icons8.com/color/48/checked--v1.png',
      },
      {
        'value': 'inactive',
        'name': 'Inactive',
        'image_url': 'https://img.icons8.com/color/48/cancel--v1.png',
      },
    ];

    return Row(
      children: [
        Expanded(
          child: _buildSimpleDropdown(
            SimpleTranslations.get(_langCode, 'Currency'),
            _selectedCurrency,
            currencies,
            (currency) => currency['code'] as String,
            (currency) => Row(
              children: [
                _buildImage(
                  currency['image_url'],
                  Icons.monetization_on,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currency['code'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        currency['name'] as String,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            (value) {
              setState(() => _selectedCurrency = value);
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSimpleDropdown(
            SimpleTranslations.get(_langCode, 'Status'),
            _selectedStatus,
            statuses,
            (status) => status['value'] as String,
            (status) => Row(
              children: [
                _buildImage(status['image_url'], Icons.info, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    status['name'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                _buildStatusBadge(status['value']),
              ],
            ),
            (value) {
              setState(() => _selectedStatus = value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleDropdown<T>(
    String label,
    String currentValue,
    List<T> items,
    String Function(T) getValue,
    Widget Function(T) buildItem,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              items: items
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: getValue(item),
                      child: buildItem(item),
                    ),
                  )
                  .toList(),
              onChanged: (value) => onChanged(value!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _addInventory,
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
                    SimpleTranslations.get(_langCode, 'adding_stock'),
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
                    SimpleTranslations.get(_langCode, 'add_stock_button'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  // UTILITY WIDGETS
  Widget _buildLoadingIndicator(String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(_primaryColor),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String type, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              type == 'products'
                  ? Icons.inventory_2_outlined
                  : type == 'locations'
                  ? Icons.location_off
                  : Icons.local_shipping,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            SimpleTranslations.get(_langCode, 'No $type available'),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 20),
            label: Text(
              SimpleTranslations.get(
                _langCode,
                'Load ${type[0].toUpperCase()}${type.substring(1)}',
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildCountBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    if (status == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: status == 'active'
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          color: status == 'active' ? Colors.green[700] : Colors.orange[700],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getItemDisplayName(dynamic item) {
    if (item is Map<String, dynamic>) {
      return item['location'] ??
          item['location_name'] ??
          item['vendor_name'] ??
          item['name'] ??
          'Unknown';
    }
    return SimpleTranslations.get(_langCode, 'Unknown');
  }
}

// Barcode Scanner Page
class BarcodeScannerPage extends StatefulWidget {
  final String langCode;
  final Color primaryColor;

  const BarcodeScannerPage({
    super.key,
    required this.langCode,
    required this.primaryColor,
  });

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  late MobileScannerController _controller;
  bool _isScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned || !mounted) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;

    setState(() => _isScanned = true);

    if (Platform.isAndroid || Platform.isIOS) {
      HapticFeedback.lightImpact();
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context, barcodes.first.rawValue);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _buildErrorState(),
          ),

          CustomPaint(
            painter: ScannerOverlay(
              scanAreaSize: 250,
              borderColor: _isScanned ? Colors.green : widget.primaryColor,
              borderWidth: 3,
            ),
            child: const SizedBox.expand(),
          ),

          if (_isScanned) _buildSuccessIndicator(),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomInstructions(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            SimpleTranslations.get(widget.langCode, 'camera_error'),
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(SimpleTranslations.get(widget.langCode, 'close')),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(
              SimpleTranslations.get(widget.langCode, 'barcode Detected'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_scanner, size: 48, color: widget.primaryColor),
          const SizedBox(height: 16),
          Text(
            SimpleTranslations.get(
              widget.langCode,
              'Position the barcode within the scanning area',
            ),
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                SimpleTranslations.get(widget.langCode, 'Cancel'),
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Scanner Overlay Painter
class ScannerOverlay extends CustomPainter {
  final double scanAreaSize;
  final Color borderColor;
  final double borderWidth;

  const ScannerOverlay({
    required this.scanAreaSize,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final scanAreaPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: scanAreaSize,
            height: scanAreaSize,
          ),
          const Radius.circular(12),
        ),
      );

    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      scanAreaPath,
    );
    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withOpacity(0.5),
    );

    _drawCornerBrackets(canvas, size);
  }

  void _drawCornerBrackets(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;

    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanAreaSize,
      height: scanAreaSize,
    );

    const cornerLength = 20.0;

    final corners = [
      (scanRect.topLeft, true, true),
      (scanRect.topRight, false, true),
      (scanRect.bottomLeft, true, false),
      (scanRect.bottomRight, false, false),
    ];

    for (final (corner, isLeft, isTop) in corners) {
      _drawCorner(canvas, paint, corner, cornerLength, isLeft, isTop);
    }
  }

  void _drawCorner(
    Canvas canvas,
    Paint paint,
    Offset corner,
    double length,
    bool isLeft,
    bool isTop,
  ) {
    final horizontalStart = isLeft
        ? corner
        : Offset(corner.dx - length, corner.dy);
    final horizontalEnd = isLeft
        ? Offset(corner.dx + length, corner.dy)
        : corner;

    final verticalStart = isTop
        ? corner
        : Offset(corner.dx, corner.dy - length);
    final verticalEnd = isTop ? Offset(corner.dx, corner.dy + length) : corner;

    canvas.drawLine(horizontalStart, horizontalEnd, paint);
    canvas.drawLine(verticalStart, verticalEnd, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
