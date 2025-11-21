import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:io';
import '../utils/simple_translations.dart';
import 'dart:convert';

class AddStockPage extends StatefulWidget {
  final String? currentTheme;

  const AddStockPage({super.key, this.currentTheme});

  @override
  State<AddStockPage> createState() => _AddStockPageState();
}

class _AddStockPageState extends State<AddStockPage> {
  // Authentication
  String? _accessToken;
  String _langCode = 'en';
  int? _companyId;
  String? _userId;


  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {
    'productId': TextEditingController(),
    'barcode': TextEditingController(),
    'reservedQuantity': TextEditingController(),
    'stockQuantity': TextEditingController(text: '0'),
    'minimumStock': TextEditingController(text: '0'),
    'costPrice': TextEditingController(text: '0'),
    'unitPrice': TextEditingController(text: '0'),
    'batchNumber': TextEditingController(),
    'supplierId': TextEditingController(),
    'blockLocation': TextEditingController(),
  };

  // State management
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isLoadingLocations = false;
  bool _isLoadingStores = false;
  
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _stores = [];
  Map<String, dynamic>? _scannedProduct;
  Map<String, dynamic>? _selectedLocation;
  Map<String, dynamic>? _selectedStore;

  // Dropdown values
  String _selectedCurrency = 'LAK';
  String _selectedStatus = 'ACTIVE';
  DateTime? _selectedExpireDate;

  // Cache primary color for performance
  late Color _primaryColor;

  @override
  void initState() {
    super.initState();
    _primaryColor = ThemeConfig.getPrimaryColor(widget.currentTheme ?? 'default');
    _initializeAuth();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Authentication and Data Loading
  Future<void> _initializeAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      _langCode = prefs.getString('languageCode') ?? 'en';
      _companyId = prefs.getInt('company_id') ?? 1;
      _userId = prefs.getString('user');
     

      if (_accessToken != null) {
        await Future.wait([_loadLocations(), _loadStores()]);
      } else {
        _showErrorSnackBar(SimpleTranslations.get(_langCode, 'auth_token_not_found'));
      }
    } catch (e) {
      _showErrorSnackBar('Failed to initialize: $e');
    }
  }

  Future<void> _loadLocations() async {
    if (_accessToken == null || _companyId == null) return;

    setState(() => _isLoadingLocations = true);

    try {
      final response = await _makeApiRequest(
        '/api/iolocation?status=admin&company_id=$_companyId',
        method: 'GET',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _locations = List<Map<String, dynamic>>.from(data['data'] ?? []);
          });
        } else {
          _showErrorSnackBar('Failed to load locations: ${data['message']}');
        }
      } else {
        _handleApiError(response, 'Failed to load locations');
      }
    } catch (e) {
      _showErrorSnackBar('Error loading locations: $e');
    } finally {
      setState(() => _isLoadingLocations = false);
    }
  }

  Future<void> _loadStores() async {
    if (_accessToken == null || _companyId == null) return;

    setState(() => _isLoadingStores = true);

    try {
      final response = await _makeApiRequest(
        '/api/iostore?status=admin&company_id=$_companyId',
        method: 'GET',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _stores = List<Map<String, dynamic>>.from(data['data'] ?? []);
          });
        } else {
          _showErrorSnackBar('Failed to load stores: ${data['message']}');
        }
      } else {
        _handleApiError(response, 'Failed to load stores');
      }
    } catch (e) {
      _showErrorSnackBar('Error loading stores: $e');
    } finally {
      setState(() => _isLoadingStores = false);
    }
  }

  // Barcode Operations
  Future<void> _scanBarcode() async {
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

  Future<void> _lookupProductByBarcode(String barcode) async {
    setState(() => _isLoading = true);

    try {
      final response = await _makeApiRequest(
        '/api/ioproduct/barcode/$barcode',
        method: 'GET',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _scannedProduct = data['data'];
            _controllers['barcode']!.text = _scannedProduct!['barcode'] ?? '';
            _controllers['productId']!.text = _scannedProduct!['product_id'].toString();
          });
          _showSuccessSnackBar(SimpleTranslations.get(_langCode, 'product_found_success'));
        } else {
          _showErrorSnackBar('Product not found: ${data['message']}');
        }
      } else if (response.statusCode == 404) {
        _showErrorSnackBar(SimpleTranslations.get(_langCode, 'product_not_found'));
      } else {
        _handleApiError(response, 'Failed to lookup product');
      }
    } catch (e) {
      _showErrorSnackBar('Error looking up product: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Form Operations
  Future<void> _createNewInventory() async {
  if (!_validateForm()) return;

  setState(() => _isSubmitting = true);

  try {
    final requestBody = _buildRequestBody();

    // ✅ Log the request body for debugging
    debugPrint('📦 DEBUG: Request Body: $requestBody');

    final response = await _makeApiRequest(
      '/api/inventory',
      method: 'POST',
      body: requestBody,
    );

    print('📡 DEBUG: Response Status: ${response.statusCode}');
    print('📝 DEBUG: Response Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      _showSuccessSnackBar(SimpleTranslations.get(_langCode, 'inventory_created_success'));
      _clearForm();
      _navigateToInventoryDashboard();
    } else {
      _handleApiError(response, 'Failed to create inventory');
    }
  } catch (e) {
    _handleCreateInventoryError(e);
  } finally {
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }
}


  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar(SimpleTranslations.get(_langCode, 'please_fill_required_fields'));
      return false;
    }

    if (_accessToken == null) {
      _showErrorSnackBar(SimpleTranslations.get(_langCode, 'auth_token_not_found'));
      return false;
    }

    // if (_userId == null || _branchId == null) {
    //   _showErrorSnackBar('User ID or Branch ID not found');
    //   return false;
    // }

    if (_selectedLocation == null) {
      _showErrorSnackBar(SimpleTranslations.get(_langCode, 'please_select_location'));
      return false;
    }

    if (_selectedStore == null) {
      _showErrorSnackBar(SimpleTranslations.get(_langCode, 'please_select_store'));
      return false;
    }

    return _validateNumericInputs();
  }


bool _validateNumericInputs() {
  final validations = [
    _validateField('productId', isInteger: true, required: true),
    // Allow 0 for stockQuantity (for defunct items)
    _validateField('stockQuantity', isInteger: true, required: true, nonNegative: true),
    // Allow 0 for minimumStock (for defunct items)
    _validateField('minimumStock', isInteger: true, required: true, nonNegative: true),
    // Allow 0 for costPrice (for defunct items)
    _validateField('costPrice', isDouble: true, required: true, nonNegative: true),
    // Allow 0 for unitPrice (for defunct items)
    _validateField('unitPrice', isDouble: true, required: true, nonNegative: true),
  ];

  return validations.every((isValid) => isValid);
}

  bool _validateField(String fieldKey, {
    bool isInteger = false,
    bool isDouble = false,
    bool required = false,
    bool positive = false,
    bool nonNegative = false,
  }) {
    final controller = _controllers[fieldKey]!;
    final value = controller.text.trim();

    if (required && value.isEmpty) {
      _showErrorSnackBar('Please enter a valid ${fieldKey.toLowerCase()}');
      return false;
    }

    if (value.isNotEmpty) {
      if (isInteger) {
        final intValue = int.tryParse(value);
        if (intValue == null || (positive && intValue <= 0) || (nonNegative && intValue < 0)) {
          _showErrorSnackBar('Please enter a valid ${fieldKey.toLowerCase()}');
          return false;
        }
      } else if (isDouble) {
        final doubleValue = double.tryParse(value);
        if (doubleValue == null || (nonNegative && doubleValue < 0)) {
          _showErrorSnackBar('Please enter a valid ${fieldKey.toLowerCase()}');
          return false;
        }
      }
    }

    return true;
  }

  Map<String, dynamic> _buildRequestBody() {
    return {
      'user_id': _userId,
      
      'barcode': _controllers['barcode']!.text.trim().isNotEmpty 
          ? _controllers['barcode']!.text.trim() : null,
      'product_id': int.parse(_controllers['productId']!.text),
      'location_id': _selectedLocation!['location_id'],
      'store_id': _selectedStore!['store_id'],
      'stock_quantity': int.parse(_controllers['stockQuantity']!.text),
      'minimum_stock': int.parse(_controllers['minimumStock']!.text),
      'reserved_quantity': _controllers['reservedQuantity']!.text.isEmpty 
          ? 0 : int.parse(_controllers['reservedQuantity']!.text),
      'cost_price_lak': double.parse(_controllers['costPrice']!.text),
      'unit_price_lak': double.parse(_controllers['unitPrice']!.text),
      'currency_primary': _selectedCurrency,
      'batch_number': _controllers['batchNumber']!.text.trim().isNotEmpty 
          ? _controllers['batchNumber']!.text.trim() : null,
      'supplier_id': _controllers['supplierId']!.text.trim().isNotEmpty 
          ? int.tryParse(_controllers['supplierId']!.text) : null,
      'expire_date': _selectedExpireDate?.toIso8601String().split('T')[0],
      'block_location': _controllers['blockLocation']!.text.trim().isNotEmpty 
          ? _controllers['blockLocation']!.text.trim() : null,
          "txntype": "Stock",
      'status': _selectedStatus,
    };
  }

  void _clearForm() {
    for (final controller in _controllers.values) {
      controller.clear();
    }
    setState(() {
      _selectedExpireDate = null;
      _selectedLocation = null;
      _selectedStore = null;
      _selectedCurrency = 'LAK';
      _selectedStatus = 'ACTIVE';
      _scannedProduct = null;
    });
  }

  // API Helper Methods
  Future<http.Response> _makeApiRequest(
    String endpoint, {
    required String method,
    Map<String, dynamic>? body,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    };

    switch (method.toUpperCase()) {
      case 'GET':
        return http.get(AppConfig.api(endpoint), headers: headers);
      case 'POST':
        return http.post(
          AppConfig.api(endpoint),
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }
  }

  void _handleApiError(http.Response response, String defaultMessage) {
    if (response.statusCode == 401) {
      _handleAuthError();
    } else {
      try {
        final errorData = json.decode(response.body);
        _showErrorSnackBar('$defaultMessage: ${errorData['message'] ?? 'Server error ${response.statusCode}'}');
      } catch (e) {
        _showErrorSnackBar('$defaultMessage: Server returned status ${response.statusCode}');
      }
    }
  }

  void _handleCreateInventoryError(dynamic error) {
    String message;
    if (error.toString().contains('SocketException') || 
        error.toString().contains('TimeoutException')) {
      message = SimpleTranslations.get(_langCode, 'network_error_check_connection');
    } else if (error.toString().contains('FormatException')) {
      message = SimpleTranslations.get(_langCode, 'invalid_data_format');
    } else {
      message = '${SimpleTranslations.get(_langCode, 'error_creating_inventory')}: $error';
    }
    _showErrorSnackBar(message);
  }

  void _handleAuthError() {
    _showErrorSnackBar(SimpleTranslations.get(_langCode, 'session_expired'));
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _navigateToInventoryDashboard() {
    if (!mounted) return;
    
    try {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/inventory-dashboard',
        (route) => false,
      );
    } catch (e) {
      try {
        Navigator.of(context).pushReplacementNamed('/inventory-dashboard');
      } catch (e2) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      }
    }
  }

  // UI Helper Methods
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: SimpleTranslations.get(_langCode, 'dismiss'),
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        SimpleTranslations.get(_langCode, 'add_new_inventory'),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _handleBackPress,
      ),
    );
  }

  void _handleBackPress() {
    if (_isSubmitting) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(SimpleTranslations.get(_langCode, 'confirm_exit')),
          content: Text(SimpleTranslations.get(_langCode, 'creating_inventory_exit_warning')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(SimpleTranslations.get(_langCode, 'stay')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              child: Text(SimpleTranslations.get(_langCode, 'exit')),
            ),
          ],
        ),
      );
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _primaryColor),
          const SizedBox(height: 16),
          Text(
            SimpleTranslations.get(_langCode, 'loading_data'),
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        if (_scannedProduct != null) _buildScannedProductInfo(),
        Expanded(child: _buildCreateForm()),
      ],
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
          _buildProductImage(),
          const SizedBox(width: 12),
          Expanded(child: _buildProductDetails()),
          IconButton(
            icon: Icon(Icons.close, color: Colors.grey[600]),
            onPressed: () {
              setState(() {
                _scannedProduct = null;
                _controllers['productId']!.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: _scannedProduct!['image_url'] != null && 
             _scannedProduct!['image_url'].toString().isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.network(
                _scannedProduct!['image_url'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildLoadingIcon();
                },
              ),
            )
          : _buildPlaceholderIcon(),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      color: Colors.green[100],
      child: Icon(Icons.inventory, color: Colors.green[600], size: 24),
    );
  }

  Widget _buildLoadingIcon() {
    return Container(
      color: Colors.green[100],
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
          ),
        ),
      ),
    );
  }

  Widget _buildProductDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 20),
            const SizedBox(width: 8),
            Text(
              SimpleTranslations.get(_langCode, 'scanned_product'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${SimpleTranslations.get(_langCode, 'product_name')}: ${_scannedProduct!['product_name'] ?? 'N/A'}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        Text(
          '${SimpleTranslations.get(_langCode, 'product_id')}: ${_scannedProduct!['product_id']}',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        if (_scannedProduct!['barcode'] != null)
          Text(
            'Barcode: ${_scannedProduct!['barcode']}',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
      ],
    );
  }

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              SimpleTranslations.get(_langCode, 'create_new_inventory_item'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildBarcodeSection(),
            const SizedBox(height: 16),
            _FastTextField(
              controller: _controllers['productId']!,
              label: SimpleTranslations.get(_langCode, 'product_id'),
              keyboardType: TextInputType.number,
              required: true,
              langCode: _langCode,
            ),
            const SizedBox(height: 16),
            _buildLocationDropdown(),
            const SizedBox(height: 16),
            _buildStoreDropdown(),
            const SizedBox(height: 16),
            _buildQuantitySection(),
            const SizedBox(height: 16),
            _buildPriceSection(),
            const SizedBox(height: 16),
            _buildOptionalFields(),
            const SizedBox(height: 16),
            _buildStatusSection(),
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBarcodeSection() {
    return Row(
      children: [
        Expanded(
          child: _FastTextField(
            controller: _controllers['barcode']!,
            label: 'Barcode *',
            keyboardType: TextInputType.text,
            required: true,
            langCode: _langCode,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            onPressed: _scanBarcode,
            tooltip: SimpleTranslations.get(_langCode, 'scan_barcode'),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantitySection() {
    return Row(
      children: [
        Expanded(
          child: _FastTextField(
            controller: _controllers['stockQuantity']!,
            label: SimpleTranslations.get(_langCode, 'stock_quantity'),
            keyboardType: TextInputType.number,
            required: true,
            langCode: _langCode,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _FastTextField(
            controller: _controllers['minimumStock']!,
            label: SimpleTranslations.get(_langCode, 'minimum_stock'),
            keyboardType: TextInputType.number,
            required: true,
            langCode: _langCode,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSection() {
    return Row(
      children: [
        Expanded(
          child: _FastTextField(
            controller: _controllers['costPrice']!,
            label: SimpleTranslations.get(_langCode, 'cost_price_lak'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            required: true,
            langCode: _langCode,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _FastTextField(
            controller: _controllers['unitPrice']!,
            label: SimpleTranslations.get(_langCode, 'unit_price_lak'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            required: true,
            langCode: _langCode,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionalFields() {
    return Column(
      children: [
        _FastTextField(
          controller: _controllers['reservedQuantity']!,
          label: SimpleTranslations.get(_langCode, 'reserved_quantity_optional'),
          keyboardType: TextInputType.number,
          langCode: _langCode,
        ),
        const SizedBox(height: 16),
        _FastTextField(
          controller: _controllers['batchNumber']!,
          label: SimpleTranslations.get(_langCode, 'batch_number_optional'),
          langCode: _langCode,
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Row(
      children: [
        Expanded(
          child: _FastDropdown(
            value: _selectedCurrency,
            label: SimpleTranslations.get(_langCode, 'currency'),
            items: const ['LAK', 'THB'],
            onChanged: (value) => setState(() => _selectedCurrency = value!),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _FastDropdown(
            value: _selectedStatus,
            label: SimpleTranslations.get(_langCode, 'status'),
            items: const ['ACTIVE', 'INACTIVE', 'RESERVED'],
            onChanged: (value) => setState(() => _selectedStatus = value!),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _createNewInventory,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isSubmitting ? Colors.grey : _primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: _isSubmitting ? 0 : 2,
        ),
        child: _isSubmitting ? _buildSubmittingContent() : _buildSubmitContent(),
      ),
    );
  }

  Widget _buildSubmittingContent() {
    return Row(
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
          SimpleTranslations.get(_langCode, 'creating_inventory'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSubmitContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_box, size: 24),
        const SizedBox(width: 8),
        Text(
          SimpleTranslations.get(_langCode, 'create_inventory_item'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // Dropdown builders remain the same as they were well-structured
  Widget _buildLocationDropdown() {
    return _DropdownField<Map<String, dynamic>>(
      value: _selectedLocation,
      label: SimpleTranslations.get(_langCode, 'location'),
      hint: 'Select location',
      items: _locations,
      isLoading: _isLoadingLocations,
      loadingText: 'Loading locations...',
      onChanged: (value) => setState(() => _selectedLocation = value),
      itemBuilder: (location) => _buildLocationItem(location),
      validator: () => _selectedLocation == null ? 'Location is required' : null,
    );
  }

  Widget _buildStoreDropdown() {
    return _DropdownField<Map<String, dynamic>>(
      value: _selectedStore,
      label: SimpleTranslations.get(_langCode, 'store'),
      hint: 'Select store',
      items: _stores,
      isLoading: _isLoadingStores,
      loadingText: 'Loading stores...',
      onChanged: (value) => setState(() => _selectedStore = value),
      itemBuilder: (store) => _buildStoreItem(store),
      validator: () => _selectedStore == null ? 'Store is required' : null,
    );
  }

  Widget _buildLocationItem(Map<String, dynamic> location) {
    return Row(
      children: [
        _buildItemImage(location['image_url'], Icons.location_on),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            location['location'] ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreItem(Map<String, dynamic> store) {
    return Row(
      children: [
        _buildItemImage(store['image_url'], Icons.store),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            store['store_name'] ?? store['name'] ?? 'Unknown Store',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildItemImage(String? imageUrl, IconData fallbackIcon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(fallbackIcon),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildLoadingIndicator();
                },
              ),
            )
          : _buildFallbackIcon(fallbackIcon),
    );
  }

  Widget _buildFallbackIcon(IconData icon) {
    return Container(
      color: Colors.grey[100],
      child: Icon(icon, color: Colors.grey[400], size: 16),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      color: Colors.grey[100],
      child: const Center(
        child: SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      ),
    );
  }
}

// Generic Dropdown Field Widget
class _DropdownField<T> extends StatelessWidget {
  final T? value;
  final String label;
  final String hint;
  final List<T> items;
  final bool isLoading;
  final String loadingText;
  final ValueChanged<T?> onChanged;
  final Widget Function(T) itemBuilder;
  final String? Function()? validator;

  const _DropdownField({
    required this.value,
    required this.label,
    required this.hint,
    required this.items,
    required this.isLoading,
    required this.loadingText,
    required this.onChanged,
    required this.itemBuilder,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label *',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: isLoading ? _buildLoadingContent() : _buildDropdown(),
        ),
        if (validator != null && validator!() != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8),
            child: Text(
              validator!()!,
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(loadingText),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        hint: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(hint),
        ),
        isExpanded: true,
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: itemBuilder(item),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
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

class _BarcodeScannerPageState extends State<BarcodeScannerPage>
    with WidgetsBindingObserver {
  late MobileScannerController _cameraController;
  bool _isScanned = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.dispose();
    super.dispose();
  }

  void _initializeCamera() {
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _cameraController.stop();
        break;
      case AppLifecycleState.resumed:
        _cameraController.start();
        break;
      case AppLifecycleState.inactive:
        break;
    }
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
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.pop(context, barcodes.first.rawValue);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: !_isInitialized ? _buildInitializingState() : _buildScannerContent(),
    );
  }

  Widget _buildInitializingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: widget.primaryColor),
          const SizedBox(height: 16),
          Text(
            SimpleTranslations.get(widget.langCode, 'initializing_camera'),
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerContent() {
    return Stack(
      children: [
        MobileScanner(
          controller: _cameraController,
          onDetect: _onDetect,
          errorBuilder: _buildErrorState,
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
        _buildBottomInstructions(),
      ],
    );
  }

  // FIXED: Updated errorBuilder signature for mobile_scanner 7.0.1
  Widget _buildErrorState(BuildContext context, MobileScannerException error) {
    return Container(
      color: Colors.black,
      child: Center(
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
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              SimpleTranslations.get(widget.langCode, 'barcode_detected'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInstructions() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
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
              SimpleTranslations.get(widget.langCode, 'scan_instruction'),
              style: const TextStyle(
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
                  SimpleTranslations.get(widget.langCode, 'cancel'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Scanner Overlay Painter
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
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final scanAreaPath = Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: scanAreaSize,
            height: scanAreaSize,
          ),
          const Radius.circular(12),
        ),
      );

    final overlayPath = Path.combine(PathOperation.difference, backgroundPath, scanAreaPath);
    canvas.drawPath(overlayPath, Paint()..color = Colors.black.withOpacity(0.5));

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
    
    // Draw all four corners
    _drawCorner(canvas, paint, scanRect.topLeft, cornerLength, true, true);
    _drawCorner(canvas, paint, scanRect.topRight, cornerLength, false, true);
    _drawCorner(canvas, paint, scanRect.bottomLeft, cornerLength, true, false);
    _drawCorner(canvas, paint, scanRect.bottomRight, cornerLength, false, false);
  }

  void _drawCorner(Canvas canvas, Paint paint, Offset corner, double length, 
                  bool isLeft, bool isTop) {
    final horizontalStart = isLeft ? corner : Offset(corner.dx - length, corner.dy);
    final horizontalEnd = isLeft ? Offset(corner.dx + length, corner.dy) : corner;
    
    final verticalStart = isTop ? corner : Offset(corner.dx, corner.dy - length);
    final verticalEnd = isTop ? Offset(corner.dx, corner.dy + length) : corner;

    canvas.drawLine(horizontalStart, horizontalEnd, paint);
    canvas.drawLine(verticalStart, verticalEnd, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Optimized custom widgets
class _FastTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool required;
  final String langCode;

  const _FastTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.required = false,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: _getInputFormatters(),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: required ? _validator : null,
    );
  }

  List<TextInputFormatter>? _getInputFormatters() {
    if (keyboardType == TextInputType.number) {
      return [FilteringTextInputFormatter.digitsOnly];
    } else if (keyboardType == const TextInputType.numberWithOptions(decimal: true)) {
      return [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))];
    }
    return null;
  }

  String? _validator(String? value) {
    if (value == null || value.isEmpty) {
      return SimpleTranslations.get(langCode, 'field_required');
    }

    if (keyboardType == TextInputType.number && int.tryParse(value) == null) {
      return SimpleTranslations.get(langCode, 'enter_valid_number');
    }

    if (keyboardType == const TextInputType.numberWithOptions(decimal: true) && 
        double.tryParse(value) == null) {
      return SimpleTranslations.get(langCode, 'enter_valid_price');
    }

    return null;
  }
}

class _FastDropdown extends StatelessWidget {
  final String value;
  final String label;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _FastDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
              value: value,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}