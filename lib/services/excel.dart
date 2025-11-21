// lib/services/excel.dart
import 'package:excel/excel.dart';
import 'package:inventory/models/terminal_models.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class ExcelService {
  
  static Future<Uint8List> createTerminalReport({
    required List<Map<String, dynamic>> terminalDetails,
    required List<Terminal> selectedTerminals,
  }) async {
    final excel = Excel.createExcel();
    
    // Remove default sheet and create our custom sheets
    excel.delete('Sheet1');
    
    // Create Organization Summary sheet
    final orgSheet = excel['Organization Summary'];
    
    // Create Terminals sheet
    final terminalsSheet = excel['Terminals'];
    
    // Build Organization Summary sheet
    if (terminalDetails.isNotEmpty) {
      _buildOrganizationSheet(orgSheet, terminalDetails.first);
    }
    
    // Build Terminals sheet
    if (terminalDetails.isNotEmpty) {
      _buildTerminalsSheet(terminalsSheet, terminalDetails);
    } else {
      _buildBasicTerminalsSheet(terminalsSheet, selectedTerminals);
    }
    
    return Uint8List.fromList(excel.encode()!);
  }

  static void _buildOrganizationSheet(Sheet sheet, Map<String, dynamic> data) {
    // Header styling
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.orange,
      fontColorHex: ExcelColor.white,
      bold: true,
      fontSize: 14,
    );
    
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 12,
      backgroundColorHex: ExcelColor.grey,
    );
    
    final dataStyle = CellStyle(fontSize: 11);
    
    // Report title
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('TERMINAL BULK PROCESS REPORT');
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = headerStyle;
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('E1'));
    
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue('Generated: ${DateTime.now().toString().substring(0, 19)}');
    sheet.cell(CellIndex.indexByString('A2')).cellStyle = dataStyle;
    
    int row = 4;
    
    // Group Information
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('GROUP INFORMATION');
    sheet.cell(CellIndex.indexByString('A$row')).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A$row'), CellIndex.indexByString('B$row'));
    row++;
    
    _addExcelRow(sheet, row++, 'Code:', data['group_code'] ?? 'N/A');
    _addExcelRow(sheet, row++, 'Name:', data['group_name'] ?? 'N/A');
    _addExcelRow(sheet, row++, 'Phone:', data['group_phone'] ?? 'N/A');
    _addExcelRow(sheet, row++, 'Created:', _formatDate(data['group_created_date']));
    row++;
    
    // Merchant Information
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('MERCHANT INFORMATION');
    sheet.cell(CellIndex.indexByString('A$row')).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A$row'), CellIndex.indexByString('B$row'));
    row++;
    
    _addExcelRow(sheet, row++, 'Code:', data['merchant_code'] ?? 'N/A');
    _addExcelRow(sheet, row++, 'Name:', data['merchant_name'] ?? 'N/A');
    _addExcelRow(sheet, row++, 'Phone:', data['merchant_phone'] ?? 'N/A');
    row++;
    
    // Store Information
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('STORE INFORMATION');
    sheet.cell(CellIndex.indexByString('A$row')).cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A$row'), CellIndex.indexByString('B$row'));
    row++;
    
    _addExcelRow(sheet, row++, 'Code:', data['store_code'] ?? 'N/A');
    _addExcelRow(sheet, row++, 'Name:', data['store_name'] ?? 'N/A');
    _addExcelRow(sheet, row++, 'Manager:', data['store_manager'] ?? 'N/A');
    _addExcelRow(sheet, row++, 'Email:', data['store_email'] ?? 'N/A');
    _addExcelRow(sheet, row++, 'Phone:', data['store_phone'] ?? 'N/A');
    _addExcelRow(sheet, row++, 'Created:', _formatDate(data['store_created_date']));
    _addExcelRow(sheet, row++, 'UPI Percentage:', '${data['upi_percentage'] ?? '0.00'}%');
    _addExcelRow(sheet, row++, 'Visa Percentage:', '${data['visa_percentage'] ?? '0.00'}%');
    _addExcelRow(sheet, row++, 'Master Percentage:', '${data['master_percentage'] ?? '0.00'}%');
    _addExcelRow(sheet, row++, 'Account:', data['store_account'] ?? 'N/A');
    
    // Auto-fit columns
    sheet.setColumnAutoFit(0);
    sheet.setColumnAutoFit(1);
  }

  static void _buildTerminalsSheet(Sheet sheet, List<Map<String, dynamic>> terminals) {
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.orange,
      fontColorHex: ExcelColor.white,
      bold: true,
      fontSize: 12,
    );
    
    final dataStyle = CellStyle(fontSize: 10);
    final centerStyle = CellStyle(fontSize: 10, horizontalAlign: HorizontalAlign.Center);
    final codeStyle = CellStyle(
      fontSize: 10,
      backgroundColorHex: ExcelColor.lightBlue,
      fontColorHex: ExcelColor.blue,
    );
    final statusStyle = CellStyle(
      fontSize: 10,
      backgroundColorHex: ExcelColor.lightGreen,
      fontColorHex: ExcelColor.green,
    );
    
    // Headers
    final headers = ['#', 'Terminal Name', 'Code', 'Terminal ID', 'Company ID', 'Store ID', 'Status', 'Hierarchy Path'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    // Data rows
    for (int i = 0; i < terminals.length; i++) {
      final terminal = terminals[i];
      final row = i + 1;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        IntCellValue(i + 1);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = centerStyle;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = 
        TextCellValue(terminal['terminal_name'] ?? 'N/A');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).cellStyle = dataStyle;
      
      final codeCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
      codeCell.value = TextCellValue(terminal['terminal_code'] ?? 'N/A');
      codeCell.cellStyle = terminal['terminal_code'] != null ? codeStyle : dataStyle;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = 
        IntCellValue(terminal['terminal_id'] ?? 0);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).cellStyle = dataStyle;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = 
        IntCellValue(terminal['company_id'] ?? 0);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).cellStyle = dataStyle;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = 
        IntCellValue(terminal['store_id'] ?? 0);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).cellStyle = dataStyle;
      
      final statusCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row));
      statusCell.value = TextCellValue('Active');
      statusCell.cellStyle = statusStyle;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = 
        TextCellValue(terminal['hierarchy_path'] ?? 'N/A');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).cellStyle = dataStyle;
    }
    
    // Auto-fit all columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnAutoFit(i);
    }
  }

  static void _buildBasicTerminalsSheet(Sheet sheet, List<Terminal> terminals) {
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.orange,
      fontColorHex: ExcelColor.white,
      bold: true,
      fontSize: 12,
    );
    
    final dataStyle = CellStyle(fontSize: 10);
    final centerStyle = CellStyle(fontSize: 10, horizontalAlign: HorizontalAlign.Center);
    final statusStyle = CellStyle(
      fontSize: 10,
      backgroundColorHex: ExcelColor.lightGreen,
      fontColorHex: ExcelColor.green,
    );
    
    // Headers
    final headers = ['#', 'Terminal Name', 'Code', 'Terminal ID', 'Company ID', 'Store ID', 'Status'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }
    
    // Data rows
    for (int i = 0; i < terminals.length; i++) {
      final terminal = terminals[i];
      final row = i + 1;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = 
        IntCellValue(i + 1);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).cellStyle = centerStyle;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = 
        TextCellValue(terminal.terminalName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).cellStyle = dataStyle;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = 
        TextCellValue(terminal.terminalCode ?? 'N/A');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).cellStyle = dataStyle;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = 
        IntCellValue(terminal.terminalId);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).cellStyle = dataStyle;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = 
        IntCellValue(terminal.companyId);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).cellStyle = dataStyle;
      
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = 
        IntCellValue(terminal.storeId);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).cellStyle = dataStyle;
      
      final statusCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row));
      statusCell.value = TextCellValue('Active');
      statusCell.cellStyle = statusStyle;
    }
    
    // Auto-fit all columns
    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnAutoFit(i);
    }
  }

  static void _addExcelRow(Sheet sheet, int row, String label, String value) {
    final labelStyle = CellStyle(bold: true, fontSize: 11);
    final valueStyle = CellStyle(fontSize: 11);
    
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(label);
    sheet.cell(CellIndex.indexByString('A$row')).cellStyle = labelStyle;
    
    sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(value);
    sheet.cell(CellIndex.indexByString('B$row')).cellStyle = valueStyle;
  }

  static String _formatDate(dynamic dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString.toString();
    }
  }

  /// Downloads Excel file - works on both mobile and web platforms
  static Future<void> downloadExcelFile(Uint8List excelData, {String? filename}) async {
    final name = filename ?? 'Terminal_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    
    if (kIsWeb) {
      // Web platform
      await _downloadOnWeb(excelData, name);
    } else {
      // Mobile platforms (Android/iOS)
      await _downloadOnMobile(excelData, name);
    }
  }

  /// Mobile download implementation
  static Future<void> _downloadOnMobile(Uint8List excelData, String filename) async {
    try {
      // Get the application documents directory
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');
      
      // Write the Excel data to file
      await file.writeAsBytes(excelData);
      
      // Share the file with other apps
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Terminal Report Excel File',
        subject: 'Terminal Report',
      );
      
      if (kDebugMode) {
        print('Excel file saved and shared: ${file.path}');
      }
    } catch (e) {
      throw Exception('Failed to save/share file on mobile: $e');
    }
  }

  /// Web download implementation using universal_html
  static Future<void> _downloadOnWeb(Uint8List excelData, String filename) async {
    try {
      final blob = html.Blob([excelData]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';
      
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
      
      if (kDebugMode) {
        print('Excel file downloaded on web: $filename');
      }
    } catch (e) {
      throw Exception('Failed to download file on web: $e');
    }
  }
}