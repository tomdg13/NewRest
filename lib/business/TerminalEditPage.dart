import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
// Import the PDF page
import 'package:inventory/business/TerminalPdfPage.dart' show TerminalPdfPage;

class TerminalEditPage extends StatefulWidget {
  final Map<String, dynamic> TerminalData;

  const TerminalEditPage({Key? key, required this.TerminalData})
    : super(key: key);

  @override
  State<TerminalEditPage> createState() => _TerminalEditPageState();
}

class _TerminalEditPageState extends State<TerminalEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _terminalNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _serialNumberController;
  late final TextEditingController _simNumberController;

  DateTime? _selectedExpireDate;
  String? _base64Image;
  String? _currentImageUrl;
  File? _imageFile;

  // PDF related variables
  String? _base64Pdf;
  String? _currentPdfUrl;
  String? _pdfFileName;
  // ignore: unused_field
  File? _pdfFile;

  bool _isLoading = false;
  bool _isDeleting = false;
  String currentTheme = ThemeConfig.defaultTheme;

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
    _initializeControllers();
  }

  void _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme =
          prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  void _initializeControllers() {
    _terminalNameController = TextEditingController(
      text: widget.TerminalData['terminal_name'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.TerminalData['terminal_phone'] ?? '',
    );
    _serialNumberController = TextEditingController(
      text: widget.TerminalData['serial_number'] ?? '',
    );
    _simNumberController = TextEditingController(
      text: widget.TerminalData['sim_number'] ?? '',
    );
    _currentImageUrl = widget.TerminalData['image_url'];
    _currentPdfUrl = widget.TerminalData['pdf_url'];
    _pdfFileName = widget.TerminalData['pdf_filename'];

    if (widget.TerminalData['expire_date'] != null &&
        widget.TerminalData['expire_date'].toString().isNotEmpty) {
      try {
        _selectedExpireDate = DateTime.parse(
          widget.TerminalData['expire_date'],
        );
      } catch (e) {
        _selectedExpireDate = null;
      }
    }
  }

  @override
  void dispose() {
    _terminalNameController.dispose();
    _phoneController.dispose();
    _serialNumberController.dispose();
    _simNumberController.dispose();
    super.dispose();
  }

  bool _isDownloading = false;

  // Open/Download PDF function with proper file saving
  Future<void> _downloadPdf(String pdfUrl, String? filename) async {
    setState(() {
      _isDownloading = true;
    });

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Downloading PDF...'),
            ],
          ),
          duration: Duration(seconds: 30),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        ),
      );

      if (kIsWeb) {
        // For web, open in new tab
        final Uri url = Uri.parse(pdfUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Could not open PDF');
        }
      } else {
        // For mobile, download the file
        final response = await http.get(Uri.parse(pdfUrl));

        if (response.statusCode == 200) {
          // Get the directory to save the file
          Directory? directory;
          if (Platform.isAndroid) {
            directory = await getExternalStorageDirectory();
          } else {
            directory = await getApplicationDocumentsDirectory();
          }

          if (directory != null) {
            // Create filename
            final fileName =
                filename ??
                'terminal_document_${DateTime.now().millisecondsSinceEpoch}.pdf';
            final filePath = '${directory.path}/$fileName';

            // Save file
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);

            // Hide loading snackbar
            ScaffoldMessenger.of(context).hideCurrentSnackBar();

            // Show success message with options
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
                      'Saved to: ${directory.path}',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Open',
                  textColor: Colors.white,
                  onPressed: () => _openFile(filePath),
                ),
              ),
            );
          } else {
            throw Exception('Could not access storage directory');
          }
        } else {
          throw Exception('Failed to download PDF: ${response.statusCode}');
        }
      }
    } catch (e) {
      // Hide loading snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

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
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  // Open downloaded file
  Future<void> _openFile(String filePath) async {
    try {
      final Uri fileUri = Uri.file(filePath);
      if (await canLaunchUrl(fileUri)) {
        await launchUrl(fileUri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not open file');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open PDF. File saved at: $filePath'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // PDF picker function
  Future<void> _pickPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        PlatformFile file = result.files.first;

        // Check file size (limit to 10MB)
        if (file.size > 10 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('PDF file size must be less than 10MB')),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        Uint8List? fileBytes;

        if (kIsWeb) {
          fileBytes = file.bytes;
        } else {
          if (file.path != null) {
            final pdfFile = File(file.path!);
            fileBytes = await pdfFile.readAsBytes();
            setState(() {
              _pdfFile = pdfFile;
            });
          }
        }

        if (fileBytes != null) {
          final String base64String = base64Encode(fileBytes);

          setState(() {
            _base64Pdf = 'data:application/pdf;base64,$base64String';
            _pdfFileName = file.name;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('PDF selected: ${file.name}')),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error selecting PDF: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _scanBarcode() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Barcode scanning is not available on web. Please enter manually.',
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => _BarcodeScannerPage()),
      );

      if (result != null && result is String && result.isNotEmpty) {
        setState(() {
          _serialNumberController.text = result;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Serial number scanned successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Error scanning barcode: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _selectExpireDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedExpireDate ?? DateTime.now().add(Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ThemeConfig.getPrimaryColor(currentTheme),
              onPrimary: ThemeConfig.getButtonTextColor(currentTheme),
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedExpireDate) {
      setState(() {
        _selectedExpireDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Select Image Source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                  _buildImageSourceOption(
                    icon: Icons.photo_camera,
                    label: 'Camera',
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ],
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      );

      if (source == null) return;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        final Uint8List imageBytes = await imageFile.readAsBytes();
        final String base64String = base64Encode(imageBytes);

        setState(() {
          _imageFile = imageFile;
          _base64Image = 'data:image/jpeg;base64,$base64String';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error selecting image: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: ThemeConfig.getPrimaryColor(currentTheme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateTerminal() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final terminalId = widget.TerminalData['terminal_id'];

      final url = AppConfig.api('/api/ioterminal/$terminalId');

      final terminalData = <String, dynamic>{
        'company_id': CompanyConfig.getCompanyId(),
      };

      if (_terminalNameController.text.trim().isNotEmpty) {
        terminalData['terminal_name'] = _terminalNameController.text.trim();
      }

      if (_phoneController.text.trim().isNotEmpty) {
        terminalData['phone'] = _phoneController.text.trim();
      }

      if (_serialNumberController.text.trim().isNotEmpty) {
        terminalData['serial_number'] = _serialNumberController.text.trim();
      }

      if (_simNumberController.text.trim().isNotEmpty) {
        terminalData['sim_number'] = _simNumberController.text.trim();
      }

      if (_selectedExpireDate != null) {
        terminalData['expire_date'] = _selectedExpireDate!
            .toIso8601String()
            .split('T')[0];
      }

      if (_base64Image != null) {
        terminalData['image'] = _base64Image;
      }

      // Add PDF data
      if (_base64Pdf != null) {
        terminalData['terminal_pdf'] = _base64Pdf;
        terminalData['pdf_filename'] = _pdfFileName;
      }

      final response = await http.put(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(terminalData),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Terminal updated successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          throw Exception(responseData['message'] ?? 'Unknown error');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['message'] ?? 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error updating Terminal: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteTerminal() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Delete Terminal'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${_terminalNameController.text}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final terminalId = widget.TerminalData['terminal_id'];

      final url = AppConfig.api('/api/ioterminal/$terminalId');

      final response = await http.delete(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Terminal deleted successfully!'),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context, 'deleted');
        } else {
          throw Exception(responseData['message'] ?? 'Unknown error');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['message'] ?? 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error deleting Terminal: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  // PDF section widget
  Widget _buildPdfSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.picture_as_pdf,
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'PDF Document',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Main PDF display area
            GestureDetector(
              onTap: _pickPdf,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (_pdfFileName != null || _currentPdfUrl != null)
                        ? ThemeConfig.getPrimaryColor(currentTheme)
                        : Colors.grey[300]!,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: _pdfFileName != null
                    ? _buildNewPdfDisplay()
                    : _currentPdfUrl != null && _currentPdfUrl!.isNotEmpty
                    ? _buildExistingPdfDisplay()
                    : _buildNoPdfDisplay(),
              ),
            ),

            // Action buttons - Always visible when PDF exists
            if (_currentPdfUrl != null && _currentPdfUrl!.isNotEmpty) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_download,
                          color: Colors.blue,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Current PDF Available',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isDownloading
                                ? null
                                : () => _downloadPdf(
                                    _currentPdfUrl!,
                                    widget.TerminalData['pdf_filename'],
                                  ),
                            icon: _isDownloading
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Icon(Icons.download, size: 18),
                            label: Text(
                              _isDownloading ? 'Downloading...' : 'Download',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ThemeConfig.getPrimaryColor(
                                currentTheme,
                              ),
                              foregroundColor: ThemeConfig.getButtonTextColor(
                                currentTheme,
                              ),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TerminalPdfPage(
                                    pdfUrl: _currentPdfUrl!,
                                    pdfFilename:
                                        widget.TerminalData['pdf_filename'] ??
                                        'Terminal_Document.pdf',
                                    terminalName:
                                        widget.TerminalData['terminal_name'] ??
                                        'Terminal',
                                    serialNumber:
                                        widget.TerminalData['serial_number'] ??
                                        'N/A',
                                    simNumber:
                                        widget.TerminalData['sim_number'] ??
                                        'N/A',
                                    expire_date:
                                        widget.TerminalData['expire_date'] !=
                                            null
                                        ? widget.TerminalData['expire_date']
                                              .toString()
                                              .split('T')[0]
                                        : 'N/A',
                                  ),
                                ),
                              );
                            },
                            icon: Icon(Icons.open_in_new, size: 18),
                            label: Text(
                              'Open',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ThemeConfig.getPrimaryColor(
                                currentTheme,
                              ),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: ThemeConfig.getPrimaryColor(
                                  currentTheme,
                                ),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Widget for newly selected PDF
  Widget _buildNewPdfDisplay() {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _pdfFileName!,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'New PDF Selected',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.clear, color: Colors.grey[600]),
          onPressed: () {
            setState(() {
              _pdfFileName = null;
              _base64Pdf = null;
              _pdfFile = null;
            });
          },
        ),
      ],
    );
  }

  // Widget for existing PDF from server
  Widget _buildExistingPdfDisplay() {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.TerminalData['pdf_filename'] ?? 'Current PDF',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'PDF Available',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.edit, color: ThemeConfig.getPrimaryColor(currentTheme)),
          ],
        ),
      ],
    );
  }

  // Widget for no PDF
  Widget _buildNoPdfDisplay() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.upload_file,
          size: 48,
          color: ThemeConfig.getPrimaryColor(currentTheme),
        ),
        SizedBox(height: 12),
        Text(
          'Tap to upload PDF',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Max size: 10MB',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.image,
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Terminal Image',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _imageFile != null
                          ? ThemeConfig.getPrimaryColor(currentTheme)
                          : Colors.grey[300]!,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            children: [
                              Image.file(
                                _imageFile!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _currentImageUrl != null && _currentImageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            children: [
                              Image.network(
                                _currentImageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildImagePlaceholder();
                                },
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildImagePlaceholder(),
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Tap to change image',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_a_photo,
          size: 48,
          color: ThemeConfig.getPrimaryColor(currentTheme),
        ),
        SizedBox(height: 12),
        Text(
          'Tap to add image',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Edit Terminal'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isLoading || _isDeleting ? null : _deleteTerminal,
            icon: _isDeleting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ThemeConfig.getButtonTextColor(currentTheme),
                      ),
                    ),
                  )
                : Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete Terminal',
          ),
          if (_isLoading)
            Container(
              margin: EdgeInsets.all(16),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ThemeConfig.getButtonTextColor(currentTheme),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImageSection(),

              SizedBox(height: 20),

              // PDF section
              _buildPdfSection(),

              SizedBox(height: 20),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.terminal,
                            color: ThemeConfig.getPrimaryColor(currentTheme),
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Terminal Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      TextFormField(
                        controller: _terminalNameController,
                        decoration: InputDecoration(
                          labelText: 'Terminal Name *',
                          hintText: 'Enter terminal name',
                          prefixIcon: Icon(
                            Icons.terminal,
                            color: ThemeConfig.getPrimaryColor(currentTheme),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Terminal name is required';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 16),

                      TextFormField(
                        controller: _serialNumberController,
                        decoration: InputDecoration(
                          labelText: 'Serial Number',
                          hintText: 'Enter or scan device serial number',
                          prefixIcon: Icon(
                            Icons.memory,
                            color: ThemeConfig.getPrimaryColor(currentTheme),
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_serialNumberController.text.isNotEmpty)
                                IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _serialNumberController.clear();
                                    });
                                  },
                                ),
                              if (!kIsWeb)
                                IconButton(
                                  icon: Icon(
                                    Icons.qr_code_scanner,
                                    color: ThemeConfig.getPrimaryColor(
                                      currentTheme,
                                    ),
                                  ),
                                  onPressed: _scanBarcode,
                                  tooltip: 'Scan Barcode',
                                ),
                            ],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (value) {
                          if (value != null &&
                              value.trim().isNotEmpty &&
                              value.trim().length < 3) {
                            return 'Serial number must be at least 3 characters';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 16),

                      TextFormField(
                        controller: _simNumberController,
                        decoration: InputDecoration(
                          labelText: 'SIM Number',
                          hintText: 'Enter SIM number',
                          prefixIcon: Icon(
                            Icons.sim_card,
                            color: ThemeConfig.getPrimaryColor(currentTheme),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (!RegExp(
                              r'^[0-9A-F]{8,}$',
                              caseSensitive: false,
                            ).hasMatch(value)) {
                              return 'SIM number must be at least 8 characters';
                            }
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 16),

                      GestureDetector(
                        onTap: _selectExpireDate,
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[50],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: ThemeConfig.getPrimaryColor(
                                  currentTheme,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedExpireDate != null
                                      ? 'Expire Date: ${_selectedExpireDate!.toLocal().toString().split(' ')[0]}'
                                      : 'Select Expire Date (Optional)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _selectedExpireDate != null
                                        ? Colors.black87
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                              if (_selectedExpireDate != null)
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedExpireDate = null;
                                    });
                                  },
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 16),

                      // Container(
                      //   padding: EdgeInsets.all(16),
                      //   decoration: BoxDecoration(
                      //     color: Colors.grey[100],
                      //     borderRadius: BorderRadius.circular(12),
                      //     border: Border.all(color: Colors.grey[300]!),
                      //   ),
                      //   child: Row(
                      //     children: [
                      //       Icon(Icons.business, color: Colors.grey[600]),
                      //       SizedBox(width: 12),
                      //       Text(
                      //         'Company ID: ${widget.TerminalData['company_id']}',
                      //         style: TextStyle(
                      //           fontSize: 16,
                      //           color: Colors.grey[700],
                      //           fontWeight: FontWeight.w500,
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 30),

              // Action buttons at bottom
              if (_currentPdfUrl != null && _currentPdfUrl!.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Download PDF button
                    Container(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _isDownloading
                            ? null
                            : () => _downloadPdf(
                                _currentPdfUrl!,
                                widget.TerminalData['pdf_filename'],
                              ),
                        icon: _isDownloading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    ThemeConfig.getPrimaryColor(currentTheme),
                                  ),
                                ),
                              )
                            : Icon(Icons.download, size: 24),
                        label: Text(
                          _isDownloading
                              ? 'Downloading PDF...'
                              : 'Download PDF Document',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ThemeConfig.getPrimaryColor(
                            currentTheme,
                          ),
                          side: BorderSide(
                            color: ThemeConfig.getPrimaryColor(currentTheme),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                  ],
                ),

              // Update Terminal button
              Container(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading || _isDeleting ? null : _updateTerminal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                    foregroundColor: ThemeConfig.getButtonTextColor(
                      currentTheme,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: ThemeConfig.getPrimaryColor(
                      currentTheme,
                    ).withOpacity(0.3),
                  ),
                  child: _isLoading
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
                              'Updating Terminal...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Update Terminal',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarcodeScannerPage extends StatefulWidget {
  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isScanning = true;
  String? _scannedCode;

  bool get _isTorchOn => cameraController.torchEnabled;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        setState(() {
          _isScanning = false;
          _scannedCode = barcode.rawValue;
        });

        HapticFeedback.mediumImpact();

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context, _scannedCode);
          }
        });
      }
    }
  }

  void _toggleTorch() {
    cameraController.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Scan Serial Number',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.yellow : Colors.grey,
            ),
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: cameraController, onDetect: _onDetect),

          _buildScanningOverlay(),

          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Position the barcode within the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isScanning ? 'Scanning...' : 'Code detected!',
                    style: TextStyle(
                      color: _isScanning ? Colors.orange : Colors.green,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.keyboard, color: Colors.white),
                label: const Text(
                  'Enter Manually',
                  style: TextStyle(color: Colors.white),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return CustomPaint(painter: ScannerOverlayPainter(), child: Container());
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = Colors.black.withOpacity(0.5);

    final double frameWidth = size.width * 0.7;
    final double frameHeight = frameWidth * 0.6;
    final double left = (size.width - frameWidth) / 2;
    final double top = (size.height - frameHeight) / 2;
    final Rect frameRect = Rect.fromLTWH(left, top, frameWidth, frameHeight);

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(
          RRect.fromRectAndRadius(frameRect, const Radius.circular(12)),
        ),
      ),
      paint,
    );

    final Paint cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final double cornerLength = 30;

    canvas.drawPath(
      Path()
        ..moveTo(left, top + cornerLength)
        ..lineTo(left, top)
        ..lineTo(left + cornerLength, top),
      cornerPaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(left + frameWidth - cornerLength, top)
        ..lineTo(left + frameWidth, top)
        ..lineTo(left + frameWidth, top + cornerLength),
      cornerPaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(left, top + frameHeight - cornerLength)
        ..lineTo(left, top + frameHeight)
        ..lineTo(left + cornerLength, top + frameHeight),
      cornerPaint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(left + frameWidth - cornerLength, top + frameHeight)
        ..lineTo(left + frameWidth, top + frameHeight)
        ..lineTo(left + frameWidth, top + frameHeight - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
