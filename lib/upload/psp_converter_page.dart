import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:csv/csv.dart';

class PSPConverterPage extends StatefulWidget {
  const PSPConverterPage({Key? key}) : super(key: key);

  @override
  State<PSPConverterPage> createState() => _PSPConverterPageState();
}

class _PSPConverterPageState extends State<PSPConverterPage> with TickerProviderStateMixin {
  // File handling
  // ignore: unused_field
  PlatformFile? _selectedFile;
  Uint8List? _fileBytes;
  String? _fileName;
  List<Map<String, dynamic>>? _pspData;
  List<Map<String, dynamic>>? _convertedData;
  
  // Loading states
  bool _isParsing = false;
  bool _isConverting = false;
  
  String currentTheme = ThemeConfig.defaultTheme;
  
  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // PSP to Settlement field mapping
  static const Map<String, String> _fieldMapping = {
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

  // Settlement detail headers (exact format for upload compatibility)
  static const List<String> _settlementHeaders = [
    'Transaction Time', 'Payment Time', 'Order Number', 'PSP Order Number',
    'Original Order Number', 'Original PSP Order Number', 'Transaction Amount',
    'Tips Amount', 'Transaction Currency', 'Merchant Settlement Amount',
    'Merchant Settlement Currency', 'MDR Amount', 'Net Merchant Settlement Amount',
    'Brand Settlement Amount', 'Brand  Settlement Currency', // Note double space
    'Interchange Fee Amount', 'Net Brand Settlement Amount', 'Reconciliation Flag',
    'Transaction Type', 'PSP Name', 'Payment Brand', 'Card Number',
    'Authorization Code', 'MCC', 'Crossboarder Flag', // Note typo
    'Group ID', 'Group Name', 'Merchant ID', 'Merchant Name',
    'Store ID', 'Store Name', 'Terminal ID', 'Terminal Settlement Time',
    'Batch Number', 'Terminal Trace Number', 'Remark'
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
      
      await _processPSPData(csvTable);
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
      
      await _processPSPData(excelTable);
    } catch (e) {
      _showSnackBar('Error parsing Excel file: $e', isError: true);
    }
  }

  Future<void> _processPSPData(List<List<dynamic>> tableData) async {
    if (tableData.isEmpty) {
      throw Exception('File is empty or invalid');
    }

    List<String> headers = tableData.first.map((cell) => cell.toString().trim()).toList();
    List<Map<String, dynamic>> pspData = [];
    
    for (int i = 1; i < tableData.length; i++) {
      var row = tableData[i];
      if (_isEmptyRow(row)) continue;
      
      // Skip end marker rows like "***END***"
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

    setState(() {
      _pspData = pspData;
    });

    _showSnackBar('PSP file parsed successfully! Found ${pspData.length} records.', isError: false);
  }

  bool _isEmptyRow(List<dynamic> row) {
    return row.every((cell) => cell == null || cell.toString().trim().isEmpty);
  }

  // Conversion methods
  Future<void> _convertToSettlement() async {
    if (_pspData == null || _pspData!.isEmpty) {
      _showSnackBar('No PSP data to convert. Please select and parse a file first.', isError: true);
      return;
    }

    setState(() {
      _isConverting = true;
    });

    try {
      List<Map<String, dynamic>> convertedData = [];
      
      for (int i = 0; i < _pspData!.length; i++) {
        Map<String, dynamic> pspRow = _pspData![i];
        Map<String, dynamic> settlementRow = {};
        
        // Map each settlement field
        _fieldMapping.forEach((settlementField, pspField) {
          if (pspField.isEmpty) {
            // Generate default values for empty mappings
            if (settlementField == 'batch_number') {
              settlementRow[settlementField] = 1;
            } else if (settlementField == 'terminal_trace_number') {
              settlementRow[settlementField] = i + 1;
            } else {
              settlementRow[settlementField] = null;
            }
          } else if (pspRow.containsKey(pspField) && pspRow[pspField] != null) {
            var value = pspRow[pspField];
            
            // Apply special conversions
            value = _convertValue(settlementField, value);
            settlementRow[settlementField] = value;
          } else {
            // Set default values for missing fields
            settlementRow[settlementField] = _getDefaultValue(settlementField, i);
          }
        });
        
        convertedData.add(settlementRow);
      }

      setState(() {
        _convertedData = convertedData;
      });

      _showSnackBar('Conversion completed! ${convertedData.length} records converted.', isError: false);
    } catch (e) {
      _showSnackBar('Error converting data: $e', isError: true);
    } finally {
      setState(() {
        _isConverting = false;
      });
    }
  }

  dynamic _convertValue(String fieldName, dynamic value) {
    if (value == null) return null;
    
    String valueStr = value.toString().trim();
    if (valueStr.isEmpty) return null;

    // Date/time fields
    if (fieldName.contains('time')) {
      try {
        DateTime dateTime = DateTime.parse(valueStr);
        return dateTime.toUtc().toIso8601String();
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
          // Convert long string to numeric hash
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

  // Download converted file
  void _downloadConvertedFile() {
    if (_convertedData == null || _convertedData!.isEmpty) {
      _showSnackBar('No converted data to download.', isError: true);
      return;
    }

    try {
      // Convert to CSV format
      List<List<dynamic>> csvRows = [];
      csvRows.add(_settlementHeaders); // Add headers
      
      // Add data rows
      for (var settlementRow in _convertedData!) {
        List<dynamic> row = _settlementHeaders.map((header) {
          String fieldName = _getFieldNameFromHeader(header);
          return settlementRow[fieldName] ?? '';
        }).toList();
        csvRows.add(row);
      }
      
      String csvContent = const ListToCsvConverter().convert(csvRows);
      
      if (kIsWeb) {
        // Web download
        final bytes = utf8.encode(csvContent);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = 'converted_settlement_details.csv';
        html.document.body!.children.add(anchor);
        anchor.click();
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      }
      
      _showSnackBar('File downloaded successfully!', isError: false);
    } catch (e) {
      _showSnackBar('Error downloading file: $e', isError: true);
    }
  }

  String _getFieldNameFromHeader(String header) {
    // Map settlement headers back to field names
    const headerToField = {
      'Transaction Time': 'transaction_time',
      'Payment Time': 'payment_time',
      'Order Number': 'order_number',
      'PSP Order Number': 'psp_order_number',
      'Original Order Number': 'original_order_number',
      'Original PSP Order Number': 'original_psp_order_number',
      'Transaction Amount': 'transaction_amount',
      'Tips Amount': 'tips_amount',
      'Transaction Currency': 'transaction_currency',
      'Merchant Settlement Amount': 'merchant_settlement_amount',
      'Merchant Settlement Currency': 'merchant_settlement_currency',
      'MDR Amount': 'mdr_amount',
      'Net Merchant Settlement Amount': 'net_merchant_settlement_amount',
      'Brand Settlement Amount': 'brand_settlement_amount',
      'Brand  Settlement Currency': 'brand_settlement_currency',
      'Interchange Fee Amount': 'interchange_fee_amount',
      'Net Brand Settlement Amount': 'net_brand_settlement_amount',
      'Reconciliation Flag': 'reconciliation_flag',
      'Transaction Type': 'transaction_type',
      'PSP Name': 'psp_name',
      'Payment Brand': 'payment_brand',
      'Card Number': 'card_number',
      'Authorization Code': 'authorization_code',
      'MCC': 'mcc',
      'Crossboarder Flag': 'crossborder_flag',
      'Group ID': 'group_id',
      'Group Name': 'group_name',
      'Merchant ID': 'merchant_id',
      'Merchant Name': 'merchant_name',
      'Store ID': 'store_id',
      'Store Name': 'store_name',
      'Terminal ID': 'terminal_id',
      'Terminal Settlement Time': 'terminal_settlement_time',
      'Batch Number': 'batch_number',
      'Terminal Trace Number': 'terminal_trace_number',
      'Remark': 'remark',
    };
    
    return headerToField[header] ?? header.toLowerCase().replaceAll(' ', '_');
  }

  void _resetState() {
    setState(() {
      _isParsing = true;
      _pspData = null;
      _convertedData = null;
    });
  }

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
                  'Upload PSP Reconciliation File',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                ),
              ],
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
      onTap: _isParsing ? null : _pickFile,
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
        child: _isParsing
            ? _buildLoadingIndicator('Parsing PSP file...')
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
          Icons.description,
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
        if (_pspData != null)
          Text(
            '${_pspData!.length} PSP records found',
            style: TextStyle(color: Colors.green, fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildUploadPrompt() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_upload, size: 48, color: Colors.grey[400]),
        SizedBox(height: 12),
        Text(
          'Click to select PSP reconciliation file',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Supports .xlsx, .xls, and .csv files',
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildConvertSection() {
    if (_pspData == null || _pspData!.isEmpty) return SizedBox.shrink();

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
                Icon(Icons.transform, color: ThemeConfig.getPrimaryColor(currentTheme)),
                SizedBox(width: 12),
                Text(
                  'Convert to Settlement Format',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Ready to convert ${_pspData!.length} PSP records to settlement details format.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 20),
            SizedBox(
              height: 50,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isConverting ? null : _convertToSettlement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                  foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isConverting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                ThemeConfig.getButtonTextColor(currentTheme),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Converting...'),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.transform),
                          SizedBox(width: 8),
                          Text('Convert to Settlement Format'),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection() {
    if (_convertedData == null || _convertedData!.isEmpty) return SizedBox.shrink();

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
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 12),
                Text(
                  'Conversion Complete',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              '✅ Successfully converted ${_convertedData!.length} records to settlement format',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _downloadConvertedFile,
                    icon: Icon(Icons.download),
                    label: Text('Download CSV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context, _convertedData);
                    },
                    icon: Icon(Icons.upload),
                    label: Text('Use for Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                      foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
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
        title: Text('PSP to Settlement Converter'),
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
                  _buildConvertSection(),
                  SizedBox(height: 20),
                  _buildResultSection(),
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