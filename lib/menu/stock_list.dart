import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/company_config.dart';

class ExpirePage extends StatefulWidget {
  final String? currentTheme;
  final int? companyId;
  final int? userId;
  final int? branchId;
  
  const ExpirePage({
    Key? key, 
    this.currentTheme,
    this.companyId,
    this.userId,
    this.branchId
  }) : super(key: key);

  @override
  State<ExpirePage> createState() => _ExpirePageState();
}

class _ExpirePageState extends State<ExpirePage>
    with TickerProviderStateMixin {
  String? accessToken;
  int? companyId;
  int? userId;
  int? branchId;
  
  List<Map<String, dynamic>> inventoryItems = [];
  List<Map<String, dynamic>> expiringItems = [];
  List<Map<String, dynamic>> expiredItems = [];
  Map<String, dynamic> valueReport = {};
  
  // Loading states
  bool isLoading = true;
  bool isRefreshing = false;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  
  // Tab controller
  late TabController _tabController;
  
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
    _tabController = TabController(length: 4, vsync: this);
    
    _initializeAuth();
  }

  // Helper method to safely parse string to int
  int? _parseStringToInt(String? value) {
    if (value == null) return null;
    return int.tryParse(value);
  }

  Future<void> _initializeAuth() async {
    print('🔐 [ExpirePage] Initializing authentication...');
    
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString('access_token');
    
    // Debug: Print all stored keys in SharedPreferences
    print('🔍 [DEBUG] All SharedPreferences keys: ${prefs.getKeys()}');
    
    // Try different possible key variations - handle all as strings first, then parse to int
    companyId = widget.companyId ?? 
        CompanyConfig.getCompanyId();
    
    userId = widget.userId ?? 
        _parseStringToInt(prefs.getString('user_id')) ??
        _parseStringToInt(prefs.getString('userId')) ??
        _parseStringToInt(prefs.getString('user'));
        
    branchId = widget.branchId ?? 
        _parseStringToInt(prefs.getString('branch_id')) ??
        _parseStringToInt(prefs.getString('branchId')) ??
        _parseStringToInt(prefs.getString('branch'));
    
    // Debug: Print what we found for each key variation (only string versions to avoid type errors)
    print('🔍 [DEBUG] SharedPreferences values:');
    print('   - companyId (string): ${prefs.getString('companyId')}');
    print('   - company (string): ${prefs.getString('company')}');
    print('   - user_id (string): ${prefs.getString('user_id')}');
    print('   - userId (string): ${prefs.getString('userId')}');
    print('   - user (string): ${prefs.getString('user')}');
    print('   - branch_id (string): ${prefs.getString('branch_id')}');
    print('   - branchId (string): ${prefs.getString('branchId')}');
    print('   - branch (string): ${prefs.getString('branch')}');
    print('🏢 [CompanyConfig] Default Company ID: ${CompanyConfig.getCompanyId()}');
    
    print('🔐 [ExpirePage] Auth Details:');
    print('   - Access Token: ${accessToken != null ? "✅ Present" : "❌ Missing"}');
    print('   - Company ID: $companyId');
    print('   - User ID: $userId');
    print('   - Branch ID: $branchId');
    
    if (accessToken != null && companyId != null) {
      print('✅ [ExpirePage] Auth successful, loading dashboard data...');
      _loadDashboardData();
    } else {
      print('❌ [ExpirePage] Auth failed - missing token or company ID');
      
      // If we have an access token but no company_id, let's try to proceed anyway
      // Some APIs might not require company_id in the URL
      if (accessToken != null && companyId == null) {
        print('⚠️ [ExpirePage] Attempting to continue without company_id...');
        // You might want to try a different API endpoint or ask user for company_id
        _showErrorSnackBar('Company ID not found. Please check your login data.');
      } else {
        _showErrorSnackBar('Authentication token or company ID not found. Please login again.');
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    print('📊 [ExpirePage] Starting dashboard data load...');
    
    setState(() {
      isLoading = true;
    });

    try {
      print('📊 [ExpirePage] Fetching expiring items...');
      await _fetchExpiringItems();
      
      print('✅ [ExpirePage] Dashboard data loaded successfully');
      print('📊 [ExpirePage] Total expiring items: ${expiringItems.length}');
      
      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      print('❌ [ExpirePage] Failed to load dashboard data: $e');
      _showErrorSnackBar('Failed to load dashboard data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
      print('📊 [ExpirePage] Dashboard loading completed (isLoading = false)');
    }
  }

  // Build query parameters including company_id
  // ignore: unused_element
  String _buildQueryParams(Map<String, dynamic> params) {
    params['company_id'] = companyId.toString();
    
    final queryString = params.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value.toString())}')
        .join('&');
    
    return queryString.isNotEmpty ? '?$queryString' : '';
  }

  // Fetch expiring items from your API
  Future<void> _fetchExpiringItems() async {
    if (accessToken == null || companyId == null) {
      print('❌ [API] Cannot fetch expiring items - missing auth or company ID');
      return;
    }
    
    final apiUrl = '/api/inventory/company/$companyId/expire';
    print('🌐 [API] Making request to: $apiUrl');
    print('🌐 [API] Company ID: $companyId');
    print('🌐 [API] Using Bearer token: ${accessToken?.substring(0, 20)}...');
    
    try {
      final response = await http.get(
        AppConfig.api(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('🌐 [API] Response Status Code: ${response.statusCode}');
      print('🌐 [API] Response Headers: ${response.headers}');
      print('🌐 [API] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 [API] Parsed response data: $data');
        
        if (data['status'] == 'success') {
          final items = List<Map<String, dynamic>>.from(data['data'] ?? []);
          setState(() {
            expiringItems = items;
          });
          
          print('✅ [API] Successfully loaded ${items.length} expiring items');
          print('📦 [API] Items data:');
          for (int i = 0; i < items.length; i++) {
            final item = items[i];
            print('   ${i + 1}. ${item['product_name']} - ${item['location']} - Qty: ${item['amount']} - Expire: ${item['expire_date']}');
          }
        } else {
          print('❌ [API] API returned non-success status: ${data['status']}');
          _showErrorSnackBar('Failed to fetch expiring items: ${data['message'] ?? 'Unknown error'}');
        }
      } else if (response.statusCode == 401) {
        print('🔐 [API] Authentication error (401) - token may be expired');
        _handleAuthError();
      } else {
        print('❌ [API] HTTP error: ${response.statusCode} - ${response.reasonPhrase}');
        _handleHttpError(response, 'fetch expiring items');
      }
    } catch (e) {
      print('💥 [API] Exception occurred during API call: $e');
      rethrow;
    }
  }

  void _handleAuthError() {
    print('🔐 [Auth] Authentication error detected - session may be expired');
    _showErrorSnackBar('Session expired. Please login again.');
    // Navigate to login page if needed
    // Navigator.pushReplacementNamed(context, '/login');
  }

  void _handleHttpError(http.Response response, String operation) {
    final errorMessage = 'Failed to $operation: ${response.statusCode} - ${response.reasonPhrase}';
    print('❌ [HTTP] Error during $operation: ${response.statusCode} - ${response.reasonPhrase}');
    print('❌ [HTTP] Response body: ${response.body}');
    _showErrorSnackBar(errorMessage);
  }

  void _showErrorSnackBar(String message) {
    print('⚠️ [UI] Showing error message: $message');
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
    print('🔄 [UI] User initiated refresh');
    setState(() {
      isRefreshing = true;
    });
    
    await _loadDashboardData();
    
    setState(() {
      isRefreshing = false;
    });
    print('🔄 [UI] Refresh completed');
  }

  String _getExpirationStatus(String? expireDate) {
    if (expireDate == null || expireDate.isEmpty) {
      return 'No Expiry';
    }
    
    try {
      final parts = expireDate.split('-');
      if (parts.length != 2) return 'Invalid Date';
      
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      
      final expiry = DateTime(year, month);
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);
      
      final difference = expiry.difference(currentMonth).inDays;
      
      if (difference < 0) {
        return 'Expired';
      } else if (difference < 90) { // Less than 3 months
        return 'Expiring Soon';
      } else {
        return 'Good';
      }
    } catch (e) {
      return 'Invalid Date';
    }
  }

  Color _getExpirationColor(String status) {
    switch (status.toLowerCase()) {
      case 'good':
        return Colors.green;
      case 'expiring soon':
        return Colors.orange;
      case 'expired':
        return Colors.red;
      case 'no expiry':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getExpirationIcon(String status) {
    switch (status.toLowerCase()) {
      case 'good':
        return Icons.check_circle;
      case 'expiring soon':
        return Icons.warning;
      case 'expired':
        return Icons.error;
      case 'no expiry':
        return Icons.all_inclusive;
      default:
        return Icons.inventory;
    }
  }

  Widget _buildExpirySummaryCards() {
    final totalItems = expiringItems.length;
    final goodCount = expiringItems.where((item) => 
        _getExpirationStatus(item['expire_date']?.toString()) == 'Good').length;
    final expiringSoonCount = expiringItems.where((item) => 
        _getExpirationStatus(item['expire_date']?.toString()) == 'Expiring Soon').length;
    final expiredCount = expiringItems.where((item) => 
        _getExpirationStatus(item['expire_date']?.toString()) == 'Expired').length;

    print('📊 [UI] Building summary cards:');
    print('   - Total: $totalItems, Good: $goodCount, Expiring Soon: $expiringSoonCount, Expired: $expiredCount');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Items',
                  totalItems.toString(),
                  Icons.inventory_2,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Good',
                  goodCount.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Expiring Soon',
                  expiringSoonCount.toString(),
                  Icons.warning,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Expired',
                  expiredCount.toString(),
                  Icons.error,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String count, IconData icon, Color color) {
    return FadeTransition(
      opacity: _fadeController,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                count,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiryItemsList() {
    if (expiringItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No expiry items found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: expiringItems.length,
      itemBuilder: (context, index) {
        final item = expiringItems[index];
        final expirationStatus = _getExpirationStatus(item['expire_date']?.toString());
        
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
                color: _getExpirationColor(expirationStatus).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getExpirationColor(expirationStatus).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  _getExpirationIcon(expirationStatus),
                  color: _getExpirationColor(expirationStatus),
                  size: 24,
                ),
              ),
              title: Text(
                item['product_name'] ?? 'Unknown Product',
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
                          item['location'] ?? 'Unknown Location',
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
                      Text(
                        'Qty: ${item['amount'] ?? 0}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  if (item['expire_date'] != null && item['expire_date'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Expires: ${item['expire_date']}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getExpirationColor(expirationStatus).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getExpirationColor(expirationStatus),
                    width: 1,
                  ),
                ),
                child: Text(
                  expirationStatus,
                  style: TextStyle(
                    color: _getExpirationColor(expirationStatus),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              onTap: () {
                // Handle item tap - navigate to details or show more info
                _showItemDetails(item);
              },
            ),
          ),
        );
      },
    );
  }

  void _showItemDetails(Map<String, dynamic> item) {
    final expirationStatus = _getExpirationStatus(item['expire_date']?.toString());
    
    print('🔍 [UI] Showing item details for: ${item['product_name']}');
    print('🔍 [UI] Item data: $item');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
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
                          color: _getExpirationColor(expirationStatus).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(
                          _getExpirationIcon(expirationStatus),
                          color: _getExpirationColor(expirationStatus),
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['product_name'] ?? 'Unknown Product',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getExpirationColor(expirationStatus).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                expirationStatus,
                                style: TextStyle(
                                  color: _getExpirationColor(expirationStatus),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow('Location', item['location'] ?? 'Unknown', Icons.location_on),
                  const SizedBox(height: 16),
                  _buildDetailRow('Quantity', item['amount']?.toString() ?? '0', Icons.inventory),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Expire Date', 
                    item['expire_date']?.toString().isNotEmpty == true ? item['expire_date'].toString() : 'No expiry date', 
                    Icons.schedule
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Add action for managing this item
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getExpirationColor(expirationStatus),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Manage Expiry',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
        title: const Text(
          'Expiry Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading expiry data...'),
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