import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:inventory/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/company_config.dart';
import '../utils/simple_translations.dart';

class ProductPage extends StatefulWidget {
  final String? currentTheme;
  final int? companyId;
  final int? userId;
  final int? branchId;
  
  const ProductPage({
    Key? key, 
    this.currentTheme,
    this.companyId,
    this.userId,
    this.branchId
  }) : super(key: key);

  @override
  State<ProductPage> createState() => _ProductPageState();
}

String langCode = 'en';

class _ProductPageState extends State<ProductPage> with TickerProviderStateMixin {
  // Constants
  static const double _breakpointWidth = 600.0;
  static const double _maxContentWidth = 1200.0;
  static const Duration _animationDuration = Duration(milliseconds: 600);
  
  // Auth & State
  String? _accessToken;
  int? _companyId;
  String _currentTheme = ThemeConfig.defaultTheme;
  
  // Data
  List<Map<String, dynamic>> _products = [];
  String _searchQuery = '';
  String? _selectedStockStatus;
  String? _selectedCurrency;
  
  // Loading states
  bool _isLoading = true;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  
  // Controllers
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('ProductPage initState() called');
    debugPrint('Language code: $langCode');
    
    _initializeControllers();
    _loadLangCode();
    _loadCurrentTheme();
    _initializeAuth();
  }

  @override
  void dispose() {
    print('ProductPage dispose() called');
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Initialization
  void _initializeControllers() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
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
      _currentTheme = widget.currentTheme ?? 
                     prefs.getString('selectedTheme') ?? 
                     ThemeConfig.defaultTheme;
      print('Theme loaded: $_currentTheme');
    });
  }

  // Authentication & Data Loading
  Future<void> _initializeAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _companyId = widget.companyId ?? CompanyConfig.getCompanyId();
    
    if (_accessToken != null && _companyId != null) {
      await _loadProductData();
    } else {
      _showError(SimpleTranslations.get(langCode, 'auth_error'));
    }
  }

  Future<void> _loadProductData() async {
    setState(() => _isLoading = true);

    try {
      await _fetchProducts();
      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      _showError('${SimpleTranslations.get(langCode, 'load_error')}: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProducts() async {
    if (_accessToken == null || _companyId == null) return;
    
    final response = await http.get(
      AppConfig.api('/api/ioview/products?company_id=$_companyId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        setState(() {
          _products = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
      } else {
        _showError('${SimpleTranslations.get(langCode, 'fetch_error')}: ${data['message'] ?? SimpleTranslations.get(langCode, 'unknown_error')}');
      }
    } else if (response.statusCode == 401) {
      _showError(SimpleTranslations.get(langCode, 'session_expired'));
    } else {
      _showError('${SimpleTranslations.get(langCode, 'http_error')}: ${response.statusCode}');
    }
  }

  Future<void> _refresh() async {
    print('Refresh triggered');
    await _loadProductData();
  }

  // UI Helpers
  bool get _isWideScreen => MediaQuery.of(context).size.width > _breakpointWidth;
  
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ThemeConfig.getThemeColors(_currentTheme)['error'] ?? Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Stock Status Logic
  Color _getStockStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'in stock':
      case 'available':
        return Colors.green;
      case 'warning':
      case 'low stock':
        return Colors.orange;
      case 'out of stock':
      case 'unavailable':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStockStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'in stock':
      case 'available':
        return Icons.check_circle;
      case 'warning':
      case 'low stock':
        return Icons.warning;
      case 'out of stock':
      case 'unavailable':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  // Filter Logic
  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((product) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final name = product['product_name']?.toString().toLowerCase() ?? '';
        if (!name.contains(_searchQuery.toLowerCase())) return false;
      }
      
      // Stock status filter
      if (_selectedStockStatus != null) {
        final stockStatus = product['stock_status']?.toString();
        if (stockStatus != _selectedStockStatus) return false;
      }
      
      // Currency filter
      if (_selectedCurrency != null) {
        final currency = product['currency_primary']?.toString();
        if (currency != _selectedCurrency) return false;
      }
      
      return true;
    }).toList();
  }

  List<String> _getUniqueValues(String field) {
    final values = _products
        .map((product) => product[field]?.toString())
        .where((value) => value != null && value.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  Map<String, int> get _stockCounts {
    final counts = <String, int>{
      'total': _products.length,
      'filtered': _filteredProducts.length,
      'in_stock': 0,
      'warning': 0,
      'out_of_stock': 0,
    };
    
    for (final product in _products) {
      final status = product['stock_status']?.toString().toLowerCase();
      switch (status) {
        case 'in stock':
        case 'available':
          counts['in_stock'] = counts['in_stock']! + 1;
          break;
        case 'warning':
        case 'low stock':
          counts['warning'] = counts['warning']! + 1;
          break;
        case 'out of stock':
        case 'unavailable':
          counts['out_of_stock'] = counts['out_of_stock']! + 1;
          break;
      }
    }
    return counts;
  }

  void _onSearchChanged(String value) {
    print('Search query: $value');
    setState(() => _searchQuery = value);
  }

  void _clearFilters() {
    print('Clearing all filters');
    setState(() {
      _searchQuery = '';
      _selectedStockStatus = null;
      _selectedCurrency = null;
      _searchController.clear();
    });
  }

  // UI Builders
  @override
  Widget build(BuildContext context) {
    print('Building ProductPage widget');
    print('Current state - loading: $_isLoading, products: ${_products.length}');
    
    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(_currentTheme),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: ThemeConfig.getPrimaryColor(_currentTheme),
        child: _isLoading ? _buildLoadingView() : _buildContent(),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        '${SimpleTranslations.get(langCode, 'products')} (${_filteredProducts.length})',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: _isWideScreen ? 22 : 18,
        ),
      ),
      elevation: 0,
      backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
      foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
      centerTitle: !kIsWeb,
      actions: [
        IconButton(
          onPressed: () {
            print('Refresh button pressed from app bar');
            _refresh();
          },
          icon: const Icon(Icons.refresh),
          tooltip: SimpleTranslations.get(langCode, 'refresh'),
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    print('Showing loading indicator');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: _isWideScreen ? 60 : 40,
            height: _isWideScreen ? 60 : 40,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                ThemeConfig.getPrimaryColor(_currentTheme),
              ),
            ),
          ),
          SizedBox(height: _isWideScreen ? 24 : 16),
          Text(
            SimpleTranslations.get(langCode, 'loading_products'),
            style: TextStyle(
              fontSize: _isWideScreen ? 18 : 16,
              color: ThemeConfig.getTextColor(_currentTheme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isWideScreen) {
      return SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Column(
              children: [
                _buildSearchAndFilters(),
                _buildProductSummary(),
                const SizedBox(height: 16),
                SizedBox(
                  height: MediaQuery.of(context).size.height - 280,
                  child: _buildProductsList(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Column(
      children: [
        _buildSearchAndFilters(),
        _buildProductSummary(),
        const SizedBox(height: 16),
        Expanded(child: _buildProductsList()),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    // Get responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final horizontalPadding = isWideScreen ? 32.0 : 16.0;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
      child: Column(
        children: [
          _buildSearchBar(),
          SizedBox(height: _isWideScreen ? 16 : 12),
          _buildFilterChips(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        labelText: SimpleTranslations.get(langCode, 'search_products'),
        prefixIcon: Icon(
          Icons.search,
          color: ThemeConfig.getPrimaryColor(_currentTheme),
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                onPressed: () {
                  print('Clear search button pressed');
                  _searchController.clear();
                  _onSearchChanged('');
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
            color: ThemeConfig.getPrimaryColor(_currentTheme),
            width: 2,
          ),
        ),
      ),
      style: TextStyle(
        fontSize: _isWideScreen ? 16 : 14,
        color: ThemeConfig.getTextColor(_currentTheme),
      ),
    );
  }

  Widget _buildFilterChips() {
    if (_isWideScreen) {
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _buildFilterChip(
            SimpleTranslations.get(langCode, 'stock_status'),
            _selectedStockStatus,
            _getUniqueValues('stock_status'),
            (value) => setState(() => _selectedStockStatus = value),
            Icons.inventory,
          ),
          _buildFilterChip(
            SimpleTranslations.get(langCode, 'currency'),
            _selectedCurrency,
            _getUniqueValues('currency_primary'),
            (value) => setState(() => _selectedCurrency = value),
            Icons.monetization_on,
          ),
          if (_hasActiveFilters) _buildClearFiltersChip(),
        ],
      );
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            SimpleTranslations.get(langCode, 'stock_status'),
            _selectedStockStatus,
            _getUniqueValues('stock_status'),
            (value) => setState(() => _selectedStockStatus = value),
            Icons.inventory,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            SimpleTranslations.get(langCode, 'currency'),
            _selectedCurrency,
            _getUniqueValues('currency_primary'),
            (value) => setState(() => _selectedCurrency = value),
            Icons.monetization_on,
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(width: 8),
            _buildClearFiltersChip(),
          ],
        ],
      ),
    );
  }

  bool get _hasActiveFilters => 
      _searchQuery.isNotEmpty || _selectedStockStatus != null || _selectedCurrency != null;

  Widget _buildFilterChip(
    String label,
    String? selectedValue,
    List<String> options,
    Function(String?) onSelected,
    IconData icon,
  ) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: 16, 
            color: selectedValue != null ? ThemeConfig.getPrimaryColor(_currentTheme) : Colors.grey[600]
          ),
          const SizedBox(width: 4),
          Text(
            selectedValue ?? label,
            style: TextStyle(
              fontSize: _isWideScreen ? 14 : 12,
              color: selectedValue != null ? ThemeConfig.getPrimaryColor(_currentTheme) : ThemeConfig.getTextColor(_currentTheme),
            ),
          ),
        ],
      ),
      selected: selectedValue != null,
      onSelected: (selected) {
        if (selected && options.isNotEmpty) {
          _showFilterDialog(label, options, onSelected);
        } else {
          onSelected(null);
        }
      },
      selectedColor: ThemeConfig.getPrimaryColor(_currentTheme).withOpacity(0.2),
      backgroundColor: ThemeConfig.getBackgroundColor(_currentTheme),
      side: BorderSide(
        color: selectedValue != null ? ThemeConfig.getPrimaryColor(_currentTheme) : Colors.grey.withOpacity(0.3),
      ),
    );
  }

  Widget _buildClearFiltersChip() {
    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.clear, size: 16, color: Colors.red),
          const SizedBox(width: 4),
          Text(
            SimpleTranslations.get(langCode, 'clear_filters'),
            style: TextStyle(
              fontSize: _isWideScreen ? 14 : 12,
              color: Colors.red,
            ),
          ),
        ],
      ),
      onPressed: _clearFilters,
      backgroundColor: Colors.red.shade50,
      side: BorderSide(color: Colors.red.shade200),
    );
  }

  void _showFilterDialog(
    String title,
    List<String> options,
    Function(String?) onSelected,
  ) {
    if (_isWideScreen) {
      // Desktop/Web: Show dialog
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: ThemeConfig.getBackgroundColor(_currentTheme),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
            child: _buildFilterDialogContent(title, options, onSelected),
          ),
        ),
      );
    } else {
      // Mobile: Show bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: ThemeConfig.getBackgroundColor(_currentTheme),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _buildFilterDialogContent(title, options, onSelected),
        ),
      );
    }
  }

  Widget _buildFilterDialogContent(
    String title,
    List<String> options,
    Function(String?) onSelected,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_isWideScreen) _buildDragHandle(),
        Padding(
          padding: EdgeInsets.all(_isWideScreen ? 24 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${SimpleTranslations.get(langCode, 'select')} $title',
                style: TextStyle(
                  fontSize: _isWideScreen ? 20 : 18,
                  fontWeight: FontWeight.bold,
                  color: ThemeConfig.getTextColor(_currentTheme),
                ),
              ),
              SizedBox(height: _isWideScreen ? 20 : 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    return ListTile(
                      title: Text(
                        option,
                        style: TextStyle(color: ThemeConfig.getTextColor(_currentTheme)),
                      ),
                      onTap: () {
                        onSelected(option);
                        Navigator.pop(context);
                      },
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: _isWideScreen ? 16 : 8,
                        vertical: 4,
                      ),
                      hoverColor: ThemeConfig.getPrimaryColor(_currentTheme).withOpacity(0.1),
                    );
                  },
                ),
              ),
              SizedBox(height: _isWideScreen ? 20 : 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        onSelected(null);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: ThemeConfig.getPrimaryColor(_currentTheme)),
                        foregroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
                      ),
                      child: Text(SimpleTranslations.get(langCode, 'clear')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
                        foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
                      ),
                      child: Text(SimpleTranslations.get(langCode, 'cancel')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDragHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildProductSummary() {
    final counts = _stockCounts;
    
    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: _isWideScreen ? 24 : 16),
        padding: EdgeInsets.all(_isWideScreen ? 20 : 16),
        decoration: BoxDecoration(
          color: ThemeConfig.getBackgroundColor(_currentTheme),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(_isWideScreen ? 16 : 12),
              decoration: BoxDecoration(
                color: ThemeConfig.getPrimaryColor(_currentTheme).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.inventory_2,
                color: ThemeConfig.getPrimaryColor(_currentTheme),
                size: _isWideScreen ? 28 : 24,
              ),
            ),
            SizedBox(width: _isWideScreen ? 20 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    SimpleTranslations.get(langCode, 'products_summary'),
                    style: TextStyle(
                      fontSize: _isWideScreen ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: ThemeConfig.getTextColor(_currentTheme),
                    ),
                  ),
                  SizedBox(height: _isWideScreen ? 6 : 4),
                  Text(
                    '${SimpleTranslations.get(langCode, 'showing')} ${counts['filtered']} ${SimpleTranslations.get(langCode, 'of')} ${counts['total']} ${SimpleTranslations.get(langCode, 'products')}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: _isWideScreen ? 16 : 14,
                    ),
                  ),
                ],
              ),
            ),
            _buildStatusIndicators(counts),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicators(Map<String, int> counts) {
    return Column(
      children: [
        _buildStatusDot(Colors.green, counts['in_stock']!),
        SizedBox(height: _isWideScreen ? 6 : 4),
        _buildStatusDot(Colors.orange, counts['warning']!),
        SizedBox(height: _isWideScreen ? 6 : 4),
        _buildStatusDot(Colors.red, counts['out_of_stock']!),
      ],
    );
  }

  Widget _buildStatusDot(Color color, int count) {
    return Row(
      children: [
        Container(
          width: _isWideScreen ? 10 : 8,
          height: _isWideScreen ? 10 : 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: _isWideScreen ? 6 : 4),
        Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: _isWideScreen ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildProductsList() {
    final filteredProducts = _filteredProducts;
    
    if (filteredProducts.isEmpty) {
      return _buildEmptyState();
    }

    final crossAxisCount = _isWideScreen ? (MediaQuery.of(context).size.width > 1200 ? 3 : 2) : 1;
    
    if (_isWideScreen) {
      return GridView.builder(
        padding: EdgeInsets.all(_isWideScreen ? 24 : 16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 3.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: filteredProducts.length,
        itemBuilder: (context, index) => _buildProductCard(filteredProducts[index], index),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(_isWideScreen ? 24 : 16),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) => _buildProductCard(filteredProducts[index], index),
    );
  }

  Widget _buildEmptyState() {
    print('Showing empty state');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: _isWideScreen ? 80 : 64,
            color: Colors.grey,
          ),
          SizedBox(height: _isWideScreen ? 20 : 16),
          Text(
            _hasActiveFilters 
                ? SimpleTranslations.get(langCode, 'no_products_match_filters') 
                : SimpleTranslations.get(langCode, 'no_products_found'),
            style: TextStyle(
              fontSize: _isWideScreen ? 18 : 16,
              color: Colors.grey,
            ),
          ),
          if (_hasActiveFilters) ...[
            SizedBox(height: _isWideScreen ? 16 : 12),
            ElevatedButton(
              onPressed: _clearFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
                foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
              ),
              child: Text(SimpleTranslations.get(langCode, 'clear_filters')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, int index) {
    print('Building product card for: ${product['product_name']}');
    final stockStatus = product['stock_status']?.toString() ?? 'unknown';
    final statusColor = _getStockStatusColor(stockStatus);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Interval((index * 0.1).clamp(0.0, 1.0), 1.0, curve: Curves.easeOut),
      )),
      child: Card(
        margin: EdgeInsets.only(bottom: _isWideScreen ? 0 : 12),
        elevation: 2,
        color: Colors.grey[200],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showProductDetails(product),
          child: Padding(
            padding: EdgeInsets.all(_isWideScreen ? 20 : 16),
            child: Row(
              children: [
                _buildProductImage(product),
                SizedBox(width: _isWideScreen ? 20 : 16),
                Expanded(child: _buildProductInfo(product)),
                _buildStatusBadge(product),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(Map<String, dynamic> product) {
    print('Building image for product: ${product['product_name']}');
    final size = _isWideScreen ? 70.0 : 60.0;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: _buildImageContent(product, size),
    );
  }

  Widget _buildImageContent(Map<String, dynamic> product, double size) {
    final imageUrl = product['image_url'];
    if (imageUrl != null && !imageUrl.toString().contains('undefined')) {
      String finalImageUrl = imageUrl.toString();
      
      // Handle relative URLs like in GroupPage
      if (!finalImageUrl.startsWith('http')) {
        final baseUrl = AppConfig.api('').toString().replaceAll('/api', '');
        
        if (finalImageUrl.startsWith('/')) {
          finalImageUrl = '$baseUrl$finalImageUrl';
        } else {
          finalImageUrl = '$baseUrl/$finalImageUrl';
        }
      }
      
      print('Final image URL: $finalImageUrl');
      
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          finalImageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              print('Image loaded successfully for ${product['product_name']}');
              return child;
            }
            print('Loading image for ${product['product_name']}...');
            return Center(
              child: SizedBox(
                width: size * 0.3,
                height: size * 0.3,
                child: CircularProgressIndicator(
                  color: ThemeConfig.getPrimaryColor(_currentTheme),
                  strokeWidth: 2,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Error loading image for ${product['product_name']}: $error');
            print('Failed URL: $finalImageUrl');
            return _buildFallbackIcon(size);
          },
        ),
      );
    }
    return _buildFallbackIcon(size);
  }

  Widget _buildFallbackIcon(double size) {
    return Icon(
      Icons.inventory_2,
      size: size * 0.5,
      color: Colors.grey[600],
    );
  }

  Widget _buildProductInfo(Map<String, dynamic> product) {
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            product['product_name'] ?? SimpleTranslations.get(langCode, 'unknown_product'),
            style: TextStyle(
              fontSize: _isWideScreen ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: ThemeConfig.getTextColor(_currentTheme),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: _isWideScreen ? 6 : 4),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: _isWideScreen ? 8 : 6,
              vertical: _isWideScreen ? 4 : 2,
            ),
            decoration: BoxDecoration(
              color: ThemeConfig.getPrimaryColor(_currentTheme).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: ThemeConfig.getPrimaryColor(_currentTheme).withOpacity(0.3)),
            ),
            child: Text(
              '${product['currency_primary'] ?? 'N/A'} ${product['total_value'] ?? '0'}',
              style: TextStyle(
                fontSize: _isWideScreen ? 14 : 12,
                color: ThemeConfig.getPrimaryColor(_currentTheme),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Map<String, dynamic> product) {
    final stockStatus = product['stock_status']?.toString() ?? 'unknown';
    final statusColor = _getStockStatusColor(stockStatus);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isWideScreen ? 12 : 8,
        vertical: _isWideScreen ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStockStatusIcon(stockStatus),
            size: _isWideScreen ? 18 : 14,
            color: statusColor,
          ),
          SizedBox(height: _isWideScreen ? 4 : 2),
          Text(
            '${SimpleTranslations.get(langCode, 'qty')}: ${product['total_amount'] ?? '0'}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: _isWideScreen ? 12 : 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showProductDetails(Map<String, dynamic> product) {
    print('Product tapped: ${product['product_name']}');
    final stockStatus = product['stock_status']?.toString() ?? 'unknown';
    
    if (kIsWeb && _isWideScreen) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: ThemeConfig.getBackgroundColor(_currentTheme),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            child: _buildProductDetailsContent(product, stockStatus),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: ThemeConfig.getBackgroundColor(_currentTheme),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _buildProductDetailsContent(product, stockStatus),
        ),
      );
    }
  }

  Widget _buildProductDetailsContent(Map<String, dynamic> product, String stockStatus) {
    final statusColor = _getStockStatusColor(stockStatus);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!kIsWeb || !_isWideScreen) _buildDragHandle(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(_isWideScreen ? 24 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailsHeader(product, stockStatus, statusColor),
                SizedBox(height: _isWideScreen ? 32 : 24),
                _buildDetailSection(
                  SimpleTranslations.get(langCode, 'product_information'),
                  _buildProductDetailRows(product, stockStatus),
                ),
                SizedBox(height: _isWideScreen ? 32 : 24),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsHeader(Map<String, dynamic> product, String stockStatus, Color statusColor) {
    final imageSize = _isWideScreen ? 100.0 : 80.0;
    
    return Row(
      children: [
        Container(
          width: imageSize,
          height: imageSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: ThemeConfig.getBackgroundColor(_currentTheme),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: _buildImageContent(product, imageSize),
        ),
        SizedBox(width: _isWideScreen ? 20 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product['product_name'] ?? SimpleTranslations.get(langCode, 'unknown_product'),
                style: TextStyle(
                  fontSize: _isWideScreen ? 24 : 20,
                  fontWeight: FontWeight.bold,
                  color: ThemeConfig.getTextColor(_currentTheme),
                ),
              ),
              SizedBox(height: _isWideScreen ? 8 : 4),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _isWideScreen ? 12 : 8,
                  vertical: _isWideScreen ? 6 : 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(
                  stockStatus.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: _isWideScreen ? 14 : 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildProductDetailRows(Map<String, dynamic> product, String stockStatus) {
    final details = [
      (SimpleTranslations.get(langCode, 'company_id'), product['company_id']?.toString() ?? 'N/A', Icons.business),
      (SimpleTranslations.get(langCode, 'record_count'), product['record_count']?.toString() ?? 'N/A', Icons.numbers),
      (SimpleTranslations.get(langCode, 'total_amount'), product['total_amount']?.toString() ?? 'N/A', Icons.calculate),
      (SimpleTranslations.get(langCode, 'total_value'), '${product['currency_primary'] ?? ''} ${product['total_value'] ?? 'N/A'}', Icons.monetization_on),
      (SimpleTranslations.get(langCode, 'stock_status'), stockStatus, Icons.inventory),
    ];

    return details
        .map((detail) => Padding(
              padding: EdgeInsets.only(bottom: _isWideScreen ? 16 : 12),
              child: _buildDetailRow(detail.$1, detail.$2, detail.$3),
            ))
        .toList();
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: _isWideScreen ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: ThemeConfig.getTextColor(_currentTheme),
          ),
        ),
        SizedBox(height: _isWideScreen ? 12 : 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(_isWideScreen ? 20 : 16),
          decoration: BoxDecoration(
            color: ThemeConfig.getBackgroundColor(_currentTheme),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon, 
          size: _isWideScreen ? 20 : 18, 
          color: ThemeConfig.getPrimaryColor(_currentTheme),
        ),
        SizedBox(width: _isWideScreen ? 12 : 8),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: _isWideScreen ? 16 : 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: _isWideScreen ? 12 : 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: _isWideScreen ? 16 : 14,
              fontWeight: FontWeight.w600,
              color: ThemeConfig.getTextColor(_currentTheme),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to edit product page
            },
            icon: const Icon(Icons.edit),
            label: Text(SimpleTranslations.get(langCode, 'edit_product')),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
              foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
              padding: EdgeInsets.symmetric(vertical: _isWideScreen ? 16 : 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        SizedBox(width: _isWideScreen ? 16 : 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to inventory/stock page for this product
            },
            icon: const Icon(Icons.inventory),
            label: Text(SimpleTranslations.get(langCode, 'view_inventory')),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: _isWideScreen ? 16 : 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: BorderSide(color: ThemeConfig.getPrimaryColor(_currentTheme)),
              foregroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildFAB() {
    if (_isWideScreen) return null;
    
    return FloatingActionButton(
      onPressed: () {
        print('Add Product FAB pressed');
        // TODO: Navigate to add product page
      },
      backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
      foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
      tooltip: SimpleTranslations.get(langCode, 'add_product'),
      child: const Icon(Icons.add),
    );
  }
}