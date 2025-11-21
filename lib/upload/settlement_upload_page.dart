import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'package:inventory/config/settlement_column.dart';
import 'package:inventory/config/missing_column_detector.dart';
import 'package:inventory/widgets/column_analysis_display_widget.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:csv/csv.dart';

// Helper class to structure validation errors
class ValidationError {
  final int rowNumber;
  final String fieldName;
  final String errorMessage;
  final String suggestion;

  ValidationError({
    required this.rowNumber,
    required this.fieldName,
    required this.errorMessage,
    required this.suggestion,
  });
}

class SettlementUploadPage extends StatefulWidget {
  const SettlementUploadPage({Key? key}) : super(key: key);

  @override
  State<SettlementUploadPage> createState() => _SettlementUploadPageState();
}

class _SettlementUploadPageState extends State<SettlementUploadPage> with TickerProviderStateMixin {
  // File handling
  Uint8List? _fileBytes;
  String? _fileName;
  List<Map<String, dynamic>>? _parsedData;
  
  // State management
  bool _isParsing = false;
  bool _isUploading = false;
  bool _isConverting = false;
  bool _isCheckingDuplicates = false;
  String _fileType = 'settlement';
  String currentTheme = ThemeConfig.defaultTheme;
  
  // Missing column analysis
  MissingColumnAnalysis? _columnAnalysis;
  // ignore: unused_field
  bool _showColumnDetails = false;
  
  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Upload tracking
  double _uploadProgress = 0.0;
  int _successCount = 0;
  int _errorCount = 0;
  List<String> _errorMessages = [];
  
  // Validation and duplicate tracking
  int _skippedRows = 0;
  List<String> _duplicateIds = [];

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

  List<String> _cleanHeaders(List<String> headers) {
    return headers.map((header) => header
        .replaceAll('\uFEFF', '')
        .replaceAll('ï»¿', '')
        .replaceAll('\u00EF\u00BB\u00BF', '')
        .trim()).toList();
  }

  String _detectFileType(List<String> headers) {
    if (kDebugMode) {
      print('=== FILE TYPE DETECTION ===');
      print('Configuration Version: ${SettlementColumn.getConfigVersion()}');
    }
    
    // FORCE SETTLEMENT TYPE: If file has System Txn ID, treat as settlement
    if (headers.any((h) => h.toLowerCase().trim().contains('system txn id'))) {
      if (kDebugMode) {
        print('✓ Detected as SETTLEMENT file (has System Txn ID column)');
      }
      String detectedType = 'settlement';
      
      _columnAnalysis = MissingColumnDetector.analyzeMissingColumns(headers, detectedType);
      
      if (kDebugMode) {
        String detailedReport = MissingColumnDetector.generateDetailedReport(_columnAnalysis!);
        print(detailedReport);
        
        print('=== CONSOLE SUMMARY ===');
        print('File Type: SETTLEMENT (forced)');
        print('Mapping Success Rate: ${(_columnAnalysis!.mappingSuccessRate * 100).toStringAsFixed(1)}%');
        print('Successfully Mapped: ${_columnAnalysis!.foundColumns.length}/${_columnAnalysis!.totalExpectedColumns}');
        print('Required Missing: ${_columnAnalysis!.requiredMissingCount}');
        print('Status: ${_columnAnalysis!.canProceed ? "READY FOR UPLOAD" : "MISSING REQUIRED COLUMNS"}');
        print('=== END CONSOLE SUMMARY ===');
      }
      
      setState(() {});
      return detectedType;
    }
    
    // Original detection logic as fallback
    String detectedType = SettlementColumn.detectFileType(headers);
    _columnAnalysis = MissingColumnDetector.analyzeMissingColumns(headers, detectedType);
    
    if (kDebugMode) {
      String detailedReport = MissingColumnDetector.generateDetailedReport(_columnAnalysis!);
      print(detailedReport);
      
      print('=== CONSOLE SUMMARY ===');
      print('File Type: ${_columnAnalysis!.fileType.toUpperCase()}');
      print('Mapping Success Rate: ${(_columnAnalysis!.mappingSuccessRate * 100).toStringAsFixed(1)}%');
      print('Successfully Mapped: ${_columnAnalysis!.foundColumns.length}/${_columnAnalysis!.totalExpectedColumns}');
      print('Required Missing: ${_columnAnalysis!.requiredMissingCount}');
      print('Status: ${_columnAnalysis!.canProceed ? "READY FOR UPLOAD" : "MISSING REQUIRED COLUMNS"}');
      print('=== END CONSOLE SUMMARY ===');
    }
    
    setState(() {});
    return detectedType;
  }

  // NEW: Check for duplicates API call
  Future<List<String>> _checkForDuplicates() async {
    if (_parsedData == null || _parsedData!.isEmpty) {
      return [];
    }

    setState(() {
      _isCheckingDuplicates = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();

      // Extract system_transaction_ids from parsed data
      List<String> transactionIds = _parsedData!
          .map((row) => row['system_transaction_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      if (transactionIds.isEmpty) {
        _showSnackBar('No valid transaction IDs to check', isError: true);
        return [];
      }

      final url = AppConfig.api('/api/settlement-details/check-duplicates');
      
      if (kDebugMode) {
        print('Checking ${transactionIds.length} transaction IDs for duplicates');
      }
      
      final response = await http.post(
        // ignore: unnecessary_type_check
        url is Uri ? url : Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'company_id': companyId,
          'system_transaction_ids': transactionIds,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<String> duplicates = List<String>.from(data['data']['duplicates'] ?? []);
        
        if (kDebugMode) {
          print('Found ${duplicates.length} duplicates');
        }
        
        return duplicates;
      } else {
        throw Exception('Failed to check duplicates: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking duplicates: $e');
      }
      _showSnackBar('Could not check duplicates. Proceeding with upload.', isError: false);
      // Return empty list on error - don't block upload
      return [];
    } finally {
      setState(() {
        _isCheckingDuplicates = false;
      });
    }
  }

  // NEW: Show duplicate BLOCKED dialog - NO UPLOAD OPTIONS
  void _showDuplicateBlockedDialog(List<String> duplicates) {
    int duplicateCount = duplicates.length;
    int totalCount = _parsedData!.length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Upload Blocked',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 24),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Duplicate transactions detected!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.red[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Found $duplicateCount transaction(s) that already exist in the database.',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Upload has been blocked to prevent duplicate data.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[800],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Summary:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text('Total records in file: $totalCount'),
                    Text(
                      'Already in database: $duplicateCount',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Duplicate Transaction IDs:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: duplicates.length,
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey[200]!,
                              width: 1,
                            ),
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: Colors.red[100],
                            radius: 12,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red[900],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            duplicates[index],
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Colors.red[900],
                            ),
                          ),
                          trailing: Icon(
                            Icons.warning,
                            color: Colors.red,
                            size: 16,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[800], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please remove duplicate transactions from your file and try again.',
                        style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              // Copy duplicate IDs to clipboard
              String duplicateList = duplicates.join('\n');
              await Clipboard.setData(ClipboardData(text: duplicateList));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Duplicate IDs copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: Icon(Icons.copy, size: 18),
            label: Text('Copy IDs'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
              foregroundColor: Colors.white,
            ),
            child: Text('OK, I Understand'),
          ),
        ],
      ),
    );
  }

  void _showColumnAnalysisDialog() {
    if (_columnAnalysis == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _columnAnalysis!.canProceed ? Icons.check_circle : Icons.warning,
              color: _columnAnalysis!.canProceed ? Colors.green : Colors.red,
            ),
            SizedBox(width: 8),
            Text('Column Analysis'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: 500),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAnalysisSummary(),
                SizedBox(height: 16),
                if (_columnAnalysis!.requiredMissingCount > 0) ...[
                  _buildMissingColumnsSection(),
                  SizedBox(height: 16),
                ],
                if (_columnAnalysis!.foundColumns.isNotEmpty) ...[
                  _buildFoundColumnsSection(),
                  SizedBox(height: 16),
                ],
                if (_columnAnalysis!.unmappedColumns.isNotEmpty) ...[
                  _buildUnmappedColumnsSection(),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
          if (!_columnAnalysis!.canProceed)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showConfigurationSuggestions();
              },
              child: Text('Fix Suggestions'),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalysisSummary() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text('File Type: ${_columnAnalysis!.fileType.toUpperCase()}'),
            Text('Expected Columns: ${_columnAnalysis!.totalExpectedColumns}'),
            Text('CSV Columns: ${_columnAnalysis!.totalCsvColumns}'),
            Text('Successfully Mapped: ${_columnAnalysis!.foundColumns.length}'),
            Text('Missing Required: ${_columnAnalysis!.requiredMissingCount}'),
            Text('Mapping Rate: ${(_columnAnalysis!.mappingSuccessRate * 100).toStringAsFixed(1)}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingColumnsSection() {
    var requiredMissing = _columnAnalysis!.missingColumns.where((col) => col.isRequired).toList();
    var optionalMissing = _columnAnalysis!.missingColumns.where((col) => !col.isRequired).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (requiredMissing.isNotEmpty) ...[
          Text(
            'Required Missing Columns',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          SizedBox(height: 8),
          ...requiredMissing.map((missing) => Card(
            color: Colors.red[50],
            child: ListTile(
              leading: Icon(Icons.error, color: Colors.red),
              title: Text(missing.expectedColumn),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('API Field: ${missing.apiField}'),
                  if (missing.suggestions.isNotEmpty)
                    Text('Similar: ${missing.suggestions.join(', ')}', 
                         style: TextStyle(fontSize: 12)),
                ],
              ),
              isThreeLine: missing.suggestions.isNotEmpty,
            ),
          )),
        ],
        if (optionalMissing.isNotEmpty) ...[
          SizedBox(height: 8),
          Text(
            'Optional Missing Columns',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          SizedBox(height: 8),
          ...optionalMissing.take(5).map((missing) => Card(
            color: Colors.orange[50],
            child: ListTile(
              leading: Icon(Icons.warning, color: Colors.orange),
              title: Text(missing.expectedColumn),
              subtitle: Text('Will use default value'),
            ),
          )),
          if (optionalMissing.length > 5)
            Text('... and ${optionalMissing.length - 5} more optional columns'),
        ],
      ],
    );
  }

  Widget _buildFoundColumnsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Successfully Mapped (${_columnAnalysis!.foundColumns.length})',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
        ),
        SizedBox(height: 8),
        Container(
          height: 150,
          child: ListView.builder(
            itemCount: _columnAnalysis!.foundColumns.length,
            itemBuilder: (context, index) {
              var found = _columnAnalysis!.foundColumns[index];
              return ListTile(
                dense: true,
                leading: Icon(
                  found.isExactMatch ? Icons.check_circle : Icons.check_circle_outline,
                  color: Colors.green,
                  size: 16,
                ),
                title: Text(found.actualColumn, style: TextStyle(fontSize: 14)),
                subtitle: Text('-> ${found.apiField}', style: TextStyle(fontSize: 12)),
                trailing: Text(
                  found.isExactMatch ? 'EXACT' : 'FUZZY',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUnmappedColumnsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unmapped CSV Columns (${_columnAnalysis!.unmappedColumns.length})',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        SizedBox(height: 4),
        Text(
          'These columns exist in your CSV but are not mapped to any database field:',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        SizedBox(height: 8),
        Container(
          height: 200,
          child: ListView.builder(
            itemCount: _columnAnalysis!.unmappedColumns.length,
            itemBuilder: (context, index) {
              var unmapped = _columnAnalysis!.unmappedColumns[index];
              return Card(
                color: Colors.blue[50],
                margin: EdgeInsets.symmetric(vertical: 2),
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.help_outline, color: Colors.blue, size: 20),
                  title: Text(
                    unmapped.columnName,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (unmapped.possibleApiField != null)
                        Text('Possible match: ${unmapped.possibleApiField}')
                      else
                        Text('No matching field found'),
                      Text(
                        'Action: ${unmapped.suggestions.join(' OR ')}',
                        style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColumnAnalysisSection() {
    return ColumnAnalysisDisplayWidget(
      analysis: _columnAnalysis,
      currentTheme: currentTheme,
    );
  }

  void _showConfigurationSuggestions() {
    if (_columnAnalysis == null) return;

    String suggestions = _generateConfigurationSuggestions(_columnAnalysis!);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Configuration Fix Suggestions'),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: Text(
              suggestions,
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  String _generateConfigurationSuggestions(MissingColumnAnalysis analysis) {
    StringBuffer suggestions = StringBuffer();
    
    suggestions.writeln('// Configuration updates for SettlementColumn.dart');
    suggestions.writeln('// Generated: ${DateTime.now().toIso8601String()}');
    suggestions.writeln('');
    
    if (analysis.fileType == 'psp') {
      suggestions.writeln('// Add these to pspAlternativeColumns:');
      for (var missing in analysis.missingColumns) {
        if (missing.suggestions.isNotEmpty) {
          suggestions.writeln("'${missing.expectedColumn}': [");
          for (var suggestion in missing.suggestions) {
            suggestions.writeln("  '$suggestion',");
          }
          suggestions.writeln('],');
        }
      }
    } else {
      suggestions.writeln('// Settlement column mapping suggestions:');
      for (var missing in analysis.missingColumns.where((m) => m.isRequired)) {
        suggestions.writeln('// Missing required: ${missing.expectedColumn}');
        suggestions.writeln('// Expected API field: ${missing.apiField}');
        if (missing.suggestions.isNotEmpty) {
          suggestions.writeln('// Similar columns found: ${missing.suggestions.join(', ')}');
        }
        suggestions.writeln('');
      }
    }
    
    return suggestions.toString();
  }

  List<ValidationError> _validateDataBeforeUpload() {
    List<ValidationError> errors = [];
    
    if (_parsedData == null || _parsedData!.isEmpty) {
      return errors;
    }
    
    for (int i = 0; i < _parsedData!.length; i++) {
      var record = _parsedData![i];
      int rowNumber = i + 2;
      
      bool hasAnyData = false;
      int filledFields = 0;
      
      for (var value in record.values) {
        if (value != null && value.toString().trim().isNotEmpty) {
          filledFields++;
          hasAnyData = true;
        }
      }
      
      if (!hasAnyData || filledFields < 3) {
        errors.add(ValidationError(
          rowNumber: rowNumber,
          fieldName: 'row_data',
          errorMessage: 'Row is empty or has insufficient data',
          suggestion: 'This row will be skipped during upload',
        ));
        continue;
      }
      
      if (_isEmpty(record['company_id']) && _isEmpty(record['psp_id'])) {
        errors.add(ValidationError(
          rowNumber: rowNumber,
          fieldName: 'company_id',
          errorMessage: 'Company/PSP ID is missing',
          suggestion: 'This row will be skipped during upload',
        ));
      }
      
      if (_isEmpty(record['transaction_time']) && _isEmpty(record['merchant_txn_time'])) {
        errors.add(ValidationError(
          rowNumber: rowNumber,
          fieldName: 'transaction_time',
          errorMessage: 'Transaction time is missing',
          suggestion: 'This row will be skipped during upload',
        ));
      }
    }
    
    return errors;
  }

  bool _isEmpty(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    return value.toString().trim().isEmpty;
  }

  // NEW: Truncate fields to match database column limits
  Map<String, dynamic> _truncateFields(Map<String, dynamic> data) {
    // Define max lengths for common problematic fields
    final Map<String, int> fieldLimits = {
      'brand_settlement_currency': 3,      // Currency codes (USD, EUR, etc.)
      'merchant_txn_currency': 3,
      'cardholder_billing_currency': 3,
      'transaction_currency': 3,
      'terminal_id': 50,
      'retrieval_reference_number': 50,
      'authorization_code': 20,
      'card_acceptor_id': 50,
      'merchant_name': 100,
      'terminal_name': 100,
      'merchant_category_code': 10,
      'system_transaction_id': 255,
      'merchant_transaction_id': 255,
      'source_filename': 255,
      'transaction_type': 50,
      'card_scheme': 50,
      'card_type': 50,
      'funding_type': 20,
      'card_subtype': 50,
      'crossborder_flag': 20,
      'transaction_status': 50,
    };
    
    Map<String, dynamic> truncatedData = Map.from(data);
    
    fieldLimits.forEach((field, maxLength) {
      if (truncatedData.containsKey(field) && truncatedData[field] != null) {
        String value = truncatedData[field].toString();
        if (value.length > maxLength) {
          truncatedData[field] = value.substring(0, maxLength);
          if (kDebugMode) {
            print('⚠️ Truncated $field from ${value.length} to $maxLength chars');
          }
        }
      }
    });
    
    return truncatedData;
  }

  void _showValidationErrorDialog(List<ValidationError> errors) {
    final criticalErrors = errors.where((e) => 
      e.fieldName == 'system_txn_id' || 
      e.fieldName == 'merchant_id' || 
      e.fieldName == 'merchant_txn_amt'
    ).toList();
    
    final warnings = errors.where((e) => e.fieldName == 'terminal_id').toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Validation Issues Found'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: 450),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (criticalErrors.isNotEmpty) ...[
                Text(
                  'Found ${criticalErrors.length} row(s) with critical errors that will be skipped:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                SizedBox(height: 8),
              ],
              if (warnings.isNotEmpty) ...[
                Text(
                  'Found ${warnings.length} row(s) with warnings:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
                SizedBox(height: 8),
              ],
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: errors.length,
                  itemBuilder: (context, index) {
                    var error = errors[index];
                    final isCritical = error.fieldName != 'terminal_id';
                    
                    return Card(
                      color: isCritical ? Colors.red[50] : Colors.orange[50],
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCritical ? Colors.red : Colors.orange,
                          child: Text(
                            '${error.rowNumber}',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        title: Text(
                          '${error.fieldName}: ${error.errorMessage}',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          error.suggestion,
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Summary:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('Total rows: ${_parsedData!.length}'),
                    Text(
                      'Rows that will be skipped: ${criticalErrors.length}',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Rows that will be attempted: ${_parsedData!.length - criticalErrors.length}',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
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
            child: Text('Cancel Upload'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _proceedWithUpload(skipInvalid: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: Text('Upload Valid Rows'),
          ),
        ],
      ),
    );
  }

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
    if (kDebugMode) {
      print('=== FILE PROCESSING START ===');
    }
    
    setState(() {
      _fileName = fileName;
      _fileBytes = bytes;
      _isParsing = true;
      _columnAnalysis = null;
      _skippedRows = 0;
      _duplicateIds = [];
    });

    try {
      String extension = fileName.toLowerCase().split('.').last;
      
      if (extension == 'csv') {
        await _parseCsvFile();
      } else {
        await _parseExcelFile();
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR in file processing: $e');
      }
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

    List<String> rawHeaders = tableData.first.map((cell) => cell.toString()).toList();
    List<String> headers = _cleanHeaders(rawHeaders);
    
    _fileType = _detectFileType(headers);
    
    if (!_columnAnalysis!.canProceed) {
      _showSnackBar('Cannot proceed: ${_columnAnalysis!.requiredMissingCount} required columns missing.', isError: true);
      return;
    }
    
    if (_fileType == 'psp') {
      await _processPSPData(tableData);
    } else {
      await _processSettlementData(tableData);
    }
  }

  Future<void> _processPSPData(List<List<dynamic>> tableData) async {
    List<String> headers = _cleanHeaders(tableData.first.map((cell) => cell.toString()).toList());
    List<Map<String, dynamic>> pspData = [];
    
    Map<String, String> foundColumns = {};
    
    for (String targetColumn in SettlementColumn.pspFieldMapping.values) {
      if (targetColumn.isNotEmpty) {
        String? foundColumn = SettlementColumn.findPSPColumn(headers, targetColumn);
        if (foundColumn != null) {
          foundColumns[targetColumn] = foundColumn;
        }
      }
    }
    
    for (int i = 1; i < tableData.length; i++) {
      var row = tableData[i];
      if (_isEmptyRow(row)) continue;
      
      if (row.isNotEmpty && row[0].toString().contains('***END***')) continue;

      Map<String, dynamic> rowData = {};
      
      foundColumns.forEach((targetColumn, foundColumn) {
        int columnIndex = headers.indexOf(foundColumn);
        if (columnIndex >= 0 && columnIndex < row.length) {
          var value = row[columnIndex];
          if (value != null && value.toString().isNotEmpty) {
            rowData[targetColumn] = value;
          }
        }
      });
      
      if (rowData.isNotEmpty) {
        pspData.add(rowData);
      }
    }

    if (pspData.isEmpty) {
      _showSnackBar('No valid PSP data found in file.', isError: true);
      return;
    }

    await _convertPSPToSettlement(pspData);
  }

  Future<void> _convertPSPToSettlement(List<Map<String, dynamic>> pspData) async {
    setState(() {
      _isConverting = true;
    });

    try {
      List<Map<String, dynamic>> convertedData = [];
      final defaultValues = SettlementColumn.getDefaultValues();
      
      for (int i = 0; i < pspData.length; i++) {
        Map<String, dynamic> pspRow = pspData[i];
        Map<String, dynamic> settlementRow = Map.from(defaultValues);
        
        SettlementColumn.pspFieldMapping.forEach((settlementField, pspField) {
          if (pspField.isNotEmpty && pspRow.containsKey(pspField)) {
            var value = pspRow[pspField];
            settlementRow[settlementField] = SettlementColumn.convertValue(settlementField, value);
          }
        });
        
        settlementRow['batch_number'] = 1;
        settlementRow['terminal_trace_number'] = i + 1;
        settlementRow['source_filename'] = _fileName ?? 'psp_conversion';
        
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

  Future<void> _processSettlementData(List<List<dynamic>> tableData) async {
    List<String> headers = tableData.first.map((cell) => cell.toString().trim()).toList();
    
    Map<String, String> headerToApiField = SettlementColumn.createHeaderMapping(headers);
    
    List<Map<String, dynamic>> parsedData = [];
    final defaultValues = SettlementColumn.getDefaultValues();
    int skippedEmpty = 0;
    
    for (int i = 1; i < tableData.length; i++) {
      var row = tableData[i];
      if (_isEmptyRow(row)) {
        skippedEmpty++;
        continue;
      }

      Map<String, dynamic> rowData = Map.from(defaultValues);
      
      for (int j = 0; j < headers.length && j < row.length; j++) {
        String header = headers[j];
        String apiField = headerToApiField[header] ?? _normalizeColumnName(header);
        var convertedValue = SettlementColumn.convertValue(apiField, row[j]);
        if (convertedValue != null) {
          rowData[apiField] = convertedValue;
        }
      }
      
      if (_hasMeaningfulData(rowData)) {
        parsedData.add(rowData);
      } else {
        skippedEmpty++;
      }
    }

    setState(() {
      _parsedData = parsedData;
      _skippedRows = skippedEmpty;
    });

    String message = 'Settlement file parsed successfully! Found ${parsedData.length} valid records';
    if (skippedEmpty > 0) {
      message += ' (${skippedEmpty} empty rows skipped)';
    }
    _showSnackBar(message, isError: false);
  }

  bool _hasMeaningfulData(Map<String, dynamic> rowData) {
    final criticalFields = [
      'system_txn_id',
      'merchant_id',
      'merchant_txn_amt',
    ];
    
    return criticalFields.any((field) {
      var value = rowData[field];
      return value != null && 
             value.toString().isNotEmpty && 
             value.toString().trim().isNotEmpty;
    });
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

  // UPDATED: Upload method with duplicate checking - BLOCKS upload if duplicates found
  Future<void> _uploadData() async {
    if (_parsedData == null || _parsedData!.isEmpty) {
      _showSnackBar('No data to upload. Please select and parse a file first.', isError: true);
      return;
    }
    
    // Validate data before upload
    List<ValidationError> validationErrors = _validateDataBeforeUpload();
    
    if (validationErrors.isNotEmpty) {
      _showValidationErrorDialog(validationErrors);
      return;
    }
    
    // Check for duplicates
    _showSnackBar('Checking for duplicates...', isError: false);
    List<String> duplicates = await _checkForDuplicates();
    
    if (duplicates.isNotEmpty) {
      _duplicateIds = duplicates;
      // BLOCK UPLOAD - Show error and stop
      _showDuplicateBlockedDialog(duplicates);
      return;
    }
    
    // No duplicates, proceed with upload
    _showSnackBar('No duplicates found. Starting upload...', isError: false);
    await _proceedWithUpload(skipInvalid: false, skipDuplicates: false);
  }

  // UPDATED: Proceed with upload (with duplicate handling)
  Future<void> _proceedWithUpload({
    bool skipInvalid = false, 
    bool skipDuplicates = false
  }) async {
    _resetUploadState();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      if (token != null && _isTokenExpired(token)) {
        _showSnackBar('Session expired. Please login again.', isError: true);
        setState(() { _isUploading = false; });
        return;
      }
      
      final url = AppConfig.api('/api/settlement-details');
      
      // Filter data
      List<Map<String, dynamic>> dataToUpload = _parsedData!;
      int skippedInvalid = 0;
      int skippedDuplicatesCount = 0;
      
      if (skipInvalid || skipDuplicates) {
        dataToUpload = _parsedData!.where((record) {
          // Check validation
          if (skipInvalid) {
            bool isValid = !_isEmpty(record['system_transaction_id']) &&
                          !_isEmpty(record['merchant_id']) &&
                          !_isEmpty(record['merchant_txn_amt']);
            if (!isValid) {
              skippedInvalid++;
              return false;
            }
          }
          
          // Check duplicates
          if (skipDuplicates) {
            String txnId = record['system_transaction_id']?.toString() ?? '';
            if (_duplicateIds.contains(txnId)) {
              skippedDuplicatesCount++;
              return false;
            }
          }
          
          return true;
        }).toList();
        
        if (kDebugMode) {
          print('Uploading ${dataToUpload.length} records');
          print('Skipped invalid: $skippedInvalid, Skipped duplicates: $skippedDuplicatesCount');
        }
      }
      
      for (int i = 0; i < dataToUpload.length; i++) {
        await _uploadSingleRecord(i, url.toString(), token, companyId, dataToUpload);
        _updateProgress(i + 1, dataToUpload.length);
      }

      _showUploadResultDialog(
        totalRows: _parsedData!.length, 
        skippedRows: skippedInvalid,
        skippedDuplicates: skippedDuplicatesCount,
      );
    } catch (e) {
      _showSnackBar('Error uploading data: $e', isError: true);
    } finally {
      setState(() { _isUploading = false; });
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
    dynamic apiUrl,  // Changed to dynamic to accept both Uri and String
    String? token, 
    dynamic companyId,
    [List<Map<String, dynamic>>? customData]
  ) async {
    try {
      final dataSource = customData ?? _parsedData!;
      Map<String, dynamic> settlementData = Map.from(dataSource[index]);
      
      // Remove pspid if exists, ensure company_id is set
      if (settlementData.containsKey('pspid')) {
        settlementData['company_id'] = settlementData['pspid'];
        settlementData.remove('pspid');
      }
      
      settlementData['company_id'] = companyId ?? settlementData['company_id'];
      
      // Convert batch_number and terminal_trace_number to integers
      if (settlementData['batch_number'] != null) {
        settlementData['batch_number'] = int.tryParse(settlementData['batch_number'].toString()) ?? 1;
      }
      
      if (settlementData['terminal_trace_number'] != null) {
        settlementData['terminal_trace_number'] = int.tryParse(settlementData['terminal_trace_number'].toString()) ?? 1;
      }
      
      // FIX: Truncate fields that exceed database limits
      settlementData = _truncateFields(settlementData);
      
      Map<String, String> headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      
      // Handle both Uri and String types
      Uri finalUri = apiUrl is Uri ? apiUrl : Uri.parse(apiUrl.toString());
      
      final response = await http.post(
        finalUri,
        headers: headers,
        body: jsonEncode(settlementData),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        _successCount++;
      } else {
        _errorCount++;
        try {
          final errorData = jsonDecode(response.body);
          String errorMsg = 'Row ${index + 1}: ${errorData['message'] ?? 'Unknown error'}';
          
          if (errorData['errors'] != null) {
            errorMsg += '\n  Validation: ${errorData['errors']}';
          }
          
          _errorMessages.add(errorMsg);
        } catch (e) {
          String errorMsg = 'Row ${index + 1}: HTTP ${response.statusCode}';
          _errorMessages.add(errorMsg);
        }
      }
    } catch (e) {
      _errorCount++;
      String errorMsg = 'Row ${index + 1}: Exception - $e';
      _errorMessages.add(errorMsg);
    }
  }

  void _resetState() {
    setState(() {
      _isParsing = true;
      _parsedData = null;
      _errorMessages.clear();
      _fileType = 'settlement';
      _columnAnalysis = null;
      _skippedRows = 0;
      _duplicateIds = [];
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

  void _updateProgress(int completedCount, [int? total]) {
    setState(() {
      _uploadProgress = completedCount / (total ?? _parsedData!.length);
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

  // UPDATED: Result dialog with duplicate info
  void _showUploadResultDialog({
    int? totalRows, 
    int? skippedRows,
    int? skippedDuplicates,
  }) {
    String errorReport = _generateErrorReport(skippedDuplicates: skippedDuplicates);
    
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
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Upload Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              if (totalRows != null) ...[
                Text('Total Records in File: $totalRows'),
                if (skippedRows != null && skippedRows > 0)
                  Text('Skipped (Invalid): $skippedRows', 
                       style: TextStyle(color: Colors.orange)),
                if (skippedDuplicates != null && skippedDuplicates > 0)
                  Text('Skipped (Duplicates): $skippedDuplicates', 
                       style: TextStyle(color: Colors.blue)),
              ],
              Text('Successful: $_successCount records', 
                   style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              Text('Failed: $_errorCount records', 
                   style: TextStyle(color: _errorCount > 0 ? Colors.red : Colors.grey)),
              Text('Total Attempted: ${_successCount + _errorCount} records'),
              if (_errorMessages.isNotEmpty) ...[
                SizedBox(height: 16),
                Text('Error Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        _errorMessages.join('\n'),
                        style: TextStyle(fontSize: 12, color: Colors.red, fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (_errorMessages.isNotEmpty) ...[
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: errorReport));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error report copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: Icon(Icons.copy),
              label: Text('Copy Errors'),
            ),
          ],
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

  String _generateErrorReport({int? skippedDuplicates}) {
    StringBuffer report = StringBuffer();
    
    report.writeln('=== UPLOAD ERROR REPORT ===');
    report.writeln('Generated: ${DateTime.now().toIso8601String()}');
    report.writeln('File: ${_fileName ?? 'Unknown'}');
    report.writeln('File Type: ${_fileType.toUpperCase()}');
    report.writeln('Configuration Version: ${SettlementColumn.getConfigVersion()}');
    report.writeln('');
    
    report.writeln('SUMMARY:');
    report.writeln('Total Records in File: ${_parsedData?.length ?? 0}');
    if (_skippedRows > 0) {
      report.writeln('Empty Rows Skipped: $_skippedRows');
    }
    if (skippedDuplicates != null && skippedDuplicates > 0) {
      report.writeln('Duplicate Rows Skipped: $skippedDuplicates');
    }
    report.writeln('Records Attempted: ${_successCount + _errorCount}');
    report.writeln('Successful Uploads: $_successCount');
    report.writeln('Failed Uploads: $_errorCount');
    if (_successCount + _errorCount > 0) {
      report.writeln('Success Rate: ${((_successCount / (_successCount + _errorCount)) * 100).toStringAsFixed(1)}%');
    }
    report.writeln('');
    
    if (_columnAnalysis != null) {
      report.writeln('COLUMN ANALYSIS:');
      report.writeln('Expected Columns: ${_columnAnalysis!.totalExpectedColumns}');
      report.writeln('CSV Columns: ${_columnAnalysis!.totalCsvColumns}');
      report.writeln('Successfully Mapped: ${_columnAnalysis!.foundColumns.length}');
      report.writeln('Missing Columns: ${_columnAnalysis!.missingColumns.length}');
      report.writeln('Required Missing: ${_columnAnalysis!.requiredMissingCount}');
      report.writeln('Mapping Success Rate: ${(_columnAnalysis!.mappingSuccessRate * 100).toStringAsFixed(1)}%');
      report.writeln('');
    }
    
    if (_errorMessages.isNotEmpty) {
      report.writeln('ERROR DETAILS:');
      for (int i = 0; i < _errorMessages.length; i++) {
        report.writeln('${i + 1}. ${_errorMessages[i]}');
      }
      report.writeln('');
    }
    
    report.writeln('=== END REPORT ===');
    
    return report.toString();
  }

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
                Spacer(),
                if (_columnAnalysis != null) ...[
                  IconButton(
                    icon: Icon(
                      _columnAnalysis!.canProceed ? Icons.check_circle : Icons.warning,
                      color: _columnAnalysis!.canProceed ? Colors.green : Colors.red,
                    ),
                    onPressed: _showColumnAnalysisDialog,
                    tooltip: 'Column Analysis Details',
                  ),
                ],
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Supports both Settlement Details and PSP Reconciliation files',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            if (_columnAnalysis != null) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _columnAnalysis!.canProceed ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _columnAnalysis!.canProceed ? Icons.check : Icons.error,
                      size: 16,
                      color: _columnAnalysis!.canProceed ? Colors.green : Colors.red,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Columns: ${_columnAnalysis!.foundColumns.length}/${_columnAnalysis!.totalExpectedColumns} mapped' +
                        (_columnAnalysis!.requiredMissingCount > 0 
                          ? ', ${_columnAnalysis!.requiredMissingCount} required missing' 
                          : ''),
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _showColumnAnalysisDialog,
                      child: Text('Details', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 20),
            _buildUploadArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    return GestureDetector(
      onTap: (_isParsing || _isConverting || _isCheckingDuplicates) ? null : _pickFile,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: 120),
        padding: EdgeInsets.all(8),
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
        child: (_isParsing || _isConverting || _isCheckingDuplicates)
            ? _buildLoadingIndicator(
                _isCheckingDuplicates ? 'Checking duplicates...' :
                _isConverting ? 'Converting PSP file...' : 
                'Parsing file...'
              )
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
          if (_skippedRows > 0)
            Text(
              '($_skippedRows empty rows skipped)',
              style: TextStyle(color: Colors.orange, fontSize: 10),
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
        SizedBox(height: 12),
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
    bool canUpload = _parsedData != null && 
                    _parsedData!.isNotEmpty && 
                    !_isUploading && 
                    !_isConverting &&
                    !_isCheckingDuplicates &&
                    (_columnAnalysis?.canProceed ?? true);

    return Container(
      height: 56,
      child: ElevatedButton(
        onPressed: canUpload ? _uploadData : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.3),
        ),
        child: _isUploading || _isCheckingDuplicates
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
                    _isCheckingDuplicates ? 'Checking Duplicates...' : 'Uploading Data...',
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
                    canUpload 
                        ? 'Upload to API'
                        : (_columnAnalysis?.canProceed == false 
                            ? 'Fix Required Columns First'
                            : 'Select File First'),
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
        title: Text('Settlement Upload'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
        actions: [
          if (_columnAnalysis != null)
            IconButton(
              icon: Icon(
                _columnAnalysis!.canProceed ? Icons.check_circle : Icons.warning,
                color: _columnAnalysis!.canProceed ? Colors.green : Colors.red,
              ),
              onPressed: _showColumnAnalysisDialog,
              tooltip: 'Column Analysis',
            ),
        ],
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
                  _buildColumnAnalysisSection(),
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