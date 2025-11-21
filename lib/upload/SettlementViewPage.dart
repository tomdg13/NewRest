import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'package:inventory/upload/SettlementDetailPage.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// Data Models
class SettlementSummary {
  final double totalAmount;
  final double totalSettlement;
  final int purchaseCount;
  final int refundCount;
  final int totalCount;

  SettlementSummary({
    required this.totalAmount,
    required this.totalSettlement,
    required this.purchaseCount,
    required this.refundCount,
    required this.totalCount,
  });
}

class ColumnDefinition {
  final String key;
  final String title;
  final double width;
  final int defaultOrder;

  const ColumnDefinition({
    required this.key,
    required this.title,
    required this.width,
    required this.defaultOrder,
  });
}

// Updated constants with default ordering
class SettlementConstants {
  static const Duration autoRefreshInterval = Duration(minutes: 5);
  static const Duration animationDuration = Duration(milliseconds: 800);
  static const Duration slideAnimationDuration = Duration(milliseconds: 600);
  static const Duration navigationHintDelay = Duration(seconds: 2);
  
  static const List<String> transactionTypes = ['All', 'PURCHASE', 'REFUND', 'REVERSAL'];
  static const List<String> currencies = ['All', 'USD', 'THB', 'EUR', 'GBP', 'LAK'];
  static const List<String> statuses = ['All', 'Matched', 'Unmatched', 'Pending'];
  static const List<int> itemsPerPageOptions = [10, 15, 20, 25, 50];
  
  static const List<ColumnDefinition> columnDefinitions = [
    ColumnDefinition(key: 'order_number', title: 'Order Number', width: 120.0, defaultOrder: 0),
    ColumnDefinition(key: 'system_tx_id', title: 'System TX ID', width: 100.0, defaultOrder: 1),
    ColumnDefinition(key: 'transaction_time', title: 'Transaction Time', width: 85.0, defaultOrder: 2),
    ColumnDefinition(key: 'type', title: 'Type', width: 70.0, defaultOrder: 3),
    ColumnDefinition(key: 'tx_amount', title: 'TX Amount', width: 80.0, defaultOrder: 4),
    ColumnDefinition(key: 'billing_amount', title: 'Billing Amount', width: 80.0, defaultOrder: 5),
    ColumnDefinition(key: 'settlement', title: 'Settlement', width: 80.0, defaultOrder: 6),
    ColumnDefinition(key: 'net_settlement', title: 'Net Settlement', width: 80.0, defaultOrder: 7),
    ColumnDefinition(key: 'merchant_store', title: 'Merchant/Store', width: 140.0, defaultOrder: 8),
    ColumnDefinition(key: 'card_info', title: 'Card Info', width: 110.0, defaultOrder: 9),
    ColumnDefinition(key: 'psp_brand', title: 'PSP/Brand', width: 100.0, defaultOrder: 10),
    ColumnDefinition(key: 'auth_mode', title: 'Auth/Mode', width: 90.0, defaultOrder: 11),
    ColumnDefinition(key: 'status', title: 'Status', width: 75.0, defaultOrder: 12),
    ColumnDefinition(key: 'terminal', title: 'Terminal', width: 85.0, defaultOrder: 13),
    ColumnDefinition(key: 'fees', title: 'Fees', width: 70.0, defaultOrder: 14),
    ColumnDefinition(key: 'actions', title: 'Actions', width: 70.0, defaultOrder: 15),
  ];
}

// Settlement Service
class SettlementService {
  static Future<List<Map<String, dynamic>>> fetchSettlements() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final url = AppConfig.api('/api/settlement-details');

    final response = await http.get(
      Uri.parse(url.toString()),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData['status'] == 'success') {
        final settlements = List<Map<String, dynamic>>.from(responseData['data']);
        return _sortSettlementsByDate(settlements);
      } else {
        throw Exception(responseData['message'] ?? 'Failed to fetch data');
      }
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
    }
  }

  static List<Map<String, dynamic>> _sortSettlementsByDate(List<Map<String, dynamic>> settlements) {
    settlements.sort((a, b) {
      try {
        final dateTimeA = a['transaction_time']?.toString();
        final dateTimeB = b['transaction_time']?.toString();
        
        if (dateTimeA == null && dateTimeB == null) return 0;
        if (dateTimeA == null) return 1;
        if (dateTimeB == null) return -1;
        
        return DateTime.parse(dateTimeB).compareTo(DateTime.parse(dateTimeA));
      } catch (e) {
        return 0;
      }
    });
    return settlements;
  }
}

// Utility Functions
class SettlementUtils {
  static String formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return '-';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd\nHH:mm').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  static String formatAmount(dynamic amount, String? currency) {
    if (amount == null) return '-';
    final value = double.tryParse(amount.toString()) ?? 0.0;
    return '${currency ?? 'USD'}\n${value.toStringAsFixed(2)}';
  }

  static String formatCompactAmount(dynamic amount) {
    if (amount == null) return '-';
    final value = double.tryParse(amount.toString()) ?? 0.0;
    return value.toStringAsFixed(2);
  }

  static String shortenId(String id) {
    if (id == '-' || id.length <= 8) return id;
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }

  static Color getAmountColor(dynamic amount) {
    if (amount == null) return Colors.grey[600]!;
    final value = double.tryParse(amount.toString()) ?? 0.0;
    if (value > 0) return Colors.green[700]!;
    if (value < 0) return Colors.red[700]!;
    return Colors.grey[600]!;
  }

  static String generateCSV(List<Map<String, dynamic>> data) {
    const headers = [
      'Order Number', 'Transaction Time', 'Transaction Type', 'Transaction Amount',
      'Currency', 'Merchant Name', 'Store Name', 'Card Number', 'PSP Name',
      'Authorization Code', 'Settlement Amount', 'Net Settlement', 'Status',
      'Terminal ID', 'Batch Number'
    ];
    
    final csvLines = <String>[
      headers.map((e) => '"$e"').join(','),
      ...data.map((settlement) => [
        settlement['order_number'],
        settlement['transaction_time'],
        settlement['transaction_type'],
        settlement['transaction_amount'],
        settlement['transaction_currency'],
        settlement['merchant_name'],
        settlement['store_name'],
        settlement['card_number'],
        settlement['psp_name'],
        settlement['authorization_code'],
        settlement['merchant_settlement_amount'],
        settlement['net_merchant_settlement_amount'],
        settlement['reconciliation_flag'],
        settlement['terminal_id'],
        settlement['batch_number']
      ].map((e) => '"${e?.toString().replaceAll('"', '""') ?? ''}"').join(','))
    ];
    
    return csvLines.join('\n');
  }
}

// Filter Manager
class FilterManager {
  String searchQuery = '';
  String selectedTransactionType = 'All';
  String selectedCurrency = 'All';
  String selectedStatus = 'All';
  DateTimeRange? dateRange;

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      selectedTransactionType != 'All' ||
      selectedCurrency != 'All' ||
      selectedStatus != 'All' ||
      dateRange != null;

  List<Map<String, dynamic>> applyFilters(List<Map<String, dynamic>> settlements) {
    List<Map<String, dynamic>> filtered = List.from(settlements);
    
    if (searchQuery.isNotEmpty) {
      filtered = _applySearchFilter(filtered);
    }
    
    if (selectedTransactionType != 'All') {
      filtered = filtered.where((s) => s['transaction_type'] == selectedTransactionType).toList();
    }
    
    if (selectedCurrency != 'All') {
      filtered = filtered.where((s) => s['transaction_currency'] == selectedCurrency).toList();
    }

    if (selectedStatus != 'All') {
      filtered = filtered.where((s) => s['reconciliation_flag'] == selectedStatus).toList();
    }
    
    if (dateRange != null) {
      filtered = _applyDateFilter(filtered);
    }
    
    return filtered;
  }

  List<Map<String, dynamic>> _applySearchFilter(List<Map<String, dynamic>> data) {
    final query = searchQuery.toLowerCase();
    return data.where((settlement) {
      return [
        settlement['order_number'],
        settlement['merchant_name'],
        settlement['card_number'],
        settlement['group_name']
      ].any((field) => field?.toString().toLowerCase().contains(query) == true);
    }).toList();
  }

  List<Map<String, dynamic>> _applyDateFilter(List<Map<String, dynamic>> data) {
    return data.where((settlement) {
      try {
        final transactionTime = DateTime.parse(settlement['transaction_time']);
        return transactionTime.isAfter(dateRange!.start.subtract(const Duration(days: 1))) &&
               transactionTime.isBefore(dateRange!.end.add(const Duration(days: 1)));
      } catch (e) {
        return false;
      }
    }).toList();
  }

  void clearAll() {
    searchQuery = '';
    selectedTransactionType = 'All';
    selectedCurrency = 'All';
    selectedStatus = 'All';
    dateRange = null;
  }
}

// Main Widget
class SettlementViewPage extends StatefulWidget {
  const SettlementViewPage({Key? key}) : super(key: key);

  @override
  State<SettlementViewPage> createState() => _SettlementViewPageState();
}

class _SettlementViewPageState extends State<SettlementViewPage>
    with TickerProviderStateMixin {
  
  // State Variables - Initialize with only selected columns visible by default
  Map<String, bool> _columnVisibility = {
    'order_number': true,     // Show by default
    'system_tx_id': false,
    'transaction_time': true,  // Show by default
    'type': true,             // Show by default (transaction_type)
    'tx_amount': true,        // Show by default (transaction_amount)
    'billing_amount': true,   // Show by default
    'settlement': false,
    'net_settlement': false,
    'merchant_store': false,
    'card_info': true,        // Show by default (card_number)
    'psp_brand': false,
    'auth_mode': true,        // Show by default (authorization_code)
    'status': false,
    'terminal': false,
    'fees': true,            // Show by default
    'actions': false,
  };
  
  // NEW: Add column ordering - reorder to put default columns first
  List<String> _columnOrder = [
    'order_number',      // Order Number
    'type',              // transaction_type
    'transaction_time',  // Transaction Time  
    'auth_mode',         // authorization_code
    'card_info',         // card_number
    'tx_amount',         // transaction_amount
    'billing_amount',    // Billing Amount
    'fees',              // Fees
    'system_tx_id',
    'settlement',
    'net_settlement',
    'merchant_store',
    'psp_brand',
    'status',
    'terminal',
    'actions',
  ];
  
  final FilterManager _filterManager = FilterManager();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _settlements = [];
  List<Map<String, dynamic>> _filteredSettlements = [];
  Set<String> _selectedItems = {};
  SettlementSummary _summaryData = SettlementSummary(
    totalAmount: 0, totalSettlement: 0, purchaseCount: 0, refundCount: 0, totalCount: 0
  );
  
  int _currentPage = 1;
  int _itemsPerPage = 15;
  // ignore: unused_field
  int _totalCount = 0;
  
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _autoRefresh = false;
  String _errorMessage = '';
  String currentTheme = ThemeConfig.defaultTheme;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeComponents();
  }

  @override
  void dispose() {
    _disposeComponents();
    super.dispose();
  }

  // Initialization & Cleanup
  void _initializeComponents() {
    _loadCurrentTheme();
    _setupAnimations();
    _fetchSettlements();
    _loadAutoRefreshPreference();
    _scheduleNavigationHint();
  }

  void _disposeComponents() {
    _searchController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _refreshTimer?.cancel();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: SettlementConstants.animationDuration,
      vsync: this,
    );
    _slideController = AnimationController(
      duration: SettlementConstants.slideAnimationDuration,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _slideController, curve: Curves.easeOutCubic));
    
    _fadeController.forward();
    _slideController.forward();
  }

  void _scheduleNavigationHint() {
    Timer(SettlementConstants.navigationHintDelay, () {
      if (mounted && _settlements.isNotEmpty) {
        _showNavigationHint();
      }
    });
  }

  // Theme and Preferences
  Future<void> _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
    await _loadColumnPreferences();
  }

  Future<void> _loadColumnPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if this is the first time loading (no saved preferences exist)
    final hasExistingPrefs = prefs.containsKey('column_preferences_initialized');
    
    setState(() {
      if (!hasExistingPrefs) {
        // First time - use our default visibility settings (already set in initialization)
        // Save the flag to indicate preferences have been initialized
        prefs.setBool('column_preferences_initialized', true);
        
        // Save the default preferences
        for (var entry in _columnVisibility.entries) {
          prefs.setBool('column_${entry.key}', entry.value);
        }
        prefs.setStringList('column_order', _columnOrder);
      } else {
        // Load existing preferences
        for (var col in SettlementConstants.columnDefinitions) {
          _columnVisibility[col.key] = prefs.getBool('column_${col.key}') ?? false;
        }
        
        // Load column order preferences
        final savedOrder = prefs.getStringList('column_order');
        if (savedOrder != null && savedOrder.isNotEmpty) {
          _columnOrder = savedOrder;
        }
      }
    });
  }

  Future<void> _saveColumnPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save visibility preferences
    for (var entry in _columnVisibility.entries) {
      await prefs.setBool('column_${entry.key}', entry.value);
    }
    
    // Save column order
    await prefs.setStringList('column_order', _columnOrder);
  }

  void _moveColumn(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _columnOrder.removeAt(oldIndex);
      _columnOrder.insert(newIndex, item);
    });
    _saveColumnPreferences();
  }

  void _resetColumnOrder() {
    setState(() {
      _columnOrder = SettlementConstants.columnDefinitions
          .map((col) => col.key)
          .toList();
    });
    _saveColumnPreferences();
  }

  Future<void> _loadAutoRefreshPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoRefresh = prefs.getBool('settlement_auto_refresh') ?? false;
    });
    if (_autoRefresh) _startAutoRefresh();
  }

  // Auto-refresh functionality
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(SettlementConstants.autoRefreshInterval, (timer) {
      if (mounted) _fetchSettlements(isRefresh: true);
    });
  }

  void _stopAutoRefresh() => _refreshTimer?.cancel();

  Future<void> _toggleAutoRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _autoRefresh = !_autoRefresh);
    await prefs.setBool('settlement_auto_refresh', _autoRefresh);
    
    if (_autoRefresh) {
      _startAutoRefresh();
      _showSnackBar('Auto-refresh enabled (every 5 minutes)', Colors.green);
    } else {
      _stopAutoRefresh();
      _showSnackBar('Auto-refresh disabled', Colors.orange);
    }
  }

  // Data Operations
  Future<void> _fetchSettlements({bool isRefresh = false}) async {
    _setLoadingState(isRefresh);

    try {
      final settlements = await SettlementService.fetchSettlements();
      setState(() {
        _settlements = settlements;
        _totalCount = settlements.length;
        _filteredSettlements = List.from(_settlements);
      });
      
      _calculateSummaryData();
      _applyFilters();
    } catch (e) {
      _handleApiError(e, isRefresh);
    } finally {
      _clearLoadingState();
    }
  }

  void _setLoadingState(bool isRefresh) {
    setState(() {
      if (isRefresh) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
        _errorMessage = '';
      }
    });
  }

  void _handleApiError(dynamic error, bool isRefresh) {
    if (!isRefresh) {
      setState(() => _errorMessage = error.toString());
    } else {
      _showSnackBar('Refresh failed: ${error.toString()}', Colors.red);
    }
  }

  void _clearLoadingState() {
    setState(() {
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  void _calculateSummaryData() {
    double totalAmount = 0;
    double totalSettlement = 0;
    int purchaseCount = 0;
    int refundCount = 0;
    
    for (var settlement in _filteredSettlements) {
      final amount = double.tryParse(settlement['transaction_amount']?.toString() ?? '0') ?? 0;
      final settlementAmount = double.tryParse(settlement['merchant_settlement_amount']?.toString() ?? '0') ?? 0;
      
      totalAmount += amount;
      totalSettlement += settlementAmount;
      
      switch (settlement['transaction_type']) {
        case 'PURCHASE':
          purchaseCount++;
          break;
        case 'REFUND':
          refundCount++;
          break;
      }
    }
    
    setState(() {
      _summaryData = SettlementSummary(
        totalAmount: totalAmount,
        totalSettlement: totalSettlement,
        purchaseCount: purchaseCount,
        refundCount: refundCount,
        totalCount: _filteredSettlements.length,
      );
    });
  }

  // Filtering
  void _applyFilters() {
    _filterManager.searchQuery = _searchController.text;
    final filtered = _filterManager.applyFilters(_settlements);
    
    setState(() {
      _filteredSettlements = filtered;
      _currentPage = 1;
      _selectedItems.clear();
    });
    
    _calculateSummaryData();
  }

  void _clearAllFilters() {
    _filterManager.clearAll();
    _searchController.clear();
    _applyFilters();
  }

  // Pagination
  List<Map<String, dynamic>> _getPaginatedData() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _filteredSettlements.length);
    return _filteredSettlements.sublist(startIndex, endIndex);
  }

  int get _totalPages => (_filteredSettlements.length / _itemsPerPage).ceil();

  // Navigation
  void _navigateToDetail(Map<String, dynamic> settlement) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettlementDetailPage(
          settlementId: settlement['id'].toString(),
          orderNumber: settlement['order_number']?.toString() ?? '',
        ),
      ),
    );
  }

  // Utility Methods
  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showNavigationHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Double-click any row to view detailed information'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Got it',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('$label copied to clipboard', Colors.green);
  }

  // Export functionality
  Future<void> _exportToCSV() async {
    try {
      final csvContent = SettlementUtils.generateCSV(_filteredSettlements);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'settlements_$timestamp.csv';
      
      _showExportDialog(csvContent, filename);
      _showSnackBar('Export completed successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Export failed: $e', Colors.red);
    }
  }

  // UI Build Methods
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              if (!isMobile) _SummaryCards(summaryData: _summaryData),
              _FilterSection(
                filterManager: _filterManager,
                searchController: _searchController,
                onFiltersChanged: _applyFilters,
                onClearFilters: _clearAllFilters,
                currentTheme: currentTheme,
              ),
              _buildTableSection(),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          const Text('Settlement Details'),
          if (_isRefreshing) ...[
            const SizedBox(width: 12),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
      backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
      foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
      elevation: 0,
      actions: [
        IconButton(
          onPressed: _toggleAutoRefresh,
          icon: Icon(_autoRefresh ? Icons.pause : Icons.play_arrow),
          tooltip: _autoRefresh ? 'Disable Auto-refresh' : 'Enable Auto-refresh',
        ),
        IconButton(
          onPressed: () => _fetchSettlements(isRefresh: true),
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
        _buildPopupMenu(),
      ],
    );
  }

  PopupMenuButton<String> _buildPopupMenu() {
    return PopupMenuButton<String>(
      onSelected: _handleMenuSelection,
      itemBuilder: (context) => [
        _buildMenuItem('export_all', Icons.download, 'Export All Data'),
        _buildMenuItem('clear_filters', Icons.clear_all, 'Clear All Filters'),
        _buildMenuItem('column_settings', Icons.view_column, 'Column Settings'),
        _buildMenuItem('reset_defaults', Icons.restore, 'Reset Column Defaults'),
        _buildMenuItem('settings', Icons.settings, 'Settings'),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, String text) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  // Add this method to reset to new defaults
  Future<void> _resetToNewDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    // Clear only column-related preferences
    final keys = prefs.getKeys().where((key) => 
      key.startsWith('column_') || key == 'column_preferences_initialized'
    ).toList();
    
    for (final key in keys) {
      await prefs.remove(key);
    }
    
    // Reload with new defaults
    await _loadColumnPreferences();
    
    _showSnackBar('Column settings reset to new defaults', Colors.green);
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'export_all':
        _exportToCSV();
        break;
      case 'clear_filters':
        _clearAllFilters();
        break;
      case 'column_settings':
        _showColumnSettingsDialog();
        break;
      case 'reset_defaults':
        _resetToNewDefaults();
        break;
      case 'settings':
        _showSettingsDialog();
        break;
    }
  }

  Widget _buildTableSection() {
    if (_isLoading) return _buildLoadingWidget();
    if (_errorMessage.isNotEmpty) return _buildErrorWidget();
    if (_filteredSettlements.isEmpty) return _buildEmptyWidget();
    
    return Expanded(
      child: Column(
        children: [
          _buildActionBar(),
          _buildResultsInfo(),
          Expanded(
            child: _SettlementTable(
              settlements: _getPaginatedData(),
              columnVisibility: _columnVisibility,
              columnOrder: _columnOrder,
              onNavigateToDetail: _navigateToDetail,
              onCopyToClipboard: _copyToClipboard,
              onShowQuickView: _showQuickViewDialog,
              selectedItems: _selectedItems,
              onSelectionChanged: (id, selected) {
                setState(() {
                  if (selected) {
                    _selectedItems.add(id);
                  } else {
                    _selectedItems.remove(id);
                  }
                });
              },
              onColumnMoved: _moveColumn,
              onShowColumnSettings: _showColumnSettingsDialog,
            ),
          ),
          if (_totalPages > 1) _buildPaginationControls(),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: ThemeConfig.getPrimaryColor(currentTheme)),
            const SizedBox(height: 16),
            const Text('Loading settlements...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Error loading settlements:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchSettlements,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return const Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No settlements found', style: TextStyle(fontSize: 18)),
            Text('Try adjusting your search or filters'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _exportToCSV,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Export All'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsInfo() {
    final paginatedData = _getPaginatedData();
    final startIndex = (_currentPage - 1) * _itemsPerPage + 1;
    final endIndex = startIndex + paginatedData.length - 1;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Showing $startIndex-$endIndex of ${_filteredSettlements.length} transactions',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const Spacer(),
          Text(
            'Page $_currentPage of $_totalPages',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    return _PaginationControls(
      currentPage: _currentPage,
      totalPages: _totalPages,
      onPageChanged: (page) => setState(() => _currentPage = page),
    );
  }

  // Dialog Methods
  void _showQuickViewDialog(Map<String, dynamic> settlement) {
    showDialog(
      context: context,
      builder: (context) => _QuickViewDialog(
        settlement: settlement,
        onNavigateToDetail: () {
          Navigator.of(context).pop();
          _navigateToDetail(settlement);
        },
        currentTheme: currentTheme,
      ),
    );
  }

  void _showExportDialog(String csvContent, String filename) {
    showDialog(
      context: context,
      builder: (context) => _ExportDialog(
        csvContent: csvContent,
        filename: filename,
        currentTheme: currentTheme,
        onExportComplete: () => _showSnackBar('CSV data copied to clipboard', Colors.green),
      ),
    );
  }

  void _showColumnSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => _ColumnSettingsDialog(
        columnVisibility: _columnVisibility,
        columnOrder: _columnOrder,
        onVisibilityChanged: (key, value) {
          setState(() => _columnVisibility[key] = value);
        },
        onColumnMoved: _moveColumn,
        onResetOrder: _resetColumnOrder,
        onSave: () async {
          await _saveColumnPreferences();
          Navigator.of(context).pop();
          _showSnackBar('Column preferences saved', Colors.green);
        },
        currentTheme: currentTheme,
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => _SettingsDialog(
        itemsPerPage: _itemsPerPage,
        autoRefresh: _autoRefresh,
        onItemsPerPageChanged: (value) {
          setState(() {
            _itemsPerPage = value;
            _currentPage = 1;
          });
          Navigator.of(context).pop();
        },
        onAutoRefreshToggle: () {
          Navigator.of(context).pop();
          _toggleAutoRefresh();
        },
      ),
    );
  }
}

// Separate Widgets for better organization
class _SummaryCards extends StatelessWidget {
  final SettlementSummary summaryData;

  const _SummaryCards({required this.summaryData});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          final cards = [
            _buildSummaryCard('Total Transactions', summaryData.totalCount.toString(), Icons.receipt_long, Colors.blue),
            _buildSummaryCard('Total Amount', 'USD ${summaryData.totalAmount.toStringAsFixed(2)}', Icons.attach_money, Colors.green),
            _buildSummaryCard('Purchases', summaryData.purchaseCount.toString(), Icons.shopping_cart, Colors.orange),
            _buildSummaryCard('Refunds', summaryData.refundCount.toString(), Icons.refresh, Colors.red),
          ];
          
          if (isWide) {
            return Row(
              children: cards.map((card) => Expanded(child: card)).toList(),
            );
          } else {
            return Column(
              children: [
                Row(children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])]),
                const SizedBox(height: 12),
                Row(children: [Expanded(child: cards[2]), const SizedBox(width: 12), Expanded(child: cards[3])]),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final FilterManager filterManager;
  final TextEditingController searchController;
  final VoidCallback onFiltersChanged;
  final VoidCallback onClearFilters;
  final String currentTheme;

  const _FilterSection({
    required this.filterManager,
    required this.searchController,
    required this.onFiltersChanged,
    required this.onClearFilters,
    required this.currentTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSearchBar(context),
          const SizedBox(height: 12),
          _buildFilterControls(context),
          if (filterManager.hasActiveFilters) ...[
            const SizedBox(height: 12),
            _buildActiveFilters(context),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: 'Search by order, merchant, card...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  searchController.clear();
                  onFiltersChanged();
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      onChanged: (value) => onFiltersChanged(),
    );
  }

  Widget _buildFilterControls(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final filters = [
          _buildDropdownFilter('Type', filterManager.selectedTransactionType, 
            SettlementConstants.transactionTypes, 
            (value) {
              filterManager.selectedTransactionType = value!;
              onFiltersChanged();
            }),
          _buildDropdownFilter('Currency', filterManager.selectedCurrency, 
            SettlementConstants.currencies, 
            (value) {
              filterManager.selectedCurrency = value!;
              onFiltersChanged();
            }),
          _buildDropdownFilter('Status', filterManager.selectedStatus, 
            SettlementConstants.statuses, 
            (value) {
              filterManager.selectedStatus = value!;
              onFiltersChanged();
            }),
          _buildDateFilter(context),
        ];
        
        if (isWide) {
          return Row(
            children: filters.map((filter) => 
              Expanded(child: filter)
            ).toList(),
          );
        } else {
          return Column(
            children: [
              Row(children: [Expanded(child: filters[0]), const SizedBox(width: 8), Expanded(child: filters[1])]),
              const SizedBox(height: 8),
              Row(children: [Expanded(child: filters[2]), const SizedBox(width: 8), Expanded(child: filters[3])]),
            ],
          );
        }
      },
    );
  }

  Widget _buildDropdownFilter(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          isDense: true,
        ),
        items: items.map((item) => DropdownMenuItem(
          value: item, 
          child: Text(item, style: const TextStyle(fontSize: 12))
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDateFilter(BuildContext context) {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton.icon(
        onPressed: () => _selectDateRange(context),
        icon: const Icon(Icons.date_range, size: 16),
        label: Text(filterManager.dateRange != null ? 'Selected' : 'Date', style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: filterManager.dateRange != null ? ThemeConfig.getPrimaryColor(currentTheme) : null,
          foregroundColor: filterManager.dateRange != null ? Colors.white : null,
        ),
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: filterManager.dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: ThemeConfig.getPrimaryColor(currentTheme),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      filterManager.dateRange = picked;
      onFiltersChanged();
    }
  }

  Widget _buildActiveFilters(BuildContext context) {
    final chips = <Widget>[];
    
    if (filterManager.searchQuery.isNotEmpty) {
      chips.add(_buildFilterChip('Search: ${filterManager.searchQuery}', () {
        searchController.clear();
        filterManager.searchQuery = '';
        onFiltersChanged();
      }));
    }
    
    if (filterManager.selectedTransactionType != 'All') {
      chips.add(_buildFilterChip(filterManager.selectedTransactionType, () {
        filterManager.selectedTransactionType = 'All';
        onFiltersChanged();
      }));
    }
    
    if (filterManager.selectedCurrency != 'All') {
      chips.add(_buildFilterChip(filterManager.selectedCurrency, () {
        filterManager.selectedCurrency = 'All';
        onFiltersChanged();
      }));
    }
    
    if (filterManager.selectedStatus != 'All') {
      chips.add(_buildFilterChip(filterManager.selectedStatus, () {
        filterManager.selectedStatus = 'All';
        onFiltersChanged();
      }));
    }
    
    if (filterManager.dateRange != null) {
      chips.add(_buildFilterChip(
        '${DateFormat('MMM dd').format(filterManager.dateRange!.start)}-${DateFormat('MMM dd').format(filterManager.dateRange!.end)}',
        () {
          filterManager.dateRange = null;
          onFiltersChanged();
        },
      ));
    }
    
    return Wrap(spacing: 6, runSpacing: 4, children: chips);
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: ThemeConfig.getPrimaryColor(currentTheme),
        ),
      ),
      deleteIcon: Icon(
        Icons.close,
        size: 16,
        color: ThemeConfig.getPrimaryColor(currentTheme),
      ),
      onDeleted: onDeleted,
      backgroundColor: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
      side: BorderSide(
        color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.3),
        width: 1,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// Enhanced Settlement Table with drag-and-drop functionality
class _SettlementTable extends StatelessWidget {
  final List<Map<String, dynamic>> settlements;
  final Map<String, bool> columnVisibility;
  final List<String> columnOrder;
  final Function(Map<String, dynamic>) onNavigateToDetail;
  final Function(String, String) onCopyToClipboard;
  final Function(Map<String, dynamic>) onShowQuickView;
  final Set<String> selectedItems;
  final Function(String, bool) onSelectionChanged;
  final Function(int, int) onColumnMoved;
  final VoidCallback onShowColumnSettings;

  const _SettlementTable({
    required this.settlements,
    required this.columnVisibility,
    required this.columnOrder,
    required this.onNavigateToDetail,
    required this.onCopyToClipboard,
    required this.onShowQuickView,
    required this.selectedItems,
    required this.onSelectionChanged,
    required this.onColumnMoved,
    required this.onShowColumnSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Table content
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              width: 1500,
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 8,
                  dataRowHeight: 56,
                  headingRowHeight: 48,
                  headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                  border: TableBorder.all(color: Colors.grey[300]!, width: 0.5),
                  columns: _buildTableColumns(),
                  rows: _buildTableRows(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }



  List<ColumnDefinition> _getOrderedVisibleColumns() {
    final columnMap = {
      for (var col in SettlementConstants.columnDefinitions) col.key: col
    };
    
    return columnOrder
        .where((key) => columnVisibility[key] == true && columnMap.containsKey(key))
        .map((key) => columnMap[key]!)
        .toList();
  }

  List<DataColumn> _buildTableColumns() {
    return _getOrderedVisibleColumns().map((col) => DataColumn(
      label: Container(
        width: col.width,
        child: Draggable<String>(
          data: col.key,
          feedback: Material(
            elevation: 4,
            child: Container(
              width: col.width,
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                border: Border.all(color: Colors.blue[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.drag_handle, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      col.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.blue[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          childWhenDragging: Container(
            width: col.width,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.drag_handle, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    col.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.grey[400],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          child: DragTarget<String>(
            onAccept: (draggedKey) {
              final draggedIndex = columnOrder.indexOf(draggedKey);
              final targetIndex = columnOrder.indexOf(col.key);
              if (draggedIndex != -1 && targetIndex != -1) {
                onColumnMoved(draggedIndex, targetIndex);
              }
            },
            builder: (context, candidateData, rejectedData) {
              return Container(
                width: col.width,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  color: candidateData.isNotEmpty ? Colors.blue[50] : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Icon(Icons.drag_handle, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        col.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      numeric: ['tx_amount', 'billing_amount', 'settlement', 'net_settlement', 'fees'].contains(col.key),
    )).toList();
  }

  List<DataRow> _buildTableRows() {
    return settlements.map((settlement) => DataRow(
      selected: selectedItems.contains(settlement['id'].toString()),
      onSelectChanged: (selected) {
        onSelectionChanged(settlement['id'].toString(), selected ?? false);
      },
      cells: _buildTableCells(settlement),
    )).toList();
  }

  List<DataCell> _buildTableCells(Map<String, dynamic> settlement) {
    return _getOrderedVisibleColumns().map((col) => 
      _buildCellForColumn(col, settlement)
    ).toList();
  }

  DataCell _buildCellForColumn(ColumnDefinition col, Map<String, dynamic> settlement) {
    switch (col.key) {
      case 'order_number':
        return _buildClickableCell(col.width, settlement['order_number']?.toString() ?? '', settlement, 
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11));
      case 'system_tx_id':
        return _buildClickableCell(col.width, SettlementUtils.shortenId(settlement['system_transaction_id']?.toString() ?? '-'), settlement,
          style: const TextStyle(fontSize: 9, fontFamily: 'monospace'));
      case 'transaction_time':
        return _buildClickableCell(col.width, SettlementUtils.formatDateTime(settlement['transaction_time']), settlement,
          style: const TextStyle(fontSize: 9), alignment: TextAlign.center);
      case 'type':
        return _buildClickableCell(col.width, '', settlement, child: _buildTypeChip(settlement['transaction_type']));
      case 'tx_amount':
        return _buildClickableCell(col.width, SettlementUtils.formatAmount(settlement['transaction_amount'], settlement['transaction_currency']), settlement,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: SettlementUtils.getAmountColor(settlement['transaction_amount'])), 
          alignment: TextAlign.right);
      case 'billing_amount':
        return _buildClickableCell(col.width, SettlementUtils.formatAmount(settlement['user_billing_amount'], settlement['user_billing_currency']), settlement,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: SettlementUtils.getAmountColor(settlement['user_billing_amount'])), 
          alignment: TextAlign.right);
      case 'settlement':
        return _buildClickableCell(col.width, SettlementUtils.formatAmount(settlement['merchant_settlement_amount'], settlement['merchant_settlement_currency']), settlement,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: SettlementUtils.getAmountColor(settlement['merchant_settlement_amount'])), 
          alignment: TextAlign.right);
      case 'net_settlement':
        return _buildClickableCell(col.width, SettlementUtils.formatAmount(settlement['net_merchant_settlement_amount'], settlement['merchant_settlement_currency']), settlement,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: SettlementUtils.getAmountColor(settlement['net_merchant_settlement_amount'])), 
          alignment: TextAlign.right);
      case 'merchant_store':
        return _buildClickableCell(col.width, '', settlement, child: _buildCompactMerchantInfo(settlement));
      case 'card_info':
        return _buildClickableCell(col.width, '', settlement, child: _buildCompactCardInfo(settlement));
      case 'psp_brand':
        return _buildClickableCell(col.width, '', settlement, child: _buildCompactPSPInfo(settlement));
      case 'auth_mode':
        return _buildClickableCell(col.width, '', settlement, child: _buildAuthModeInfo(settlement));
      case 'status':
        return _buildClickableCell(col.width, '', settlement, child: _buildCompactStatusInfo(settlement));
      case 'terminal':
        return _buildClickableCell(col.width, '', settlement, child: _buildCompactTerminalInfo(settlement));
      case 'fees':
        return _buildClickableCell(col.width, SettlementUtils.formatAmount(settlement['interchange_fee_amount'], settlement['transaction_currency']), settlement,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: SettlementUtils.getAmountColor(settlement['interchange_fee_amount'])), 
          alignment: TextAlign.right);
      case 'actions':
        return _buildActionCell(settlement);
      default:
        return _buildClickableCell(col.width, settlement[col.key]?.toString() ?? '-', settlement);
    }
  }

  Widget _buildCompactMerchantInfo(Map<String, dynamic> settlement) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          settlement['merchant_name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 9),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          settlement['store_name'] ?? '',
          style: TextStyle(fontSize: 8, color: Colors.grey[600]),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          settlement['group_id'] ?? '',
          style: TextStyle(fontSize: 7, color: Colors.grey[500]),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCompactCardInfo(Map<String, dynamic> settlement) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          settlement['card_number'] ?? '',
          style: const TextStyle(fontSize: 8, fontFamily: 'monospace', fontWeight: FontWeight.w500),
        ),
        Text(
          settlement['payment_brand'] ?? '',
          style: TextStyle(fontSize: 8, color: Colors.grey[600]),
        ),
        Text(
          settlement['funding_type'] ?? '',
          style: TextStyle(fontSize: 7, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildCompactPSPInfo(Map<String, dynamic> settlement) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          settlement['psp_name'] ?? '',
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          settlement['payment_brand'] ?? '',
          style: TextStyle(fontSize: 8, color: Colors.grey[600]),
        ),
        Text(
          'MCC: ${settlement['mcc'] ?? '-'}',
          style: TextStyle(fontSize: 7, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildAuthModeInfo(Map<String, dynamic> settlement) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          settlement['authorization_code'] ?? '-',
          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w500),
        ),
        Text(
          settlement['transaction_initiation_mode'] ?? '',
          style: TextStyle(fontSize: 7, color: Colors.grey[600]),
        ),
        Text(
          settlement['system_result_code'] ?? '',
          style: TextStyle(fontSize: 7, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildCompactStatusInfo(Map<String, dynamic> settlement) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: settlement['reconciliation_flag'] == 'Matched' ? Colors.green[100] : Colors.orange[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            settlement['reconciliation_flag'] ?? '',
            style: TextStyle(
              fontSize: 7, 
              fontWeight: FontWeight.bold,
              color: settlement['reconciliation_flag'] == 'Matched' ? Colors.green[800] : Colors.orange[800],
            ),
          ),
        ),
        const SizedBox(height: 1),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: settlement['crossborder_flag'] == 'Domestic' ? Colors.blue[100] : Colors.purple[100],
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            settlement['crossborder_flag'] ?? '',
            style: const TextStyle(fontSize: 6, fontWeight: FontWeight.bold),
          ),
        ),
        Text(
          settlement['transaction_status'] ?? '',
          style: TextStyle(fontSize: 6, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildCompactTerminalInfo(Map<String, dynamic> settlement) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('T: ${settlement['terminal_id'] ?? '-'}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w500)),
        Text('B: ${settlement['batch_number'] ?? '-'}', style: TextStyle(fontSize: 7, color: Colors.grey[600])),
        Text('TR: ${settlement['terminal_trace_number'] ?? '-'}', style: TextStyle(fontSize: 7, color: Colors.grey[600])),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildCompactFeesInfo(Map<String, dynamic> settlement) {
    final interchangeFee = settlement['interchange_fee_amount'];
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (interchangeFee != null)
          Text(
            SettlementUtils.formatCompactAmount(interchangeFee),
            style: TextStyle(fontSize: 7, color: SettlementUtils.getAmountColor(interchangeFee)),
          ),
        Text(
          settlement['mdr_rules'] ?? '-',
          style: TextStyle(fontSize: 6, color: Colors.grey[600]),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  DataCell _buildClickableCell(double width, String text, Map<String, dynamic> settlement, {
    TextStyle? style,
    TextAlign? alignment,
    Widget? child,
  }) {
    return DataCell(
      GestureDetector(
        onDoubleTap: () => onNavigateToDetail(settlement),
        child: Container(
          width: width,
          child: child ?? Text(
            text,
            style: style ?? const TextStyle(fontSize: 11),
            textAlign: alignment,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String? type) {
    const colors = {
      'PURCHASE': (Colors.green, Colors.white),
      'REFUND': (Colors.orange, Colors.white),
      'REVERSAL': (Colors.red, Colors.white),
    };
    final colorPair = colors[type] ?? (Colors.blue, Colors.white);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorPair.$1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type ?? '',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: colorPair.$2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  DataCell _buildActionCell(Map<String, dynamic> settlement) {
    return DataCell(
      Container(
        width: 70,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility, size: 16),
              onPressed: () => onShowQuickView(settlement),
              tooltip: 'Quick View',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () => onCopyToClipboard(settlement['order_number']?.toString() ?? '', 'Order number'),
              tooltip: 'Copy Order',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
          ],
        ),
      ),
    );
  }
}

//------------------------------------------------------------

// Pagination Controls Widget
class _PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Function(int) onPageChanged;

  const _PaginationControls({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPaginationButton(Icons.first_page, 'First Page', currentPage > 1, () => onPageChanged(1)),
          _buildPaginationButton(Icons.chevron_left, 'Previous', currentPage > 1, () => onPageChanged(currentPage - 1)),
          const SizedBox(width: 8),
          ..._buildPageNumbers(),
          const SizedBox(width: 8),
          _buildPaginationButton(Icons.chevron_right, 'Next', currentPage < totalPages, () => onPageChanged(currentPage + 1)),
          _buildPaginationButton(Icons.last_page, 'Last Page', currentPage < totalPages, () => onPageChanged(totalPages)),
        ],
      ),
    );
  }

  Widget _buildPaginationButton(IconData icon, String tooltip, bool enabled, VoidCallback onPressed) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: enabled ? null : Colors.grey[100],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    final pageCount = totalPages > 7 ? 7 : totalPages;
    return List.generate(pageCount, (index) {
      int page;
      if (totalPages <= 7) {
        page = index + 1;
      } else if (currentPage <= 4) {
        page = index + 1;
      } else if (currentPage >= totalPages - 3) {
        page = totalPages - 6 + index;
      } else {
        page = currentPage - 3 + index;
      }
      
      if (page < 1 || page > totalPages) return const SizedBox.shrink();
      
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          onTap: () => onPageChanged(page),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: page == currentPage ? Colors.blue : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: page == currentPage ? Colors.blue : Colors.grey[300]!,
              ),
            ),
            child: Text(
              page.toString(),
              style: TextStyle(
                fontWeight: page == currentPage ? FontWeight.bold : FontWeight.normal,
                color: page == currentPage ? Colors.white : Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    });
  }
}

// Dialog Widgets
class _QuickViewDialog extends StatelessWidget {
  final Map<String, dynamic> settlement;
  final VoidCallback onNavigateToDetail;
  final String currentTheme;

  const _QuickViewDialog({
    required this.settlement,
    required this.onNavigateToDetail,
    required this.currentTheme,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Quick View - Order #${settlement['order_number'] ?? ''}'),
      content: Container(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Transaction Type', settlement['transaction_type']?.toString() ?? '-'),
              _buildDetailRow('Amount', SettlementUtils.formatAmount(settlement['transaction_amount'], settlement['transaction_currency'])),
              _buildDetailRow('Merchant', settlement['merchant_name']?.toString() ?? '-'),
              _buildDetailRow('Card Number', settlement['card_number']?.toString() ?? '-'),
              _buildDetailRow('Authorization', settlement['authorization_code']?.toString() ?? '-'),
              _buildDetailRow('Status', settlement['reconciliation_flag']?.toString() ?? '-'),
              _buildDetailRow('Date', SettlementUtils.formatDateTime(settlement['transaction_time'])),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: onNavigateToDetail,
          style: ElevatedButton.styleFrom(
            backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
            foregroundColor: Colors.white,
          ),
          child: const Text('View Details'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    );
  }
}

class _ExportDialog extends StatelessWidget {
  final String csvContent;
  final String filename;
  final String currentTheme;
  final VoidCallback onExportComplete;

  const _ExportDialog({
    required this.csvContent,
    required this.filename,
    required this.currentTheme,
    required this.onExportComplete,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.file_download, color: ThemeConfig.getPrimaryColor(currentTheme)),
          const SizedBox(width: 8),
          const Text('Export Settlement Data'),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: $filename', style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            const Text('CSV Data Preview:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    csvContent.length > 1000 
                        ? '${csvContent.substring(0, 1000)}...\n\n[Content truncated for preview]'
                        : csvContent,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Copy the data and save it as a .csv file to import into spreadsheet applications.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: csvContent));
            Navigator.of(context).pop();
            onExportComplete();
          },
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copy to Clipboard'),
          style: ElevatedButton.styleFrom(
            backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// Enhanced Column Settings Dialog with reordering
class _ColumnSettingsDialog extends StatefulWidget {
  final Map<String, bool> columnVisibility;
  final List<String> columnOrder;
  final Function(String, bool) onVisibilityChanged;
  final Function(int, int) onColumnMoved;
  final VoidCallback onResetOrder;
  final VoidCallback onSave;
  final String currentTheme;

  const _ColumnSettingsDialog({
    required this.columnVisibility,
    required this.columnOrder,
    required this.onVisibilityChanged,
    required this.onColumnMoved,
    required this.onResetOrder,
    required this.onSave,
    required this.currentTheme,
  });

  @override
  State<_ColumnSettingsDialog> createState() => _ColumnSettingsDialogState();
}

class _ColumnSettingsDialogState extends State<_ColumnSettingsDialog> {
  late Map<String, bool> _localVisibility;
  late List<String> _localOrder;

  @override
  void initState() {
    super.initState();
    _localVisibility = Map.from(widget.columnVisibility);
    _localOrder = List.from(widget.columnOrder);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.view_column, color: ThemeConfig.getPrimaryColor(widget.currentTheme)),
          const SizedBox(width: 8),
          const Text('Column Settings'),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Drag to reorder columns, toggle to show/hide:',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _localOrder = SettlementConstants.columnDefinitions
                          .map((col) => col.key)
                          .toList();
                    });
                    widget.onResetOrder();
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    foregroundColor: Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (var col in SettlementConstants.columnDefinitions) {
                        _localVisibility[col.key] = true;
                        widget.onVisibilityChanged(col.key, true);
                      }
                    });
                  },
                  child: Text(
                    'Show All',
                    style: TextStyle(color: ThemeConfig.getPrimaryColor(widget.currentTheme)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ReorderableListView(
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = _localOrder.removeAt(oldIndex);
                    _localOrder.insert(newIndex, item);
                  });
                  widget.onColumnMoved(oldIndex, newIndex);
                },
                children: _localOrder.map((key) {
                  final col = SettlementConstants.columnDefinitions
                      .firstWhere((c) => c.key == key);
                  
                  return Container(
                    key: ValueKey(key),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CheckboxListTile(
                      secondary: Icon(
                        Icons.drag_handle,
                        color: Colors.grey[600],
                      ),
                      title: Text(col.title, style: const TextStyle(fontSize: 14)),
                      subtitle: Text('Width: ${col.width.toInt()}px', 
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      value: _localVisibility[col.key] ?? true,
                      onChanged: (bool? value) {
                        setState(() {
                          _localVisibility[col.key] = value ?? true;
                          widget.onVisibilityChanged(col.key, value ?? true);
                        });
                      },
                      dense: true,
                      activeColor: ThemeConfig.getPrimaryColor(widget.currentTheme),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: widget.onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: ThemeConfig.getPrimaryColor(widget.currentTheme),
            foregroundColor: Colors.white,
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _SettingsDialog extends StatelessWidget {
  final int itemsPerPage;
  final bool autoRefresh;
  final Function(int) onItemsPerPageChanged;
  final VoidCallback onAutoRefreshToggle;

  const _SettingsDialog({
    required this.itemsPerPage,
    required this.autoRefresh,
    required this.onItemsPerPageChanged,
    required this.onAutoRefreshToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.view_list),
            title: const Text('Items per page'),
            subtitle: Text('$itemsPerPage items'),
            trailing: DropdownButton<int>(
              value: itemsPerPage,
              items: SettlementConstants.itemsPerPageOptions.map((count) => DropdownMenuItem(
                value: count,
                child: Text(count.toString()),
              )).toList(),
              onChanged: (value) {
                if (value != null) {
                  onItemsPerPageChanged(value);
                }
              },
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.refresh),
            title: const Text('Auto-refresh'),
            subtitle: const Text('Refresh data every 5 minutes'),
            value: autoRefresh,
            onChanged: (value) => onAutoRefreshToggle(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}