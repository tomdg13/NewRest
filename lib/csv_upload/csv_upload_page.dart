import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // Added missing import

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;

class CSVUploadPage extends StatefulWidget {
  final String apiType;

  /// apiType can be "acquirer-settlement" or "settlement-summary"
  const CSVUploadPage({super.key, this.apiType = "acquirer-settlement"});

  @override
  State<CSVUploadPage> createState() => _CSVUploadPageState();
}

class _CSVUploadPageState extends State<CSVUploadPage> {
  List<List<dynamic>> _csvData = [];
  bool _loading = false;
  String? _statusMessage;
  String? _fileName;
  int? _fileSize;
  int? _rowCount;

  Future<void> _pickAndParseCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return; // User canceled
      }

      PlatformFile file = result.files.first;
      
      // Validate file
      if (file.size == 0) {
        setState(() {
          _statusMessage = "⚠️ Selected file is empty";
        });
        return;
      }

      if (file.size > 10 * 1024 * 1024) { // 10MB limit
        setState(() {
          _statusMessage = "⚠️ File too large (max 10MB)";
        });
        return;
      }

      if (file.path == null) {
        // For web or some platforms, path might be null
        if (file.bytes != null) {
          await _parseCSVFromBytes(file.bytes!);
        } else {
          setState(() {
            _statusMessage = "⚠️ Could not read file";
          });
          return;
        }
      } else {
        await _parseCSVFromFile(File(file.path!));
      }

      setState(() {
        _fileName = file.name;
        _fileSize = file.size;
        _rowCount = _csvData.isNotEmpty ? _csvData.length - 1 : 0; // Exclude header
        _statusMessage = null;
      });

    } catch (e) {
      setState(() {
        _statusMessage = "❌ Error reading file: $e";
        _csvData.clear();
        _fileName = null;
        _fileSize = null;
        _rowCount = null;
      });
    }
  }

  Future<void> _parseCSVFromFile(File file) async {
    final input = file.openRead();
    final fields = await input
        .transform(utf8.decoder)
        .transform(const CsvToListConverter())
        .toList();
    
    setState(() {
      _csvData = fields;
    });
  }

  Future<void> _parseCSVFromBytes(Uint8List bytes) async {
    final String csvString = utf8.decode(bytes);
    final List<List<dynamic>> fields = const CsvToListConverter().convert(csvString);
    
    setState(() {
      _csvData = fields;
    });
  }

  Future<void> _uploadCSV() async {
    if (_csvData.isEmpty) {
      setState(() {
        _statusMessage = "⚠️ Please pick a CSV file first.";
      });
      return;
    }

    // Validate CSV structure
    if (_csvData.length < 2) {
      setState(() {
        _statusMessage = "⚠️ CSV file must contain at least a header and one data row";
      });
      return;
    }

    setState(() {
      _loading = true;
      _statusMessage = null;
    });

    try {
      // First row is header
      final headers = _csvData.first.map((h) => h.toString().trim()).toList();
      final dataRows = _csvData.skip(1);

      // Validate headers are not empty
      if (headers.any((header) => header.isEmpty)) {
        throw Exception("CSV headers cannot be empty");
      }

      final jsonData = dataRows.map((row) {
        final map = <String, dynamic>{};
        for (int i = 0; i < headers.length; i++) {
          final value = i < row.length ? row[i] : '';
          map[headers[i]] = value.toString().trim();
        }
        return map;
      }).toList();

      // Use your actual API endpoint - remove localhost for production
      final url = Uri.parse(
          "https://your-api-domain.com/api/payment-system/${widget.apiType}/import-csv");

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          // Add authentication if needed:
          // "Authorization": "Bearer your_token",
        },
        body: jsonEncode({
          "csvData": jsonData,
          "fileName": _fileName,
          "uploadedAt": DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _statusMessage = "✅ Upload successful!${responseData['message'] != null ? '\n${responseData['message']}' : ''}";
        });
      } else {
        String errorMessage = "Upload failed: ${response.statusCode}";
        try {
          final errorData = jsonDecode(response.body);
          errorMessage += " - ${errorData['message'] ?? errorData['error'] ?? response.body}";
        } catch (_) {
          errorMessage += " - ${response.body}";
        }
        setState(() {
          _statusMessage = "❌ $errorMessage";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "❌ Error: ${e.toString()}";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _clearData() {
    setState(() {
      _csvData.clear();
      _fileName = null;
      _fileSize = null;
      _rowCount = null;
      _statusMessage = null;
    });
  }

  Widget _buildFileInfo() {
    if (_fileName == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📄 File: $_fileName', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (_fileSize != null) Text('📊 Size: ${(_fileSize! / 1024).toStringAsFixed(2)} KB'),
            if (_rowCount != null) Text('📈 Rows: $_rowCount'),
          ],
        ),
      ),
    );
  }

  Widget _buildCSVPreview() {
    if (_csvData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Column(
            children: [
              Icon(Icons.insert_drive_file, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text("No CSV file loaded", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text("Preview (${_csvData.length} rows):", 
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Card(
              child: ListView.builder(
                itemCount: _csvData.length,
                itemBuilder: (context, index) {
                  final isHeader = index == 0;
                  return Container(
                    decoration: BoxDecoration(
                      color: isHeader ? Colors.blue[50] : null,
                      border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                    ),
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _csvData[index].join(", "),
                      style: TextStyle(
                        fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                        color: isHeader ? Colors.blue[700] : Colors.black87,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: Text("CSV Upload - ${widget.apiType.replaceAll('-', ' ').titleCase()}"),
        actions: [
          if (_csvData.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearData,
              tooltip: 'Clear data',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // File selection button
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text("Select CSV File"),
              onPressed: _loading ? null : _pickAndParseCSV,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // File information
            _buildFileInfo(),
            
            const SizedBox(height: 16),
            
            // CSV Preview
            _buildCSVPreview(),
            
            const SizedBox(height: 16),
            
            // Status message
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusMessage!.contains("✅") 
                      ? Colors.green[50] 
                      : Colors.red[50],
                  border: Border.all(
                    color: _statusMessage!.contains("✅")
                        ? Colors.green
                        : Colors.red,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _statusMessage!.contains("✅")
                        ? Colors.green[800]
                        : Colors.red[800],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Upload button
            ElevatedButton(
              onPressed: _loading ? null : _uploadCSV,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _loading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text("Uploading..."),
                      ],
                    )
                  : const Text("Upload CSV", style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// Extension for string title case formatting
extension StringExtension on String {
  String get titleCase {
    if (isEmpty) return this;
    return split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}