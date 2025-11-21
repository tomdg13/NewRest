import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory/config/missing_column_detector.dart';

class ColumnAnalysisDisplayWidget extends StatefulWidget {
  final MissingColumnAnalysis? analysis;
  final String currentTheme;

  const ColumnAnalysisDisplayWidget({
    Key? key,
    required this.analysis,
    required this.currentTheme,
  }) : super(key: key);

  @override
  State<ColumnAnalysisDisplayWidget> createState() => _ColumnAnalysisDisplayWidgetState();
}

class _ColumnAnalysisDisplayWidgetState extends State<ColumnAnalysisDisplayWidget> {
  final TextEditingController _textController = TextEditingController();
  // ignore: unused_field
  bool _showRawReport = false;
  String _selectedView = 'summary'; // summary, missing, found, unmapped, raw

  @override
  void initState() {
    super.initState();
    _updateTextContent();
  }

  @override
  void didUpdateWidget(ColumnAnalysisDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.analysis != widget.analysis) {
      _updateTextContent();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _updateTextContent() {
    if (widget.analysis == null) {
      _textController.text = 'No column analysis available. Upload a file to see column mapping details.';
      return;
    }

    String content = '';
    switch (_selectedView) {
      case 'summary':
        content = _generateSummaryView();
        break;
      case 'missing':
        content = _generateMissingView();
        break;
      case 'found':
        content = _generateFoundView();
        break;
      case 'unmapped':
        content = _generateUnmappedView();
        break;
      case 'raw':
        content = MissingColumnDetector.generateDetailedReport(widget.analysis!);
        break;
    }
    _textController.text = content;
  }

  String _generateSummaryView() {
    final analysis = widget.analysis!;
    StringBuffer content = StringBuffer();
    
    content.writeln('=== COLUMN ANALYSIS SUMMARY ===');
    content.writeln('File Type: ${analysis.fileType.toUpperCase()}');
    content.writeln('Generated: ${DateTime.now().toString().substring(0, 19)}');
    content.writeln('');
    content.writeln('OVERVIEW:');
    content.writeln('• Total Expected Columns: ${analysis.totalExpectedColumns}');
    content.writeln('• Total CSV Columns: ${analysis.totalCsvColumns}');
    content.writeln('• Successfully Mapped: ${analysis.foundColumns.length}');
    content.writeln('• Missing Columns: ${analysis.missingColumns.length}');
    content.writeln('• Required Missing: ${analysis.requiredMissingCount}');
    content.writeln('• Unmapped CSV Columns: ${analysis.unmappedColumns.length}');
    content.writeln('• Mapping Success Rate: ${(analysis.mappingSuccessRate * 100).toStringAsFixed(1)}%');
    content.writeln('');
    
    String status = analysis.canProceed ? 'READY FOR UPLOAD' : 'CANNOT UPLOAD - MISSING REQUIRED COLUMNS';
    content.writeln('STATUS: $status');
    
    if (analysis.requiredMissingCount > 0) {
      content.writeln('');
      content.writeln('CRITICAL ISSUES:');
      var requiredMissing = analysis.missingColumns.where((col) => col.isRequired).toList();
      for (var missing in requiredMissing) {
        content.writeln('• Missing required: ${missing.expectedColumn}');
      }
    }
    
    if (analysis.unmappedColumns.isNotEmpty) {
      content.writeln('');
      content.writeln('UNMAPPED COLUMNS (will be ignored):');
      for (var unmapped in analysis.unmappedColumns.take(10)) {
        content.writeln('• ${unmapped.columnName}');
      }
      if (analysis.unmappedColumns.length > 10) {
        content.writeln('• ... and ${analysis.unmappedColumns.length - 10} more');
      }
    }
    
    return content.toString();
  }

  String _generateMissingView() {
    final analysis = widget.analysis!;
    StringBuffer content = StringBuffer();
    
    content.writeln('=== MISSING COLUMNS DETAILS ===');
    
    var requiredMissing = analysis.missingColumns.where((col) => col.isRequired).toList();
    var optionalMissing = analysis.missingColumns.where((col) => !col.isRequired).toList();
    
    if (requiredMissing.isNotEmpty) {
      content.writeln('REQUIRED MISSING COLUMNS (${requiredMissing.length}):');
      content.writeln('These columns must be added to your CSV file:');
      content.writeln('');
      
      for (var missing in requiredMissing) {
        content.writeln('Column: ${missing.expectedColumn}');
        content.writeln('  API Field: ${missing.apiField}');
        if (missing.suggestions.isNotEmpty) {
          content.writeln('  Similar columns found: ${missing.suggestions.join(', ')}');
        }
        if (missing.alternativeNames.isNotEmpty) {
          content.writeln('  Alternative names: ${missing.alternativeNames.join(', ')}');
        }
        content.writeln('  Fix: Add column "${missing.expectedColumn}" to your CSV');
        content.writeln('');
      }
    }
    
    if (optionalMissing.isNotEmpty) {
      content.writeln('OPTIONAL MISSING COLUMNS (${optionalMissing.length}):');
      content.writeln('These columns are optional and will use default values:');
      content.writeln('');
      
      for (var missing in optionalMissing) {
        content.writeln('Column: ${missing.expectedColumn}');
        content.writeln('  API Field: ${missing.apiField}');
        if (missing.suggestions.isNotEmpty) {
          content.writeln('  Similar columns: ${missing.suggestions.join(', ')}');
        }
        content.writeln('  Status: Will use default value');
        content.writeln('');
      }
    }
    
    if (analysis.missingColumns.isEmpty) {
      content.writeln('No missing columns found!');
      content.writeln('All expected columns are present in your CSV file.');
    }
    
    return content.toString();
  }

  String _generateFoundView() {
    final analysis = widget.analysis!;
    StringBuffer content = StringBuffer();
    
    content.writeln('=== SUCCESSFULLY MAPPED COLUMNS ===');
    content.writeln('Total mapped: ${analysis.foundColumns.length}');
    content.writeln('');
    
    var exactMatches = analysis.foundColumns.where((col) => col.isExactMatch).toList();
    var fuzzyMatches = analysis.foundColumns.where((col) => !col.isExactMatch).toList();
    
    if (exactMatches.isNotEmpty) {
      content.writeln('EXACT MATCHES (${exactMatches.length}):');
      for (var found in exactMatches) {
        content.writeln('✓ ${found.actualColumn} -> ${found.apiField}');
      }
      content.writeln('');
    }
    
    if (fuzzyMatches.isNotEmpty) {
      content.writeln('FUZZY MATCHES (${fuzzyMatches.length}):');
      content.writeln('These columns were matched using similarity detection:');
      for (var found in fuzzyMatches) {
        content.writeln('≈ ${found.actualColumn} -> ${found.apiField}');
        content.writeln('  Expected: ${found.expectedColumn}');
      }
      content.writeln('');
    }
    
    if (analysis.foundColumns.isEmpty) {
      content.writeln('No columns were successfully mapped.');
      content.writeln('Check your CSV headers and column configuration.');
    }
    
    return content.toString();
  }

  String _generateUnmappedView() {
    final analysis = widget.analysis!;
    StringBuffer content = StringBuffer();
    
    content.writeln('=== UNMAPPED CSV COLUMNS ===');
    content.writeln('Total unmapped: ${analysis.unmappedColumns.length}');
    content.writeln('');
    content.writeln('These columns exist in your CSV but are not mapped to any database field.');
    content.writeln('They will be ignored during upload unless you add mappings.');
    content.writeln('');
    
    if (analysis.unmappedColumns.isNotEmpty) {
      for (var unmapped in analysis.unmappedColumns) {
        content.writeln('Column: ${unmapped.columnName}');
        if (unmapped.possibleApiField != null) {
          content.writeln('  Possible match: ${unmapped.possibleApiField}');
          content.writeln('  Suggestion: Add "${unmapped.columnName}" as alternative name for "${unmapped.possibleApiField}"');
        } else {
          content.writeln('  No possible match found');
          content.writeln('  Suggestion: Add new field mapping if this data is needed');
        }
        content.writeln('  Actions: ${unmapped.suggestions.join(' OR ')}');
        content.writeln('');
      }
      
      content.writeln('CONFIGURATION SUGGESTIONS:');
      content.writeln('Add these to SettlementColumn.dart:');
      content.writeln('');
      
      for (var unmapped in analysis.unmappedColumns) {
        if (unmapped.possibleApiField != null) {
          content.writeln('// Add alternative for ${unmapped.possibleApiField}');
          content.writeln("'${unmapped.possibleApiField}': [");
          content.writeln("  '${unmapped.columnName}',  // Found in your CSV");
          content.writeln("],");
        } else {
          content.writeln('// Add new field mapping');
          content.writeln("'new_field_name': '${unmapped.columnName}',");
        }
        content.writeln('');
      }
    } else {
      content.writeln('All CSV columns are successfully mapped!');
      content.writeln('No unmapped columns found.');
    }
    
    return content.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.analysis == null) {
      return SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with view selector
            Row(
              children: [
                Icon(Icons.analytics, color: Theme.of(context).primaryColor),
                SizedBox(width: 12),
                Text(
                  'Column Analysis Report',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                Spacer(),
                _buildStatusChip(),
              ],
            ),
            SizedBox(height: 16),
            
            // View selector tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildViewTab('summary', 'Summary', Icons.summarize),
                  _buildViewTab('missing', 'Missing (${widget.analysis!.missingColumns.length})', Icons.error_outline),
                  _buildViewTab('found', 'Found (${widget.analysis!.foundColumns.length})', Icons.check_circle_outline),
                  _buildViewTab('unmapped', 'Unmapped (${widget.analysis!.unmappedColumns.length})', Icons.help_outline),
                  _buildViewTab('raw', 'Raw Report', Icons.code),
                ],
              ),
            ),
            SizedBox(height: 16),
            
            // Text field with content
            Container(
              height: 400,
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                readOnly: true,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
            SizedBox(height: 12),
            
            // Action buttons
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _textController.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Analysis copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: Icon(Icons.copy),
                  label: Text('Copy to Clipboard'),
                ),
                SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _updateTextContent();
                    });
                  },
                  icon: Icon(Icons.refresh),
                  label: Text('Refresh'),
                ),
                Spacer(),
                Text(
                  'Lines: ${_textController.text.split('\n').length}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color = widget.analysis!.canProceed ? Colors.green : Colors.red;
    String text = widget.analysis!.canProceed ? 'Ready' : 'Issues Found';
    IconData icon = widget.analysis!.canProceed ? Icons.check_circle : Icons.error;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewTab(String value, String label, IconData icon) {
    bool isSelected = _selectedView == value;
    
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedView = value;
              _updateTextContent();
            });
          }
        },
        avatar: Icon(
          icon,
          size: 16,
          color: isSelected ? Colors.white : Theme.of(context).primaryColor,
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Theme.of(context).primaryColor,
          ),
        ),
        selectedColor: Theme.of(context).primaryColor,
        checkmarkColor: Colors.white,
      ),
    );
  }
}