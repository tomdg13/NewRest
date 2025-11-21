import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
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
import 'dart:typed_data';
// For web file handling
import 'package:universal_html/html.dart' as html;

// Data Models
class Group {
  final int id;
  final String groupName;
  final int companyId;
  final String? imageUrl;
  final String? groupCode;
  final String? phone;

  Group({
    required this.id,
    required this.groupName,
    required this.companyId,
    this.imageUrl,
    this.groupCode,
    this.phone,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['group_id'] ?? 0,
      groupName: json['group_name'] ?? '',
      companyId: json['company_id'] ?? 0,
      imageUrl: json['image_url'],
      groupCode: json['group_code'],
      phone: json['phone'],
    );
  }
}

class Merchant {
  final int merchantId;
  final String merchantName;
  final int companyId;
  final int groupId;
  final String? imageUrl;
  final String? merchantCode;
  final String? phone;

  Merchant({
    required this.merchantId,
    required this.merchantName,
    required this.companyId,
    required this.groupId,
    this.imageUrl,
    this.merchantCode,
    this.phone,
  });

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      merchantId: json['merchant_id'] ?? 0,
      merchantName: json['merchant_name'] ?? '',
      companyId: json['company_id'] ?? 0,
      groupId: json['group_id'] ?? 0,
      imageUrl: json['image_url'],
      merchantCode: json['merchant_code'],
      phone: json['phone'],
    );
  }
}

class Store {
  final int storeId;
  final String storeName;
  final int companyId;
  final int merchantId;
  final String? imageUrl;
  final String? storeCode;
  final String? phone;
  final String? address;

  Store({
    required this.storeId,
    required this.storeName,
    required this.companyId,
    required this.merchantId,
    this.imageUrl,
    this.storeCode,
    this.phone,
    this.address,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      storeId: json['store_id'] ?? 0,
      storeName: json['store_name'] ?? '',
      companyId: json['company_id'] ?? 0,
      merchantId: json['merchant_id'] ?? 0,
      imageUrl: json['image_url'],
      storeCode: json['store_code'],
      phone: json['phone'],
      address: json['address'],
    );
  }
}

class TerminalAddPage extends StatefulWidget {
  const TerminalAddPage({Key? key}) : super(key: key);

  @override
  State<TerminalAddPage> createState() => _TerminalAddPageState();
}

class _TerminalAddPageState extends State<TerminalAddPage>
    with TickerProviderStateMixin {
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _terminalNameController = TextEditingController();
  final _terminalNameFocus = FocusNode();

  // NEW: Controllers for the new fields
  final _serialNumberController = TextEditingController();
  final _simNumberController = TextEditingController();
  final _serialNumberFocus = FocusNode();
  final _simNumberFocus = FocusNode();

  // NEW: Expire date
  DateTime? _selectedExpireDate;

  // State variables
  String? _base64Image;
  File? _imageFile; // For mobile
  Uint8List? _webImageBytes; // For web
  // ignore: unused_field
  String? _webImageName; // For web
  bool _isLoading = false;
  String currentTheme = ThemeConfig.defaultTheme;

  // Dropdown data
  List<Group> _groups = [];
  Group? _selectedGroup;
  bool _isLoadingGroups = false;

  List<Merchant> _merchants = [];
  Merchant? _selectedMerchant;
  bool _isLoadingMerchants = false;

  List<Store> _stores = [];
  Store? _selectedStore;
  bool _isLoadingStores = false;

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _disposeResources();
    super.dispose();
  }

  void _initializeData() {
    _loadCurrentTheme();
    _setupAnimations();
    _loadGroups();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  void _disposeResources() {
    _terminalNameController.dispose();
    _terminalNameFocus.dispose();
    _serialNumberController.dispose();
    _simNumberController.dispose();
    _serialNumberFocus.dispose();
    _simNumberFocus.dispose();
    _fadeController.dispose();
  }

  // NEW: Cross-platform image picking
  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        // Web-specific image picking
        await _pickImageWeb();
      } else {
        // Mobile-specific image picking
        await _pickImageMobile();
      }
    } catch (e) {
      print('Error picking image: $e');
      _showSnackBar(message: 'Error selecting image: $e', isError: true);
    }
  }

  Future<void> _pickImageWeb() async {
    final html.FileUploadInputElement input = html.FileUploadInputElement();
    input.accept = 'image/*';
    input.click();

    input.onChange.listen((e) async {
      final files = input.files;
      if (files!.isEmpty) return;

      final file = files[0];
      final reader = html.FileReader();

      reader.onLoadEnd.listen((e) async {
        final Uint8List bytes = reader.result as Uint8List;
        final String base64String = base64Encode(bytes);

        setState(() {
          _webImageBytes = bytes;
          _webImageName = file.name;
          _base64Image = 'data:${file.type};base64,$base64String';
        });

        print('Web image selected and converted to base64');
        _showSnackBar(message: 'Image selected successfully', isError: false);
      });

      reader.readAsArrayBuffer(file);
    });
  }

  Future<void> _pickImageMobile() async {
    // Show image source selection dialog for mobile
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

      print('Mobile image selected and converted to base64');
      _showSnackBar(message: 'Image selected successfully', isError: false);
    }
  }

  void _showSnackBar({required String message, required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
            ),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
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

  Widget _buildImageDisplay() {
    if (kIsWeb && _webImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Image.memory(
              _webImageBytes!,
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
                child: Icon(Icons.edit, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      );
    } else if (!kIsWeb && _imageFile != null) {
      return ClipRRect(
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
                child: Icon(Icons.edit, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      );
    } else {
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
          SizedBox(height: 4),
          Text(
            'Recommended: 800x800px',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          if (kIsWeb) ...[
            SizedBox(height: 8),
            Text(
              'Click to browse files',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      );
    }
  }

  // NEW: Barcode scanning method (mobile only)
  Future<void> _scanBarcode() async {
    if (kIsWeb) {
      _showSnackBar(
        message:
            'Barcode scanning is not available on web. Please enter manually.',
        isError: true,
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
        _showSnackBar(
          message: 'Serial number scanned successfully',
          isError: false,
        );
      }
    } catch (e) {
      _showSnackBar(message: 'Error scanning barcode: $e', isError: true);
    }
  }

  // Data Loading methods
  Future<void> _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme =
          prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
    });
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoadingGroups = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();

      final url = AppConfig.api('/api/iogroup?company_id=$companyId');
      final response = await http.get(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final List<dynamic> groupsJson = responseData['data'];
          setState(() {
            _groups = groupsJson.map((json) => Group.fromJson(json)).toList();
          });
        }
      } else {
        throw Exception('Failed to load groups: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar(message: 'Failed to load groups: $e', isError: true);
    } finally {
      setState(() => _isLoadingGroups = false);
    }
  }

  Future<void> _loadMerchants() async {
    if (_selectedGroup == null) return;

    setState(() => _isLoadingMerchants = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();

      final url = AppConfig.api(
        '/api/iomerchant/company/$companyId/group/${_selectedGroup!.id}',
      );
      final response = await http.get(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final List<dynamic> merchantsJson = responseData['data'];
          setState(() {
            _merchants = merchantsJson
                .map((json) => Merchant.fromJson(json))
                .toList();
          });
        } else {
          setState(() => _merchants = []);
        }
      } else {
        throw Exception('Failed to load merchants: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar(message: 'Failed to load merchants: $e', isError: true);
      setState(() => _merchants = []);
    } finally {
      setState(() => _isLoadingMerchants = false);
    }
  }

  Future<void> _loadStores() async {
    if (_selectedMerchant == null) return;

    setState(() => _isLoadingStores = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();

      final url = AppConfig.api(
        '/api/ioterminal/company/$companyId/merchant/${_selectedMerchant!.merchantId}',
      );
      final response = await http.get(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success' &&
            responseData['data'] != null) {
          final List<dynamic> storesJson = responseData['data'];
          setState(() {
            _stores = storesJson.map((json) => Store.fromJson(json)).toList();
          });
        } else {
          setState(() => _stores = []);
        }
      } else {
        throw Exception('Failed to load stores: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar(message: 'Failed to load stores: $e', isError: true);
      setState(() => _stores = []);
    } finally {
      setState(() => _isLoadingStores = false);
    }
  }

  // NEW: Date picker method
  Future<void> _selectExpireDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedExpireDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)), // 10 years
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ThemeConfig.getPrimaryColor(currentTheme),
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

  // API Operations with new fields
  Future<void> _createTerminal() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      _showSnackBar(
        message: 'Please fill in all required fields',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();

      final terminalData = <String, dynamic>{
        'company_id': companyId,
        'terminal_name': _terminalNameController.text.trim(),
      };

      final savedPhone = prefs.getString('user');
      if (savedPhone?.isNotEmpty == true) {
        terminalData['phone'] = savedPhone!;
      }

      if (_selectedGroup != null) terminalData['group_id'] = _selectedGroup!.id;
      if (_selectedMerchant != null)
        terminalData['merchant_id'] = _selectedMerchant!.merchantId;
      if (_selectedStore != null)
        terminalData['store_id'] = _selectedStore!.storeId;
      if (_base64Image != null) terminalData['image'] = _base64Image!;

      // NEW: Add the three new fields
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

      final userId = prefs.getInt('user_id');
      if (userId != null) terminalData['user_id'] = userId;

      // Console logging
      final apiUrl = AppConfig.api('/api/ioterminal').toString();
      print('🌐 API URL: $apiUrl');
      print('📤 REQUEST HEADERS:');
      print('   Content-Type: application/json');
      if (token != null)
        print('   Authorization: Bearer ${token.substring(0, 20)}...');
      print('📦 REQUEST BODY:');
      print(const JsonEncoder.withIndent('  ').convert(terminalData));
      print('⏱️ Sending request at: ${DateTime.now().toIso8601String()}');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(terminalData),
      );

      print('📥 RESPONSE STATUS: ${response.statusCode}');
      print('📥 RESPONSE HEADERS: ${response.headers}');
      print('📥 RESPONSE BODY:');

      try {
        final responseJson = jsonDecode(response.body);
        print(const JsonEncoder.withIndent('  ').convert(responseJson));
      } catch (e) {
        print('Raw response body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          print('✅ Terminal created successfully!');
          final terminalCode = _extractTerminalCode(responseData);
          print('🏷️ Generated Terminal Code: $terminalCode');
          _showSuccessDialog(terminalCode);
          return;
        }
      }

      print('❌ Request failed with status: ${response.statusCode}');
      _handleErrorResponse(response);
    } catch (e) {
      print('💥 Exception occurred: $e');
      _showErrorDialog(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _extractTerminalCode(Map<String, dynamic> responseData) {
    if (responseData['data']?['terminal_code'] != null) {
      return responseData['data']['terminal_code'];
    }
    if (responseData['message']?.toString().contains('code: ') == true) {
      return responseData['message'].toString().split('code: ').last;
    }
    return 'N/A';
  }

  void _handleErrorResponse(http.Response response) {
    final errorData = jsonDecode(response.body);
    String errorMessage;

    switch (response.statusCode) {
      case 409:
        errorMessage =
            'Terminal already exists: ${errorData['details'] ?? errorData['message']}';
        break;
      case 400:
        if (errorData['message'] is List) {
          errorMessage =
              'Validation error: ${(errorData['message'] as List).join(', ')}';
        } else {
          errorMessage = 'Validation error: ${errorData['message']}';
        }
        break;
      default:
        errorMessage =
            errorData['message'] ?? 'Server error: ${response.statusCode}';
    }

    throw Exception(errorMessage);
  }

  // UI helper methods
  void _showSuccessDialog(String terminalCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terminal "${_terminalNameController.text}" created successfully!',
            ),
            const SizedBox(height: 8),
            if (terminalCode != 'N/A') ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Text(
                  'Terminal Code: $terminalCode',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_serialNumberController.text.trim().isNotEmpty) ...[
              Text('Serial Number: ${_serialNumberController.text.trim()}'),
              const SizedBox(height: 4),
            ],
            if (_simNumberController.text.trim().isNotEmpty) ...[
              Text('SIM Number: ${_simNumberController.text.trim()}'),
              const SizedBox(height: 4),
            ],
            if (_selectedExpireDate != null) ...[
              Text(
                'Expires: ${_selectedExpireDate!.day}/${_selectedExpireDate!.month}/${_selectedExpireDate!.year}',
              ),
              const SizedBox(height: 4),
            ],
            if (_selectedGroup != null) ...[
              Text('Group: ${_selectedGroup!.groupName}'),
              const SizedBox(height: 4),
            ],
            if (_selectedMerchant != null) ...[
              Text('Merchant: ${_selectedMerchant!.merchantName}'),
              const SizedBox(height: 4),
            ],
            if (_selectedStore != null) ...[
              Text('Store: ${_selectedStore!.storeName}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
            },
            child: Text(
              'OK',
              style: TextStyle(
                color: ThemeConfig.getPrimaryColor(currentTheme),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Error'),
          ],
        ),
        content: Text('Failed to create terminal:\n$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Try Again',
              style: TextStyle(
                color: ThemeConfig.getPrimaryColor(currentTheme),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // UI widget builders
  Widget _buildDropdown<T>({
    required String label,
    required String hint,
    required IconData icon,
    required T? value,
    required List<T> items,
    required Widget Function(T) itemBuilder,
    required void Function(T?) onChanged,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
          suffixIcon: isLoading
              ? Container(
                  width: 20,
                  height: 20,
                  padding: const EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ThemeConfig.getPrimaryColor(currentTheme),
                    ),
                  ),
                )
              : null,
        ),
        items: items
            .map(
              (item) =>
                  DropdownMenuItem<T>(value: item, child: itemBuilder(item)),
            )
            .toList(),
        onChanged: isEnabled && !isLoading ? onChanged : null,
      ),
    );
  }

  Widget _buildListTile({
    required String title,
    required IconData icon,
    String? imageUrl,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[200],
        ),
        child: imageUrl?.isNotEmpty == true && !imageUrl!.contains('undefined')
            ? ClipOval(
                child: Image.network(
                  imageUrl,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(icon, color: Colors.grey[600], size: 18);
                  },
                ),
              )
            : Icon(icon, color: Colors.grey[600], size: 18),
      ),
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? hint,
    TextInputAction? textInputAction,
    VoidCallback? onFieldSubmitted,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        validator: validator,
        textInputAction: textInputAction ?? TextInputAction.next,
        onFieldSubmitted: onFieldSubmitted != null
            ? (_) => onFieldSubmitted()
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
      ),
    );
  }

  // NEW: Enhanced serial number field with scanner
  Widget _buildSerialNumberField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _serialNumberController,
        focusNode: _serialNumberFocus,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.next,
        validator: (value) {
          if (value != null &&
              value.trim().isNotEmpty &&
              value.trim().length < 3) {
            return 'Serial number must be at least 3 characters';
          }
          return null;
        },
        onFieldSubmitted: (_) => _simNumberFocus.requestFocus(),
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
                  icon: Icon(Icons.clear, color: Colors.grey[600]),
                  onPressed: () {
                    setState(() {
                      _serialNumberController.clear();
                    });
                  },
                ),
              if (!kIsWeb) // Only show scanner on mobile
                IconButton(
                  icon: Icon(
                    Icons.qr_code_scanner,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                  onPressed: _scanBarcode,
                  tooltip: 'Scan Barcode',
                ),
            ],
          ),

          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
      ),
    );
  }

  // NEW: Date picker field widget
  Widget _buildDatePickerField({
    required String label,
    required IconData icon,
    required DateTime? selectedDate,
    required VoidCallback onTap,
    String? hint,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            hintText: hint ?? 'Select date',
            prefixIcon: Icon(
              icon,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            suffixIcon: Icon(
              Icons.calendar_today,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
          child: Text(
            selectedDate != null
                ? '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'
                : hint ?? 'Select date',
            style: TextStyle(
              color: selectedDate != null ? Colors.black87 : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      color: ThemeConfig.getPrimaryColor(currentTheme),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ThemeConfig.getPrimaryColor(currentTheme),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    // Get responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final imageSize = isWideScreen ? 200.0 : 180.0;

    return _buildSectionCard(
      title: 'Terminal Image (Optional)',
      icon: Icons.image,
      children: [
        Center(
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: imageSize,
              height: imageSize,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (kIsWeb ? _webImageBytes != null : _imageFile != null)
                      ? ThemeConfig.getPrimaryColor(currentTheme)
                      : Colors.grey[300]!,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildImageDisplay(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection() {
    return _buildSectionCard(
      title: 'Basic Information',
      icon: Icons.info,
      children: [
        _buildDropdown<Group>(
          label: 'Group',
          hint: _isLoadingGroups
              ? 'Loading groups...'
              : 'Select a group (optional)',
          icon: Icons.group,
          value: _selectedGroup,
          items: _groups,
          itemBuilder: (group) => _buildListTile(
            title: group.groupName,
            icon: Icons.group,
            imageUrl: group.imageUrl,
          ),
          onChanged: (Group? value) {
            setState(() {
              _selectedGroup = value;
              _selectedMerchant = null;
              _selectedStore = null;
              _merchants.clear();
              _stores.clear();
            });
            if (value != null) {
              _loadMerchants();
            }
          },
          isLoading: _isLoadingGroups,
        ),

        _buildDropdown<Merchant>(
          label: 'Merchant',
          hint: _selectedGroup == null
              ? 'Select a group first'
              : _isLoadingMerchants
              ? 'Loading merchants...'
              : 'Select a merchant (optional)',
          icon: Icons.business,
          value: _selectedMerchant,
          items: _merchants,
          itemBuilder: (merchant) => _buildListTile(
            title: merchant.merchantName,
            icon: Icons.business,
            imageUrl: merchant.imageUrl,
          ),
          onChanged: (Merchant? value) {
            setState(() {
              _selectedMerchant = value;
              _selectedStore = null;
              _stores.clear();
            });
            if (value != null) {
              _loadStores();
            }
          },
          isLoading: _isLoadingMerchants,
          isEnabled: _selectedGroup != null,
        ),

        _buildDropdown<Store>(
          label: 'Store',
          hint: _selectedMerchant == null
              ? 'Select a merchant first'
              : _isLoadingStores
              ? 'Loading stores...'
              : 'Select a store (optional)',
          icon: Icons.store,
          value: _selectedStore,
          items: _stores,
          itemBuilder: (store) => _buildListTile(
            title: store.storeName,
            icon: Icons.store,
            imageUrl: store.imageUrl,
          ),
          onChanged: (Store? value) {
            setState(() {
              _selectedStore = value;
            });
          },
          isLoading: _isLoadingStores,
          isEnabled: _selectedMerchant != null,
        ),

        _buildTextField(
          controller: _terminalNameController,
          label: 'Terminal Name *',
          icon: Icons.terminal,
          focusNode: _terminalNameFocus,
          hint: 'Enter terminal name',
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Terminal name is required';
            }
            if (value.trim().length < 2) {
              return 'Terminal name must be at least 2 characters';
            }
            return null;
          },
          onFieldSubmitted: () => _serialNumberFocus.requestFocus(),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfoSection() {
    return _buildSectionCard(
      title: 'Additional Information (Optional)',
      icon: Icons.settings,
      children: [
        _buildSerialNumberField(),

        // SIM Number field with new validation (minimum 8 digits)
        _buildTextField(
          controller: _simNumberController,
          label: 'SIM Number',
          icon: Icons.sim_card,
          focusNode: _simNumberFocus,
          hint: 'Enter SIM card number (minimum 8 digits)',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          validator: (value) {
            if (value != null && value.trim().isNotEmpty) {
              final digitsOnly = value.trim().replaceAll(RegExp(r'[^0-9]'), '');
              if (digitsOnly.length < 8) {
                return 'SIM number must have at least 8 digits';
              }
            }
            return null;
          },
          onFieldSubmitted: () => FocusScope.of(context).unfocus(),
        ),

        _buildDatePickerField(
          label: 'Expiry Date',
          icon: Icons.schedule,
          selectedDate: _selectedExpireDate,
          hint: 'Select expiry date (optional)',
          onTap: _selectExpireDate,
        ),

        if (_selectedExpireDate != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  _selectedExpireDate!.isBefore(
                    DateTime.now().add(const Duration(days: 30)),
                  )
                  ? Colors.orange[50]
                  : Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    _selectedExpireDate!.isBefore(
                      DateTime.now().add(const Duration(days: 30)),
                    )
                    ? Colors.orange[200]!
                    : Colors.green[200]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedExpireDate!.isBefore(DateTime.now())
                      ? Icons.error
                      : _selectedExpireDate!.isBefore(
                          DateTime.now().add(const Duration(days: 30)),
                        )
                      ? Icons.warning
                      : Icons.check_circle,
                  color: _selectedExpireDate!.isBefore(DateTime.now())
                      ? Colors.red
                      : _selectedExpireDate!.isBefore(
                          DateTime.now().add(const Duration(days: 30)),
                        )
                      ? Colors.orange
                      : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedExpireDate!.isBefore(DateTime.now())
                        ? 'Warning: This date is in the past'
                        : _selectedExpireDate!.isBefore(
                            DateTime.now().add(const Duration(days: 30)),
                          )
                        ? 'Warning: Expires within 30 days'
                        : 'Valid expiry date',
                    style: TextStyle(
                      fontSize: 12,
                      color: _selectedExpireDate!.isBefore(DateTime.now())
                          ? Colors.red[700]
                          : _selectedExpireDate!.isBefore(
                              DateTime.now().add(const Duration(days: 30)),
                            )
                          ? Colors.orange[700]
                          : Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final horizontalPadding = isWideScreen ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Add New Terminal'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
        actions: [
          if (_isLoading)
            Container(
              margin: EdgeInsets.all(16),
              width: 24,
              height: 24,
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
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isWideScreen ? 800 : double.infinity,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Terminal Image Section
                  _buildImageSection(),

                  SizedBox(height: 20),

                  // Basic Information
                  _buildFormSection(),

                  SizedBox(height: 20),

                  // Additional Information
                  _buildAdditionalInfoSection(),

                  SizedBox(height: 30),

                  // Create Button
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createTerminal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeConfig.getPrimaryColor(
                            currentTheme,
                          ),
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
                                        ThemeConfig.getButtonTextColor(
                                          currentTheme,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Text(
                                    'Creating Terminal...',
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
                                  Icon(Icons.add_circle, size: 24),
                                  SizedBox(width: 12),
                                  Text(
                                    'Create Terminal',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Barcode Scanner Page (Mobile Only)
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

// Custom painter for scanning overlay
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

    // Draw corner guides
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
