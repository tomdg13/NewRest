import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class SettlementDetailPage extends StatefulWidget {
  final String settlementId;
  final String orderNumber;

  const SettlementDetailPage({
    Key? key,
    required this.settlementId,
    required this.orderNumber,
  }) : super(key: key);

  @override
  State<SettlementDetailPage> createState() => _SettlementDetailPageState();
}

class _SettlementDetailPageState extends State<SettlementDetailPage>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _settlementDetail;
  bool _isLoading = false;
  String _errorMessage = '';
  String currentTheme = ThemeConfig.defaultTheme;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
    _setupAnimations();
    _fetchSettlementDetail();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
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

  void _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  Future<void> _fetchSettlementDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
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
          List<Map<String, dynamic>> settlements = 
              List<Map<String, dynamic>>.from(responseData['data']);
          
          Map<String, dynamic>? foundSettlement;
          try {
            foundSettlement = settlements.firstWhere(
              (settlement) => settlement['id'].toString() == widget.settlementId,
            );
          } catch (e) {
            foundSettlement = null;
          }
          
          if (foundSettlement != null) {
            setState(() {
              _settlementDetail = foundSettlement;
            });
          } else {
            throw Exception('Settlement with ID ${widget.settlementId} not found');
          }
        } else {
          throw Exception(responseData['message'] ?? 'Failed to fetch data');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return '-';
    try {
      DateTime dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('MMM dd, yyyy HH:mm:ss').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _formatAmount(dynamic amount, String? currency) {
    if (amount == null) return '-';
    currency = currency ?? 'USD';
    double value = double.tryParse(amount.toString()) ?? 0.0;
    return '$currency ${value.toStringAsFixed(2)}';
  }

  Color _getAmountColor(dynamic amount) {
    if (amount == null) return Colors.grey[700]!;
    double value = double.tryParse(amount.toString()) ?? 0.0;
    if (value > 0) return Colors.green[700]!;
    if (value < 0) return Colors.red[700]!;
    return Colors.grey[700]!;
  }

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty || text == '-') return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _exportSettlement() async {
    if (_settlementDetail == null) return;
    
    try {
      final csvContent = _generateCSVContent();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'settlement_${widget.orderNumber}_$timestamp.csv';
      
      _showExportDialog(csvContent, filename);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _generateCSVContent() {
    final settlement = _settlementDetail!;
    final headers = ['Field', 'Value'];
    
    final data = [
      ['ID', settlement['id']?.toString() ?? ''],
      ['Order Number', settlement['order_number']?.toString() ?? ''],
      ['PSP Order Number', settlement['psp_order_number']?.toString() ?? ''],
      ['Transaction Time', settlement['transaction_time']?.toString() ?? ''],
      ['Transaction Type', settlement['transaction_type']?.toString() ?? ''],
      ['Transaction Amount', settlement['transaction_amount']?.toString() ?? ''],
      ['Settlement Amount', settlement['merchant_settlement_amount']?.toString() ?? ''],
      ['PSP Name', settlement['psp_name']?.toString() ?? ''],
      ['Merchant Name', settlement['merchant_name']?.toString() ?? ''],
      ['Card Number', settlement['card_number']?.toString() ?? ''],
    ];
    
    final csvLines = <String>[
      headers.map((e) => '"$e"').join(','),
      ...data.map((row) => row.map((e) => '"${e.replaceAll('"', '""')}"').join(','))
    ];
    
    return csvLines.join('\n');
  }

  Widget _buildDetailCard(String title, List<Widget> children, IconData icon, {Color? backgroundColor}) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: backgroundColor != null 
            ? LinearGradient(
                colors: [backgroundColor.withOpacity(0.05), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon, 
                      color: ThemeConfig.getPrimaryColor(currentTheme),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ThemeConfig.getPrimaryColor(currentTheme),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool copyable = false, Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                      color: valueColor ?? Colors.grey[900],
                    ),
                  ),
                ),
                if (copyable && value != '-' && value.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.copy, size: 14),
                    onPressed: () => _copyToClipboard(value, label),
                    tooltip: 'Copy $label',
                    constraints: BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.all(4),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildAmountDisplay(dynamic amount, String? currency, String label, {double? width}) {
    Color amountColor = _getAmountColor(amount);

    return Container(
      width: width,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: amountColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: amountColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            _formatAmount(amount, currency),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(String csvContent, String filename) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.file_download, color: ThemeConfig.getPrimaryColor(currentTheme)),
            SizedBox(width: 8),
            Text('Export Settlement Data'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File: $filename', style: TextStyle(fontWeight: FontWeight.w500)),
              SizedBox(height: 16),
              Text('CSV Data Preview:', style: TextStyle(fontWeight: FontWeight.w500)),
              SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.maxFinite,
                  padding: EdgeInsets.all(8),
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
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvContent));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('CSV data copied to clipboard'), backgroundColor: Colors.green),
              );
            },
            icon: Icon(Icons.copy, size: 16),
            label: Text('Copy to Clipboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Settlement Detail - ${widget.orderNumber}'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
        actions: [
          if (_settlementDetail != null) ...[
            IconButton(
              onPressed: () => _copyToClipboard(widget.orderNumber, 'Order Number'),
              icon: Icon(Icons.copy),
              tooltip: 'Copy Order Number',
            ),
            IconButton(
              onPressed: _exportSettlement,
              icon: Icon(Icons.download),
              tooltip: 'Export Settlement',
            ),
          ],
          IconButton(
            onPressed: _fetchSettlementDetail,
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: ThemeConfig.getPrimaryColor(currentTheme)),
            SizedBox(height: 16),
            Text('Loading settlement details...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Error loading settlement details:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(_errorMessage, textAlign: TextAlign.center),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchSettlementDetail,
              child: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_settlementDetail == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No settlement details found', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('Settlement ID: ${widget.settlementId}'),
          ],
        ),
      );
    }

    return _buildTwoColumnLayout();
  }

  Widget _buildTwoColumnLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use single column on smaller screens
        bool isMobile = constraints.maxWidth < 800;
        
        if (isMobile) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                _buildTransactionOverview(),
                SizedBox(height: 16),
                ..._buildAllSections(),
                _buildActionButtons(),
              ],
            ),
          );
        }

        // Two-column layout for larger screens
        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Header overview spans full width
              _buildTransactionOverview(),
              SizedBox(height: 16),
              
              // Two-column content
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column
                  Expanded(
                    child: Column(
                      children: _buildLeftColumnSections(),
                    ),
                  ),
                  SizedBox(width: 16),
                  
                  // Right Column
                  Expanded(
                    child: Column(
                      children: _buildRightColumnSections(),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 20),
              _buildActionButtons(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionOverview() {
    return _buildDetailCard(
      'Transaction Overview',
      [
        // Amount grid
        Row(
          children: [
            Expanded(child: _buildAmountDisplay(_settlementDetail!['transaction_amount'], _settlementDetail!['transaction_currency'], 'Transaction Amount')),
            SizedBox(width: 12),
            Expanded(child: _buildAmountDisplay(_settlementDetail!['user_billing_amount'], _settlementDetail!['user_billing_currency'], 'Billing Amount')),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildAmountDisplay(_settlementDetail!['merchant_settlement_amount'], _settlementDetail!['merchant_settlement_currency'], 'Settlement Amount')),
            SizedBox(width: 12),
            Expanded(child: _buildAmountDisplay(_settlementDetail!['net_merchant_settlement_amount'], _settlementDetail!['merchant_settlement_currency'], 'Net Settlement')),
          ],
        ),
        SizedBox(height: 16),
        
        // Status chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatusChip(
              _settlementDetail!['transaction_type'] ?? '',
              _settlementDetail!['transaction_type'] == 'PURCHASE' ? Colors.green : Colors.orange,
            ),
            _buildStatusChip(
              _settlementDetail!['reconciliation_flag'] ?? '',
              _settlementDetail!['reconciliation_flag'] == 'Matched' ? Colors.green : Colors.orange,
            ),
            _buildStatusChip(
              _settlementDetail!['crossborder_flag'] ?? '',
              _settlementDetail!['crossborder_flag'] == 'Domestic' ? Colors.blue : Colors.purple,
            ),
            _buildStatusChip(
              _settlementDetail!['transaction_status'] ?? '',
              _settlementDetail!['transaction_status'] == 'Success' ? Colors.green : Colors.red,
            ),
          ],
        ),
      ],
      Icons.receipt_long,
      backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
    );
  }

  List<Widget> _buildLeftColumnSections() {
    return [
      // Transaction Information
      _buildDetailCard(
        'Transaction Information',
        [
          _buildDetailRow('Order Number', _settlementDetail!['order_number']?.toString() ?? '-', copyable: true),
          _buildDetailRow('PSP Order Number', _settlementDetail!['psp_order_number']?.toString() ?? '-', copyable: true),
          _buildDetailRow('System Transaction ID', _settlementDetail!['system_transaction_id']?.toString() ?? '-', copyable: true),
          _buildDetailRow('Original Order Number', _settlementDetail!['original_order_number']?.toString() ?? '-'),
          _buildDetailRow('Transaction Time', _formatDateTime(_settlementDetail!['transaction_time']?.toString())),
          _buildDetailRow('Payment Time', _formatDateTime(_settlementDetail!['payment_time']?.toString())),
          _buildDetailRow('Transaction Status', _settlementDetail!['transaction_status']?.toString() ?? '-'),
          _buildDetailRow('System Result Code', _settlementDetail!['system_result_code']?.toString() ?? '-'),
          _buildDetailRow('PSP Result Code', _settlementDetail!['psp_result_code']?.toString() ?? '-'),
        ],
        Icons.info_outline,
      ),

      // Payment Information
      _buildDetailCard(
        'Payment Information',
        [
          _buildDetailRow('PSP Name', _settlementDetail!['psp_name']?.toString() ?? '-'),
          _buildDetailRow('Payment Brand', _settlementDetail!['payment_brand']?.toString() ?? '-'),
          _buildDetailRow('Card Number', _settlementDetail!['card_number']?.toString() ?? '-', copyable: true),
          _buildDetailRow('Authorization Code', _settlementDetail!['authorization_code']?.toString() ?? '-', copyable: true),
          _buildDetailRow('Funding Type', _settlementDetail!['funding_type']?.toString() ?? '-'),
          _buildDetailRow('Transaction Initiation Mode', _settlementDetail!['transaction_initiation_mode']?.toString() ?? '-'),
          _buildDetailRow('MCC', _settlementDetail!['mcc']?.toString() ?? '-'),
          _buildDetailRow('Issuer Country', _settlementDetail!['issuer_country']?.toString() ?? '-'),
          _buildDetailRow('Product ID', _settlementDetail!['product_id']?.toString() ?? '-'),
          _buildDetailRow('Product Type', _settlementDetail!['product_type_id']?.toString() ?? '-'),
        ],
        Icons.credit_card,
      ),

      // Terminal Information
      _buildDetailCard(
        'Terminal Information',
        [
          _buildDetailRow('Terminal ID', _settlementDetail!['terminal_id']?.toString() ?? '-'),
          _buildDetailRow('Batch Number', _settlementDetail!['batch_number']?.toString() ?? '-'),
          _buildDetailRow('Terminal Trace Number', _settlementDetail!['terminal_trace_number']?.toString() ?? '-'),
          _buildDetailRow('Terminal Settlement Time', _formatDateTime(_settlementDetail!['terminal_settlement_time']?.toString())),
        ],
        Icons.computer,
      ),
    ];
  }

  List<Widget> _buildRightColumnSections() {
    return [
      // Merchant Information
      _buildDetailCard(
        'Merchant Information',
        [
          _buildDetailRow('Group', '${_settlementDetail!['group_name'] ?? ''} (${_settlementDetail!['group_id'] ?? ''})'),
          _buildDetailRow('Merchant', '${_settlementDetail!['merchant_name'] ?? ''} (${_settlementDetail!['merchant_id'] ?? ''})'),
          _buildDetailRow('Store', '${_settlementDetail!['store_name'] ?? ''} (${_settlementDetail!['store_id'] ?? ''})'),
          _buildDetailRow('Merchant Nation', _settlementDetail!['merchant_nation']?.toString() ?? '-'),
          _buildDetailRow('Merchant City', _settlementDetail!['merchant_city']?.toString() ?? '-'),
          _buildDetailRow('Merchant Order Reference', _settlementDetail!['merchant_order_reference']?.toString() ?? '-'),
        ],
        Icons.store,
      ),

      // Fee Information
      _buildDetailCard(
        'Fee & Rates Information',
        [
          _buildDetailRow('MDR Amount', _formatAmount(_settlementDetail!['mdr_amount'], _settlementDetail!['merchant_settlement_currency']), 
            valueColor: _getAmountColor(_settlementDetail!['mdr_amount'])),
          _buildDetailRow('MDR Rules', _settlementDetail!['mdr_rules']?.toString() ?? '-'),
          _buildDetailRow('Interchange Fee', _formatAmount(_settlementDetail!['interchange_fee_amount'], _settlementDetail!['merchant_settlement_currency']),
            valueColor: _getAmountColor(_settlementDetail!['interchange_fee_amount'])),
          _buildDetailRow('VAT Amount', _formatAmount(_settlementDetail!['vat_amount'], _settlementDetail!['merchant_settlement_currency']),
            valueColor: _getAmountColor(_settlementDetail!['vat_amount'])),
          _buildDetailRow('WHT Amount', _formatAmount(_settlementDetail!['wht_amount'], _settlementDetail!['merchant_settlement_currency']),
            valueColor: _getAmountColor(_settlementDetail!['wht_amount'])),
          _buildDetailRow('Merchant Capture Amount', _formatAmount(_settlementDetail!['merchant_capture_amount'], _settlementDetail!['merchant_local_currency']),
            valueColor: _getAmountColor(_settlementDetail!['merchant_capture_amount'])),
        ],
        Icons.calculate,
      ),

      // Additional Information
      _buildDetailCard(
        'Additional Information',
        [
          _buildDetailRow('Source Filename', _settlementDetail!['source_filename']?.toString() ?? '-'),
          _buildDetailRow('Company ID', _settlementDetail!['company_id']?.toString() ?? '-'),
          _buildDetailRow('Upload Date', _formatDateTime(_settlementDetail!['datetime_upload']?.toString())),
          _buildDetailRow('Created At', _formatDateTime(_settlementDetail!['created_at']?.toString())),
          _buildDetailRow('Updated At', _formatDateTime(_settlementDetail!['updated_at']?.toString())),
          if (_settlementDetail!['remark'] != null && _settlementDetail!['remark'].toString().isNotEmpty)
            _buildDetailRow('Remark', _settlementDetail!['remark']?.toString() ?? '-'),
          if (_settlementDetail!['metadata'] != null && _settlementDetail!['metadata'].toString().isNotEmpty)
            _buildDetailRow('Metadata', _settlementDetail!['metadata']?.toString() ?? '-'),
        ],
        Icons.description,
      ),
    ];
  }

  List<Widget> _buildAllSections() {
    return [
      ..._buildLeftColumnSections(),
      ..._buildRightColumnSections(),
    ];
  }

  Widget _buildActionButtons() {
    return Container(
      margin: EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _exportSettlement,
              icon: Icon(Icons.download),
              label: Text('Export to CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _copyToClipboard(
                _settlementDetail!['order_number']?.toString() ?? '',
                'Order Number'
              ),
              icon: Icon(Icons.copy),
              label: Text('Copy Order #'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: ThemeConfig.getPrimaryColor(currentTheme)),
                foregroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}