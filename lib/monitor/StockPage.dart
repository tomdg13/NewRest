import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/company_config.dart';

class StockPage extends StatefulWidget {
  final String? currentTheme;
  final int? companyId;
  final int? userId;
  final int? branchId;
  
  const StockPage({
    Key? key, 
    this.currentTheme,
    this.companyId,
    this.userId,
    this.branchId
  }) : super(key: key);

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage>
    with TickerProviderStateMixin {
  String? accessToken;
  int? companyId;
  int? userId;
  int? branchId;
  
  List<Map<String, dynamic>> expiringItems = [];
  
  // Loading states
  bool isLoading = true;
  bool isRefreshing = false;
  
  // Filter state
  String? selectedFilter;
  
  // Language state
  String currentLanguage = 'en';
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _loadLanguagePreference();
    _initializeAuth();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  String tr(String key) {
    // Temporary solution - just return the key until SimpleTranslations is configured
    return key;
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentLanguage = prefs.getString('language_code') ?? 'en';
    });
  }

  Future<void> _saveLanguagePreference(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    setState(() {
      currentLanguage = languageCode;
    });
  }

  int? _parseStringToInt(String? value) {
    if (value == null) return null;
    return int.tryParse(value);
  }

  Future<void> _initializeAuth() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString('access_token');
    
    companyId = widget.companyId ?? CompanyConfig.getCompanyId();
    userId = widget.userId ?? 
        _parseStringToInt(prefs.getString('user_id')) ??
        _parseStringToInt(prefs.getString('userId')) ??
        _parseStringToInt(prefs.getString('user'));
    branchId = widget.branchId ?? 
        _parseStringToInt(prefs.getString('branch_id')) ??
        _parseStringToInt(prefs.getString('branchId')) ??
        _parseStringToInt(prefs.getString('branch'));
    
    if (accessToken != null && companyId != null) {
      _loadDashboardData();
    } else {
      _showErrorSnackBar('Authentication token or company ID not found. Please login again.');
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      isLoading = true;
    });

    try {
      await _fetchExpiringItems();
      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      _showErrorSnackBar('Failed to load dashboard data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchExpiringItems() async {
    if (accessToken == null || companyId == null) {
      return;
    }
    
    final apiUrl = '/api/inventory/company/$companyId/expire';
    
    try {
      final response = await http.get(
        AppConfig.api(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'success') {
          final items = List<Map<String, dynamic>>.from(data['data'] ?? []);
          setState(() {
            expiringItems = items;
          });
        } else {
          _showErrorSnackBar('Failed to fetch expiring items: ${data['message'] ?? 'Unknown error'}');
        }
      } else if (response.statusCode == 401) {
        _handleAuthError();
      } else {
        _handleHttpError(response, 'fetch expiring items');
      }
    } catch (e) {
      rethrow;
    }
  }

  void _handleAuthError() {
    _showErrorSnackBar('Session expired. Please login again.');
  }

  void _handleHttpError(http.Response response, String operation) {
    final errorMessage = 'Failed to $operation: ${response.statusCode} - ${response.reasonPhrase}';
    _showErrorSnackBar(errorMessage);
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _refresh() async {
    setState(() {
      isRefreshing = true;
    });
    
    await _loadDashboardData();
    
    setState(() {
      isRefreshing = false;
    });
  }

  String _getStockStatus(Map<String, dynamic> item) {
    return item['stock_status']?.toString() ?? 'No Stock';
  }

  Color _getStockStatusColor(String? stockStatus) {
    switch (stockStatus?.toLowerCase()) {
      case 'best stock':
        return Colors.green;
      case 'wroning stock':
        return Colors.orange;
      case 'no stock':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStockStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'best stock':
        return Icons.check_circle;
      case 'wroning stock':
        return Icons.warning;
      case 'no stock':
        return Icons.error;
      default:
        return Icons.inventory;
    }
  }

  Widget _buildExpirySummaryCards() {
    final totalItems = expiringItems.length;
    final bestStockCount = expiringItems.where((item) => 
        _getStockStatus(item) == 'Best Stock').length;
    final wroningStockCount = expiringItems.where((item) => 
        _getStockStatus(item) == 'Wroning Stock').length;
    final noStockCount = expiringItems.where((item) => 
        _getStockStatus(item) == 'No Stock').length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _buildSummaryCard(
        totalItems,
        bestStockCount,
        wroningStockCount,
        noStockCount,
      ),
    );
  }

  Widget _buildSummaryCard(int total, int bestStock, int wroningStock, int noStock) {
    return FadeTransition(
      opacity: _fadeController,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.inventory_2,
                    size: 32,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('inventory_summary'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$total ${tr('total_items')}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        if (selectedFilter != null)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStockStatusColor(selectedFilter!).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: _getStockStatusColor(selectedFilter!),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStockStatusIcon(selectedFilter!),
                                  size: 14,
                                  color: _getStockStatusColor(selectedFilter!),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  selectedFilter!,
                                  style: TextStyle(
                                    color: _getStockStatusColor(selectedFilter!),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (selectedFilter != null)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedFilter = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.clear,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterCard(tr('best_stock'), bestStock.toString(), Icons.check_circle, Colors.green, 'Best Stock'),
                    const SizedBox(width: 12),
                    _buildFilterCard(tr('wroning_stock'), wroningStock.toString(), Icons.warning, Colors.orange, 'Wroning Stock'),
                    const SizedBox(width: 12),
                    _buildFilterCard(tr('no_stock'), noStock.toString(), Icons.error, Colors.red, 'No Stock'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCard(String title, String count, IconData icon, Color color, String? filterStatus) {
    final isSelected = selectedFilter == filterStatus;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = isSelected ? null : filterStatus;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Card(
          elevation: isSelected ? 6 : 2,
          color: isSelected ? color.withOpacity(0.1) : null,
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
                  count,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
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

  Widget _buildExpiryItemsList() {
    List<Map<String, dynamic>> filteredItems = expiringItems.where((item) {
      if (selectedFilter == null) return true;
      final itemStatus = _getStockStatus(item);
      return itemStatus == selectedFilter;
    }).toList();

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selectedFilter == null ? Icons.inventory_2 : _getStockStatusIcon(selectedFilter!),
              size: 64, 
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              tr('no_stock_items_found'),
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (selectedFilter != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    selectedFilter = null;
                  });
                },
                child: Text(tr('show_all_items')),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        if (selectedFilter != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getStockStatusColor(selectedFilter!).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getStockStatusColor(selectedFilter!),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getStockStatusIcon(selectedFilter!),
                  size: 16,
                  color: _getStockStatusColor(selectedFilter!),
                ),
                const SizedBox(width: 8),
                Text(
                  '${tr('showing_items')} $selectedFilter ${tr('items')} (${filteredItems.length})',
                  style: TextStyle(
                    color: _getStockStatusColor(selectedFilter!),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedFilter = null;
                    });
                  },
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: _getStockStatusColor(selectedFilter!),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              final item = filteredItems[index];
              final stockStatus = _getStockStatus(item);
              
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _slideController,
                  curve: Interval(
                    index * 0.1,
                    1.0,
                    curve: Curves.easeOut,
                  ),
                )),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _getStockStatusColor(stockStatus).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getStockStatusColor(stockStatus).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Icon(
                        _getStockStatusIcon(stockStatus),
                        color: _getStockStatusColor(stockStatus),
                        size: 24,
                      ),
                    ),
                    title: Text(
                      item['product_name'] ?? tr('unknown_product'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item['location'] ?? tr('unknown_location'),
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.inventory, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${tr('qty')}: ${item['amount'] ?? 0}',
                                style: TextStyle(color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getStockStatusColor(stockStatus).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _getStockStatusColor(stockStatus),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  stockStatus,
                                  style: TextStyle(
                                    color: _getStockStatusColor(stockStatus),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                item['expire_date'] == '∞' 
                                  ? tr('never_expires')
                                  : '${tr('expires')}: ${item['month_expire'] ?? item['expire_date']}',
                                style: TextStyle(
                                  color: item['expire_date'] == '∞' 
                                    ? Colors.blue.shade600 
                                    : Colors.grey[600],
                                  fontWeight: item['expire_date'] == '∞' 
                                    ? FontWeight.w500 
                                    : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStockStatusColor(stockStatus).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getStockStatusColor(stockStatus),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStockStatusIcon(stockStatus),
                            color: _getStockStatusColor(stockStatus),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            stockStatus,
                            style: TextStyle(
                              color: _getStockStatusColor(stockStatus),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      _showItemDetails(item);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showItemDetails(Map<String, dynamic> item) {
    final stockStatus = _getStockStatus(item);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _getStockStatusColor(stockStatus).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(
                          _getStockStatusIcon(stockStatus),
                          color: _getStockStatusColor(stockStatus),
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['product_name'] ?? tr('unknown_product'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStockStatusColor(stockStatus).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                stockStatus,
                                style: TextStyle(
                                  color: _getStockStatusColor(stockStatus),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),                                  const SizedBox(height: 24),
                  _buildDetailRow(tr('location'), item['location'] ?? tr('unknown_location'), Icons.location_on),
                  const SizedBox(height: 16),
                  _buildDetailRow(tr('quantity'), item['amount']?.toString() ?? '0', Icons.inventory),
                  const SizedBox(height: 16),
                  _buildDetailRow(tr('stock_status'), stockStatus, Icons.assessment),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    tr('expire_date'), 
                    item['expire_date'] == '∞' 
                        ? tr('never_expires')
                        : (item['expire_date']?.toString().isNotEmpty == true 
                            ? '${item['expire_date']} (${item['month_expire'] ?? ''})'
                            : tr('no_expiry_date')), 
                    item['expire_date'] == '∞' 
                        ? Icons.all_inclusive 
                        : Icons.schedule
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getStockStatusColor(stockStatus),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        tr('manage_stock'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('expiry_dashboard'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (String languageCode) {
              _saveLanguagePreference(languageCode);
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'en',
                child: Row(
                  children: [
                    Text('🇺🇸'),
                    SizedBox(width: 8),
                    Text('English'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'lo',
                child: Row(
                  children: [
                    Text('🇱🇦'),
                    SizedBox(width: 8),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(tr('loading_expiry_data')),
                  ],
                ),
              )
            : Column(
                children: [
                  _buildExpirySummaryCards(),
                  Expanded(
                    child: _buildExpiryItemsList(),
                  ),
                ],
              ),
      ),
    );
  }
}