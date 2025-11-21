import 'package:inventory/config/settlement_column.dart';

class MissingColumnDetector {
  static const String VERSION = '1.0.0';

  /// Detailed analysis of missing columns with suggestions
  static MissingColumnAnalysis analyzeMissingColumns(
    List<String> csvHeaders, 
    String fileType
  ) {
    print('=== MISSING COLUMN ANALYSIS ===');
    print('File Type: $fileType');
    print('CSV Headers: ${csvHeaders.length}');
    print('Headers: $csvHeaders');
    print('');

    if (fileType == 'psp') {
      return _analyzePSPColumns(csvHeaders);
    } else {
      return _analyzeSettlementColumns(csvHeaders);
    }
  }

  static MissingColumnAnalysis _analyzePSPColumns(List<String> csvHeaders) {
    List<MissingColumnDetail> missingColumns = [];
    List<MappedColumnDetail> foundColumns = [];
    List<UnmappedColumnDetail> unmappedColumns = [];
    
    // Check each expected PSP field
    for (String apiField in SettlementColumn.pspFieldMapping.keys) {
      String expectedColumn = SettlementColumn.pspFieldMapping[apiField]!;
      if (expectedColumn.isEmpty) continue;
      
      String? foundColumn = SettlementColumn.findPSPColumn(csvHeaders, expectedColumn);
      
      if (foundColumn != null) {
        foundColumns.add(MappedColumnDetail(
          apiField: apiField,
          expectedColumn: expectedColumn,
          actualColumn: foundColumn,
          isExactMatch: foundColumn == expectedColumn,
        ));
      } else {
        // Get suggestions for missing column
        List<String> suggestions = _getSuggestionsForColumn(csvHeaders, expectedColumn);
        bool isRequired = SettlementColumn.requiredColumns.contains(apiField);
        
        missingColumns.add(MissingColumnDetail(
          apiField: apiField,
          expectedColumn: expectedColumn,
          isRequired: isRequired,
          suggestions: suggestions,
          alternativeNames: SettlementColumn.pspAlternativeColumns[expectedColumn] ?? [],
        ));
      }
    }
    
    // Check for unmapped columns in CSV
    for (String header in csvHeaders) {
      bool isMapped = foundColumns.any((col) => col.actualColumn == header);
      if (!isMapped) {
        String? possibleApiField = _findPossibleApiField(header, 'psp');
        unmappedColumns.add(UnmappedColumnDetail(
          columnName: header,
          possibleApiField: possibleApiField,
          suggestions: _getSuggestionsForUnmappedColumn(header, 'psp'),
        ));
      }
    }
    
    return MissingColumnAnalysis(
      fileType: 'psp',
      totalExpectedColumns: SettlementColumn.pspFieldMapping.values.where((v) => v.isNotEmpty).length,
      totalCsvColumns: csvHeaders.length,
      foundColumns: foundColumns,
      missingColumns: missingColumns,
      unmappedColumns: unmappedColumns,
      requiredMissingCount: missingColumns.where((col) => col.isRequired).length,
    );
  }

  static MissingColumnAnalysis _analyzeSettlementColumns(List<String> csvHeaders) {
    List<MissingColumnDetail> missingColumns = [];
    List<MappedColumnDetail> foundColumns = [];
    List<UnmappedColumnDetail> unmappedColumns = [];
    
    Map<String, String> headerToApiField = SettlementColumn.createHeaderMapping(csvHeaders);
    
    // Check each expected settlement field
    for (String apiField in SettlementColumn.settlementColumnMapping.keys) {
      String expectedColumn = SettlementColumn.settlementColumnMapping[apiField]!;
      
      String? foundHeader;
      for (String header in csvHeaders) {
        if (headerToApiField[header] == apiField) {
          foundHeader = header;
          break;
        }
      }
      
      if (foundHeader != null) {
        foundColumns.add(MappedColumnDetail(
          apiField: apiField,
          expectedColumn: expectedColumn,
          actualColumn: foundHeader,
          isExactMatch: foundHeader == expectedColumn,
        ));
      } else {
        List<String> suggestions = _getSuggestionsForColumn(csvHeaders, expectedColumn);
        bool isRequired = SettlementColumn.requiredColumns.contains(apiField);
        
        missingColumns.add(MissingColumnDetail(
          apiField: apiField,
          expectedColumn: expectedColumn,
          isRequired: isRequired,
          suggestions: suggestions,
          alternativeNames: [],
        ));
      }
    }
    
    // Check for unmapped columns
    for (String header in csvHeaders) {
      if (!headerToApiField.containsKey(header)) {
        String? possibleApiField = _findPossibleApiField(header, 'settlement');
        unmappedColumns.add(UnmappedColumnDetail(
          columnName: header,
          possibleApiField: possibleApiField,
          suggestions: _getSuggestionsForUnmappedColumn(header, 'settlement'),
        ));
      }
    }
    
    return MissingColumnAnalysis(
      fileType: 'settlement',
      totalExpectedColumns: SettlementColumn.settlementColumnMapping.length,
      totalCsvColumns: csvHeaders.length,
      foundColumns: foundColumns,
      missingColumns: missingColumns,
      unmappedColumns: unmappedColumns,
      requiredMissingCount: missingColumns.where((col) => col.isRequired).length,
    );
  }

  static List<String> _getSuggestionsForColumn(List<String> csvHeaders, String expectedColumn) {
    List<String> suggestions = [];
    String normalizedExpected = _normalizeForComparison(expectedColumn);
    
    for (String header in csvHeaders) {
      String normalizedHeader = _normalizeForComparison(header);
      double similarity = _calculateSimilarity(normalizedExpected, normalizedHeader);
      
      if (similarity > 0.6) { // 60% similarity threshold
        suggestions.add(header);
      }
    }
    
    // Sort by similarity
    suggestions.sort((a, b) {
      double simA = _calculateSimilarity(normalizedExpected, _normalizeForComparison(a));
      double simB = _calculateSimilarity(normalizedExpected, _normalizeForComparison(b));
      return simB.compareTo(simA);
    });
    
    return suggestions.take(3).toList(); // Top 3 suggestions
  }

  static String? _findPossibleApiField(String columnName, String fileType) {
    String normalized = _normalizeForComparison(columnName);
    
    Map<String, String> mappings = fileType == 'psp' 
        ? SettlementColumn.pspFieldMapping 
        : SettlementColumn.settlementColumnMapping;
    
    String? bestMatch;
    double bestSimilarity = 0.0;
    
    for (String apiField in mappings.keys) {
      String expectedColumn = mappings[apiField]!;
      if (expectedColumn.isEmpty) continue;
      
      double similarity = _calculateSimilarity(normalized, _normalizeForComparison(expectedColumn));
      if (similarity > bestSimilarity && similarity > 0.7) {
        bestSimilarity = similarity;
        bestMatch = apiField;
      }
    }
    
    return bestMatch;
  }

  static List<String> _getSuggestionsForUnmappedColumn(String columnName, String fileType) {
    // Suggest possible configuration updates
    List<String> suggestions = [];
    
    if (fileType == 'psp') {
      suggestions.add('Add to pspAlternativeColumns mapping');
      suggestions.add('Add new field to pspFieldMapping');
    } else {
      suggestions.add('Add to settlementColumnMapping');
      suggestions.add('Update column header format');
    }
    
    return suggestions;
  }

  static String _normalizeForComparison(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }

  static double _calculateSimilarity(String str1, String str2) {
    if (str1 == str2) return 1.0;
    if (str1.isEmpty || str2.isEmpty) return 0.0;
    
    // Simple similarity calculation based on common characters and length
    Set<String> chars1 = str1.split('').toSet();
    Set<String> chars2 = str2.split('').toSet();
    
    int commonChars = chars1.intersection(chars2).length;
    int totalChars = chars1.union(chars2).length;
    
    double charSimilarity = commonChars / totalChars;
    
    // Also consider substring matching
    double substringBonus = 0.0;
    if (str1.contains(str2) || str2.contains(str1)) {
      substringBonus = 0.3;
    }
    
    return (charSimilarity + substringBonus).clamp(0.0, 1.0);
  }

  /// Generate detailed report for missing columns
  static String generateDetailedReport(MissingColumnAnalysis analysis) {
    StringBuffer report = StringBuffer();
    
    report.writeln('=== MISSING COLUMN DETAILED REPORT ===');
    report.writeln('File Type: ${analysis.fileType.toUpperCase()}');
    report.writeln('Configuration Version: ${SettlementColumn.getConfigVersion()}');
    report.writeln('Analysis Version: $VERSION');
    report.writeln('Generated: ${DateTime.now().toIso8601String()}');
    report.writeln('');
    
    report.writeln('SUMMARY:');
    report.writeln('Total Expected Columns: ${analysis.totalExpectedColumns}');
    report.writeln('Total CSV Columns: ${analysis.totalCsvColumns}');
    report.writeln('Successfully Mapped: ${analysis.foundColumns.length}');
    report.writeln('Missing Columns: ${analysis.missingColumns.length}');
    report.writeln('Required Missing: ${analysis.requiredMissingCount}');
    report.writeln('Unmapped CSV Columns: ${analysis.unmappedColumns.length}');
    report.writeln('Mapping Success Rate: ${(analysis.foundColumns.length / analysis.totalExpectedColumns * 100).toStringAsFixed(1)}%');
    report.writeln('');
    
    // Required missing columns (critical)
    var requiredMissing = analysis.missingColumns.where((col) => col.isRequired).toList();
    if (requiredMissing.isNotEmpty) {
      report.writeln('🔴 CRITICAL - REQUIRED MISSING COLUMNS:');
      for (var missing in requiredMissing) {
        report.writeln('  ❌ ${missing.expectedColumn}');
        report.writeln('     API Field: ${missing.apiField}');
        if (missing.suggestions.isNotEmpty) {
          report.writeln('     Similar columns found: ${missing.suggestions.join(', ')}');
        }
        if (missing.alternativeNames.isNotEmpty) {
          report.writeln('     Alternative names: ${missing.alternativeNames.join(', ')}');
        }
        report.writeln('     🔧 Fix: Add column "${missing.expectedColumn}" to your CSV');
        report.writeln('');
      }
    }
    
    // Optional missing columns
    var optionalMissing = analysis.missingColumns.where((col) => !col.isRequired).toList();
    if (optionalMissing.isNotEmpty) {
      report.writeln('🟡 OPTIONAL MISSING COLUMNS:');
      for (var missing in optionalMissing) {
        report.writeln('  ⚠️  ${missing.expectedColumn}');
        report.writeln('     API Field: ${missing.apiField}');
        if (missing.suggestions.isNotEmpty) {
          report.writeln('     Similar columns: ${missing.suggestions.join(', ')}');
        }
        report.writeln('     🔧 Fix: Optional - will use default value');
        report.writeln('');
      }
    }
    
    // Successfully mapped columns
    if (analysis.foundColumns.isNotEmpty) {
      report.writeln('✅ SUCCESSFULLY MAPPED COLUMNS:');
      for (var found in analysis.foundColumns) {
        String matchType = found.isExactMatch ? 'EXACT' : 'FUZZY';
        report.writeln('  ✓ ${found.actualColumn} -> ${found.apiField} [$matchType]');
      }
      report.writeln('');
    }
    
    // Unmapped CSV columns
    if (analysis.unmappedColumns.isNotEmpty) {
      report.writeln('🔵 UNMAPPED CSV COLUMNS:');
      for (var unmapped in analysis.unmappedColumns) {
        report.writeln('  ❓ ${unmapped.columnName}');
        if (unmapped.possibleApiField != null) {
          report.writeln('     Possible match: ${unmapped.possibleApiField}');
        }
        report.writeln('     🔧 Action: ${unmapped.suggestions.join(' OR ')}');
        report.writeln('');
      }
    }
    
    // Configuration suggestions
    report.writeln('🛠️  CONFIGURATION UPDATE SUGGESTIONS:');
    if (analysis.fileType == 'psp') {
      report.writeln('To fix missing PSP columns, update SettlementColumn.dart:');
      report.writeln('');
      for (var missing in analysis.missingColumns) {
        if (missing.suggestions.isNotEmpty) {
          report.writeln('// Add alternative for ${missing.expectedColumn}');
          report.writeln("'${missing.expectedColumn}': [");
          for (var suggestion in missing.suggestions) {
            report.writeln("  '$suggestion',");
          }
          report.writeln("],");
          report.writeln('');
        }
      }
    } else {
      report.writeln('To fix missing Settlement columns:');
      report.writeln('1. Check CSV headers match expected format');
      report.writeln('2. Update SettlementColumn.settlementColumnMapping if needed');
      report.writeln('3. Ensure all required columns are present');
    }
    
    report.writeln('=== END REPORT ===');
    
    return report.toString();
  }

  /// Generate quick summary for UI display
  static String generateQuickSummary(MissingColumnAnalysis analysis) {
    int mappingPercentage = (analysis.foundColumns.length / analysis.totalExpectedColumns * 100).round();
    
    String status = analysis.requiredMissingCount == 0 ? '✅ Ready' : '❌ Missing Required';
    
    return 'Column Mapping: $mappingPercentage% ($status)\n'
           'Found: ${analysis.foundColumns.length}/${analysis.totalExpectedColumns}\n'
           'Required Missing: ${analysis.requiredMissingCount}\n'
           'Unmapped: ${analysis.unmappedColumns.length}';
  }
}

// Data classes for analysis results
class MissingColumnAnalysis {
  final String fileType;
  final int totalExpectedColumns;
  final int totalCsvColumns;
  final List<MappedColumnDetail> foundColumns;
  final List<MissingColumnDetail> missingColumns;
  final List<UnmappedColumnDetail> unmappedColumns;
  final int requiredMissingCount;

  MissingColumnAnalysis({
    required this.fileType,
    required this.totalExpectedColumns,
    required this.totalCsvColumns,
    required this.foundColumns,
    required this.missingColumns,
    required this.unmappedColumns,
    required this.requiredMissingCount,
  });

  bool get canProceed => requiredMissingCount == 0;
  double get mappingSuccessRate => foundColumns.length / totalExpectedColumns;
}

class MissingColumnDetail {
  final String apiField;
  final String expectedColumn;
  final bool isRequired;
  final List<String> suggestions;
  final List<String> alternativeNames;

  MissingColumnDetail({
    required this.apiField,
    required this.expectedColumn,
    required this.isRequired,
    required this.suggestions,
    required this.alternativeNames,
  });
}

class MappedColumnDetail {
  final String apiField;
  final String expectedColumn;
  final String actualColumn;
  final bool isExactMatch;

  MappedColumnDetail({
    required this.apiField,
    required this.expectedColumn,
    required this.actualColumn,
    required this.isExactMatch,
  });
}

class UnmappedColumnDetail {
  final String columnName;
  final String? possibleApiField;
  final List<String> suggestions;

  UnmappedColumnDetail({
    required this.columnName,
    this.possibleApiField,
    required this.suggestions,
  });
}