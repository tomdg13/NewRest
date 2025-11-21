import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'TerminalAddPage.dart';
import 'TerminalEditPage.dart';
import 'TerminalPdfPage.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'dart:io';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({Key? key}) : super(key: key);

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

String langCode = 'en';

class _TerminalPageState extends State<TerminalPage> {
  List<IoTerminal> terminals = [];
  List<IoTerminal> filteredTerminals = [];
  bool loading = true;
  String? error;
  String currentTheme = ThemeConfig.defaultTheme;
  
  // Track downloading state for each terminal
  Map<int, bool> downloadingTerminals = {};

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('TerminalPage initState() called');
    debugPrint('Language code: $langCode');

    _loadLangCode();
    _loadCurrentTheme();
    fetchTerminals();
    
    _searchController.addListener(() {
      print('Search query: ${_searchController.text}');
      filterTerminals(_searchController.text);
    });
  }

  void _loadLangCode() async {
    print('Loading language code...');
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCode = prefs.getString('languageCode') ?? 'en';
      print('Language code loaded: $langCode');
    });
  }

  void _loadCurrentTheme() async {
    print('Loading current theme...');
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
      print('Theme loaded: $currentTheme');
    });
  }

  @override
  void dispose() {
    print('TerminalPage dispose() called');
    _searchController.dispose();
    super.dispose();
  }

  void filterTerminals(String query) {
    print('Filtering terminals with query: "$query"');
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredTerminals = terminals.where((terminal) {
        final nameLower = terminal.terminalName.toLowerCase();
        final codeLower = terminal.terminalCode?.toLowerCase() ?? '';
        final phoneLower = terminal.phone?.toLowerCase() ?? '';
        bool matches = nameLower.contains(lowerQuery) || 
                      codeLower.contains(lowerQuery) || 
                      phoneLower.contains(lowerQuery);
        return matches;
      }).toList();
      print('Filtered terminals count: ${filteredTerminals.length}');
    });
  }

  Future<void> fetchTerminals() async {
    print('Starting fetchTerminals()');
    
    if (!mounted) {
      print('Widget not mounted, aborting fetchTerminals()');
      return;
    }
    
    setState(() {
      loading = true;
      error = null;
    });

    final url = AppConfig.api('/api/ioterminal');
    print('API URL: $url');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      print('Token: ${token != null ? '${token.substring(0, 20)}...' : 'null'}');
      print('Company ID: $companyId');
      
      final queryParams = {
        'company_id': companyId.toString(),
      };
      
      final uri = Uri.parse(url.toString()).replace(queryParameters: queryParams);
      print('Full URI: $uri');
      
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      
      final response = await http.get(uri, headers: headers);

      print('Response Status Code: ${response.statusCode}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          print('Parsed JSON successfully');
          
          if (data['status'] == 'success') {
            final List<dynamic> rawTerminals = data['data'] ?? [];
            print('Raw terminals count: ${rawTerminals.length}');
            
            if (rawTerminals.isNotEmpty) {
              print('First terminal data: ${rawTerminals[0]}');
            }
            
            terminals = rawTerminals.map((e) {
              try {
                return IoTerminal.fromJson(e);
              } catch (parseError) {
                print('Error parsing terminal: $parseError');
                rethrow;
              }
            }).toList();
            
            filteredTerminals = List.from(terminals);
            
            print('Total terminals loaded: ${terminals.length}');
            
            setState(() => loading = false);
          } else {
            setState(() {
              loading = false;
              error = data['message'] ?? 'Unknown error from API';
            });
          }
        } catch (jsonError) {
          print('JSON parsing error: $jsonError');
          setState(() {
            loading = false;
            error = 'Failed to parse server response: $jsonError';
          });
        }
      } else {
        setState(() {
          loading = false;
          error = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e, stackTrace) {
      print('Exception caught: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        loading = false;
        error = 'Failed to load data: $e';
      });
    }
  }

  // Helper method to format expire date
  String _formatExpireDate(dynamic expireDate) {
    if (expireDate == null) return 'N/A';
    
    try {
      final date = DateTime.parse(expireDate.toString());
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  // Download PDF function
  Future<void> _downloadPdf(IoTerminal terminal) async {
    if (terminal.pdfUrl == null || terminal.pdfUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info, color: Colors.white),
              SizedBox(width: 8),
              Text('No PDF available for this terminal'),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      downloadingTerminals[terminal.terminalId] = true;
    });

    try {
      if (kIsWeb) {
        // For web, open in new tab
        final Uri url = Uri.parse(terminal.pdfUrl!);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('PDF opened in new tab'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // For mobile, download the file
        final response = await http.get(Uri.parse(terminal.pdfUrl!));
        
        if (response.statusCode == 200) {
          Directory? directory;
          if (Platform.isAndroid) {
            directory = await getExternalStorageDirectory();
          } else {
            directory = await getApplicationDocumentsDirectory();
          }

          if (directory != null) {
            final downloadDir = Directory('${directory.path}/Downloads');
            if (!await downloadDir.exists()) {
              await downloadDir.create(recursive: true);
            }

            final fileName = terminal.pdfFilename ?? 
                'terminal_${terminal.terminalName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
            final filePath = '${downloadDir.path}/$fileName';
            
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(child: Text('PDF downloaded successfully!')),
                  ],
                ),
                backgroundColor: Colors.green,
                action: SnackBarAction(
                  label: 'Open',
                  textColor: Colors.white,
                  onPressed: () => _openFile(filePath),
                ),
              ),
            );
          }
        } else {
          throw Exception('Failed to download: ${response.statusCode}');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error downloading PDF: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        downloadingTerminals[terminal.terminalId] = false;
      });
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
      final Uri fileUri = Uri.file(filePath);
      if (await canLaunchUrl(fileUri)) {
        await launchUrl(fileUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open PDF'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Navigate to PDF page - UPDATED WITH ALL FIELDS
  void _openPdfPage(IoTerminal terminal) {
    if (terminal.pdfUrl == null || terminal.pdfUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info, color: Colors.white),
              SizedBox(width: 8),
              Text('No PDF available for this terminal'),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TerminalPdfPage(
          pdfUrl: terminal.pdfUrl!,
          pdfFilename: terminal.pdfFilename ?? 'Terminal_Document.pdf',
          terminalName: terminal.terminalName,
          serialNumber: terminal.serialNumber ?? 'N/A',
          simNumber: terminal.simNumber ?? 'N/A',
          expire_date: _formatExpireDate(terminal.expireDate),
        ),
      ),
    );
  }

  void _onAddTerminal() async {
    print('Add Terminal button pressed');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TerminalAddPage()),
    );

    print('Add Terminal result: $result');
    if (result == true) {
      print('Refreshing terminals after add');
      fetchTerminals();
    }
  }

  Widget _buildTerminalImage(IoTerminal terminal) {
    if (terminal.imageUrl == null || terminal.imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[200],
        child: Icon(
          Icons.business,
          color: Colors.grey[600],
          size: 30,
        ),
      );
    }

    String imageUrl = terminal.imageUrl!;
    
    if (!imageUrl.startsWith('http')) {
      final baseUrl = AppConfig.api('').toString().replaceAll('/api', '');
      if (imageUrl.startsWith('/')) {
        imageUrl = '$baseUrl$imageUrl';
      } else {
        imageUrl = '$baseUrl/$imageUrl';
      }
    }

    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.business,
              color: Colors.grey[600],
              size: 30,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Building TerminalPage widget');
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final horizontalPadding = isWideScreen ? 32.0 : 16.0;
    final cardMargin = isWideScreen ? 
        EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8) :
        EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    if (loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Terminals'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  ThemeConfig.getPrimaryColor(currentTheme),
                ),
              ),
              SizedBox(height: 16),
              Text('Loading Terminals...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Terminals'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        ),
        body: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: isWideScreen ? 600 : double.infinity),
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Error Loading Terminals',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: fetchTerminals,
                    icon: Icon(Icons.refresh),
                    label: Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                      foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (terminals.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Terminals (0)'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          actions: [
            IconButton(
              onPressed: fetchTerminals,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: isWideScreen ? 600 : double.infinity),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.domain_add, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Terminals found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _onAddTerminal,
                  icon: Icon(Icons.add),
                  label: Text('Add First Terminal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                    foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: isWideScreen ? null : FloatingActionButton(
          onPressed: _onAddTerminal,
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          tooltip: SimpleTranslations.get(langCode, 'add_Terminal'),
          child: const Icon(Icons.add),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${SimpleTranslations.get(langCode, 'Terminals')} (${filteredTerminals.length})'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          if (isWideScreen)
            IconButton(
              onPressed: _onAddTerminal,
              icon: const Icon(Icons.add),
              tooltip: SimpleTranslations.get(langCode, 'add_Terminal'),
            ),
          IconButton(
            onPressed: fetchTerminals,
            icon: const Icon(Icons.refresh),
            tooltip: SimpleTranslations.get(langCode, 'refresh'),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isWideScreen ? 1200 : double.infinity),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: SimpleTranslations.get(langCode, 'search'),
                    prefixIcon: Icon(
                      Icons.search,
                      color: ThemeConfig.getPrimaryColor(currentTheme),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () => _searchController.clear(),
                            icon: Icon(Icons.clear),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: ThemeConfig.getPrimaryColor(currentTheme),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: filteredTerminals.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No Terminals match your search'
                                  : 'No Terminals found',
                              style: const TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: fetchTerminals,
                        child: isWideScreen
                            ? _buildGridView(cardMargin)
                            : _buildListView(cardMargin),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: isWideScreen ? null : FloatingActionButton(
        onPressed: _onAddTerminal,
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        tooltip: SimpleTranslations.get(langCode, 'add_Terminal'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildListView(EdgeInsets cardMargin) {
    return ListView.builder(
      itemCount: filteredTerminals.length,
      itemBuilder: (ctx, i) {
        final terminal = filteredTerminals[i];
        final hasPdf = terminal.pdfUrl != null && terminal.pdfUrl!.isNotEmpty;
        final isDownloading = downloadingTerminals[terminal.terminalId] ?? false;

        return Card(
          margin: cardMargin,
          elevation: 2,
          child: ListTile(
            leading: _buildTerminalImage(terminal),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    terminal.terminalName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (hasPdf)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.picture_as_pdf, size: 14, color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          'PDF',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            subtitle: _buildTerminalSubtitle(terminal),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasPdf) ...[
                  // Download button
                  isDownloading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              ThemeConfig.getPrimaryColor(currentTheme),
                            ),
                          ),
                        )
                      : IconButton(
                          icon: Icon(Icons.download),
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                          onPressed: () => _downloadPdf(terminal),
                          tooltip: 'Download PDF',
                        ),
                ],
                Icon(
                  Icons.edit,
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                ),
              ],
            ),
            onTap: () => _navigateToEdit(terminal),
            onLongPress: hasPdf ? () => _openPdfPage(terminal) : null,
          ),
        );
      },
    );
  }

  Widget _buildGridView(EdgeInsets cardMargin) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: cardMargin.horizontal / 2),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 2,
        childAspectRatio: 3.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: filteredTerminals.length,
      itemBuilder: (ctx, i) {
        final terminal = filteredTerminals[i];
        final hasPdf = terminal.pdfUrl != null && terminal.pdfUrl!.isNotEmpty;
        final isDownloading = downloadingTerminals[terminal.terminalId] ?? false;

        return Card(
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _navigateToEdit(terminal),
            onLongPress: hasPdf ? () => _openPdfPage(terminal) : null,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildTerminalImage(terminal),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                terminal.terminalName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasPdf)
                              Icon(
                                Icons.picture_as_pdf,
                                size: 16,
                                color: Colors.red,
                              ),
                          ],
                        ),
                        SizedBox(height: 4),
                        _buildTerminalSubtitle(terminal, compact: true),
                      ],
                    ),
                  ),
                  if (hasPdf)
                    isDownloading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                ThemeConfig.getPrimaryColor(currentTheme),
                              ),
                            ),
                          )
                        : IconButton(
                            icon: Icon(Icons.download, size: 18),
                            color: ThemeConfig.getPrimaryColor(currentTheme),
                            onPressed: () => _downloadPdf(terminal),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                            tooltip: 'Download PDF',
                          ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.edit,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTerminalSubtitle(IoTerminal terminal, {bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (terminal.terminalCode != null && terminal.terminalCode!.isNotEmpty)
          Text(
            'Code: ${terminal.terminalCode}',
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w500,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (!compact && terminal.phone != null && terminal.phone!.isNotEmpty)
          Text(
            'Phone: ${terminal.phone}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (!compact)
          Text(
            'Company ID: ${terminal.companyId}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  void _navigateToEdit(IoTerminal terminal) async {
    print('Terminal tapped: ${terminal.terminalName}');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TerminalEditPage(
          TerminalData: terminal.toJson(),
        ),
      ),
    );

    print('Edit Terminal result: $result');
    if (result == true || result == 'deleted') {
      print('Terminal operation completed, refreshing list...');
      fetchTerminals();
      
      if (result == 'deleted') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terminal removed from list'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

// Updated IoTerminal model with ALL required fields
class IoTerminal {
  final int terminalId;
  final int companyId;
  final String terminalName;
  final String? terminalCode;
  final String? phone;
  final String? serialNumber;
  final String? simNumber;
  final String? expireDate;
  final String? imageUrl;
  final String? pdfUrl;
  final String? pdfFilename;
  final int? createBy;
  final String? createdDate;
  final String? updatedDate;
  
  IoTerminal({
    required this.terminalId,
    required this.companyId,
    required this.terminalName,
    this.terminalCode,
    this.phone,
    this.serialNumber,
    this.simNumber,
    this.expireDate,
    this.imageUrl,
    this.pdfUrl,
    this.pdfFilename,
    this.createBy,
    this.createdDate,
    this.updatedDate,
  });
  
  factory IoTerminal.fromJson(Map<String, dynamic> json) {
    print('Converting JSON to IoTerminal');
    
    try {
      int? parseCreateBy(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is String) {
          if (value.isEmpty || value.toLowerCase() == 'null') return null;
          return int.tryParse(value);
        }
        return null;
      }

      final terminal = IoTerminal(
        terminalId: json['terminal_id'] ?? 0,
        companyId: json['company_id'] ?? CompanyConfig.getCompanyId(),
        terminalName: json['terminal_name'] ?? '',
        terminalCode: json['terminal_code'],
        phone: json['phone'],
        serialNumber: json['serial_number'],
        simNumber: json['sim_number'],
        expireDate: json['expire_date'],
        imageUrl: json['image_url'],
        pdfUrl: json['pdf_url'],
        pdfFilename: json['pdf_filename'],
        createBy: parseCreateBy(json['create_by']),
        createdDate: json['created_date'],
        updatedDate: json['updated_date'],
      );
      print('Successfully created IoTerminal: ${terminal.terminalName}');
      return terminal;
    } catch (e, stackTrace) {
      print('Error parsing IoTerminal JSON: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'terminal_id': terminalId,
      'company_id': companyId,
      'terminal_name': terminalName,
      'terminal_code': terminalCode,
      'phone': phone,
      'serial_number': serialNumber,
      'sim_number': simNumber,
      'expire_date': expireDate,
      'image_url': imageUrl,
      'pdf_url': pdfUrl,
      'pdf_filename': pdfFilename,
      'create_by': createBy,
      'created_date': createdDate,
      'updated_date': updatedDate,
    };
  }
}
