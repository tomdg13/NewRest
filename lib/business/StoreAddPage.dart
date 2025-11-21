import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;

// Import the postal code data
import 'postal_code_data.dart';

// Import MCC data
import 'mcc_data.dart';

// Existing Models
class Group {
  final int groupId;
  final String groupName;
  final String? imageUrl;

  const Group({
    required this.groupId,
    required this.groupName,
    this.imageUrl,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      groupId: json['group_id'] as int,
      groupName: json['group_name'] as String,
      imageUrl: json['image_url'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Group && other.groupId == groupId;
  }

  @override
  int get hashCode => groupId.hashCode;
}

class Merchant {
  final int merchantId;
  final String merchantName;
  final String? imageUrl;

  const Merchant({
    required this.merchantId,
    required this.merchantName,
    this.imageUrl,
  });

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      merchantId: json['merchant_id'] as int,
      merchantName: json['merchant_name'] as String,
      imageUrl: json['image_url'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Merchant && other.merchantId == merchantId;
  }

  @override
  int get hashCode => merchantId.hashCode;
}

class User {
  final int userId;
  final String userName;
  final String? phone;
  final String? email;

  const User({
    required this.userId,
    required this.userName,
    this.phone,
    this.email,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'] as int,
      userName: json['user_name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;
}

class StoreAddPage extends StatefulWidget {
  const StoreAddPage({Key? key}) : super(key: key);

  @override
  State<StoreAddPage> createState() => _StoreAddPageState();
}

class _StoreAddPageState extends State<StoreAddPage> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  
  // Transaction type constants
  static const List<String> _onlineTransactionTypes = [
    'Link Pay',
    'MOTO',
  ];
  
  static const List<String> _offlineTransactionTypes = [
    'Purchase',
    'Pre-authorization',
    'Pre-auth Comp',
    'Refund',
    'Cancel',
    'Reversal',
  ];
  
  // All Controllers
  late final TextEditingController _storeNameController;
  late final TextEditingController _storeManagerController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _countryController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _storeTypeController;
  late final TextEditingController _notesController;
  late final TextEditingController _upiPercentageController;
  late final TextEditingController _visaPercentageController;
  late final TextEditingController _masterPercentageController;
  late final TextEditingController _accountController;
  late final TextEditingController _account2Controller;
  late final TextEditingController _store_modeController;
  late final TextEditingController _webController;
  late final TextEditingController _email1Controller;
  late final TextEditingController _email2Controller;
  late final TextEditingController _email3Controller;
  late final TextEditingController _email4Controller;
  late final TextEditingController _email5Controller;
  late final TextEditingController _mccCodeController;
  late final TextEditingController _account_nameController;
  late final TextEditingController _cifController;
  late final TextEditingController _onlineTypeController;
  late final TextEditingController _offlineTypeController;

  // State Variables
  String? _storeMode;
  PostalCode? _selectedPostalCode;
  MccCode? _selectedMccCode;
  String? _base64Image;
  File? _imageFile;
  Uint8List? _webImageBytes;
  // ignore: unused_field
  String? _webImageName;
  bool _isLoading = false;
  bool _isLoadingGroups = false;
  bool _isLoadingMerchants = false;
  bool _isLoadingUsers = false;
  bool _isLoadingCif = false;
  String currentTheme = ThemeConfig.defaultTheme;

  // Cached data
  late final List<PostalCode> _cachedPostalCodes;
  late final List<MccCode> _cachedMccCodes;

  // Transaction types selection
  Set<String> _selectedOnlineTypes = {};
  Set<String> _selectedOfflineTypes = {};

  // CIF Account Selection
  List<Map<String, dynamic>> _cifAccounts = [];
  List<Map<String, dynamic>> _selectedAccounts = [];

  // Dropdown Data
  List<Group> _groups = [];
  Group? _selectedGroup;
  List<Merchant> _merchants = [];
  Merchant? _selectedMerchant;
  // ignore: unused_field
  List<User> _users = [];
  User? _selectedApprover1;
  User? _selectedApprover2;

  // Animation Controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeCachedData();
    _loadCurrentTheme();
    _setupAnimations();
    _loadUserPhone();
    _loadGroups();
    _loadUsers();
    
    // Set default MDR percentages to 3
    _upiPercentageController.text = '3';
    _visaPercentageController.text = '3';
    _masterPercentageController.text = '3';
  }

  void _initializeControllers() {
    _storeNameController = TextEditingController();
    _storeManagerController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _countryController = TextEditingController();
    _postalCodeController = TextEditingController();
    _storeTypeController = TextEditingController();
    _notesController = TextEditingController();
    _upiPercentageController = TextEditingController();
    _visaPercentageController = TextEditingController();
    _masterPercentageController = TextEditingController();
    _accountController = TextEditingController();
    _account2Controller = TextEditingController();
    _store_modeController = TextEditingController();
    _webController = TextEditingController();
    _email1Controller = TextEditingController();
    _email2Controller = TextEditingController();
    _email3Controller = TextEditingController();
    _email4Controller = TextEditingController();
    _email5Controller = TextEditingController();
    _mccCodeController = TextEditingController();
    _account_nameController = TextEditingController();
    _cifController = TextEditingController();
    _onlineTypeController = TextEditingController();
    _offlineTypeController = TextEditingController();
  }

  void _initializeCachedData() {
    _cachedPostalCodes = PostalCodeData.getAllPostalCodes();
    _cachedMccCodes = MccData.getAllMccCodes();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  void _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
      });
    }
  }

  void _loadUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final userPhone = prefs.getString('user');
    if (userPhone != null && userPhone.isNotEmpty && mounted) {
      _phoneController.text = userPhone;
    }
  }

  Future<void> _loadGroups() async {
    if (_isLoadingGroups) return;
    
    if (mounted) setState(() => _isLoadingGroups = true);
    
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

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          final List<dynamic> groupsJson = responseData['data'];
          if (mounted) {
            setState(() {
              _groups = groupsJson.map((json) => Group.fromJson(json)).toList();
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error loading groups: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingGroups = false);
      }
    }
  }

  Future<void> _loadMerchants() async {
    if (_selectedGroup == null || _isLoadingMerchants) return;
    
    if (mounted) {
      setState(() {
        _isLoadingMerchants = true;
        _merchants.clear();
        _selectedMerchant = null;
      });
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      final url = AppConfig.api('/api/iomerchant/company/$companyId/group/${_selectedGroup!.groupId}');
      
      final response = await http.get(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          final List<dynamic> merchantsJson = responseData['data'];
          if (mounted) {
            setState(() {
              _merchants = merchantsJson.map((json) => Merchant.fromJson(json)).toList();
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error loading merchants: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMerchants = false);
      }
    }
  }

  Future<void> _loadUsers() async {
    if (_isLoadingUsers) return;
    
    if (mounted) setState(() => _isLoadingUsers = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      final url = AppConfig.api('/api/iouser?company_id=$companyId');
      
      final response = await http.get(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          final List<dynamic> usersJson = responseData['data'];
          if (mounted) {
            setState(() {
              _users = usersJson.map((json) => User.fromJson(json)).toList();
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error loading users: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _fetchCifData() async {
    final cifValue = _cifController.text.trim();
    
    if (cifValue.isEmpty) {
      _showSnackBar(message: 'Please enter CIF number first', isError: true);
      return;
    }

    if (mounted) setState(() => _isLoadingCif = true);

    try {
      print('🔍 Fetching CIF data for: $cifValue');
      
      final response = await http.post(
        Uri.parse('https://dehome.ldblao.la/atm-api/v1/api/atmsystem/atm-system/cif-mapping-direct'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'customerId': cifValue}),
      );

      print('📥 CIF Response Status: ${response.statusCode}');
      print('📥 CIF Response Body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['response'] == '00' && responseData['data'] != null) {
          final atmData = responseData['data']['atmData'];
          final t24Data = atmData['t24_data'] as List<dynamic>?;
          
          if (t24Data != null && t24Data.isNotEmpty) {
            setState(() {
              _cifAccounts = t24Data.map((e) => e as Map<String, dynamic>).toList();
              _selectedAccounts.clear();
            });
            
            print('✅ Found ${_cifAccounts.length} accounts');
            _showAccountSelectionDialog();
          } else {
            _showSnackBar(message: 'No accounts found for this CIF', isError: true);
          }
        } else {
          throw Exception(responseData['data']?['message'] ?? 'Failed to fetch CIF data');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ CIF lookup error: $e');
      if (mounted) {
        _showSnackBar(message: 'Error fetching CIF data: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoadingCif = false);
    }
  }

  void _showAccountSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.account_balance, color: ThemeConfig.getPrimaryColor(currentTheme)),
              SizedBox(width: 12),
              Expanded(
                child: Text('Select Accounts (Max 2)', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_cifAccounts.isNotEmpty) ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_cifAccounts[0]['CUSTOMER_NAME1']}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          '${_cifAccounts[0]['CUSTOMER_NAME2']}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'CIF: ${_cifAccounts[0]['CUST_CIF']}',
                          style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _cifAccounts.length,
                    itemBuilder: (context, index) {
                      final account = _cifAccounts[index];
                      final isSelected = _selectedAccounts.contains(account);
                      final isInactive = account['INACTIV_MARKER'] == 'Y';
                      
                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        elevation: isSelected ? 4 : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected 
                                ? ThemeConfig.getPrimaryColor(currentTheme)
                                : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: CheckboxListTile(
                          value: isSelected,
                          enabled: !isInactive,
                          onChanged: (bool? checked) {
                            setDialogState(() {
                              if (checked == true) {
                                if (_selectedAccounts.length < 2) {
                                  _selectedAccounts.add(account);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Maximum 2 accounts can be selected'),
                                      backgroundColor: Colors.orange,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } else {
                                _selectedAccounts.remove(account);
                              }
                            });
                          },
                          activeColor: ThemeConfig.getPrimaryColor(currentTheme),
                          title: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isInactive 
                                      ? Colors.red[100]
                                      : ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  account['ACCTID'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isInactive ? Colors.red[700] : ThemeConfig.getPrimaryColor(currentTheme),
                                  ),
                                ),
                              ),
                              if (isInactive) ...[
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'INACTIVE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Category: ${account['CATEGORY']}',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: account['CURRENCY'] == 'LAK' 
                                            ? Colors.green[100]
                                            : Colors.blue[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        account['CURRENCY'],
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: account['CURRENCY'] == 'LAK' 
                                              ? Colors.green[700]
                                              : Colors.blue[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Balance: ${account['WORKING_BALANCE']} ${account['CURRENCY']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: _selectedAccounts.isEmpty
                  ? null
                  : () {
                      _applySelectedAccounts();
                      Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                foregroundColor: Colors.white,
              ),
              child: Text('Apply (${_selectedAccounts.length})'),
            ),
          ],
        ),
      ),
    );
  }

  void _applySelectedAccounts() {
    if (_selectedAccounts.isEmpty) return;

    _cifController.text = _selectedAccounts[0]['CUST_CIF'].toString();
    _account_nameController.text = _selectedAccounts[0]['CUSTOMER_NAME1'] ?? '';

    final lakAccount = _selectedAccounts.firstWhere(
      (acc) => acc['CURRENCY'] == 'LAK',
      orElse: () => _selectedAccounts[0],
    );
    _accountController.text = lakAccount['ACCTID'].toString();

    if (_selectedAccounts.length == 2) {
      final secondAccount = _selectedAccounts.firstWhere(
        (acc) => acc != lakAccount,
        orElse: () => _selectedAccounts[1],
      );
      _account2Controller.text = secondAccount['ACCTID'].toString();
    }

    setState(() {});
    
    _showSnackBar(
      message: 'CIF data applied successfully!',
      isError: false,
    );
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeManagerController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _postalCodeController.dispose();
    _storeTypeController.dispose();
    _notesController.dispose();
    _upiPercentageController.dispose();
    _visaPercentageController.dispose();
    _masterPercentageController.dispose();
    _accountController.dispose();
    _account2Controller.dispose();
    _store_modeController.dispose();
    _webController.dispose();
    _email1Controller.dispose();
    _email2Controller.dispose();
    _email3Controller.dispose();
    _email4Controller.dispose();
    _email5Controller.dispose();
    _mccCodeController.dispose();
    _account_nameController.dispose();
    _cifController.dispose();
    _onlineTypeController.dispose();
    _offlineTypeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        await _pickImageWeb();
      } else {
        await _pickImageMobile();
      }
    } catch (e) {
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
      if (file.size > 5 * 1024 * 1024) {
        _showSnackBar(message: 'Image size must be less than 5MB', isError: true);
        return;
      }

      final reader = html.FileReader();
      reader.onLoadEnd.listen((e) async {
        if (mounted) {
          final Uint8List bytes = reader.result as Uint8List;
          final compressedBytes = await _compressImageWeb(bytes);
          final String base64String = base64Encode(compressedBytes);
          
          setState(() {
            _webImageBytes = compressedBytes;
            _webImageName = file.name;
            _base64Image = 'data:image/jpeg;base64,$base64String';
          });

          _showSnackBar(message: 'Image selected and compressed successfully', isError: false);
        }
      });

      reader.readAsArrayBuffer(file);
    });
  }

  Future<Uint8List> _compressImageWeb(Uint8List imageBytes) async {
    try {
      final canvas = html.CanvasElement();
      final ctx = canvas.context2D;
      final img = html.ImageElement();
      final completer = Completer<Uint8List>();
      
      img.onLoad.listen((_) {
        double width = img.width!.toDouble();
        double height = img.height!.toDouble();
        
        if (width > 400 || height > 400) {
          if (width > height) {
            height = height * (400 / width);
            width = 400;
          } else {
            width = width * (400 / height);
            height = 400;
          }
        }
        
        canvas.width = width.round();
        canvas.height = height.round();
        ctx.drawImageScaled(img, 0, 0, width, height);
        
        try {
          final dataUrl = canvas.toDataUrl('image/jpeg', 0.6);
          final base64Data = dataUrl.split(',')[1];
          completer.complete(base64Decode(base64Data));
        } catch (e) {
          completer.complete(imageBytes);
        }
      });
      
      img.onError.listen((_) => completer.complete(imageBytes));
      
      final blob = html.Blob([imageBytes]);
      img.src = html.Url.createObjectUrlFromBlob(blob);
      
      return await completer.future.timeout(
        Duration(seconds: 10),
        onTimeout: () => imageBytes,
      );
    } catch (e) {
      return imageBytes;
    }
  }

  Future<void> _pickImageMobile() async {
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
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 60,
    );

    if (image != null && mounted) {
      final File imageFile = File(image.path);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64String = base64Encode(imageBytes);
      
      setState(() {
        _imageFile = imageFile;
        _base64Image = 'data:image/jpeg;base64,$base64String';
      });

      _showSnackBar(message: 'Image selected successfully', isError: false);
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

  Widget _buildImageDisplay() {
    if (kIsWeb && _webImageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
                child: Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (!kIsWeb && _imageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo, size: 48, color: ThemeConfig.getPrimaryColor(currentTheme)),
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
            'Recommended: 400x400px',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      );
    }
  }

  Future<void> _createStore() async {
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate()) {
      _showSnackBar(message: 'Please fill in all required fields', isError: true);
      return;
    }

    if (_storeMode == null || _storeMode!.isEmpty) {
      _showSnackBar(message: 'Please select a store mode', isError: true);
      return;
    }

    // Validate transaction types based on store mode
    if (_storeMode == 'online' && _selectedOnlineTypes.isEmpty) {
      _showSnackBar(message: 'Please select at least one online transaction type', isError: true);
      return;
    }

    if (_storeMode == 'offline' && _selectedOfflineTypes.isEmpty) {
      _showSnackBar(message: 'Please select at least one offline transaction type', isError: true);
      return;
    }

    if (_storeMode == 'hybrid') {
      if (_selectedOnlineTypes.isEmpty && _selectedOfflineTypes.isEmpty) {
        _showSnackBar(message: 'Please select at least one transaction type', isError: true);
        return;
      }
    }

    if (_storeMode == 'online' || _storeMode == 'hybrid') {
      if (_webController.text.trim().isEmpty) {
        _showSnackBar(message: 'Website is required for online stores', isError: true);
        return;
      }
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();

      final url = AppConfig.api('/api/iostore');

      // Combine transaction types
      final List<String> allTransactionTypes = [];
      
      if (_storeMode == 'online') {
        allTransactionTypes.addAll(_selectedOnlineTypes.toList());
      } else if (_storeMode == 'offline') {
        allTransactionTypes.addAll(_selectedOfflineTypes.toList());
      } else if (_storeMode == 'hybrid') {
        allTransactionTypes.addAll(_selectedOnlineTypes.toList());
        allTransactionTypes.addAll(_selectedOfflineTypes.toList());
      }
      
      final String? combinedStoreType = allTransactionTypes.isNotEmpty 
          ? allTransactionTypes.join(', ')
          : null;

      print('📤 Creating Store:');
      print('  Store Mode: $_storeMode');
      print('  Store Type (Transaction Types): $combinedStoreType');
      print('  Online Types: $_selectedOnlineTypes');
      print('  Offline Types: $_selectedOfflineTypes');

      final storeData = {
        'company_id': companyId.toString(),
        'group_id': _selectedGroup?.groupId,
        'merchant_id': _selectedMerchant?.merchantId,
        'store_name': _storeNameController.text.trim(),
        'store_manager': _getTextOrNull(_storeManagerController),
        'email': _getTextOrNull(_emailController),
        'phone': _getTextOrNull(_phoneController),
        'address': _getTextOrNull(_addressController),
        'city': _getTextOrNull(_cityController),
        'state': _getTextOrNull(_stateController),
        'country': _getTextOrNull(_countryController),
        'postal_code': _getTextOrNull(_postalCodeController),
        'mcc': _selectedMccCode?.code,
        'store_type': combinedStoreType,
        'notes': _getTextOrNull(_notesController),
        'upi_percentage': _parseDoubleOrNull(_upiPercentageController),
        'visa_percentage': _parseDoubleOrNull(_visaPercentageController),
        'master_percentage': _parseDoubleOrNull(_masterPercentageController),
        'account': _getTextOrNull(_accountController),
        'account2': _getTextOrNull(_account2Controller),
        'store_mode': _getTextOrNull(_store_modeController),
        'web': _getTextOrNull(_webController),
        'email1': _getTextOrNull(_email1Controller),
        'email2': _getTextOrNull(_email2Controller),
        'email3': _getTextOrNull(_email3Controller),
        'email4': _getTextOrNull(_email4Controller),
        'email5': _getTextOrNull(_email5Controller),
        'account_name': _getTextOrNull(_account_nameController),
        'cif': _getTextOrNull(_cifController),
        'approve1': _selectedApprover1?.userId,
        'approve2': _selectedApprover2?.userId,
      };

      if (_base64Image != null) {
        storeData['image'] = _base64Image!;
      }

      final response = await http.post(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(storeData),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['status'] == 'success') {
          _showSuccessDialog();
        } else {
          throw Exception(responseData['message'] ?? 'Unknown error');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) _showErrorDialog(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _getTextOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  double? _parseDoubleOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : double.tryParse(text);
  }

  void _showSnackBar({required String message, required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showSuccessDialog() {
    if (!mounted) return;
    
    String approvalInfo = '';
    if (_selectedApprover1 != null || _selectedApprover2 != null) {
      approvalInfo = '\n\nApprovers assigned:';
      if (_selectedApprover1 != null) {
        approvalInfo += '\n✓ ${_selectedApprover1!.userName}';
      }
      if (_selectedApprover2 != null) {
        approvalInfo += '\n✓ ${_selectedApprover2!.userName}';
      }
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Store Created!')),
          ],
        ),
        content: Text('Store "${_storeNameController.text}" has been created successfully!$approvalInfo'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
            },
            child: Text('OK', style: TextStyle(color: ThemeConfig.getPrimaryColor(currentTheme))),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Error'),
          ],
        ),
        content: Text('Failed to create store:\n$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Try Again', style: TextStyle(color: ThemeConfig.getPrimaryColor(currentTheme))),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? hint,
    bool enabled = true,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: ThemeConfig.getPrimaryColor(currentTheme)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ThemeConfig.getPrimaryColor(currentTheme), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required String Function(T) getDisplayText,
    required void Function(T?)? onChanged,
    bool isLoading = false,
    String? hint,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: ThemeConfig.getPrimaryColor(currentTheme)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ThemeConfig.getPrimaryColor(currentTheme), width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: isLoading ? SizedBox(
            width: 20,
            height: 20,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ) : null,
        ),
        items: items.map((item) => DropdownMenuItem<T>(
          value: item,
          child: Text(getDisplayText(item)),
        )).toList(),
        onChanged: isLoading ? null : onChanged,
        menuMaxHeight: 200,
      ),
    );
  }

  Widget _buildPostalCodeDropdown() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Autocomplete<PostalCode>(
        displayStringForOption: (PostalCode option) => 
            '${option.code} - ${option.district}, ${option.province}',
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text == '') {
            return _cachedPostalCodes.take(10);
          }
          final String query = textEditingValue.text.toLowerCase();
          return _cachedPostalCodes.where((PostalCode option) {
            return option.code.toLowerCase().contains(query) ||
                   option.district.toLowerCase().contains(query) ||
                   option.province.toLowerCase().contains(query);
          }).take(20);
        },
        onSelected: (PostalCode selection) {
          _selectedPostalCode = selection;
          _postalCodeController.text = selection.code;
          setState(() {});
        },
        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
          if (_selectedPostalCode != null && controller.text.isEmpty) {
            controller.text = '${_selectedPostalCode!.code} - ${_selectedPostalCode!.district}, ${_selectedPostalCode!.province}';
          }
          
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            onEditingComplete: onEditingComplete,
            validator: (value) {
              if (_selectedPostalCode == null || _postalCodeController.text.isEmpty) {
                return 'Postal code is required';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Postal Code *',
              hintText: 'Type to search postal codes...',
              prefixIcon: Icon(
                Icons.local_post_office,
                color: ThemeConfig.getPrimaryColor(currentTheme),
              ),
              suffixIcon: Icon(
                Icons.search,
                color: Colors.grey[600],
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
              fillColor: Colors.white,
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: BoxConstraints(maxHeight: 200, maxWidth: 400),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final PostalCode option = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: index < options.length - 1
                              ? Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                option.code,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeConfig.getPrimaryColor(currentTheme),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.district,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    option.province,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMccCodeDropdown() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Autocomplete<MccCode>(
        displayStringForOption: (MccCode option) => 
            '${option.code} - ${option.nameEnglish} (${option.nameLao})',
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text == '') {
            return _cachedMccCodes.take(10);
          }
          final String query = textEditingValue.text.toLowerCase();
          return _cachedMccCodes.where((MccCode option) {
            return option.code.toLowerCase().contains(query) ||
                   option.nameEnglish.toLowerCase().contains(query) ||
                   option.nameLao.toLowerCase().contains(query) ||
                   option.category.toLowerCase().contains(query);
          }).take(20);
        },
        onSelected: (MccCode selection) {
          _selectedMccCode = selection;
          _mccCodeController.text = selection.code;
          setState(() {});
        },
        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
          if (_selectedMccCode != null && controller.text.isEmpty) {
            controller.text = '${_selectedMccCode!.code} - ${_selectedMccCode!.nameEnglish}';
          }
          
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            onEditingComplete: onEditingComplete,
            validator: (value) {
              if (_selectedMccCode == null || _mccCodeController.text.isEmpty) {
                return 'MCC code is required';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: 'MCC Code *',
              hintText: 'Type to search MCC codes...',
              prefixIcon: Icon(
                Icons.category,
                color: ThemeConfig.getPrimaryColor(currentTheme),
              ),
              suffixIcon: Icon(
                Icons.search,
                color: Colors.grey[600],
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
              fillColor: Colors.white,
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: BoxConstraints(maxHeight: 200, maxWidth: 500),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final MccCode option = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: index < options.length - 1
                              ? Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                option.code,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeConfig.getPrimaryColor(currentTheme),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.nameEnglish,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    option.nameLao,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Category: ${option.category}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                      fontStyle: FontStyle.italic,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStoreModeRadio() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          // Online Option
          RadioListTile<String>(
            title: Text('Online'),
            value: 'online',
            groupValue: _storeMode,
            onChanged: (String? value) {
              setState(() {
                _storeMode = value;
                _store_modeController.text = value ?? '';
              });
            },
            activeColor: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          
          // Online Transaction Types (shown when online is selected)
          if (_storeMode == 'online')
            Container(
              margin: EdgeInsets.only(left: 16, right: 16, bottom: 12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.language, size: 16, color: Colors.blue[700]),
                        SizedBox(width: 8),
                        Text(
                          'Online Transaction Types *',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        Spacer(),
                        if (_selectedOnlineTypes.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue[700],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_selectedOnlineTypes.length}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...List.generate(_onlineTransactionTypes.length, (index) {
                    final transactionType = _onlineTransactionTypes[index];
                    final isSelected = _selectedOnlineTypes.contains(transactionType);
                    
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (bool? checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedOnlineTypes.add(transactionType);
                          } else {
                            _selectedOnlineTypes.remove(transactionType);
                          }
                          _onlineTypeController.text = _selectedOnlineTypes.join(', ');
                        });
                      },
                      title: Text(
                        transactionType,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      activeColor: Colors.blue[700],
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    );
                  }),
                ],
              ),
            ),

          if (_storeMode != 'online') Divider(height: 1),

          // Offline Option
          RadioListTile<String>(
            title: Text('Offline'),
            value: 'offline',
            groupValue: _storeMode,
            onChanged: (String? value) {
              setState(() {
                _storeMode = value;
                _store_modeController.text = value ?? '';
              });
            },
            activeColor: ThemeConfig.getPrimaryColor(currentTheme),
          ),

          // Offline Transaction Types (shown when offline is selected)
          if (_storeMode == 'offline')
            Container(
              margin: EdgeInsets.only(left: 16, right: 16, bottom: 12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.store, size: 16, color: Colors.green[700]),
                        SizedBox(width: 8),
                        Text(
                          'Offline Transaction Types *',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                        Spacer(),
                        if (_selectedOfflineTypes.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green[700],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_selectedOfflineTypes.length}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...List.generate(_offlineTransactionTypes.length, (index) {
                    final transactionType = _offlineTransactionTypes[index];
                    final isSelected = _selectedOfflineTypes.contains(transactionType);
                    
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (bool? checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedOfflineTypes.add(transactionType);
                          } else {
                            _selectedOfflineTypes.remove(transactionType);
                          }
                          _offlineTypeController.text = _selectedOfflineTypes.join(', ');
                        });
                      },
                      title: Text(
                        transactionType,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      activeColor: Colors.green[700],
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    );
                  }),
                ],
              ),
            ),

          if (_storeMode != 'offline') Divider(height: 1),

          // Hybrid Option
          RadioListTile<String>(
            title: Text('Online + Offline (Hybrid)'),
            value: 'hybrid',
            groupValue: _storeMode,
            onChanged: (String? value) {
              setState(() {
                _storeMode = value;
                _store_modeController.text = value ?? '';
              });
            },
            activeColor: ThemeConfig.getPrimaryColor(currentTheme),
          ),

          // Hybrid Transaction Types (shown when hybrid is selected)
          if (_storeMode == 'hybrid')
            Container(
              margin: EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Column(
                children: [
                  // Online Types
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.language, size: 16, color: Colors.blue[700]),
                              SizedBox(width: 8),
                              Text(
                                'Online Transaction Types',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                              Spacer(),
                              if (_selectedOnlineTypes.isNotEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[700],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_selectedOnlineTypes.length}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        ...List.generate(_onlineTransactionTypes.length, (index) {
                          final transactionType = _onlineTransactionTypes[index];
                          final isSelected = _selectedOnlineTypes.contains(transactionType);
                          
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (bool? checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedOnlineTypes.add(transactionType);
                                } else {
                                  _selectedOnlineTypes.remove(transactionType);
                                }
                                _onlineTypeController.text = _selectedOnlineTypes.join(', ');
                              });
                            },
                            title: Text(
                              transactionType,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            activeColor: Colors.blue[700],
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          );
                        }),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 12),

                  // Offline Types
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.store, size: 16, color: Colors.green[700]),
                              SizedBox(width: 8),
                              Text(
                                'Offline Transaction Types',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                              Spacer(),
                              if (_selectedOfflineTypes.isNotEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green[700],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_selectedOfflineTypes.length}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        ...List.generate(_offlineTransactionTypes.length, (index) {
                          final transactionType = _offlineTransactionTypes[index];
                          final isSelected = _selectedOfflineTypes.contains(transactionType);
                          
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (bool? checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedOfflineTypes.add(transactionType);
                                } else {
                                  _selectedOfflineTypes.remove(transactionType);
                                }
                                _offlineTypeController.text = _selectedOfflineTypes.join(', ');
                              });
                            },
                            title: Text(
                              transactionType,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            activeColor: Colors.green[700],
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Add New Store',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Store Image Section
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                            'Store Image (Optional)',
                            style: TextStyle(
                              fontSize: 20,
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
                            width: 200,
                            height: 200,
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
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _buildImageDisplay(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Basic Information Section
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Basic Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                        ),
                      ),
                      SizedBox(height: 16),

                      _buildDropdown<Group>(
                        label: 'Select Group',
                        icon: Icons.group,
                        value: _selectedGroup,
                        items: _groups,
                        getDisplayText: (group) => group.groupName,
                        onChanged: (Group? group) {
                          setState(() {
                            _selectedGroup = group;
                            _selectedMerchant = null;
                          });
                          if (group != null) {
                            _loadMerchants();
                          }
                        },
                        isLoading: _isLoadingGroups,
                        hint: 'Choose a group...',
                      ),

                      _buildDropdown<Merchant>(
                        label: 'Select Merchant',
                        icon: Icons.business,
                        value: _selectedMerchant,
                        items: _merchants,
                        getDisplayText: (merchant) => merchant.merchantName,
                        onChanged: (Merchant? merchant) {
                          setState(() {
                            _selectedMerchant = merchant;
                          });
                        },
                        isLoading: _isLoadingMerchants,
                        hint: _selectedGroup == null ? 'Select a group first' : 'Choose a merchant...',
                      ),

                      _buildTextField(
                        controller: _storeNameController,
                        label: 'Store Name *',
                        icon: Icons.store,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Store name is required';
                          }
                          return null;
                        },
                        hint: 'Enter store name',
                      ),

                      _buildTextField(
                        controller: _storeManagerController,
                        label: 'Store Manager',
                        icon: Icons.person,
                        hint: 'Enter manager name',
                      ),

                      Row(
                        children: [
                          Text(
                            'Store Mode',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            ' *',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      _buildStoreModeRadio(),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Address Information Section
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Address Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                        ),
                      ),
                      SizedBox(height: 16),

                      _buildTextField(
                        controller: _addressController,
                        label: 'Address',
                        icon: Icons.location_on,
                        maxLines: 2,
                        hint: 'Enter full address',
                      ),

                      _buildTextField(
                        controller: _cityController,
                        label: 'City',
                        icon: Icons.location_city,
                        hint: 'Enter city',
                      ),

                      _buildTextField(
                        controller: _stateController,
                        label: 'State/Province',
                        icon: Icons.map,
                        hint: 'Enter state or province',
                      ),

                      _buildTextField(
                        controller: _countryController,
                        label: 'Country',
                        icon: Icons.flag,
                        hint: 'Enter country',
                      ),

                      _buildPostalCodeDropdown(),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Business Information Section
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Business Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                        ),
                      ),
                      SizedBox(height: 16),

                      _buildMccCodeDropdown(),

                      _buildTextField(
                        controller: _notesController,
                        label: 'Notes',
                        icon: Icons.note,
                        maxLines: 3,
                        hint: 'Any additional notes about the store',
                      ),
                    ],
                  ),
                ),

                // Online Store Information (Conditional)
                if (_storeMode == 'online' || _storeMode == 'hybrid') ...[
                  SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.language,
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Online Store Information',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: ThemeConfig.getPrimaryColor(currentTheme),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        _buildTextField(
                          controller: _webController,
                          label: 'Website URL *',
                          icon: Icons.web,
                          keyboardType: TextInputType.url,
                          hint: 'https://example.com',
                          validator: (_storeMode == 'online' || _storeMode == 'hybrid') 
                              ? (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Website is required for online stores';
                                  }
                                  return null;
                                }
                              : null,
                        ),

                        Text(
                          'Additional Email Addresses',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),

                        _buildTextField(
                          controller: _email1Controller,
                          label: 'Email 1 *',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          hint: 'Additional email address',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email 1 is required';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                              return 'Enter valid email';
                            }
                            return null;
                          },
                        ),

                        _buildTextField(
                          controller: _email2Controller,
                          label: 'Email 2',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          hint: 'Additional email address',
                        ),

                        _buildTextField(
                          controller: _email3Controller,
                          label: 'Email 3',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          hint: 'Additional email address',
                        ),

                        _buildTextField(
                          controller: _email4Controller,
                          label: 'Email 4',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          hint: 'Additional email address',
                        ),

                        _buildTextField(
                          controller: _email5Controller,
                          label: 'Email 5',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          hint: 'Additional email address',
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 20),

                // Payment Information Section
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.payment,
                            color: ThemeConfig.getPrimaryColor(currentTheme),
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Payment Information',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: ThemeConfig.getPrimaryColor(currentTheme),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      Row(
                        children: [
                          Text(
                            'MDR Percentages',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            ' *',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _upiPercentageController,
                              label: 'UPI % *',
                              icon: Icons.account_balance_wallet,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              hint: '0.00 - 3.00',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'UPI % is required';
                                }
                                final numValue = double.tryParse(value.trim());
                                if (numValue == null) {
                                  return 'Invalid number';
                                }
                                if (numValue < 0 || numValue > 3) {
                                  return 'Must be 0-3';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _visaPercentageController,
                              label: 'Visa % *',
                              icon: Icons.credit_card,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              hint: '0.00 - 3.00',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Visa % is required';
                                }
                                final numValue = double.tryParse(value.trim());
                                if (numValue == null) {
                                  return 'Invalid number';
                                }
                                if (numValue < 0 || numValue > 3) {
                                  return 'Must be 0-3';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      _buildTextField(
                        controller: _masterPercentageController,
                        label: 'Mastercard % *',
                        icon: Icons.credit_card,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        hint: '0.00 - 3.00',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Mastercard % is required';
                          }
                          final numValue = double.tryParse(value.trim());
                          if (numValue == null) {
                            return 'Invalid number';
                          }
                          if (numValue < 0 || numValue > 3) {
                            return 'Must be between 0 and 3';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 8),
                      Divider(color: Colors.grey[200]),
                      SizedBox(height: 8),

                      Row(
                        children: [
                          Text(
                            'Account Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            ' *',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _cifController,
                              label: 'CIF *',
                              icon: Icons.fingerprint,
                              hint: 'Customer ID',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'CIF is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          Container(
                            margin: EdgeInsets.only(bottom: 16),
                            child: ElevatedButton.icon(
                              onPressed: _isLoadingCif ? null : _fetchCifData,
                              icon: _isLoadingCif
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Icon(Icons.search, size: 20),
                              label: Text('Lookup'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      _buildTextField(
                        controller: _account_nameController,
                        label: 'Account Name *',
                        icon: Icons.person_outline,
                        hint: 'Account holder name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Account name is required';
                          }
                          return null;
                        },
                      ),

                      _buildTextField(
                        controller: _accountController,
                        label: 'Account Number (LAK) *',
                        icon: Icons.account_balance,
                        hint: 'Primary account number',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Account number is required';
                          }
                          return null;
                        },
                      ),

                      _buildTextField(
                        controller: _account2Controller,
                        label: 'Account Number 2 (Optional)',
                        icon: Icons.account_balance,
                        hint: 'Secondary account number',
                      ),
                    ],
                  ),
                ),

                // SizedBox(height: 20),

                // // Contact Information Section
                // Container(
                //   padding: EdgeInsets.all(20),
                //   decoration: BoxDecoration(
                //     color: Colors.white,
                //     borderRadius: BorderRadius.circular(16),
                //     boxShadow: [
                //       BoxShadow(
                //         color: Colors.black.withOpacity(0.05),
                //         blurRadius: 10,
                //         offset: Offset(0, 2),
                //       ),
                //     ],
                //   ),
                //   child: Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Row(
                //         children: [
                //           Icon(
                //             Icons.contacts,
                //             color: ThemeConfig.getPrimaryColor(currentTheme),
                //             size: 24,
                //           ),
                //           SizedBox(width: 12),
                //           Text(
                //             'Contact Information',
                //             style: TextStyle(
                //               fontSize: 20,
                //               fontWeight: FontWeight.bold,
                //               color: ThemeConfig.getPrimaryColor(currentTheme),
                //             ),
                //           ),
                //         ],
                //       ),
                //       SizedBox(height: 16),

                //       _buildTextField(
                //         controller: _emailController,
                //         label: 'Email',
                //         icon: Icons.email,
                //         keyboardType: TextInputType.emailAddress,
                //         hint: 'store@example.com',
                //         validator: (value) {
                //           if (value != null && value.trim().isNotEmpty) {
                //             if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                //               return 'Enter a valid email address';
                //             }
                //           }
                //           return null;
                //         },
                //       ),

                //       _buildTextField(
                //         controller: _phoneController,
                //         label: 'Phone Number',
                //         icon: Icons.phone,
                //         keyboardType: TextInputType.phone,
                //         hint: '+856 20 XXXX XXXX',
                //       ),
                //     ],
                //   ),
                // ),

                // SizedBox(height: 20),

                // // Approvers Section
                // Container(
                //   padding: EdgeInsets.all(20),
                //   decoration: BoxDecoration(
                //     color: Colors.white,
                //     borderRadius: BorderRadius.circular(16),
                //     boxShadow: [
                //       BoxShadow(
                //         color: Colors.black.withOpacity(0.05),
                //         blurRadius: 10,
                //         offset: Offset(0, 2),
                //       ),
                //     ],
                //   ),
                //   child: Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Row(
                //         children: [
                //           Icon(
                //             Icons.how_to_reg,
                //             color: ThemeConfig.getPrimaryColor(currentTheme),
                //             size: 24,
                //           ),
                //           SizedBox(width: 12),
                //           Text(
                //             'Approvers (Optional)',
                //             style: TextStyle(
                //               fontSize: 20,
                //               fontWeight: FontWeight.bold,
                //               color: ThemeConfig.getPrimaryColor(currentTheme),
                //             ),
                //           ),
                //         ],
                //       ),
                //       SizedBox(height: 16),

                //       _buildDropdown<User>(
                //         label: 'Approver 1',
                //         icon: Icons.person_add,
                //         value: _selectedApprover1,
                //         items: _users,
                //         getDisplayText: (user) => user.userName,
                //         onChanged: (User? user) {
                //           setState(() {
                //             _selectedApprover1 = user;
                //           });
                //         },
                //         isLoading: _isLoadingUsers,
                //         hint: 'Select first approver...',
                //       ),

                //       _buildDropdown<User>(
                //         label: 'Approver 2',
                //         icon: Icons.person_add,
                //         value: _selectedApprover2,
                //         items: _users,
                //         getDisplayText: (user) => user.userName,
                //         onChanged: (User? user) {
                //           setState(() {
                //             _selectedApprover2 = user;
                //           });
                //         },
                //         isLoading: _isLoadingUsers,
                //         hint: 'Select second approver...',
                //       ),
                //     ],
                //   ),
                // ),

                SizedBox(height: 30),

                // Submit Button
                Container(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 16),
                              Text(
                                'Creating Store...',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_business, size: 24),
                              SizedBox(width: 12),
                              Text(
                                'Create Store',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}