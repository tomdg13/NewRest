import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:inventory/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/company_config.dart';
import '../utils/simple_translations.dart';

class LocationPage extends StatefulWidget {
  final String? currentTheme;
  final int? companyId;
  final int? userId;
  final int? branchId;
  
  const LocationPage({
    Key? key, 
    this.currentTheme,
    this.companyId,
    this.userId,
    this.branchId
  }) : super(key: key);

  @override
  State<LocationPage> createState() => _LocationPageState();
}

String langCode = 'en';

class _LocationPageState extends State<LocationPage> with TickerProviderStateMixin {
  // Constants
  static const double _breakpointWidth = 600.0;
  static const double _maxContentWidth = 1200.0;
  static const Duration _animationDuration = Duration(milliseconds: 600);
  
  // Auth & State
  String? _accessToken;
  int? _companyId;
  int? _userId;
  int? _branchId;
  String _currentTheme = ThemeConfig.defaultTheme;
  
  // Data
  List<Map<String, dynamic>> _locationItems = [];
  String? _selectedFilter;
  
  // Loading states
  bool _isLoading = true;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  
  @override
  void initState() {
    super.initState();
    print('LocationPage initState() called');
    debugPrint('Language code: $langCode');
    
    _initializeControllers();
    _loadLangCode();
    _loadCurrentTheme();
    _initializeAuth();
  }

  @override
  void dispose() {
    print('LocationPage dispose() called');
    _fadeController.dispose();
    _slideController.dispose();
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
    _userId = widget.userId ?? _parseId(prefs, ['user_id', 'userId', 'user']);
    _branchId = widget.branchId ?? _parseId(prefs, ['branch_id', 'branchId', 'branch']);
    
    print('Token: ${_accessToken != null ? '${_accessToken!.substring(0, 20)}...' : 'null'}');
    print('Company ID: $_companyId');
    print('User ID: $_userId');
    print('Branch ID: $_branchId');
    
    if (_accessToken != null && _companyId != null) {
      await _loadDashboardData();
    } else {
      _showError(SimpleTranslations.get(langCode, 'auth_error'));
    }
  }

  int? _parseId(SharedPreferences prefs, List<String> keys) {
    for (final key in keys) {
      final value = prefs.getString(key);
      if (value != null) {
        return int.tryParse(value);
      }
    }
    return null;
  }

  Future<void> _loadDashboardData() async {
    print('Starting _loadDashboardData()');
    setState(() => _isLoading = true);

    try {
      await _fetchLocationItems();
      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      print('Error loading dashboard data: $e');
      _showError('${SimpleTranslations.get(langCode, 'load_error')}: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLocationItems() async {
    if (_accessToken == null || _companyId == null) return;
    
    final url = AppConfig.api('/api/ioview/locations?company_id=$_companyId');
    print('API URL: $url');
    
    try {
      final response = await http.get(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _locationItems = List<Map<String, dynamic>>.from(data['data'] ?? []);
          });
          print('Location items loaded: ${_locationItems.length}');
        } else {
          print('API returned error: ${data['message']}');
          _showError('${SimpleTranslations.get(langCode, 'fetch_error')}: ${data['message'] ?? SimpleTranslations.get(langCode, 'unknown_error')}');
        }
      } else if (response.statusCode == 401) {
        _showError(SimpleTranslations.get(langCode, 'session_expired'));
      } else {
        _showError('${SimpleTranslations.get(langCode, 'http_error')}: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception in _fetchLocationItems: $e');
      _showError('${SimpleTranslations.get(langCode, 'fetch_error')}: $e');
    }
  }

  Future<void> _refresh() async {
    print('Refresh triggered');
    await _loadDashboardData();
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
  String _getStockStatus(Map<String, dynamic> item) {
    return item['stock_status']?.toString() ?? SimpleTranslations.get(langCode, 'unknown_status');
  }

  Color _getStockStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'good': return Colors.green;
      case 'warning': return Colors.orange;
      case 'critical': return Colors.red;
      case 'out of stock': return Colors.red.shade800;
      default: return Colors.grey;
    }
  }

  IconData _getStockStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'good': return Icons.check_circle;
      case 'warning': return Icons.warning;
      case 'critical': return Icons.error;
      case 'out of stock': return Icons.remove_circle;
      default: return Icons.inventory;
    }
  }

  // Stock Counts
  Map<String, int> get _stockCounts {
    final counts = <String, int>{
      'total': _locationItems.length,
      'good': 0,
      'warning': 0,
      'critical': 0,
      'out_of_stock': 0,
    };
    
    for (final item in _locationItems) {
      final status = _getStockStatus(item).toLowerCase();
      switch (status) {
        case 'good': counts['good'] = counts['good']! + 1; break;
        case 'warning': counts['warning'] = counts['warning']! + 1; break;
        case 'critical': counts['critical'] = counts['critical']! + 1; break;
        case 'out of stock': counts['out_of_stock'] = counts['out_of_stock']! + 1; break;
      }
    }
    return counts;
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedFilter == null) return _locationItems;
    return _locationItems.where((item) {
      return _getStockStatus(item).toLowerCase() == _selectedFilter?.toLowerCase();
    }).toList();
  }

  // UI Builders
  @override
  Widget build(BuildContext context) {
    print('Building LocationPage widget');
    print('Current state - loading: $_isLoading, items: ${_locationItems.length}');
    
    return Scaffold(
      backgroundColor: ThemeConfig.getBackgroundColor(_currentTheme),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: ThemeConfig.getPrimaryColor(_currentTheme),
        child: _isLoading ? _buildLoadingView() : _buildContent(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        '${SimpleTranslations.get(langCode, 'location_dashboard')} (${_filteredItems.length})',
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
            SimpleTranslations.get(langCode, 'loading_location_data'),
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
                _buildSummaryCard(),
                SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: _buildLocationsList(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Column(
      children: [
        _buildSummaryCard(),
        Expanded(child: _buildLocationsList()),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final counts = _stockCounts;
    
    return Padding(
      padding: EdgeInsets.all(_isWideScreen ? 24.0 : 16.0),
      child: FadeTransition(
        opacity: _fadeController,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: _isWideScreen ? 800 : double.infinity,
          ),
          child: Card(
            elevation: 4,
            color: ThemeConfig.getBackgroundColor(_currentTheme),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(_isWideScreen ? 24.0 : 16.0),
              child: Column(
                children: [
                  _buildSummaryHeader(counts['total']!),
                  SizedBox(height: _isWideScreen ? 20 : 16),
                  const Divider(),
                  SizedBox(height: _isWideScreen ? 12 : 8),
                  _buildFilterCards(counts),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(int total) {
    return Row(
      children: [
        Icon(
          Icons.location_on,
          size: _isWideScreen ? 40 : 32,
          color: ThemeConfig.getPrimaryColor(_currentTheme),
        ),
        SizedBox(width: _isWideScreen ? 20 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                SimpleTranslations.get(langCode, 'location_summary'),
                style: TextStyle(
                  fontSize: _isWideScreen ? 20 : 18,
                  fontWeight: FontWeight.bold,
                  color: ThemeConfig.getTextColor(_currentTheme),
                ),
              ),
              Text(
                '$total ${SimpleTranslations.get(langCode, 'total_locations')}',
                style: TextStyle(
                  fontSize: _isWideScreen ? 28 : 24,
                  fontWeight: FontWeight.bold,
                  color: ThemeConfig.getPrimaryColor(_currentTheme),
                ),
              ),
              if (_selectedFilter != null) _buildFilterChip(),
            ],
          ),
        ),
        if (_selectedFilter != null) _buildClearFilterButton(),
      ],
    );
  }

  Widget _buildFilterChip() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _getStockStatusColor(_selectedFilter!).withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _getStockStatusColor(_selectedFilter!)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStockStatusIcon(_selectedFilter!),
            size: 14,
            color: _getStockStatusColor(_selectedFilter!),
          ),
          const SizedBox(width: 6),
          Text(
            _selectedFilter!,
            style: TextStyle(
              color: _getStockStatusColor(_selectedFilter!),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClearFilterButton() {
    return GestureDetector(
      onTap: () {
        print('Clear filter button pressed');
        setState(() => _selectedFilter = null);
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.clear, size: 20, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildFilterCards(Map<String, int> counts) {
    final filterData = [
      (SimpleTranslations.get(langCode, 'good_stock'), counts['good']!, Icons.check_circle, Colors.green, 'Good'),
      (SimpleTranslations.get(langCode, 'warning_stock'), counts['warning']!, Icons.warning, Colors.orange, 'Warning'),
      (SimpleTranslations.get(langCode, 'critical_stock'), counts['critical']!, Icons.error, Colors.red, 'Critical'),
      (SimpleTranslations.get(langCode, 'out_of_stock'), counts['out_of_stock']!, Icons.remove_circle, Colors.red.shade800, 'Out of Stock'),
    ];

    if (_isWideScreen) {
      return Wrap(
        spacing: 16,
        runSpacing: 12,
        children: filterData.map((data) => _buildFilterCard(data.$1, data.$2, data.$3, data.$4, data.$5)).toList(),
      );
    }
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filterData
          .map((data) => Padding(
            padding: EdgeInsets.only(right: data == filterData.last ? 0 : 12),
            child: _buildFilterCard(data.$1, data.$2, data.$3, data.$4, data.$5),
          ))
          .toList(),
      ),
    );
  }

  Widget _buildFilterCard(String title, int count, IconData icon, Color color, String filterStatus) {
    final isSelected = _selectedFilter == filterStatus;
    
    return GestureDetector(
      onTap: () {
        print('Filter card tapped: $filterStatus');
        setState(() => _selectedFilter = isSelected ? null : filterStatus);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Card(
          elevation: isSelected ? 6 : 2,
          color: isSelected ? color.withOpacity(0.1) : ThemeConfig.getBackgroundColor(_currentTheme),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 4),
                Text(
                  count.toString(),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? color : Colors.grey,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationsList() {
    final filteredItems = _filteredItems;
    
    if (filteredItems.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        if (_selectedFilter != null) _buildFilterIndicator(filteredItems.length),
        Expanded(child: _buildItemsGrid(filteredItems)),
      ],
    );
  }

  Widget _buildEmptyState() {
    print('Showing empty state');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedFilter == null ? Icons.location_on : _getStockStatusIcon(_selectedFilter!),
            size: _isWideScreen ? 80 : 64,
            color: Colors.grey,
          ),
          SizedBox(height: _isWideScreen ? 20 : 16),
          Text(
            SimpleTranslations.get(langCode, 'no_location_items_found'),
            style: TextStyle(fontSize: _isWideScreen ? 18 : 16, color: Colors.grey),
          ),
          if (_selectedFilter != null) ...[
            SizedBox(height: _isWideScreen ? 12 : 8),
            TextButton(
              onPressed: () {
                print('Show all items button pressed');
                setState(() => _selectedFilter = null);
              },
              child: Text(
                SimpleTranslations.get(langCode, 'show_all_items'),
                style: TextStyle(color: ThemeConfig.getPrimaryColor(_currentTheme)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterIndicator(int count) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _isWideScreen ? 24 : 16,
        vertical: _isWideScreen ? 12 : 8,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: _isWideScreen ? 20 : 16,
        vertical: _isWideScreen ? 12 : 8,
      ),
      decoration: BoxDecoration(
        color: _getStockStatusColor(_selectedFilter!).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getStockStatusColor(_selectedFilter!)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStockStatusIcon(_selectedFilter!),
            size: 16,
            color: _getStockStatusColor(_selectedFilter!),
          ),
          const SizedBox(width: 8),
          Text(
            '${SimpleTranslations.get(langCode, 'showing_items')} $_selectedFilter ${SimpleTranslations.get(langCode, 'items')} ($count)',
            style: TextStyle(
              color: _getStockStatusColor(_selectedFilter!),
              fontSize: _isWideScreen ? 16 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              print('Clear filter from indicator');
              setState(() => _selectedFilter = null);
            },
            child: Icon(
              Icons.close,
              size: 16,
              color: _getStockStatusColor(_selectedFilter!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsGrid(List<Map<String, dynamic>> items) {
    final crossAxisCount = _isWideScreen ? (MediaQuery.of(context).size.width > 1200 ? 3 : 2) : 1;
    
    if (_isWideScreen) {
      return GridView.builder(
        padding: EdgeInsets.all(_isWideScreen ? 24 : 16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 3.2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildLocationCard(items[index], index),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(_isWideScreen ? 24 : 16),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildLocationCard(items[index], index),
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> item, int index) {
    print('Building location card for: ${item['location']}');
    final stockStatus = _getStockStatus(item);
    
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Interval(index * 0.1, 1.0, curve: Curves.easeOut),
      )),
      child: Card(
        margin: EdgeInsets.only(bottom: _isWideScreen ? 0 : 12),
        elevation: 2,
        color: ThemeConfig.getBackgroundColor(_currentTheme),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _getStockStatusColor(stockStatus).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showItemDetails(item),
          child: Padding(
            padding: EdgeInsets.all(_isWideScreen ? 20 : 16),
            child: Row(
              children: [
                _buildItemImage(item, stockStatus),
                SizedBox(width: _isWideScreen ? 20 : 16),
                Expanded(child: _buildItemInfo(item)),
                _buildStatusIndicator(stockStatus),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemImage(Map<String, dynamic> item, String stockStatus) {
    print('Building image for location: ${item['location']}');
    final size = _isWideScreen ? 60.0 : 50.0;
    final radius = size / 2;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getStockStatusColor(stockStatus).withOpacity(0.1),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: _buildImageContent(item, stockStatus, size, radius),
    );
  }

  Widget _buildImageContent(Map<String, dynamic> item, String stockStatus, double size, double radius) {
    final imageUrl = item['image_url'];
    if (imageUrl != null && imageUrl != 'undefined/iouser/${item['image']}') {
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
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          finalImageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              print('Image loaded successfully for ${item['location']}');
              return child;
            }
            print('Loading image for ${item['location']}...');
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
            print('Error loading image for ${item['location']}: $error');
            print('Failed URL: $finalImageUrl');
            return _buildFallbackIcon(stockStatus, size);
          },
        ),
      );
    }
    return _buildFallbackIcon(stockStatus, size);
  }

  Widget _buildFallbackIcon(String stockStatus, double size) {
    return Icon(
      _getStockStatusIcon(stockStatus),
      color: _getStockStatusColor(stockStatus),
      size: size * 0.5,
    );
  }

  Widget _buildItemInfo(Map<String, dynamic> item) {
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item['location'] ?? SimpleTranslations.get(langCode, 'unknown_location'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: _isWideScreen ? 18 : 16,
              color: ThemeConfig.getTextColor(_currentTheme),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: _isWideScreen ? 4 : 2),
          Row(
            children: [
              Icon(Icons.location_on, size: _isWideScreen ? 16 : 14, color: Colors.grey[600]),
              SizedBox(width: _isWideScreen ? 4 : 2),
              Expanded(
                child: Text(
                  item['product_name'] ?? SimpleTranslations.get(langCode, 'unknown_product'),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: _isWideScreen ? 14 : 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: _isWideScreen ? 4 : 2),
          Text(
            '${SimpleTranslations.get(langCode, 'qty')}: ${item['total_amount'] ?? 0}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: _isWideScreen ? 12 : 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String stockStatus) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isWideScreen ? 16 : 12,
        vertical: _isWideScreen ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: _getStockStatusColor(stockStatus).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getStockStatusColor(stockStatus)),
      ),
      child: Icon(
        _getStockStatusIcon(stockStatus),
        color: _getStockStatusColor(stockStatus),
        size: _isWideScreen ? 20 : 16,
      ),
    );
  }

  void _showItemDetails(Map<String, dynamic> item) {
    print('Location item tapped: ${item['location']}');
    final stockStatus = _getStockStatus(item);
    
    if (kIsWeb && _isWideScreen) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: ThemeConfig.getBackgroundColor(_currentTheme),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: _buildItemDetailsContent(item, stockStatus),
          ),
        ),
      );
    } else {
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
          child: _buildItemDetailsContent(item, stockStatus),
        ),
      );
    }
  }

  Widget _buildItemDetailsContent(Map<String, dynamic> item, String stockStatus) {
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
                _buildDetailsHeader(item, stockStatus),
                SizedBox(height: _isWideScreen ? 32 : 24),
                ..._buildDetailRows(item, stockStatus),
                SizedBox(height: _isWideScreen ? 32 : 24),
                _buildManageButton(stockStatus),
              ],
            ),
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
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildDetailsHeader(Map<String, dynamic> item, String stockStatus) {
    final imageSize = _isWideScreen ? 100.0 : 80.0;
    
    return Row(
      children: [
        Container(
          width: imageSize,
          height: imageSize,
          decoration: BoxDecoration(
            color: _getStockStatusColor(stockStatus).withOpacity(0.1),
            borderRadius: BorderRadius.circular(imageSize / 2),
          ),
          child: _buildImageContent(item, stockStatus, imageSize, imageSize / 2),
        ),
        SizedBox(width: _isWideScreen ? 20 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['product_name'] ?? SimpleTranslations.get(langCode, 'unknown_product'),
                style: TextStyle(
                  fontSize: _isWideScreen ? 24 : 20,
                  fontWeight: FontWeight.bold,
                  color: ThemeConfig.getTextColor(_currentTheme),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _isWideScreen ? 16 : 12,
                  vertical: _isWideScreen ? 6 : 4,
                ),
                decoration: BoxDecoration(
                  color: _getStockStatusColor(stockStatus).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  stockStatus,
                  style: TextStyle(
                    color: _getStockStatusColor(stockStatus),
                    fontSize: _isWideScreen ? 14 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDetailRows(Map<String, dynamic> item, String stockStatus) {
    final details = [
      (SimpleTranslations.get(langCode, 'location'), item['location'] ?? SimpleTranslations.get(langCode, 'unknown_location'), Icons.location_on),
      (SimpleTranslations.get(langCode, 'quantity'), item['total_amount']?.toString() ?? '0', Icons.inventory),
      (SimpleTranslations.get(langCode, 'stock_status'), stockStatus, Icons.assessment),
      (SimpleTranslations.get(langCode, 'total_value'), '${item['total_value'] ?? '0'} ${item['currency_primary'] ?? 'LAK'}', Icons.monetization_on),
      (SimpleTranslations.get(langCode, 'record_count'), item['record_count']?.toString() ?? '0', Icons.analytics),
    ];

    return details
      .map((detail) => Padding(
        padding: EdgeInsets.only(bottom: _isWideScreen ? 20 : 16),
        child: _buildDetailRow(detail.$1, detail.$2, detail.$3),
      ))
      .toList();
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon, 
          size: _isWideScreen ? 24 : 20, 
          color: ThemeConfig.getPrimaryColor(_currentTheme),
        ),
        SizedBox(width: _isWideScreen ? 16 : 12),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: _isWideScreen ? 18 : 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: _isWideScreen ? 12 : 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: _isWideScreen ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: ThemeConfig.getTextColor(_currentTheme),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManageButton(String stockStatus) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          // TODO: Navigate to location management page
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeConfig.getPrimaryColor(_currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(_currentTheme),
          padding: EdgeInsets.symmetric(vertical: _isWideScreen ? 20 : 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          SimpleTranslations.get(langCode, 'manage_location'),
          style: TextStyle(
            fontSize: _isWideScreen ? 18 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}