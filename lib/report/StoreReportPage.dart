import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

// For web downloads
import 'package:universal_html/html.dart' as html;

// Data Models
class StoreReportSummary {
  final int totalItems;
  final int uniqueGroups;
  final int uniqueMerchants;
  final int uniqueStores;
  final int activeTerminals;
  final int inactiveTerminals;

  StoreReportSummary({
    required this.totalItems,
    required this.uniqueGroups,
    required this.uniqueMerchants,
    required this.uniqueStores,
    required this.activeTerminals,
    required this.inactiveTerminals,
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

// Constants
class StoreReportConstants {
  static const Duration autoRefreshInterval = Duration(minutes: 5);
  static const Duration animationDuration = Duration(milliseconds: 800);
  
  static const List<int> itemsPerPageOptions = [10, 15, 20, 25, 50];
  
  // Terminal columns based on actual API structure
  static const List<ColumnDefinition> terminalColumns = [
    // Store Info (Priority columns)
    ColumnDefinition(key: 'store_code', title: 'Store Code', width: 140.0, defaultOrder: 0),
    ColumnDefinition(key: 'store_manager', title: 'Store Manager', width: 150.0, defaultOrder: 1),
    ColumnDefinition(key: 'store_type', title: 'Store Type', width: 150.0, defaultOrder: 2),
    ColumnDefinition(key: 'store_mode', title: 'Store Mode', width: 120.0, defaultOrder: 3),
    ColumnDefinition(key: 'store_account', title: 'Account', width: 150.0, defaultOrder: 4),
    ColumnDefinition(key: 'store_account2', title: 'Account 2', width: 150.0, defaultOrder: 5),
    
    // Terminal Info (Priority columns)
    ColumnDefinition(key: 'terminal_code', title: 'Terminal Code', width: 120.0, defaultOrder: 6),
    ColumnDefinition(key: 'terminal_name', title: 'Terminal Name', width: 180.0, defaultOrder: 7),
    ColumnDefinition(key: 'serial_number', title: 'Serial Number', width: 160.0, defaultOrder: 8),
    ColumnDefinition(key: 'sim_number', title: 'SIM Number', width: 120.0, defaultOrder: 9),
    ColumnDefinition(key: 'expire_date', title: 'Expire Date', width: 120.0, defaultOrder: 10),
    
    // Fees & Percentages (Priority columns)
    ColumnDefinition(key: 'upi_percentage', title: 'UPI %', width: 80.0, defaultOrder: 11),
    ColumnDefinition(key: 'visa_percentage', title: 'Visa %', width: 80.0, defaultOrder: 12),
    ColumnDefinition(key: 'master_percentage', title: 'Master %', width: 80.0, defaultOrder: 13),
    
    // Group Info
    ColumnDefinition(key: 'group_code', title: 'Group Code', width: 120.0, defaultOrder: 14),
    ColumnDefinition(key: 'group_name', title: 'Group Name', width: 180.0, defaultOrder: 15),
    ColumnDefinition(key: 'group_phone', title: 'Group Phone', width: 120.0, defaultOrder: 16),
    
    // Merchant Info
    ColumnDefinition(key: 'merchant_code', title: 'Merchant Code', width: 140.0, defaultOrder: 17),
    ColumnDefinition(key: 'merchant_name', title: 'Merchant Name', width: 180.0, defaultOrder: 18),
    ColumnDefinition(key: 'merchant_phone', title: 'Merchant Phone', width: 120.0, defaultOrder: 19),
    
    // Other Store Info
    ColumnDefinition(key: 'store_name', title: 'Store Name', width: 180.0, defaultOrder: 20),
    ColumnDefinition(key: 'store_email', title: 'Store Email', width: 160.0, defaultOrder: 21),
    ColumnDefinition(key: 'store_phone', title: 'Store Phone', width: 120.0, defaultOrder: 22),
    ColumnDefinition(key: 'address', title: 'Address', width: 180.0, defaultOrder: 23),
    ColumnDefinition(key: 'city', title: 'City', width: 120.0, defaultOrder: 24),
    ColumnDefinition(key: 'state', title: 'State', width: 120.0, defaultOrder: 25),
    ColumnDefinition(key: 'country', title: 'Country', width: 100.0, defaultOrder: 26),
    
    // Other Terminal Info
    ColumnDefinition(key: 'terminal_id', title: 'Terminal ID', width: 100.0, defaultOrder: 27),
    ColumnDefinition(key: 'terminal_phone', title: 'Terminal Phone', width: 120.0, defaultOrder: 28),
    
    // Hierarchy
    ColumnDefinition(key: 'hierarchy_path', title: 'Hierarchy Path', width: 250.0, defaultOrder: 29),
    ColumnDefinition(key: 'terminal_availability', title: 'Availability', width: 120.0, defaultOrder: 30),
    
    // Counts
    ColumnDefinition(key: 'merchants_in_group', title: 'Merchants', width: 100.0, defaultOrder: 31),
    ColumnDefinition(key: 'stores_in_merchant', title: 'Stores', width: 100.0, defaultOrder: 32),
    ColumnDefinition(key: 'terminals_in_store', title: 'Terminals', width: 100.0, defaultOrder: 33),
    
    // Dates
    ColumnDefinition(key: 'terminal_created_date', title: 'Terminal Created', width: 140.0, defaultOrder: 34),
    ColumnDefinition(key: 'terminal_updated_date', title: 'Terminal Updated', width: 140.0, defaultOrder: 35),
  ];
}

// Store Report Service
class StoreReportService {
  static Future<List<Map<String, dynamic>>> fetchTerminals(int companyId) async {
    return _fetchData('terminals', companyId);
  }

  static Future<List<Map<String, dynamic>>> _fetchData(String endpoint, int companyId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final url = AppConfig.api('/api/ioview/$endpoint?company_id=$companyId');

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
        return List<Map<String, dynamic>>.from(responseData['data']);
      } else {
        throw Exception(responseData['message'] ?? 'Failed to fetch data');
      }
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
    }
  }
}

// Utility Functions
class StoreReportUtils {
  static String formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return '-';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd, yyyy\nHH:mm:ss').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  static String generateCSV(List<Map<String, dynamic>> data, String reportType) {
    if (data.isEmpty) return '';
    
    final headers = data.first.keys.toList();
    final csvLines = <String>[
      headers.map((e) => '"$e"').join(','),
      ...data.map((item) => 
        headers.map((key) => '"${item[key]?.toString().replaceAll('"', '""') ?? ''}"').join(',')
      )
    ];
    
    return csvLines.join('\n');
  }

  static List<int>? generateExcel(
    List<Map<String, dynamic>> data, 
    List<String> columnOrder,
    Map<String, bool> columnVisibility
  ) {
    if (data.isEmpty) return null;
    
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Terminals'];
      
      // Get visible columns
      final visibleColumns = columnOrder
          .where((key) => columnVisibility[key] == true)
          .toList();
      
      // Add headers
      for (int i = 0; i < visibleColumns.length; i++) {
        final col = visibleColumns[i];
        final columnDef = StoreReportConstants.terminalColumns
            .firstWhere(
              (c) => c.key == col, 
              orElse: () => ColumnDefinition(
                key: col, 
                title: col, 
                width: 120, 
                defaultOrder: i
              )
            );
        
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(columnDef.title);
        cell.cellStyle = CellStyle(
          bold: true,
        );
      }
      
      // Add data rows
      for (int rowIndex = 0; rowIndex < data.length; rowIndex++) {
        final item = data[rowIndex];
        for (int colIndex = 0; colIndex < visibleColumns.length; colIndex++) {
          final key = visibleColumns[colIndex];
          final value = item[key];
          
          final cell = sheet.cell(CellIndex.indexByColumnRow(
            columnIndex: colIndex, 
            rowIndex: rowIndex + 1
          ));
          
          if (value != null && value.toString().isNotEmpty && value.toString() != 'null') {
            // Handle different data types
            if (value is num) {
              cell.value = DoubleCellValue(value.toDouble());
            } else if (key.contains('date') || key == 'expire_date') {
              cell.value = TextCellValue(formatDateTime(value.toString()));
            } else {
              cell.value = TextCellValue(value.toString());
            }
          } else {
            cell.value = TextCellValue('-');
          }
        }
      }
      
      // Auto-fit columns (approximate width)
      try {
        for (int i = 0; i < visibleColumns.length; i++) {
          sheet.setColumnWidth(i, 15.0);
        }
      } catch (e) {
        print('Column width setting not supported');
      }
      
      return excel.encode();
    } catch (e) {
      print('Error generating Excel: $e');
      return null;
    }
  }
}

// Filter Manager
class FilterManager {
  String searchQuery = '';
  int? companyIdFilter;
  String? groupFilter;
  String? merchantFilter;
  String? storeFilter;
  String? availabilityFilter;

  bool get hasActiveFilters => 
      searchQuery.isNotEmpty || 
      companyIdFilter != null || 
      groupFilter != null ||
      merchantFilter != null ||
      storeFilter != null ||
      availabilityFilter != null;

  List<Map<String, dynamic>> applyFilters(List<Map<String, dynamic>> items) {
    List<Map<String, dynamic>> filtered = List.from(items);
    
    if (searchQuery.isNotEmpty) {
      filtered = _applySearchFilter(filtered);
    }
    
    if (companyIdFilter != null) {
      filtered = filtered.where((item) => item['company_id'] == companyIdFilter).toList();
    }
    
    if (groupFilter != null && groupFilter!.isNotEmpty) {
      filtered = filtered.where((item) => 
        item['group_name']?.toString().toLowerCase().contains(groupFilter!.toLowerCase()) ?? false
      ).toList();
    }
    
    if (merchantFilter != null && merchantFilter!.isNotEmpty) {
      filtered = filtered.where((item) => 
        item['merchant_name']?.toString().toLowerCase().contains(merchantFilter!.toLowerCase()) ?? false
      ).toList();
    }
    
    if (storeFilter != null && storeFilter!.isNotEmpty) {
      filtered = filtered.where((item) => 
        item['store_name']?.toString().toLowerCase().contains(storeFilter!.toLowerCase()) ?? false
      ).toList();
    }
    
    if (availabilityFilter != null && availabilityFilter!.isNotEmpty) {
      filtered = filtered.where((item) => 
        item['terminal_availability']?.toString() == availabilityFilter
      ).toList();
    }
    
    return filtered;
  }

  List<Map<String, dynamic>> _applySearchFilter(List<Map<String, dynamic>> data) {
    final query = searchQuery.toLowerCase();
    return data.where((item) {
      return [
        item['group_code'],
        item['group_name'],
        item['merchant_code'],
        item['merchant_name'],
        item['store_code'],
        item['store_name'],
        item['store_manager'],
        item['store_account'],
        item['store_account2'],
        item['store_type'],
        item['store_mode'],
        item['terminal_code'],
        item['terminal_name'],
        item['terminal_id']?.toString(),
        item['serial_number'],
        item['sim_number'],
        item['hierarchy_path'],
      ].any((field) => field?.toString().toLowerCase().contains(query) == true);
    }).toList();
  }

  void clearAll() {
    searchQuery = '';
    companyIdFilter = null;
    groupFilter = null;
    merchantFilter = null;
    storeFilter = null;
    availabilityFilter = null;
  }
}

// Main Widget
class StoreReportPage extends StatefulWidget {
  const StoreReportPage({Key? key}) : super(key: key);

  @override
  State<StoreReportPage> createState() => _StoreReportPageState();
}

class _StoreReportPageState extends State<StoreReportPage>
    with TickerProviderStateMixin {
  
  // State Variables - Default visibility for key columns
  Map<String, bool> _columnVisibility = {
    // Store - show by default
    'store_code': true,
    'store_manager': true,
    'store_type': true,
    'store_account': true,
    'store_account2': true,
    
    // Terminal - show by default
    'terminal_code': true,
    'terminal_name': true,
    'serial_number': true,
    'sim_number': true,
    'expire_date': true,
    
    // Fees - show by default
    'upi_percentage': true,
    'visa_percentage': true,
    'master_percentage': true,
    
    // Store mode (if exists)
    'store_mode': true,
    
    // Group - hide by default
    'group_code': false,
    'group_name': false,
    'group_phone': false,
    
    // Merchant - hide by default
    'merchant_code': false,
    'merchant_name': false,
    'merchant_phone': false,
    
    // Other store fields - hide by default
    'store_name': false,
    'store_email': false,
    'store_phone': false,
    'address': false,
    'city': false,
    'state': false,
    'country': false,
    
    // Other terminal fields - hide by default
    'terminal_id': false,
    'terminal_phone': false,
    
    // Hierarchy - hide by default
    'hierarchy_path': false,
    'terminal_availability': false,
    
    // Counts - hide by default
    'merchants_in_group': false,
    'stores_in_merchant': false,
    'terminals_in_store': false,
    
    // Dates - hide by default
    'terminal_created_date': false,
    'terminal_updated_date': false,
  };
  
  List<String> _columnOrder = [
    // Default visible columns first
    'store_code', 'store_manager', 'terminal_code', 'terminal_name',
    'serial_number', 'sim_number', 'expire_date', 'store_mode', 'store_type',
    'upi_percentage', 'visa_percentage', 'master_percentage',
    'store_account', 'store_account2',
    // Hidden columns after
    'group_code', 'group_name', 'group_phone',
    'merchant_code', 'merchant_name', 'merchant_phone',
    'store_name', 'store_email', 'store_phone',
    'address', 'city', 'state', 'country',
    'terminal_id', 'terminal_phone',
    'hierarchy_path', 'terminal_availability',
    'merchants_in_group', 'stores_in_merchant', 'terminals_in_store',
    'terminal_created_date', 'terminal_updated_date',
  ];
  
  final FilterManager _filterManager = FilterManager();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _companyIdController = TextEditingController(text: '2');
  
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredItems = [];
  Set<String> _selectedItems = {};
  StoreReportSummary _summaryData = StoreReportSummary(
    totalItems: 0,
    uniqueGroups: 0,
    uniqueMerchants: 0,
    uniqueStores: 0,
    activeTerminals: 0,
    inactiveTerminals: 0,
  );
  
  String _currentReportType = 'Terminals';
  int _currentPage = 1;
  int _itemsPerPage = 15;
  int _companyId = 2;
  
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _autoRefresh = false;
  String _errorMessage = '';
  String currentTheme = ThemeConfig.defaultTheme;
  
  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
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

  void _initializeComponents() {
    _loadCurrentTheme();
    _setupAnimations();
    _fetchData();
    _loadAutoRefreshPreference();
  }

  void _disposeComponents() {
    _searchController.dispose();
    _companyIdController.dispose();
    _fadeController.dispose();
    _refreshTimer?.cancel();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: StoreReportConstants.animationDuration,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _fadeController.forward();
  }

  Future<void> _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
    await _loadColumnPreferences();
  }

  Future<void> _loadColumnPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'store_report_terminals';
    
    setState(() {
      for (var col in _getCurrentColumns()) {
        _columnVisibility[col.key] = prefs.getBool('${key}_${col.key}') ?? (_columnVisibility[col.key] ?? false);
      }
      
      final savedOrder = prefs.getStringList('${key}_order');
      if (savedOrder != null && savedOrder.isNotEmpty) {
        _columnOrder = savedOrder;
      }
    });
  }

  Future<void> _saveColumnPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'store_report_terminals';
    
    for (var entry in _columnVisibility.entries) {
      await prefs.setBool('${key}_${entry.key}', entry.value);
    }
    
    await prefs.setStringList('${key}_order', _columnOrder);
  }

  List<ColumnDefinition> _getCurrentColumns() {
    return StoreReportConstants.terminalColumns;
  }

  Future<void> _loadAutoRefreshPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoRefresh = prefs.getBool('store_report_auto_refresh') ?? false;
    });
    if (_autoRefresh) _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(StoreReportConstants.autoRefreshInterval, (timer) {
      if (mounted) _fetchData(isRefresh: true);
    });
  }

  void _stopAutoRefresh() => _refreshTimer?.cancel();

  Future<void> _toggleAutoRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _autoRefresh = !_autoRefresh);
    await prefs.setBool('store_report_auto_refresh', _autoRefresh);
    
    if (_autoRefresh) {
      _startAutoRefresh();
      _showSnackBar('Auto-refresh enabled (every 5 minutes)', Colors.green);
    } else {
      _stopAutoRefresh();
      _showSnackBar('Auto-refresh disabled', Colors.orange);
    }
  }

  Future<void> _fetchData({bool isRefresh = false}) async {
    _setLoadingState(isRefresh);

    try {
      final data = await StoreReportService.fetchTerminals(_companyId);
      
      setState(() {
        _items = data;
        _filteredItems = List.from(_items);
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
    final uniqueGroupCodes = <String>{};
    final uniqueMerchantCodes = <String>{};
    final uniqueStoreCodes = <String>{};
    int activeCount = 0;
    int inactiveCount = 0;
    
    for (var item in _filteredItems) {
      if (item['group_code'] != null) uniqueGroupCodes.add(item['group_code']);
      if (item['merchant_code'] != null) uniqueMerchantCodes.add(item['merchant_code']);
      if (item['store_code'] != null) uniqueStoreCodes.add(item['store_code']);
      
      final availability = item['terminal_availability']?.toString() ?? '';
      if (availability.contains('Available')) {
        activeCount++;
      } else if (availability.contains('No Terminal')) {
        inactiveCount++;
      }
    }
    
    setState(() {
      _summaryData = StoreReportSummary(
        totalItems: _filteredItems.length,
        uniqueGroups: uniqueGroupCodes.length,
        uniqueMerchants: uniqueMerchantCodes.length,
        uniqueStores: uniqueStoreCodes.length,
        activeTerminals: activeCount,
        inactiveTerminals: inactiveCount,
      );
    });
  }

  void _applyFilters() {
    _filterManager.searchQuery = _searchController.text;
    final filtered = _filterManager.applyFilters(_items);
    
    setState(() {
      _filteredItems = filtered;
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

  List<Map<String, dynamic>> _getPaginatedData() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _filteredItems.length);
    return _filteredItems.sublist(startIndex, endIndex);
  }

  int get _totalPages => (_filteredItems.length / _itemsPerPage).ceil();

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

  // ignore: unused_element
  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('$label copied to clipboard', Colors.green);
  }

  Future<void> _exportToCSV() async {
    try {
      final csvContent = StoreReportUtils.generateCSV(_filteredItems, 'Terminals');
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      // ignore: unused_local_variable
      final filename = 'terminals_$timestamp.csv';
      
      await Clipboard.setData(ClipboardData(text: csvContent));
      _showSnackBar('CSV data copied to clipboard', Colors.green);
    } catch (e) {
      _showSnackBar('Export failed: $e', Colors.red);
    }
  }

  Future<void> _exportToExcel() async {
    try {
      final excelContent = StoreReportUtils.generateExcel(
        _filteredItems, 
        _columnOrder, 
        _columnVisibility
      );
      
      if (excelContent == null) {
        _showSnackBar('Failed to generate Excel file', Colors.red);
        return;
      }
      
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'terminals_$timestamp.xlsx';
      
      if (kIsWeb) {
        final blob = html.Blob([excelContent], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        // ignore: unused_local_variable
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..click();
        html.Url.revokeObjectUrl(url);
        _showSnackBar('Excel file downloaded: $filename', Colors.green);
      } else {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/$filename';
        final file = File(filePath);
        await file.writeAsBytes(excelContent);
        
        final result = await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'Terminal Report',
          text: 'Terminal report exported on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
        );
        
        if (result.status == ShareResultStatus.success) {
          _showSnackBar('Excel file shared successfully', Colors.green);
        } else {
          _showSnackBar('Excel file saved: $filename', Colors.green);
        }
      }
    } catch (e) {
      _showSnackBar('Excel export failed: $e', Colors.red);
      print('Excel export error: $e');
    }
  }

  // ignore: unused_element
  void _changeReportType(String newType) {
    setState(() {
      _currentReportType = newType;
      _currentPage = 1;
      _items.clear();
      _filteredItems.clear();
      _selectedItems.clear();
    });
    _loadColumnPreferences();
    _fetchData();
  }

  void _updateCompanyId() {
    final newCompanyId = int.tryParse(_companyIdController.text);
    if (newCompanyId != null && newCompanyId > 0) {
      setState(() {
        _companyId = newCompanyId;
      });
      _fetchData();
    } else {
      _showSnackBar('Please enter a valid company ID', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _SummaryCards(summaryData: _summaryData, currentReportType: _currentReportType),
            _FilterSection(
              filterManager: _filterManager,
              searchController: _searchController,
              companyIdController: _companyIdController,
              onFiltersChanged: _applyFilters,
              onClearFilters: _clearAllFilters,
              onUpdateCompanyId: _updateCompanyId,
              currentTheme: currentTheme,
            ),
            _buildTableSection(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          const Text('Terminal Report'),
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
          onPressed: () => _fetchData(isRefresh: true),
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'export_csv':
                _exportToCSV();
                break;
              case 'export_excel':
                _exportToExcel();
                break;
              case 'clear_filters':
                _clearAllFilters();
                break;
              case 'column_settings':
                _showColumnSettingsDialog();
                break;
              case 'settings':
                _showSettingsDialog();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'export_csv',
              child: Row(children: [
                Icon(Icons.file_download, color: Colors.green),
                SizedBox(width: 8),
                Text('Export CSV')
              ]),
            ),
            const PopupMenuItem(
              value: 'export_excel',
              child: Row(children: [
                Icon(Icons.table_chart, color: Colors.green),
                SizedBox(width: 8),
                Text('Export Excel')
              ]),
            ),
            const PopupMenuItem(value: 'clear_filters', child: Row(children: [Icon(Icons.clear_all), SizedBox(width: 8), Text('Clear Filters')])),
            const PopupMenuItem(value: 'column_settings', child: Row(children: [Icon(Icons.view_column), SizedBox(width: 8), Text('Column Settings')])),
            const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings), SizedBox(width: 8), Text('Settings')])),
          ],
        ),
      ],
    );
  }

  Widget _buildTableSection() {
    if (_isLoading) return _buildLoadingWidget();
    if (_errorMessage.isNotEmpty) return _buildErrorWidget();
    if (_filteredItems.isEmpty) return _buildEmptyWidget();
    
    return Expanded(
      child: Column(
        children: [
          _buildResultsInfo(),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: _buildDataTable(),
              ),
            ),
          ),
          if (_totalPages > 1) _buildPaginationControls(),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    final visibleColumns = _columnOrder
        .where((key) => _columnVisibility[key] == true)
        .toList();
    
    final columnDefs = _getCurrentColumns()
        .where((col) => visibleColumns.contains(col.key))
        .toList();

    return DataTable(
      columnSpacing: 12,
      dataRowHeight: 60,
      headingRowHeight: 48,
      headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
      border: TableBorder.all(color: Colors.grey[300]!, width: 0.5),
      columns: columnDefs.map((col) => DataColumn(
        label: Container(
          width: col.width,
          child: Text(
            col.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      )).toList(),
      rows: _getPaginatedData().map((item) => DataRow(
        cells: columnDefs.map((col) => DataCell(
          Container(
            width: col.width,
            child: _buildCellContent(col.key, item),
          ),
        )).toList(),
      )).toList(),
    );
  }

  Widget _buildCellContent(String key, Map<String, dynamic> item) {
    final value = item[key];
    
    if (value == null || value.toString().isEmpty || value.toString() == 'null') {
      return const Text('-', style: TextStyle(fontSize: 11, color: Colors.grey));
    }
    
    switch (key) {
      case 'terminal_created_date':
      case 'terminal_updated_date':
      case 'expire_date':
        return Text(
          StoreReportUtils.formatDateTime(value.toString()),
          style: const TextStyle(fontSize: 10),
        );
      
      case 'terminal_availability':
        final isAvailable = value.toString().contains('Available');
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isAvailable ? Colors.green[100] : Colors.red[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isAvailable ? Colors.green[800] : Colors.red[800],
            ),
          ),
        );
      
      case 'upi_percentage':
      case 'visa_percentage':
      case 'master_percentage':
        return Text(
          '${value}%',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        );
      
      case 'hierarchy_path':
        return Tooltip(
          message: value.toString(),
          child: Text(
            value.toString(),
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      
      case 'merchants_in_group':
      case 'stores_in_merchant':
      case 'terminals_in_store':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
        );
      
      case 'store_email':
        return SelectableText(
          value.toString(),
          style: const TextStyle(fontSize: 10, color: Colors.blue),
        );
      
      case 'store_account':
      case 'store_account2':
        return SelectableText(
          value.toString(),
          style: const TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w500,
          ),
        );
      
      case 'store_mode':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
        );
      
      case 'group_phone':
      case 'merchant_phone':
      case 'store_phone':
      case 'terminal_phone':
        return Text(
          value.toString(),
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        );
      
      case 'group_code':
      case 'merchant_code':
      case 'store_code':
      case 'terminal_code':
        return Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        );
      
      case 'group_name':
      case 'merchant_name':
      case 'store_name':
      case 'terminal_name':
        return Text(
          value.toString(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      
      case 'address':
      case 'store_type':
        return Text(
          value.toString(),
          style: const TextStyle(fontSize: 10),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      
      default:
        return Text(
          value.toString(),
          style: const TextStyle(fontSize: 11),
          overflow: TextOverflow.ellipsis,
        );
    }
  }

  Widget _buildLoadingWidget() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: ThemeConfig.getPrimaryColor(currentTheme)),
            const SizedBox(height: 16),
            const Text('Loading terminals...'),
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
            const Text('Error loading terminals:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchData,
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
            Icon(Icons.devices_other, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No terminals found', style: TextStyle(fontSize: 18)),
            Text('Try adjusting your filters or company ID'),
          ],
        ),
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
            'Showing $startIndex-$endIndex of ${_filteredItems.length} items',
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
          IconButton(
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage = 1) : null,
            icon: const Icon(Icons.first_page),
          ),
          IconButton(
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Page $_currentPage of $_totalPages'),
          IconButton(
            onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage = _totalPages) : null,
            icon: const Icon(Icons.last_page),
          ),
        ],
      ),
    );
  }

  void _showColumnSettingsDialog() {
    // Create a local copy for editing
    List<String> tempColumnOrder = List.from(_columnOrder);
    Map<String, bool> tempColumnVisibility = Map.from(_columnVisibility);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.view_column),
                const SizedBox(width: 8),
                const Text('Column Settings'),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setDialogState(() {
                      for (var key in tempColumnVisibility.keys) {
                        tempColumnVisibility[key] = true;
                      }
                    });
                  },
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('Show All', style: TextStyle(fontSize: 12)),
                ),
                TextButton.icon(
                  onPressed: () {
                    setDialogState(() {
                      for (var key in tempColumnVisibility.keys) {
                        tempColumnVisibility[key] = false;
                      }
                    });
                  },
                  icon: const Icon(Icons.visibility_off, size: 16),
                  label: const Text('Hide All', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Drag to reorder columns. Toggle visibility with checkbox.',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ReorderableListView.builder(
                      itemCount: tempColumnOrder.length,
                      onReorder: (oldIndex, newIndex) {
                        setDialogState(() {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final item = tempColumnOrder.removeAt(oldIndex);
                          tempColumnOrder.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final key = tempColumnOrder[index];
                        final columnDef = StoreReportConstants.terminalColumns
                            .firstWhere(
                              (c) => c.key == key,
                              orElse: () => ColumnDefinition(
                                key: key,
                                title: key,
                                width: 120,
                                defaultOrder: index,
                              ),
                            );
                        
                        final isVisible = tempColumnVisibility[key] ?? true;
                        
                        return Container(
                          key: ValueKey(key),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isVisible ? Colors.white : Colors.grey.shade100,
                            border: Border.all(
                              color: isVisible ? Colors.blue.shade200 : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.drag_indicator,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              columnDef.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isVisible ? Colors.black : Colors.grey,
                              ),
                            ),
                            subtitle: Text(
                              key,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontFamily: 'monospace',
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isVisible)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Visible',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Checkbox(
                                  value: isVisible,
                                  onChanged: (bool? value) {
                                    setDialogState(() {
                                      tempColumnVisibility[key] = value ?? true;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    tempColumnOrder = _getCurrentColumns()
                        .map((col) => col.key)
                        .toList()
                      ..sort((a, b) {
                        final colA = _getCurrentColumns().firstWhere((c) => c.key == a);
                        final colB = _getCurrentColumns().firstWhere((c) => c.key == b);
                        return colA.defaultOrder.compareTo(colB.defaultOrder);
                      });
                  });
                },
                child: const Text('Reset Order'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _columnOrder = tempColumnOrder;
                    _columnVisibility = tempColumnVisibility;
                  });
                  _saveColumnPreferences();
                  Navigator.pop(context);
                  _showSnackBar('Column settings saved', Colors.green);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.view_list),
              title: const Text('Items per page'),
              trailing: DropdownButton<int>(
                value: _itemsPerPage,
                items: StoreReportConstants.itemsPerPageOptions.map((count) => DropdownMenuItem(
                  value: count,
                  child: Text(count.toString()),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _itemsPerPage = value!;
                    _currentPage = 1;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// Summary Cards Widget - FIXED VERSION
class _SummaryCards extends StatelessWidget {
  final StoreReportSummary summaryData;
  final String currentReportType;

  const _SummaryCards({required this.summaryData, required this.currentReportType});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildSummaryCard('Total Records', summaryData.totalItems.toString(), Icons.inventory_2, Colors.blue),
          const SizedBox(width: 12),
          _buildSummaryCard('Groups', summaryData.uniqueGroups.toString(), Icons.business, Colors.purple),
          const SizedBox(width: 12),
          _buildSummaryCard('Merchants', summaryData.uniqueMerchants.toString(), Icons.store, Colors.orange),
          const SizedBox(width: 12),
          _buildSummaryCard('Stores', summaryData.uniqueStores.toString(), Icons.location_on, Colors.teal),
          const SizedBox(width: 12),
          _buildSummaryCard('Active Terminals', summaryData.activeTerminals.toString(), Icons.check_circle, Colors.green),
          const SizedBox(width: 12),
          _buildSummaryCard('Inactive', summaryData.inactiveTerminals.toString(), Icons.cancel, Colors.red),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 140,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
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
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
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

// Filter Section Widget
class _FilterSection extends StatelessWidget {
  final FilterManager filterManager;
  final TextEditingController searchController;
  final TextEditingController companyIdController;
  final VoidCallback onFiltersChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onUpdateCompanyId;
  final String currentTheme;

  const _FilterSection({
    required this.filterManager,
    required this.searchController,
    required this.companyIdController,
    required this.onFiltersChanged,
    required this.onClearFilters,
    required this.onUpdateCompanyId,
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
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by ID, name, description...',
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
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                  onChanged: (value) => onFiltersChanged(),
                ),
              ),
              const SizedBox(width: 12),
              // Expanded(
              //   child: TextField(
              //     controller: companyIdController,
              //     decoration: InputDecoration(
              //       labelText: 'Company ID',
              //       border: OutlineInputBorder(
              //         borderRadius: BorderRadius.circular(8),
              //       ),
              //       contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              //       isDense: true,
              //     ),
              //     keyboardType: TextInputType.number,
              //   ),
              // ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onUpdateCompanyId,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
          if (filterManager.hasActiveFilters) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Active filters:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                if (filterManager.searchQuery.isNotEmpty)
                  Chip(
                    label: Text('Search: ${filterManager.searchQuery}', style: const TextStyle(fontSize: 11)),
                    onDeleted: () {
                      searchController.clear();
                      onFiltersChanged();
                    },
                    deleteIconColor: Colors.red,
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear All'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}