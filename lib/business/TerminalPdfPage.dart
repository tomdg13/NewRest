import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/theme.dart';
// ignore: unused_import
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class TerminalPdfPage extends StatefulWidget {
  final String pdfUrl;
  final String? pdfFilename;
  final String terminalName;

  const TerminalPdfPage({
    Key? key,
    required this.pdfUrl,
    this.pdfFilename,
    required this.terminalName, required serialNumber, required simNumber, required String expire_date,
  }) : super(key: key);

  @override
  State<TerminalPdfPage> createState() => _TerminalPdfPageState();
}

class _TerminalPdfPageState extends State<TerminalPdfPage> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _downloadedFilePath;
  String currentTheme = ThemeConfig.defaultTheme;

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
  }

  void _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  Future<void> _downloadPdf() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      if (kIsWeb) {
        // For web, open in new tab
        final Uri url = Uri.parse(widget.pdfUrl);
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
        } else {
          throw Exception('Could not open PDF');
        }
      } else {
        // For mobile, download with progress
        final response = await http.get(
          Uri.parse(widget.pdfUrl),
        );

        if (response.statusCode == 200) {
          // Get storage directory
          Directory? directory;
          if (Platform.isAndroid) {
            directory = await getExternalStorageDirectory();
          } else {
            directory = await getApplicationDocumentsDirectory();
          }

          if (directory != null) {
            // Create Downloads folder if it doesn't exist
            final downloadDir = Directory('${directory.path}/Downloads');
            if (!await downloadDir.exists()) {
              await downloadDir.create(recursive: true);
            }

            // Generate filename
            final fileName = widget.pdfFilename ?? 
                'terminal_${widget.terminalName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
            final filePath = '${downloadDir.path}/$fileName';

            // Save file
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);

            setState(() {
              _downloadedFilePath = filePath;
              _downloadProgress = 1.0;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(child: Text('PDF downloaded successfully!')),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Location: ${downloadDir.path}',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 5),
              ),
            );
          } else {
            throw Exception('Could not access storage');
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
              Expanded(child: Text('Error: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _openDownloadedPdf() async {
    if (_downloadedFilePath == null) return;

    try {
      final Uri fileUri = Uri.file(_downloadedFilePath!);
      if (await canLaunchUrl(fileUri)) {
        await launchUrl(fileUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: try to open with system viewer
        if (Platform.isAndroid || Platform.isIOS) {
          await launchUrl(
            Uri.parse(_downloadedFilePath!),
            mode: LaunchMode.externalApplication,
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open PDF. File saved at: $_downloadedFilePath'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _viewOnline() async {
    try {
      final Uri url = Uri.parse(widget.pdfUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not open PDF');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error opening PDF: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sharePdf() async {
    if (_downloadedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please download the PDF first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // You can integrate share_plus package here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share functionality - integrate share_plus package'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Terminal Document'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // PDF Info Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    // PDF Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.picture_as_pdf,
                        size: 60,
                        color: Colors.red,
                      ),
                    ),
                    
                    SizedBox(height: 20),
                    
                    // Terminal Name
                    Text(
                      widget.terminalName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: 8),
                    
                    // Filename
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.pdfFilename ?? 'terminal_document.pdf',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    if (_downloadedFilePath != null) ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Downloaded',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Download Progress
            if (_isDownloading) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                ThemeConfig.getPrimaryColor(currentTheme),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            'Downloading PDF...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ThemeConfig.getPrimaryColor(currentTheme),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],

            // Action Buttons
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ThemeConfig.getPrimaryColor(currentTheme),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Download Button
                    if (!kIsWeb || _downloadedFilePath == null)
                      ElevatedButton.icon(
                        onPressed: _isDownloading ? null : _downloadPdf,
                        icon: Icon(Icons.download, size: 22),
                        label: Text(
                          _downloadedFilePath != null 
                              ? 'Download Again' 
                              : 'Download to Device',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    
                    if (_downloadedFilePath != null) ...[
                      SizedBox(height: 12),
                      // Open Downloaded File Button
                      ElevatedButton.icon(
                        onPressed: _openDownloadedPdf,
                        icon: Icon(Icons.open_in_new, size: 22),
                        label: Text(
                          'Open Downloaded PDF',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ],
                    
                    SizedBox(height: 12),
                    
                    // View Online Button
                    OutlinedButton.icon(
                      onPressed: _viewOnline,
                      icon: Icon(Icons.preview, size: 22),
                      label: Text(
                        'View Online',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    // Share Button (optional)
                    OutlinedButton.icon(
                      onPressed: _downloadedFilePath != null ? _sharePdf : null,
                      icon: Icon(Icons.share, size: 22),
                      label: Text(
                        'Share PDF',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: _downloadedFilePath != null ? Colors.blue : Colors.grey,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Info Card
            Card(
              elevation: 2,
              color: Colors.blue.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            kIsWeb
                                ? 'On web, the PDF will open in a new browser tab.'
                                : 'Downloaded PDFs are saved in your device\'s Downloads folder.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}