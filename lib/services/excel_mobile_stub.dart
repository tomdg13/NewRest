// lib/services/excel_mobile_stub.dart
import 'dart:typed_data';

/// Stub implementation for mobile platforms
/// This file is imported on mobile and provides a stub for web-only functions
Future<void> downloadExcelOnWeb(Uint8List excelData, String filename) async {
  throw Exception('Web download not available on mobile platforms');
}