import 'package:inventory/config/company_config.dart';
// ignore: unused_import
import 'package:uuid/uuid.dart';

/// Central configuration for Settlement file column mappings and validations
/// Updated to use appropriate null/dynamic defaults instead of hardcoded test data
class SettlementColumn {
  // PSP to Settlement field mapping
  static const Map<String, String> pspFieldMapping = {
    'company_id': '',
    'transaction_time': 'Merchant Txn Time',
    'payment_time': 'Txn Pay Time', 
    'order_number': 'Merchant Txn ID',
    'psp_order_number': 'PSP Txn ID',
    'original_order_number': 'Original Merchant Txn ID',
    'original_psp_order_number': 'Original PSP Txn ID',
    'system_transaction_id': 'System Txn ID',
    'original_system_transaction_id': 'Original System Txn ID',
    'system_transaction_time': 'System Txn Time',
    'transaction_amount': 'Merchant Txn Amt',
    'tips_amount': 'Tips Amount',
    'transaction_currency': 'Merchant Txn Curr',
    'user_billing_amount': 'User Billing Amt',
    'user_billing_currency': 'User Billing Curr',
    'merchant_local_amount': 'Merchant Local Amt',
    'merchant_local_currency': 'Merchant Local Curr',
    'merchant_capture_amount': 'Merchant Capture Amt',
    'local_capture_amount': 'Local Capture Amt',
    'local_tips_amount': 'Local Tips Amt',
    'local_surcharge_fee_amount': 'Local Surcharge Fee Amt',
    'surcharge_fee_amount': 'Surcharge Fee Amt',
    'merchant_discount_amount': 'Merchant Discount Amt',
    'merchant_settlement_amount': 'Merchant Sttl Amt',
    'merchant_settlement_currency': 'Merchant Sttl Curr',
    'net_merchant_settlement_amount': 'Net Merchant Sttl Amt',
    'brand_settlement_amount': 'PSP Sttl Amt',
    'brand_settlement_currency': 'PSP Sttl Curr',
    'net_brand_settlement_amount': 'Net PSP Sttl Amt',
    'mdr_amount': 'MDR Amount',
    'interchange_fee_amount': 'PSP Interchange Fee',
    'psp_scheme_fee': 'PSP Scheme Fee',
    'acquirer_service_fee': 'Acquirer Service Fee',
    'transaction_service_fee': 'Txn Service Fee',
    'vat_amount': 'VAT Amount',
    'wht_amount': 'WHT Amount',
    'rate_local_to_transaction': 'Rate of Local to Txn',
    'rate_transaction_to_settlement': 'Rate from Merchant Txn to Sttl',
    'reconciliation_flag': 'Txn Status',
    'transaction_type': 'Txn Type',
    'transaction_status': 'Txn Status',
    'system_result_code': 'System Result Code',
    'psp_result_code': 'PSP Result Code',
    'crossborder_flag': 'Crossborder Flag',
    'psp_name': 'PSP Name',
    'payment_brand': 'Payment Brand',
    'card_number': 'Card Number',
    'authorization_code': 'PSP Authorization Code',
    'funding_type': 'Funding Type',
    'product_id': 'Product ID',
    'product_type_id': 'Product Type ID',
    'payment_method_variant': 'Payment Method Variant',
    'transaction_initiation_mode': 'Txn Initiation Mode',
    'eci': 'ECI',
    'linkpay_order_id': 'LinkPay Order ID',
    'group_id': 'Group ID',
    'group_name': 'Group Name',
    'merchant_id': 'Merchant ID',
    'merchant_name': 'Merchant Name',
    'store_id': 'Store ID',
    'store_name': 'Store Name',
    'mcc': 'Store MCC',
    'merchant_nation': 'Merchant Nation',
    'merchant_city': 'Merchant City',
    'merchant_order_reference': 'Merchant Order Reference',
    'issuer_country': 'Issuer Country',
    'terminal_id': 'Terminal ID',
    'terminal_settlement_time': 'Terminal Sttl Time',
    'batch_number': 'Batch Number',
    'terminal_trace_number': 'Terminal Trace Number',
    'mdr_rules': 'MDR Rules',
    'api_type': 'API Type',
    'api_code': 'API Code',
    'remark': 'Metadata',
    'metadata': 'Metadata',
    'source_filename': '',
    'settlement_account_name': 'Settlement Account Name',
    'settlement_account_number': 'Settlement Account Number',
    'extra_info': 'Extra Info',
  };

  // Alternative column names for PSP files
  static const Map<String, List<String>> pspAlternativeColumns = {
    'Merchant Txn Time': ['Transaction Time', 'Merchant Transaction Time', 'Txn Time', 'Trans Time', 'Payment Time'],
    'Merchant Txn ID': ['Transaction ID', 'Merchant Transaction ID', 'Order ID', 'Trans ID', 'Txn ID'],
    'PSP Txn ID': ['PSP Transaction ID', 'PSP Order ID', 'Payment ID', 'Gateway ID', 'Provider ID', 'PSP ID'],
    'Merchant Txn Amt': ['Transaction Amount', 'Merchant Transaction Amount', 'Amount', 'Trans Amount', 'Payment Amount'],
    'Merchant Txn Curr': ['Transaction Currency', 'Currency', 'Txn Currency', 'Trans Currency', 'Payment Currency'],
    'PSP Name': ['Payment Service Provider', 'Provider Name', 'Gateway', 'PSP', 'Payment Gateway'],
    'Payment Brand': ['Card Brand', 'Brand', 'Card Type', 'Payment Type', 'Card Scheme'],
    'Card Number': ['Card No', 'PAN', 'Card', 'Card Num', 'Account Number'],
    'PSP Authorization Code': ['Auth Code', 'Authorization', 'Approval Code', 'Auth', 'Authorization Number'],
    'Merchant Sttl Amt': ['Settlement Amount', 'Settlement Amt', 'Sttl Amount', 'Net Amount', 'Final Amount'],
    'Net Merchant Sttl Amt': ['Net Settlement', 'Net Settlement Amount', 'Net Amount', 'Final Net Amount'],
    'PSP Interchange Fee': ['Interchange Fee', 'IC Fee', 'Network Fee', 'Processing Fee', 'Transaction Fee'],
    'Txn Status': ['Transaction Status', 'Status', 'Payment Status', 'Trans Status', 'Settlement Status'],
    'Txn Type': ['Transaction Type', 'Type', 'Payment Type', 'Trans Type', 'Operation Type'],
    'Crossborder Flag': ['Cross Border', 'International', 'Border Flag', 'Cross Border Flag', 'International Flag'],
    'Store MCC': ['MCC', 'Merchant Category Code', 'Category Code', 'Business Code', 'Industry Code'],
    'Merchant Name': ['Merchant', 'Business Name', 'Store Name', 'Company Name', 'Business'],
    'Group Name': ['Group', 'Organization', 'Company Name', 'Corporate Name', 'Group ID'],
    'System Txn ID': ['System Transaction ID', 'Internal ID', 'Reference ID', 'System ID', 'Internal Reference'],
    'User Billing Amt': ['Billing Amount', 'Customer Amount', 'Cardholder Amount', 'User Amount', 'Bill Amount'],
    'Funding Type': ['Card Type', 'Payment Method', 'Fund Source', 'Account Type', 'Payment Source'],
    'Txn Initiation Mode': ['Initiation Mode', 'Entry Mode', 'Transaction Mode', 'Payment Mode', 'Entry Type'],
    'API Code': ['API Type Code', 'API Version', 'Interface Code', 'Gateway Code', 'API Identifier'],
    'MDR Amount': ['MDR', 'Merchant Discount Rate', 'Commission', 'Service Fee', 'Processing Fee'],
    'Terminal ID': ['Terminal', 'POS ID', 'Device ID', 'Terminal Number', 'POS Terminal'],
    'Batch Number': ['Batch', 'Batch ID', 'Settlement Batch', 'Batch No', 'Processing Batch'],
    'Issuer Country': ['Issuer', 'Card Issuer Country', 'Issuing Country', 'Bank Country', 'Card Country'],
    'PSP Sttl Amt': ['PSP Settlement Amount', 'Brand Settlement Amount', 'PSP Sttl Amount'],
    'PSP Sttl Curr': ['PSP Settlement Currency', 'Brand Settlement Currency', 'PSP Sttl Currency'],
    'Net PSP Sttl Amt': ['Net PSP Settlement Amount', 'Net Brand Settlement Amount', 'Net PSP Sttl Amount'],
    'Terminal Sttl Time': ['Terminal Settlement Time', 'Settlement Time', 'Terminal Settlement Timestamp'],
    'Terminal Trace Number': ['Terminal Trace', 'Trace Number', 'Terminal Reference Number'],
    'Extra Info': ['Additional Info', 'Notes', 'Comments', 'Extra Data', 'Additional Data'],
  };

  // Settlement column mapping
  static const Map<String, String> settlementColumnMapping = {
    'company_id': 'Company ID',
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
    'brand_settlement_currency': 'Brand Settlement Currency',
    'interchange_fee_amount': 'Interchange Fee Amount',
    'net_brand_settlement_amount': 'Net Brand Settlement Amount',
    'reconciliation_flag': 'Reconciliation Flag',
    'transaction_type': 'Transaction Type',
    'psp_name': 'PSP Name',
    'payment_brand': 'Payment Brand',
    'card_number': 'Card Number',
    'authorization_code': 'Authorization Code',
    'mcc': 'MCC',
    'crossborder_flag': 'Crossborder Flag',
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
    'remark': 'Remark',
    'source_filename': 'Source Filename',
    'merchant_nation': 'Merchant Nation',
    'merchant_city': 'Merchant City',
    'system_transaction_time': 'System Transaction Time',
    'api_type': 'API Type',
    'api_code': 'API Code',
    'payment_method_variant': 'Payment Method Variant',
    'funding_type': 'Funding Type',
    'product_id': 'Product ID',
    'product_type_id': 'Product Type ID',
    'issuer_country': 'Issuer Country',
    'merchant_order_reference': 'Merchant Order Reference',
    'system_transaction_id': 'System Transaction ID',
    'original_system_transaction_id': 'Original System Transaction ID',
    'merchant_local_amount': 'Merchant Local Amount',
    'local_tips_amount': 'Local Tips Amount',
    'local_surcharge_fee_amount': 'Local Surcharge Fee Amount',
    'local_capture_amount': 'Local Capture Amount',
    'merchant_local_currency': 'Merchant Local Currency',
    'rate_local_to_transaction': 'Rate Local to Transaction',
    'surcharge_fee_amount': 'Surcharge Fee Amount',
    'merchant_capture_amount': 'Merchant Capture Amount',
    'merchant_discount_amount': 'Merchant Discount Amount',
    'rate_transaction_to_settlement': 'Rate Transaction to Settlement',
    'mdr_rules': 'MDR Rules',
    'psp_scheme_fee': 'PSP Scheme Fee',
    'acquirer_service_fee': 'Acquirer Service Fee',
    'transaction_service_fee': 'Transaction Service Fee',
    'vat_amount': 'VAT Amount',
    'wht_amount': 'WHT Amount',
    'user_billing_amount': 'User Billing Amount',
    'user_billing_currency': 'User Billing Currency',
    'eci': 'ECI',
    'transaction_initiation_mode': 'Transaction Initiation Mode',
    'linkpay_order_id': 'LinkPay Order ID',
    'transaction_status': 'Transaction Status',
    'system_result_code': 'System Result Code',
    'psp_result_code': 'PSP Result Code',
    'settlement_account_name': 'Settlement Account Name',
    'settlement_account_number': 'Settlement Account Number',
    'metadata': 'Metadata',
    'extra_info': 'Extra Info',
  };

  // Alternative column names for Settlement files
  static const Map<String, List<String>> settlementAlternativeColumns = {
    'Transaction Time': ['Merchant Txn Time', 'merchant_txn_time'],
    'Order Number': ['Merchant Txn ID', 'merchant_txn_id'],
    'Transaction Amount': ['Merchant Txn Amt', 'merchant_txn_amt'],
    'Transaction Currency': ['Merchant Txn Curr', 'merchant_txn_curr'],
    'Merchant Settlement Amount': ['Merchant Sttl Amt', 'merchant_sttl_amt', 'Merchant Local Amt', 'merchant_local_amt'],
    'Merchant Settlement Currency': ['Merchant Sttl Curr', 'merchant_sttl_curr', 'Merchant Local Curr', 'merchant_local_curr'],
    'Reconciliation Flag': ['Txn Status', 'txn_status'],
    'Transaction Type': ['Txn Type', 'txn_type'],
    'Company ID': ['PSP ID', 'psp_id', 'Acquirer ID', 'acquirer_id'],
    'Payment Time': ['Txn Pay Time', 'txn_pay_time'],
    'PSP Order Number': ['PSP Txn ID', 'psp_txn_id'],
    'System Transaction ID': ['System Txn ID', 'system_txn_id'],
    'System Transaction Time': ['System Txn Time', 'system_txn_time'],
    'Original Order Number': ['Original Merchant Txn ID', 'original_merchant_txn_id'],
    'Original System Transaction ID': ['Original System Txn ID', 'original_system_txn_id'],
    'Original PSP Order Number': ['Original PSP Txn ID', 'original_psp_txn_id'],
    'Merchant Local Amount': ['Merchant Local Amt', 'merchant_local_amt'],
    'Merchant Local Currency': ['Merchant Local Curr', 'merchant_local_curr'],
    'Local Tips Amount': ['Local Tips Amt', 'local_tips_amt'],
    'Local Surcharge Fee Amount': ['Local Surcharge Fee Amt', 'local_surcharge_fee_amt'],
    'Local Capture Amount': ['Local Capture Amt', 'local_capture_amt'],
    'Rate Local to Transaction': ['Rate of Local to Txn', 'rate_of_local_to_txn'],
    'Surcharge Fee Amount': ['Surcharge Fee Amt', 'surcharge_fee_amt'],
    'Merchant Capture Amount': ['Merchant Capture Amt', 'merchant_capture_amt'],
    'Merchant Discount Amount': ['Merchant Discount Amt', 'merchant_discount_amt', 'Acquirer Discount Amt'],
    'Rate Transaction to Settlement': ['Rate from Merchant Txn to Sttl', 'rate_from_merchant_txn_to_sttl'],
    'User Billing Amount': ['User Billing Amt', 'user_billing_amt'],
    'User Billing Currency': ['User Billing Curr', 'user_billing_curr'],
    'Transaction Initiation Mode': ['Txn Initiation Mode', 'txn_initiation_mode'],
    'Transaction Status': ['Txn Status', 'txn_status'],
    'Authorization Code': ['PSP Authorization Code', 'psp_authorization_code'],
    'Interchange Fee Amount': ['PSP Interchange Fee', 'psp_interchange_fee'],
    'Transaction Service Fee': ['Txn Service Fee', 'txn_service_fee'],
    'Net Merchant Settlement Amount': ['Net Merchant Sttl Amt', 'net_merchant_sttl_amt'],
    'MCC': ['Store MCC', 'store_mcc'],
    'VAT Amount': ['PSP VAT Amount', 'psp_vat_amount'],
    'WHT Amount': ['PSP WHT Amount', 'psp_wht_amount'],
    'Brand Settlement Amount': ['PSP Sttl Amt', 'psp_sttl_amt'],
    'Brand Settlement Currency': ['PSP Sttl Curr', 'psp_sttl_curr'],
    'Net Brand Settlement Amount': ['PSP Net Sttl Amt', 'psp_net_sttl_amt', 'Net PSP Sttl Amt'],
  };

  // Required columns for validation
  static const List<String> requiredColumns = [
    'company_id', 
    'transaction_time', 
    'order_number', 
    'transaction_amount',
    'transaction_currency', 
    'merchant_settlement_amount', 
    'merchant_settlement_currency',
    'reconciliation_flag', 
    'transaction_type', 
    'psp_name', 
    'payment_brand',
    'merchant_id', 
    'merchant_name', 
    'store_id', 
    'store_name',
  ];

  // Data type configurations
  static const Set<String> dateTimeColumns = {
    'transaction_time', 
    'payment_time', 
    'terminal_settlement_time', 
    'system_transaction_time'
  };

  // Integer columns
  static const Set<String> integerColumns = {
    'psp_order_number',
    'original_psp_order_number',
    'batch_number',
    'terminal_trace_number',
  };

  // Numeric columns
  static const Set<String> numericColumns = {
    'transaction_amount', 'tips_amount', 'merchant_settlement_amount',
    'mdr_amount', 'net_merchant_settlement_amount', 'brand_settlement_amount',
    'interchange_fee_amount', 'net_brand_settlement_amount',
    'merchant_capture_amount', 'user_billing_amount', 'merchant_local_amount',
    'local_tips_amount', 'local_surcharge_fee_amount', 'local_capture_amount',
    'surcharge_fee_amount', 'merchant_discount_amount', 'psp_scheme_fee',
    'acquirer_service_fee', 'transaction_service_fee', 'vat_amount', 'wht_amount',
    'rate_local_to_transaction', 'rate_transaction_to_settlement'
  };

  // String length limits
  static const Map<String, int> stringLengthLimits = {
    'order_number': 100,
    'original_order_number': 100,
    'transaction_currency': 10,
    'merchant_settlement_currency': 10,
    'brand_settlement_currency': 10,
    'merchant_local_currency': 10,
    'user_billing_currency': 10,
    'reconciliation_flag': 50,
    'transaction_type': 50,
    'psp_name': 255,
    'payment_brand': 100,
    'card_number': 50,
    'crossborder_flag': 50,
    'group_id': 100,
    'group_name': 255,
    'merchant_id': 100,
    'merchant_name': 255,
    'store_id': 100,
    'store_name': 255,
    'terminal_id': 100,
    'source_filename': 255,
    'merchant_nation': 100,
    'merchant_city': 100,
    'api_type': 100,
    'api_code': 100,
    'payment_method_variant': 100,
    'funding_type': 50,
    'product_id': 100,
    'product_type_id': 100,
    'issuer_country': 100,
    'merchant_order_reference': 255,
    'system_transaction_id': 255,
    'original_system_transaction_id': 255,
    'mdr_rules': 255,
    'eci': 50,
    'transaction_initiation_mode': 100,
    'linkpay_order_id': 255,
    'transaction_status': 50,
    'system_result_code': 50,
    'psp_result_code': 50,
    'settlement_account_name': 255,
    'settlement_account_number': 255,
    'psp_order_number': 255,
    'original_psp_order_number': 255,
    'remark': 1000,
    'metadata': -1,
    'extra_info': 1000,
    'authorization_code': 255,
    'mcc': 50,
    'batch_number': 50,
    'terminal_trace_number': 50,
  };

  // PSP file detection indicators
  static const List<String> pspDetectionIndicators = [
    'PSP Txn ID', 'PSP Name', 'PSP Sttl Amt', 'System Txn ID',
    'Merchant Txn Time', 'PSP Authorization Code', 'PSP Interchange Fee',
    'Rate of Local to Txn', 'Net PSP Sttl Amt', 'PSP Scheme Fee'
  ];

  // Settlement file detection indicators
  static const List<String> settlementDetectionIndicators = [
    'Transaction Time', 'Payment Time', 'Order Number', 'Settlement Amount',
    'Terminal ID', 'Batch Number', 'Terminal Trace Number', 'Merchant Settlement Amount'
  ];

  // Enum validation values
  static const Map<String, Map<String, dynamic>> enumValidations = {
    'reconciliation_flag': {
      'valid_values': ['Matched', 'Unmatched', 'Pending', 'Failed', 'Reconciled', 'matched', 'unmatched', 'pending', 'failed', 'reconciled'],
      'case_sensitive': false,
    },
    'transaction_type': {
      'valid_values': ['PURCHASE', 'REFUND', 'VOID', 'PREAUTH', 'CAPTURE', 'purchase', 'refund', 'void', 'preauth', 'capture'],
      'case_sensitive': false,
    },
    'crossborder_flag': {
      'valid_values': ['International', 'Domestic', 'international', 'domestic'],
      'case_sensitive': false,
    },
  };

  // UPDATED: Default values - using null or dynamic values instead of hardcoded test data
  static Map<String, dynamic> getDefaultValues() {
    final timestamp = DateTime.now();
    
    return {
      // Required with sensible defaults
      'company_id': CompanyConfig.getCompanyId(),
      'transaction_time': timestamp.toIso8601String(),
      'crossborder_flag': 'Domestic',
      'reconciliation_flag': 'Matched',
      'transaction_type': 'PURCHASE',
      'transaction_status': 'Success',
      
      // Terminal/batch defaults
      'terminal_id': 'TERMINAL001',
      'batch_number': 1,
      'terminal_trace_number': 1,
      
      // Numeric defaults (zero)
      'transaction_amount': 0.0,
      'tips_amount': 0.0,
      'merchant_settlement_amount': 0.0,
      'net_merchant_settlement_amount': 0.0,
      'mdr_amount': 0.0,
      'brand_settlement_amount': 0.0,
      'interchange_fee_amount': 0.0,
      'net_brand_settlement_amount': 0.0,
      'merchant_capture_amount': 0.0,
      'user_billing_amount': 0.0,
      'merchant_local_amount': 0.0,
      'local_tips_amount': 0.0,
      'local_surcharge_fee_amount': 0.0,
      'local_capture_amount': 0.0,
      'surcharge_fee_amount': 0.0,
      'merchant_discount_amount': 0.0,
      'psp_scheme_fee': 0.0,
      'acquirer_service_fee': 0.0,
      'transaction_service_fee': 0.0,
      'vat_amount': 0.0,
      'wht_amount': 0.0,
      'rate_local_to_transaction': 1.0,
      'rate_transaction_to_settlement': 1.0,
      
      // Currency defaults
      'transaction_currency': 'USD',
      'merchant_settlement_currency': 'USD',
      'brand_settlement_currency': 'USD',
      'merchant_local_currency': 'USD',
      'user_billing_currency': 'USD',
      
      // Geographic defaults  
      'merchant_nation': 'LAO',
      'merchant_city': 'Vientiane',
      'issuer_country': 'LAO',
      
      // Transaction mode defaults
      'funding_type': 'Debit',
      'transaction_initiation_mode': 'manual',
      
      // System defaults
      'system_result_code': 'S0000',
      'api_code': 'STANDARD_API_V2',
      'mdr_rules': 'Combination',
      'system_transaction_time': timestamp.toIso8601String(),
      
      // NULL for IDs that should come from CSV (NOT hardcoded test data)
      'order_number': null,
      'psp_order_number': null,
      'original_order_number': null,
      'original_psp_order_number': null,
      'system_transaction_id': null,
      'original_system_transaction_id': null,
      'psp_name': null,
      'payment_brand': null,
      'card_number': null,
      'authorization_code': null,
      'mcc': null,
      'group_id': null,
      'group_name': null,
      'merchant_id': null,
      'merchant_name': null,
      'store_id': null,
      'store_name': null,
      'metadata': null,
      'extra_info': null,
      'payment_time': null,
      'terminal_settlement_time': null,
      'merchant_order_reference': null,
      'linkpay_order_id': null,
      'psp_result_code': null,
      'product_id': null,
      'product_type_id': null,
      'payment_method_variant': null,
      'eci': null,
      'settlement_account_name': null,
      'settlement_account_number': null,
      'remark': null,
      'api_type': null,
    };
  }

  // Helper methods for column operations
  static String? findPSPColumn(List<String> headers, String targetColumn) {
    // First try exact match
    for (String header in headers) {
      if (header.trim() == targetColumn.trim()) {
        return header;
      }
    }
    
    // Try alternative column names
    final alternatives = pspAlternativeColumns[targetColumn];
    if (alternatives != null) {
      for (String alternative in alternatives) {
        for (String header in headers) {
          if (header.trim().toLowerCase() == alternative.toLowerCase()) {
            return header;
          }
        }
      }
    }
    
    // Try partial matching
    for (String header in headers) {
      String normalizedHeader = header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      String normalizedTarget = targetColumn.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      
      if (normalizedHeader.contains(normalizedTarget) || normalizedTarget.contains(normalizedHeader)) {
        return header;
      }
    }
    
    return null;
  }

  static String detectFileType(List<String> headers) {
    int pspMatches = 0;
    int settlementMatches = 0;
    
    for (String indicator in pspDetectionIndicators) {
      if (findPSPColumn(headers, indicator) != null) {
        pspMatches++;
      }
    }
    
    for (String indicator in settlementDetectionIndicators) {
      for (String header in headers) {
        if (header.toLowerCase().contains(indicator.toLowerCase())) {
          settlementMatches++;
          break;
        }
      }
    }
    
    return pspMatches >= settlementMatches ? 'psp' : 'settlement';
  }

  static Map<String, String> createHeaderMapping(List<String> headers) {
    Map<String, String> headerToApiField = {};
    
    // First pass: exact matches
    for (String header in headers) {
      for (String apiField in settlementColumnMapping.keys) {
        String? expectedHeader = settlementColumnMapping[apiField];
        if (expectedHeader != null && header.trim() == expectedHeader.trim()) {
          headerToApiField[header] = apiField;
          break;
        }
      }
    }
    
    // Second pass: check settlement alternative columns
    for (String header in headers) {
      if (headerToApiField.containsKey(header)) continue;
      
      for (var entry in settlementAlternativeColumns.entries) {
        String standardName = entry.key;
        List<String> alternatives = entry.value;
        
        if (alternatives.any((alt) => alt.trim().toLowerCase() == header.trim().toLowerCase())) {
          var matchingEntry = settlementColumnMapping.entries.firstWhere(
            (e) => e.value == standardName,
            orElse: () => MapEntry('', ''),
          );
          
          if (matchingEntry.key.isNotEmpty) {
            headerToApiField[header] = matchingEntry.key;
            break;
          }
        }
      }
    }
    
    // Third pass: normalized matching
    for (String header in headers) {
      if (headerToApiField.containsKey(header)) continue;
      
      for (String apiField in settlementColumnMapping.keys) {
        String normalizedHeader = _normalizeColumnName(header);
        String normalizedApiField = _normalizeColumnName(apiField);
        
        if (normalizedHeader == normalizedApiField) {
          headerToApiField[header] = apiField;
          break;
        }
      }
    }
    
    return headerToApiField;
  }

  static List<String> validateRequiredColumns(Map<String, String> headerToApiField) {
    List<String> missingColumns = [];
    
    for (String apiField in requiredColumns) {
      if (!headerToApiField.containsValue(apiField)) {
        String expectedHeader = settlementColumnMapping[apiField] ?? apiField;
        missingColumns.add(expectedHeader);
      }
    }
    
    return missingColumns;
  }

  static dynamic convertValue(String columnName, dynamic value) {
    if (value == null) return null;
    
    String valueStr = value.toString().trim();
    if (valueStr.isEmpty) return null;

    // Integer conversion
    if (integerColumns.contains(columnName)) {
      try {
        return int.tryParse(valueStr.replaceAll(RegExp(r'[^0-9]'), ''));
      } catch (e) {
        return null;
      }
    }

    // Date/time conversion
    if (dateTimeColumns.contains(columnName)) {
      try {
        DateTime dateTime = DateTime.parse(valueStr);
        return dateTime.toIso8601String();
      } catch (e) {
        return valueStr;
      }
    }

    // Numeric conversion
    if (numericColumns.contains(columnName)) {
      try {
        String cleanedValue = valueStr.replaceAll(RegExp(r'[^0-9.-]'), '');
        if (cleanedValue.isEmpty) return 0.0;
        
        double? doubleValue = double.tryParse(cleanedValue);
        if (doubleValue != null) {
          if (columnName == 'rate_local_to_transaction' || columnName == 'rate_transaction_to_settlement') {
            if (doubleValue > 9999.999999) {
              doubleValue = 9999.999999;
            } else if (doubleValue < -9999.999999) {
              doubleValue = -9999.999999;
            }
            return double.parse(doubleValue.toStringAsFixed(6));
          } else {
            return double.parse(doubleValue.toStringAsFixed(2));
          }
        }
        return 0.0;
      } catch (e) {
        return 0.0;
      }
    }
    
    // String validation
    int? maxLength = stringLengthLimits[columnName];
    if (maxLength != null) {
      if (maxLength == -1) {
        return valueStr;
      }
      if (valueStr.length > maxLength) {
        return valueStr.substring(0, maxLength);
      }
    }
    
    // Enum validation
    final enumConfig = enumValidations[columnName];
    if (enumConfig != null) {
      final validValues = enumConfig['valid_values'] as List<String>;
      final caseSensitive = enumConfig['case_sensitive'] as bool? ?? true;
      
      if (!caseSensitive) {
        String lowerValue = valueStr.toLowerCase();
        for (String validValue in validValues) {
          if (validValue.toLowerCase() == lowerValue) {
            return valueStr;
          }
        }
      } else {
        if (validValues.contains(valueStr)) {
          return valueStr;
        }
      }
    }
    
    return valueStr;
  }

  static String _normalizeColumnName(String columnName) {
    return columnName
        .toLowerCase()
        .trim()
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'[^\w]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static String getConfigVersion() {
    return '2.1.0'; // Updated version
  }

  static Map<String, dynamic> getMappingStats() {
    return {
      'psp_field_mappings': pspFieldMapping.length,
      'psp_alternatives': pspAlternativeColumns.length,
      'settlement_columns': settlementColumnMapping.length,
      'settlement_alternatives': settlementAlternativeColumns.length,
      'required_columns': requiredColumns.length,
      'config_version': getConfigVersion(),
      'preserve_original_strings': true,
      'uses_dynamic_defaults': true,
    };
  }
}