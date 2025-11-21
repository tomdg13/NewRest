import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:csv/csv.dart';

class EnhancedSettlementUploadPage extends StatefulWidget {
  const EnhancedSettlementUploadPage({Key? key}) : super(key: key);

  @override
  State<EnhancedSettlementUploadPage> createState() => _EnhancedSettlementUploadPageState();
}

class _EnhancedSettlementUploadPageState extends State<EnhancedSettlementUploadPage> with TickerProviderStateMixin {
  // File handling
  // ignore: unused_field
  PlatformFile? _selectedFile;
  Uint8List? _fileBytes;
  String? _fileName;
  List<Map<String, dynamic>>? _parsedData;
  
  // Loading states
  bool _isParsing = false;
  bool _isUploading = false;
  bool _isConverting = false;
  
  String currentTheme = ThemeConfig.defaultTheme;
  String _fileType = 'settlement'; // 'settlement' or 'psp'
  
  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Upload progress
  double _uploadProgress = 0.0;
  int _successCount = 0;
  int _errorCount = 0;
  List<String> _errorMessages = [];

  // PSP to Settlement field mapping
  static const Map<String, String> _pspFieldMapping = {
    'transaction_time': 'Merchant Txn Time',
    'payment_time': 'Txn Pay Time', 
    'terminal_settlement_time': 'PSP Settlement Date',
    'order_number': 'Merchant Txn ID',
    'psp_order_number': 'System Txn ID',
    'original_order_number': 'Original Merchant Txn ID',
    'original_psp_order_number': 'Original System Txn ID',
    'transaction_amount': 'Merchant Txn Amt',
    'tips_amount': 'Tips Amount',
    'merchant_settlement_amount': 'PSP Sttl Amt',
    'mdr_amount': 'PSP Discount Amt',
    'net_merchant_settlement_amount': 'PSP Net Sttl Amt',
    'brand_settlement_amount': 'PSP Sttl Amt',
    'interchange_fee_amount': 'PSP Interchange Fee',
    'net_brand_settlement_amount': 'PSP Net Sttl Amt',
    'transaction_currency': 'Merchant Txn Curr',
    'merchant_settlement_currency': 'PSP Sttl Curr',
    'brand_settlement_currency': 'PSP Sttl Curr',
    'reconciliation_flag': 'Txn Status',
    'transaction_type': 'Txn Type',
    'psp_name': 'PSP Name',
    'payment_brand': 'Payment Brand',
    'card_number': 'Card Number',
    'authorization_code': 'PSP Authorization Code',
    'mcc': 'Store MCC',
    'crossborder_flag': 'Crossborder Flag',
    'group_id': 'Group ID',
    'group_name': 'Group Name',
    'merchant_id': 'Merchant ID',
    'merchant_name': 'Merchant Name',
    'store_id': 'Store ID',
    'store_name': 'Store Name',
    'terminal_id': 'Terminal ID',
    'batch_number': '', // Will be generated
    'terminal_trace_number': '', // Will be generated
    'remark': 'PSP ARN'
  };

  // Column mapping for settlement files (from your original code)
  static const Map<String, String> _settlementColumnMapping = {
    'transaction_time': 'Transaction Time',
    'payment_time': 'Payment Time',
    'order_number': 'Order Number',
    'psp_order_number': 'PSP Order Number',
    'original_order_number': 'Original Order Number',
    'original_psp_order_number': 'Original PSP Order Number',
    'transaction_amount': 'Transaction Amount',
    'tips_amount': 'Tips Amount',
    'transaction_currency': 'Transaction Currency',
    'merchant_settlement_amount': 'Merchant Settlement Amount',
    'merchant_settlement_currency': 'Merchant Settlement Currency',
    'mdr_amount': 'MDR Amount',
    'net_merchant_settlement_amount': 'Net Merchant Settlement Amount',
    'brand_settlement_amount': 'Brand Settlement Amount',
    'brand_settlement_currency': 'Brand  Settlement Currency',
    'interchange_fee_amount': 'Interchange Fee Amount',
    'net_brand_settlement_amount': 'Net Brand Settlement Amount',
    'reconciliation_flag': 'Reconciliation Flag',
    'transaction_type': 'Transaction Type',
    'psp_name': 'PSP Name',
    'payment_brand': 'Payment Brand',
    'card_number': 'Card Number',
    'authorization_code': 'Authorization Code',
    'mcc': 'MCC',
    'crossborder_flag': 'Crossboarder Flag',
    'group_id': 'Group ID',
    'group_name': 'Group Name',
    'merchant_id': 'Merchant ID',
    'merchant_name': 'Merchant Name',
    'store_id': 'Store ID',
    'store_name': 'Store Name',
    'terminal_id': 'Terminal ID',
    'terminal_settlement_time': 'Terminal Settlement Time',
    'batch_number': 'Batch Number',
    'terminal_trace_number': 'Terminal Trace Number',
    'remark': 'Remark'
  };

  static const List<String> _requiredColumns = [
    'transaction_time', 'payment_time', 'order_number', 'psp_order_number',
    'transaction_amount', 'transaction_currency', 'merchant_settlement_amount',
    'merchant_settlement_currency', 'mdr_amount', 'net_merchant_settlement_amount',
    'reconciliation_flag', 'transaction_type', 'psp_name', 'payment_brand',
    'card_number', 'authorization_code', 'mcc', 'group_id',
    'group_name', 'merchant_id', 'merchant_name', 'store_id', 'store_name',
    'terminal_id', 'terminal_settlement_time', 'batch_number', 'terminal_trace_number'
  ];

  static const List<String> _optionalColumns = [
    'crossborder_flag', 'original_order_number', 'original_psp_order_number',
    'tips_amount', 'brand_settlement_amount', 'brand_settlement_currency',
    'interchange_fee_amount', 'net_brand_settlement_amount', 'remark'
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
    _setupAnimations();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  void _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  // File type detection
  String _detectFileType(List<String> headers) {
    // Check for PSP specific headers
    List<String> pspHeaders = ['Merchant Txn Time', 'PSP Name', 'PSP Sttl Amt', 'System Txn ID'];
    int pspMatches = pspHeaders.where((header) => headers.contains(header)).length;
    
    // Check for settlement specific headers
    List<String> settlementHeaders = ['Transaction Time', 'Payment Time', 'Order Number'];
    int settlementMatches = settlementHeaders.where((header) => headers.contains(header)).length;
    
    if (pspMatches >= 3) {
      return 'psp';
    } else if (settlementMatches >= 2) {
      return 'settlement';
    } else {
      return 'settlement'; // Default to settlement
    }
  }

  // File picking methods
  Future<void> _pickFile() async {
    try {
      _resetState();
      
      if (kIsWeb) {
        await _pickFileWeb();
      } else {
        await _pickFileMobile();
      }
    } catch (e) {
      _showSnackBar('Error selecting file: $e', isError: true);
    }
  }

  Future<void> _pickFileWeb() async {
    final html.FileUploadInputElement input = html.FileUploadInputElement();
    input.accept = '.xlsx,.xls,.csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.ms-excel,text/csv';
    input.click();

    input.onChange.listen((e) async {
      final files = input.files;
      if (files!.isEmpty) return;

      final file = files[0];
      if (!_isValidFileType(file.name)) return;

      final reader = html.FileReader();
      reader.onLoadEnd.listen((e) async {
        final Uint8List bytes = reader.result as Uint8List;
        await _processFile(file.name, bytes);
      });
      reader.readAsArrayBuffer(file);
    });
  }

  Future<void> _pickFileMobile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (!_isValidFileType(file.name)) return;
      
      await _processFile(file.name, file.bytes!);
    }
  }

  bool _isValidFileType(String fileName) {
    String extension = fileName.toLowerCase().split('.').last;
    List<String> allowedExtensions = ['xlsx', 'xls', 'csv'];
    
    if (!allowedExtensions.contains(extension)) {
      _showSnackBar('Please select a valid file (.xlsx, .xls, or .csv)', isError: true);
      return false;
    }
    
    return true;
  }

  Future<void> _processFile(String fileName, Uint8List bytes) async {
    setState(() {
      _fileName = fileName;
      _fileBytes = bytes;
      _isParsing = true;
    });

    try {
      String extension = fileName.toLowerCase().split('.').last;
      
      if (extension == 'csv') {
        await _parseCsvFile();
      } else {
        await _parseExcelFile();
      }
    } catch (e) {
      _showSnackBar('Error processing file: $e', isError: true);
    } finally {
      setState(() {
        _isParsing = false;
      });
    }
  }

  Future<void> _parseCsvFile() async {
    try {
      String csvString = String.fromCharCodes(_fileBytes!);
      
      List<List<dynamic>> csvTable = const CsvToListConverter(
        fieldDelimiter: ',',
        textDelimiter: '"',
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csvString);
      
      await _processTableData(csvTable);
    } catch (e) {
      _showSnackBar('Error parsing CSV file: $e', isError: true);
    }
  }

  Future<void> _parseExcelFile() async {
    try {
      var excel = excel_pkg.Excel.decodeBytes(_fileBytes!);
      var table = excel.tables[excel.tables.keys.first];
      
      if (table == null || table.rows.isEmpty) {
        throw Exception('Excel file is empty or invalid');
      }

      List<List<dynamic>> excelTable = table.rows.map((row) => 
        row.map((cell) => cell?.value?.toString() ?? '').toList()
      ).toList();
      
      await _processTableData(excelTable);
    } catch (e) {
      _showSnackBar('Error parsing Excel file: $e', isError: true);
    }
  }

  Future<void> _processTableData(List<List<dynamic>> tableData) async {
    if (tableData.isEmpty) {
      throw Exception('File is empty or invalid');
    }

    List<String> headers = tableData.first.map((cell) => cell.toString().trim()).toList();
    
    // Detect file type
    _fileType = _detectFileType(headers);
    print('🔍 Detected file type: $_fileType');
    
    if (_fileType == 'psp') {
      await _processPSPData(tableData);
    } else {
      await _processSettlementData(tableData);
    }
  }

  Future<void> _processPSPData(List<List<dynamic>> tableData) async {
    List<String> headers = tableData.first.map((cell) => cell.toString().trim()).toList();
    List<Map<String, dynamic>> pspData = [];
    
    for (int i = 1; i < tableData.length; i++) {
      var row = tableData[i];
      if (_isEmptyRow(row)) continue;
      
      // Skip end marker rows
      if (row.isNotEmpty && row[0].toString().contains('***END***')) continue;

      Map<String, dynamic> rowData = {};
      
      for (int j = 0; j < headers.length && j < row.length; j++) {
        String header = headers[j];
        var value = row[j];
        if (value != null && value.toString().isNotEmpty) {
          rowData[header] = value;
        }
      }
      
      if (rowData.isNotEmpty) {
        pspData.add(rowData);
      }
    }

    print('📊 Found ${pspData.length} PSP records, converting to settlement format...');
    await _convertPSPToSettlement(pspData);
  }

  Future<void> _convertPSPToSettlement(List<Map<String, dynamic>> pspData) async {
    setState(() {
      _isConverting = true;
    });

    try {
      List<Map<String, dynamic>> convertedData = [];
      
      for (int i = 0; i < pspData.length; i++) {
        Map<String, dynamic> pspRow = pspData[i];
        Map<String, dynamic> settlementRow = {};
        
        // Map each settlement field
        _pspFieldMapping.forEach((settlementField, pspField) {
          if (pspField.isEmpty) {
            // Generate default values
            if (settlementField == 'batch_number') {
              settlementRow[settlementField] = 1;
            } else if (settlementField == 'terminal_trace_number') {
              settlementRow[settlementField] = i + 1;
            } else {
              settlementRow[settlementField] = null;
            }
          } else if (pspRow.containsKey(pspField) && pspRow[pspField] != null) {
            var value = pspRow[pspField];
            value = _convertPSPValue(settlementField, value);
            settlementRow[settlementField] = value;
          } else {
            settlementRow[settlementField] = _getDefaultValue(settlementField, i);
          }
        });
        
        convertedData.add(settlementRow);
      }

      setState(() {
        _parsedData = convertedData;
      });

      _showSnackBar('PSP file converted successfully! Found ${convertedData.length} records.', isError: false);
    } catch (e) {
      _showSnackBar('Error converting PSP data: $e', isError: true);
    } finally {
      setState(() {
        _isConverting = false;
      });
    }
  }

  dynamic _convertPSPValue(String fieldName, dynamic value) {
    if (value == null) return null;
    
    String valueStr = value.toString().trim();
    if (valueStr.isEmpty) return null;

    // Date/time fields
    if (fieldName.contains('time')) {
      try {
        DateTime dateTime = DateTime.parse(valueStr);
        String isoString = dateTime.toUtc().toIso8601String();
        if (!isoString.endsWith('Z')) {
          isoString = isoString + 'Z';
        }
        return isoString;
      } catch (e) {
        return valueStr;
      }
    }

    // Special field conversions
    switch (fieldName) {
      case 'reconciliation_flag':
        return valueStr.toLowerCase() == 'success' ? 'Reconciled' : 'Unreconciled';
      
      case 'psp_order_number':
        if (valueStr.length > 10) {
          return valueStr.split('').fold(0, (hash, char) => 
            ((hash << 5) - hash + char.codeUnitAt(0)) & 0xFFFFFFFF).abs();
        }
        return int.tryParse(valueStr) ?? valueStr;
      
      case 'order_number':
      case 'authorization_code':
      case 'mcc':
      case 'terminal_id':
      case 'batch_number':
      case 'terminal_trace_number':
        return int.tryParse(valueStr) ?? valueStr;
      
      default:
        if (fieldName.contains('amount')) {
          double? doubleValue = double.tryParse(valueStr);
          return doubleValue != null ? double.parse(doubleValue.toStringAsFixed(2)) : 0.0;
        }
        return valueStr;
    }
  }

  dynamic _getDefaultValue(String fieldName, int index) {
    switch (fieldName) {
      case 'batch_number':
        return 1;
      case 'terminal_trace_number':
        return index + 1;
      case 'tips_amount':
      case 'mdr_amount':
        return 0.0;
      case 'crossborder_flag':
        return 'Domestic';
      default:
        return null;
    }
  }

  Future<void> _processSettlementData(List<List<dynamic>> tableData) async {
    List<String> headers = tableData.first.map((cell) => cell.toString().trim()).toList();
    
    Map<String, String> headerToApiField = _createHeaderMapping(headers);
    
    List<String> missingColumns = _validateRequiredColumns(headerToApiField);
    if (missingColumns.isNotEmpty) {
      throw Exception('Missing required columns: ${missingColumns.join(', ')}');
    }

    List<Map<String, dynamic>> parsedData = [];
    
    for (int i = 1; i < tableData.length; i++) {
      var row = tableData[i];
      if (_isEmptyRow(row)) continue;

      Map<String, dynamic> rowData = {};
      
      // Set default values for optional columns
      for (String optionalColumn in _optionalColumns) {
        rowData[optionalColumn] = _getDefaultValueForOptional(optionalColumn);
      }
      
      // Process actual data
      for (int j = 0; j < headers.length && j < row.length; j++) {
        String header = headers[j];
        String apiField = headerToApiField[header] ?? _normalizeColumnName(header);
        var convertedValue = _convertCellValue(apiField, row[j]);
        rowData[apiField] = convertedValue;
      }
      
      // Handle crossborder flag typo
      if (rowData.containsKey('crossboarder_flag') && rowData.containsKey('crossborder_flag')) {
        rowData.remove('crossboarder_flag');
      } else if (rowData.containsKey('crossboarder_flag')) {
        rowData['crossborder_flag'] = rowData['crossboarder_flag'];
        rowData.remove('crossboarder_flag');
      }
      
      parsedData.add(rowData);
    }

    setState(() {
      _parsedData = parsedData;
    });

    _showSnackBar('Settlement file parsed successfully! Found ${parsedData.length} records.', isError: false);
  }

  Map<String, String> _createHeaderMapping(List<String> headers) {
    Map<String, String> headerToApiField = {};
    
    for (String header in headers) {
      // ignore: unused_local_variable
      bool mapped = false;
      
      // Exact matches for settlement headers
      Map<String, String> exactMatches = {
        'Crossboarder Flag': 'crossborder_flag',
        'Brand  Settlement Currency': 'brand_settlement_currency',
      };
      
      exactMatches.addAll(Map.fromEntries(
        _settlementColumnMapping.entries.map((e) => MapEntry(e.value, e.key))
      ));
      
      if (exactMatches.containsKey(header)) {
        headerToApiField[header] = exactMatches[header]!;
        mapped = true;
      } else {
        // Normalized matching
        for (String apiField in _settlementColumnMapping.keys) {
          String expectedHeader = _settlementColumnMapping[apiField]!;
          String normalizedHeader = _normalizeColumnName(header);
          String normalizedExpected = _normalizeColumnName(expectedHeader);
          String normalizedApiField = _normalizeColumnName(apiField);
          
          if (normalizedHeader == normalizedExpected || normalizedHeader == normalizedApiField) {
            headerToApiField[header] = apiField;
            mapped = true;
            break;
          }
        }
      }
    }
    
    return headerToApiField;
  }

  List<String> _validateRequiredColumns(Map<String, String> headerToApiField) {
    List<String> missingColumns = [];
    
    for (String apiField in _requiredColumns) {
      if (!headerToApiField.containsValue(apiField)) {
        String expectedHeader = _settlementColumnMapping[apiField] ?? apiField;
        missingColumns.add('$expectedHeader (or $apiField)');
      }
    }
    
    return missingColumns;
  }

  bool _isEmptyRow(List<dynamic> row) {
    return row.every((cell) => cell == null || cell.toString().trim().isEmpty);
  }

  String _normalizeColumnName(String columnName) {
    return columnName
        .toLowerCase()
        .trim()
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'[^\w]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_'), '');
  }

  dynamic _convertCellValue(String columnName, dynamic value) {
    if (value == null) return null;
    
    String valueStr = value.toString().trim();
    if (valueStr.isEmpty) return null;

    const dateTimeColumns = {
      'transaction_time', 'payment_time', 'terminal_settlement_time'
    };
    
    if (dateTimeColumns.contains(columnName)) {
      try {
        DateTime dateTime;
        
        if (valueStr.contains('UTC +')) {
          String cleanDate = valueStr.replaceAll(' UTC +07:00', '+07:00').replaceAll(' ', 'T');
          dateTime = DateTime.parse(cleanDate);
        } else if (valueStr.contains('T')) {
          dateTime = DateTime.parse(valueStr);
        } else {
          dateTime = DateTime.parse(valueStr);
        }
        
        String isoString = dateTime.toUtc().toIso8601String();
        if (!isoString.endsWith('Z')) {
          isoString = isoString + 'Z';
        }
        
        return isoString;
      } catch (e) {
        return valueStr;
      }
    }

    const numericIntColumns = {
      'company_id', 'order_number', 'psp_order_number', 'original_order_number',
      'original_psp_order_number', 'authorization_code', 'mcc', 'terminal_id',
      'batch_number', 'terminal_trace_number'
    };
    
    const numericDoubleColumns = {
      'transaction_amount', 'tips_amount', 'merchant_settlement_amount',
      'mdr_amount', 'net_merchant_settlement_amount', 'brand_settlement_amount',
      'interchange_fee_amount', 'net_brand_settlement_amount'
    };

    if (numericIntColumns.contains(columnName)) {
      return int.tryParse(valueStr) ?? valueStr;
    } else if (numericDoubleColumns.contains(columnName)) {
      double? doubleValue = double.tryParse(valueStr);
      return doubleValue != null ? double.parse(doubleValue.toStringAsFixed(2)) : valueStr;
    }
    
    return valueStr;
  }

  dynamic _getDefaultValueForOptional(String columnName) {
    switch (columnName) {
      case 'crossborder_flag':
        return 'Domestic';
      case 'original_order_number':
      case 'original_psp_order_number':
      case 'tips_amount':
      case 'brand_settlement_amount':
      case 'brand_settlement_currency':
      case 'interchange_fee_amount':
      case 'net_brand_settlement_amount':
      case 'remark':
        return null;
      default:
        return null;
    }
  }

  // Upload methods (from your original code)
  Future<void> _uploadData() async {
    if (_parsedData == null || _parsedData!.isEmpty) {
      _showSnackBar('No data to upload. Please select and parse a file first.', isError: true);
      return;
    }

    _resetUploadState();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      if (token != null && _isTokenExpired(token)) {
        _showSnackBar('Session expired. Please login again and try uploading.', isError: true);
        setState(() {
          _isUploading = false;
        });
        return;
      }
      
      final url = AppConfig.api('/api/settlement-details');
      
      for (int i = 0; i < _parsedData!.length; i++) {
        await _uploadSingleRecord(i, url.toString(), token, companyId);
        _updateProgress(i + 1);
      }

      _showUploadResultDialog();
    } catch (e) {
      _showSnackBar('Error uploading data: $e', isError: true);
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  bool _isTokenExpired(String token) {
    try {
      List<String> parts = token.split('.');
      if (parts.length != 3) return true;
      
      String payload = parts[1];
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      
      String decodedPayload = String.fromCharCodes(base64.decode(payload));
      Map<String, dynamic> payloadMap = jsonDecode(decodedPayload);
      
      int exp = payloadMap['exp'] ?? 0;
      int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      return exp < currentTime;
    } catch (e) {
      return true;
    }
  }

Future<void> _uploadSingleRecord(
  int index, 
  String apiUrl, 
  String? token, 
  dynamic companyId,
  [List<Map<String, dynamic>>? customData]
) async {
  try {
    final dataSource = customData ?? _parsedData!;
    Map<String, dynamic> settlementData = Map.from(dataSource[index]);
    
    // FIX: Remove pspid if it exists, ensure company_id is set
    if (settlementData.containsKey('pspid')) {
      settlementData['company_id'] = settlementData['pspid'];
      settlementData.remove('pspid');
    }
    
    // Ensure company_id is set
    settlementData['company_id'] = companyId ?? settlementData['company_id'];
    
    // FIX: Convert batch_number and terminal_trace_number to integers
    if (settlementData['batch_number'] != null) {
      settlementData['batch_number'] = int.tryParse(settlementData['batch_number'].toString()) ?? 1;
    }
    
    if (settlementData['terminal_trace_number'] != null) {
      settlementData['terminal_trace_number'] = int.tryParse(settlementData['terminal_trace_number'].toString()) ?? 1;
    }
    
    // ✅ NEW: Detailed logging BEFORE request
    print('=== UPLOAD REQUEST DEBUG (Row ${index + 1}) ===');
    print('API URL: $apiUrl');
    print('Has Token: ${token != null}');
    if (token != null) {
      print('Token (first 20 chars): ${token.substring(0, 20)}...');
    }
    print('Company ID: $companyId');
    print('');
    print('REQUEST BODY:');
    
    // Pretty print the JSON body
    String prettyJson = JsonEncoder.withIndent('  ').convert(settlementData);
    print(prettyJson);
    print('');
    print('CRITICAL FIELDS CHECK:');
    print('  - company_id: ${settlementData['company_id']}');
    print('  - transaction_time: ${settlementData['transaction_time']}');
    print('  - system_transaction_id: ${settlementData['system_transaction_id']}');
    print('  - merchant_id: ${settlementData['merchant_id']}');
    print('  - terminal_id: ${settlementData['terminal_id']}');
    print('=== END REQUEST DEBUG ===');
    print('');
    
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    
    // Make the request
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: headers,
      body: jsonEncode(settlementData),
    );
    
    // ✅ NEW: Detailed logging AFTER response
    print('=== UPLOAD RESPONSE DEBUG (Row ${index + 1}) ===');
    print('Status Code: ${response.statusCode}');
    print('Status Message: ${response.reasonPhrase}');
    print('');
    print('RESPONSE HEADERS:');
    response.headers.forEach((key, value) {
      print('  $key: $value');
    });
    print('');
    print('RESPONSE BODY:');
    try {
      // Try to pretty print JSON response
      var responseJson = jsonDecode(response.body);
      String prettyResponse = JsonEncoder.withIndent('  ').convert(responseJson);
      print(prettyResponse);
    } catch (e) {
      // If not JSON, print raw
      print(response.body);
    }
    print('=== END RESPONSE DEBUG ===');
    print('');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      _successCount++;
      print('✅ Row ${index + 1}: SUCCESS');
    } else {
      _errorCount++;
      try {
        final errorData = jsonDecode(response.body);
        String errorMsg = 'Row ${index + 1}: ${errorData['message'] ?? 'Unknown error'}';
        
        // ✅ NEW: Include validation errors if present
        if (errorData['errors'] != null) {
          errorMsg += '\n  Validation: ${errorData['errors']}';
        }
        
        _errorMessages.add(errorMsg);
        print('❌ Row ${index + 1}: FAILED - $errorMsg');
      } catch (e) {
        String errorMsg = 'Row ${index + 1}: HTTP ${response.statusCode} - ${response.reasonPhrase}';
        _errorMessages.add(errorMsg);
        print('❌ Row ${index + 1}: FAILED - $errorMsg');
      }
    }
  } catch (e, stackTrace) {
    _errorCount++;
    String errorMsg = 'Row ${index + 1}: Exception - $e';
    _errorMessages.add(errorMsg);
    print('❌ Row ${index + 1}: EXCEPTION');
    print('Error: $e');
    print('Stack trace: $stackTrace');
  }
}

  // State management methods
  void _resetState() {
    setState(() {
      _isParsing = true;
      _parsedData = null;
      _errorMessages.clear();
      _fileType = 'settlement';
    });
  }

  void _resetUploadState() {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _successCount = 0;
      _errorCount = 0;
      _errorMessages.clear();
    });
  }

  void _updateProgress(int completedCount) {
    setState(() {
      _uploadProgress = completedCount / _parsedData!.length;
    });
  }

  // UI helper methods
  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error : Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showUploadResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              _errorCount == 0 ? Icons.check_circle : Icons.warning,
              color: _errorCount == 0 ? Colors.green : Colors.orange,
              size: 28,
            ),
            SizedBox(width: 12),
            Text('Upload Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upload Summary:'),
            SizedBox(height: 8),
            Text('✅ Successful: $_successCount records'),
            Text('❌ Failed: $_errorCount records'),
            if (_errorMessages.isNotEmpty) ...[
              SizedBox(height: 16),
              Text('Errors:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Container(
                height: 200,
                child: SingleChildScrollView(
                  child: Text(
                    _errorMessages.take(10).join('\n'),
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ),
              if (_errorMessages.length > 10)
                Text('... and ${_errorMessages.length - 10} more errors'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (_errorCount == 0) {
                Navigator.of(context).pop(true);
              }
            },
            child: Text(
              'OK',
              style: TextStyle(
                color: ThemeConfig.getPrimaryColor(currentTheme),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // UI Widget builders
  Widget _buildFileUploadSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload_file, color: ThemeConfig.getPrimaryColor(currentTheme)),
                SizedBox(width: 12),
                Text(
                  'Upload Settlement or PSP File',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Supports both Settlement Details and PSP Reconciliation files',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            SizedBox(height: 20),
            _buildUploadArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    return GestureDetector(
      onTap: (_isParsing || _isConverting) ? null : _pickFile,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _fileName != null 
                ? ThemeConfig.getPrimaryColor(currentTheme)
                : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: (_isParsing || _isConverting)
            ? _buildLoadingIndicator(_isConverting ? 'Converting PSP file...' : 'Parsing file...')
            : _fileName != null
                ? _buildFileInfo()
                : _buildUploadPrompt(),
      ),
    );
  }

  Widget _buildLoadingIndicator(String text) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: ThemeConfig.getPrimaryColor(currentTheme)),
        SizedBox(height: 12),
        Text(text),
      ],
    );
  }

  Widget _buildFileInfo() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _fileType == 'psp' ? Icons.transform : Icons.description,
          size: 48,
          color: ThemeConfig.getPrimaryColor(currentTheme),
        ),
        SizedBox(height: 8),
        Text(
          _fileName!,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          textAlign: TextAlign.center,
        ),
        if (_parsedData != null) ...[
          Text(
            '${_parsedData!.length} records found',
            style: TextStyle(color: Colors.green, fontSize: 12),
          ),
          if (_fileType == 'psp')
            Text(
              '(Converted from PSP format)',
              style: TextStyle(color: Colors.blue, fontSize: 10),
            ),
        ],
      ],
    );
  }

  Widget _buildUploadPrompt() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_upload, size: 48, color: Colors.grey[400]),
        SizedBox(width: 12),
        Text(
          'Click to select file',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Settlement Details or PSP Reconciliation',
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
        SizedBox(height: 2),
        Text(
          'Supports .xlsx, .xls, and .csv files',
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDataPreview() {
    if (_parsedData == null || _parsedData!.isEmpty) return SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview, color: ThemeConfig.getPrimaryColor(currentTheme)),
                SizedBox(width: 12),
                Text(
                  'Data Preview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _fileType == 'psp' ? Colors.blue[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _fileType == 'psp' ? 'PSP (Converted)' : 'Settlement',
                    style: TextStyle(
                      color: _fileType == 'psp' ? Colors.blue[800] : Colors.green[800],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '${_parsedData!.length} records',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: _parsedData!.first.keys.take(5).map((key) => 
                        DataColumn(label: Text(key, style: TextStyle(fontWeight: FontWeight.bold)))
                    ).toList(),
                    rows: _parsedData!.take(5).map((row) => 
                        DataRow(
                          cells: row.values.take(5).map((value) => 
                              DataCell(Text(value?.toString() ?? ''))
                          ).toList(),
                        )
                    ).toList(),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Showing first 5 columns and 5 rows',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadProgress() {
    if (!_isUploading && _uploadProgress == 0.0) return SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload, color: ThemeConfig.getPrimaryColor(currentTheme)),
                SizedBox(width: 12),
                Text(
                  'Upload Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                ThemeConfig.getPrimaryColor(currentTheme),
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(_uploadProgress * 100).toInt()}% Complete'),
                Text('$_successCount success, $_errorCount errors'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    return Container(
      height: 56,
      child: ElevatedButton(
        onPressed: (_parsedData == null || _parsedData!.isEmpty || _isUploading || _isConverting) 
            ? null 
            : _uploadData,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.3),
        ),
        child: _isUploading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ThemeConfig.getButtonTextColor(currentTheme),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Uploading Data...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Upload to API',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final horizontalPadding = isWideScreen ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Smart Settlement Upload'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isWideScreen ? 800 : double.infinity),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16.0,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFileUploadSection(),
                  SizedBox(height: 20),
                  _buildDataPreview(),
                  SizedBox(height: 20),
                  _buildUploadProgress(),
                  SizedBox(height: 30),
                  _buildUploadButton(),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}