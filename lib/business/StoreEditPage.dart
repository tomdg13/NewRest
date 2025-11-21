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

// User Model
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

class StoreEditPage extends StatefulWidget {
  final Map<String, dynamic> storeData;

  const StoreEditPage({Key? key, required this.storeData}) : super(key: key);

  @override
  State<StoreEditPage> createState() => _StoreEditPageState();
}

class _StoreEditPageState extends State<StoreEditPage> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  
  // All Controllers
  late final TextEditingController _storeNameController;
  late final TextEditingController _storeCodeController;
  late final TextEditingController _storeManagerController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _countryController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _storeTypeController;
  late final TextEditingController _statusController;
  late final TextEditingController _openingHoursController;
  late final TextEditingController _squareFootageController;
  late final TextEditingController _notesController;
  late final TextEditingController _upiPercentageController;
  late final TextEditingController _visaPercentageController;
  late final TextEditingController _masterPercentageController;
  late final TextEditingController _accountController;
  late final TextEditingController _account2Controller;
  late final TextEditingController _webController;
  late final TextEditingController _email1Controller;
  late final TextEditingController _email2Controller;
  late final TextEditingController _email3Controller;
  late final TextEditingController _email4Controller;
  late final TextEditingController _email5Controller;
  late final TextEditingController _storeModeController;
  late final TextEditingController _mccCodeController;
  late final TextEditingController _account_nameController;
  late final TextEditingController _cifController;
  late final TextEditingController _onlineTypeController;
  late final TextEditingController _offlineTypeController;

  // Store Type Constants - REMOVED (not needed anymore)
  
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

  // State Variables
  String? _storeMode;
  PostalCode? _selectedPostalCode;
  MccCode? _selectedMccCode;
  String? _base64Image;
  String? _currentImageUrl;
  File? _imageFile;
  Uint8List? _webImageBytes;
  // ignore: unused_field
  String? _webImageName;
  bool _isLoading = false;
  bool _isDeleting = false;
  bool _isLoadingCif = false;
  String currentTheme = ThemeConfig.defaultTheme;

  // Cached data for better performance
  late final List<PostalCode> _cachedPostalCodes;
  late final List<MccCode> _cachedMccCodes;

  // Store types selection - REMOVED (not needed anymore)

  // Transaction types selection
  Set<String> _selectedOnlineTypes = {};
  Set<String> _selectedOfflineTypes = {};

  // CIF Account Selection
  List<Map<String, dynamic>> _cifAccounts = [];
  List<Map<String, dynamic>> _selectedAccounts = [];

  // Approval state variables
  List<User> _users = [];
  User? _selectedApprover1;
  // ignore: unused_field
  User? _selectedApprover2;
  bool _isLoadingUsers = false;

  // Animation Controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeCachedData();
    _loadCurrentTheme();
    _initializeControllers();
    _setupAnimations();
    _loadUsers();
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

  Future<void> _loadUsers() async {
    if (_isLoadingUsers) return;
    
    if (mounted) setState(() => _isLoadingUsers = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      final currentUserPhone = prefs.getString('phone');
      
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
              
              if (widget.storeData['approve1'] != null) {
                final approve1Id = widget.storeData['approve1'];
                _selectedApprover1 = _users.firstWhere(
                  (user) => user.userId == approve1Id,
                  orElse: () => _users.isNotEmpty ? _users.first : User(userId: 0, userName: ''),
                );
              } else if (currentUserPhone != null && currentUserPhone.isNotEmpty) {
                _selectedApprover1 = _users.firstWhere(
                  (user) => user.phone == currentUserPhone,
                  orElse: () => _users.isNotEmpty ? _users.first : User(userId: 0, userName: ''),
                );
              }
              
              if (widget.storeData['approve2'] != null) {
                final approve2Id = widget.storeData['approve2'];
                _selectedApprover2 = _users.firstWhere(
                  (user) => user.userId == approve2Id,
                  orElse: () => _users.isNotEmpty ? _users.first : User(userId: 0, userName: ''),
                );
              } else if (_selectedApprover1 == null && currentUserPhone != null && currentUserPhone.isNotEmpty) {
                _selectedApprover2 = _users.firstWhere(
                  (user) => user.phone == currentUserPhone,
                  orElse: () => _users.isNotEmpty ? _users.first : User(userId: 0, userName: ''),
                );
              }
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

  void _initializeControllers() {
    _storeNameController = TextEditingController(text: widget.storeData['store_name'] ?? '');
    _currentImageUrl = widget.storeData['image_url'];
    _storeCodeController = TextEditingController(text: widget.storeData['store_code'] ?? '');
    _storeManagerController = TextEditingController(text: widget.storeData['store_manager'] ?? '');
    _emailController = TextEditingController(text: widget.storeData['email'] ?? '');
    _phoneController = TextEditingController(text: widget.storeData['phone'] ?? '');
    _addressController = TextEditingController(text: widget.storeData['address'] ?? '');
    _cityController = TextEditingController(text: widget.storeData['city'] ?? '');
    _stateController = TextEditingController(text: widget.storeData['state'] ?? '');
    _countryController = TextEditingController(text: widget.storeData['country'] ?? '');
    _postalCodeController = TextEditingController(text: widget.storeData['postal_code'] ?? '');
    _storeTypeController = TextEditingController(text: widget.storeData['store_type'] ?? '');
    _statusController = TextEditingController(text: widget.storeData['status'] ?? '');
    _openingHoursController = TextEditingController(text: widget.storeData['opening_hours'] ?? '');
    _squareFootageController = TextEditingController(text: widget.storeData['square_footage']?.toString() ?? '');
    _notesController = TextEditingController(text: widget.storeData['notes'] ?? '');
    
    // Set MDR percentages with default 3 if empty
    _upiPercentageController = TextEditingController(text: widget.storeData['upi_percentage']?.toString() ?? '3');
    _visaPercentageController = TextEditingController(text: widget.storeData['visa_percentage']?.toString() ?? '3');
    _masterPercentageController = TextEditingController(text: widget.storeData['master_percentage']?.toString() ?? '3');
    
    _accountController = TextEditingController(text: widget.storeData['account'] ?? '');
    _account2Controller = TextEditingController(text: widget.storeData['account2'] ?? '');
    _webController = TextEditingController(text: widget.storeData['web'] ?? '');
    _email1Controller = TextEditingController(text: widget.storeData['email1'] ?? '');
    _email2Controller = TextEditingController(text: widget.storeData['email2'] ?? '');
    _email3Controller = TextEditingController(text: widget.storeData['email3'] ?? '');
    _email4Controller = TextEditingController(text: widget.storeData['email4'] ?? '');
    _email5Controller = TextEditingController(text: widget.storeData['email5'] ?? '');
    _mccCodeController = TextEditingController();
    _account_nameController = TextEditingController(text: widget.storeData['account_name'] ?? '');
    _cifController = TextEditingController(text: widget.storeData['cif'] ?? '');
    _onlineTypeController = TextEditingController();
    _offlineTypeController = TextEditingController();
    
    _storeMode = widget.storeData['store_mode'];
    _storeModeController = TextEditingController(text: widget.storeData['store_mode'] ?? '');
    
    print('\n🔄 ========== INITIALIZING TRANSACTION TYPES ==========');
    print('Store Mode from data: $_storeMode');
    print('Store Type from data: ${widget.storeData['store_type']}');
    
    // ✅ INITIALIZE TRANSACTION TYPES from store_type field
    // Clear any existing selections first
    _selectedOnlineTypes.clear();
    _selectedOfflineTypes.clear();
    
    if (widget.storeData['store_type'] != null) {
      final storeType = widget.storeData['store_type'].toString().trim();
      print('Store Type value: "$storeType"');
      
      if (storeType.isNotEmpty) {
        // Split the comma-separated transaction types
        final types = storeType.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        print('Split into ${types.length} types: $types');
        
        // Separate online and offline types
        print('\nChecking each type:');
        for (var type in types) {
          print('  Type: "$type"');
          
          final isOnlineType = _onlineTransactionTypes.contains(type);
          final isOfflineType = _offlineTransactionTypes.contains(type);
          
          print('    Is in online list? $isOnlineType');
          print('    Is in offline list? $isOfflineType');
          
          if (isOnlineType) {
            _selectedOnlineTypes.add(type);
            print('    ✅ Added to online types');
          }
          if (isOfflineType) {
            _selectedOfflineTypes.add(type);
            print('    ✅ Added to offline types');
          }
          if (!isOnlineType && !isOfflineType) {
            print('    ⚠️  WARNING: Type "$type" not found in any list!');
            print('    Available online types: $_onlineTransactionTypes');
            print('    Available offline types: $_offlineTransactionTypes');
          }
        }
        
        // Update controllers
        _onlineTypeController.text = _selectedOnlineTypes.join(', ');
        _offlineTypeController.text = _selectedOfflineTypes.join(', ');
        
        print('\n📊 Final Results:');
        print('  Online Types Loaded: $_selectedOnlineTypes');
        print('  Offline Types Loaded: $_selectedOfflineTypes');
      } else {
        print('⚠️  Store type is empty string');
      }
    } else {
      print('⚠️  Store type is NULL');
    }
    print('========================================\n');
    
    if (widget.storeData['mcc'] != null) {
      final mccCode = widget.storeData['mcc'].toString();
      final mcc = _cachedMccCodes.firstWhere(
        (code) => code.code == mccCode,
        orElse: () => MccCode(code: mccCode, nameEnglish: 'Unknown', nameLao: 'Unknown', category: 'Unknown'),
      );
      _selectedMccCode = mcc;
      _mccCodeController.text = '${mcc.code} - ${mcc.nameEnglish}';
    }

    if (widget.storeData['postal_code'] != null) {
      final postalCode = widget.storeData['postal_code'].toString();
      final postal = _cachedPostalCodes.firstWhere(
        (code) => code.code == postalCode,
        orElse: () => PostalCode(code: postalCode, district: 'Unknown', province: 'Unknown'),
      );
      _selectedPostalCode = postal;
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeCodeController.dispose();
    _storeManagerController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _postalCodeController.dispose();
    _storeTypeController.dispose();
    _statusController.dispose();
    _openingHoursController.dispose();
    _squareFootageController.dispose();
    _notesController.dispose();
    _upiPercentageController.dispose();
    _visaPercentageController.dispose();
    _masterPercentageController.dispose();
    _accountController.dispose();
    _account2Controller.dispose();
    _webController.dispose();
    _email1Controller.dispose();
    _email2Controller.dispose();
    _email3Controller.dispose();
    _email4Controller.dispose();
    _email5Controller.dispose();
    _storeModeController.dispose();
    _mccCodeController.dispose();
    _account_nameController.dispose();
    _cifController.dispose();
    _onlineTypeController.dispose();
    _offlineTypeController.dispose();
    _fadeController.dispose();
    super.dispose();
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
          final String base64String = base64Encode(bytes);
          
          setState(() {
            _webImageBytes = bytes;
            _webImageName = file.name;
            _base64Image = 'data:${file.type};base64,$base64String';
          });

          _showSnackBar(message: 'Image selected successfully', isError: false);
        }
      });

      reader.readAsArrayBuffer(file);
    });
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
    } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
      );
    } else {
      return _buildImagePlaceholder();
    }
  }

  Widget _buildImagePlaceholder() {
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

  // Build Online Transaction Types Checkboxes - REMOVED (_buildStoreTypeCheckboxes removed)

  // Build Online Transaction Types Checkboxes
  Widget _buildOnlineTransactionTypes() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[300]!),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.language,
                  size: 20,
                  color: Colors.blue[700],
                ),
                SizedBox(width: 8),
                Text(
                  'Online Transaction Types',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                Spacer(),
                if (_selectedOnlineTypes.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedOnlineTypes.length} selected',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Checkboxes
          ...List.generate(_onlineTransactionTypes.length, (index) {
            final transactionType = _onlineTransactionTypes[index];
            final isSelected = _selectedOnlineTypes.contains(transactionType);
            
            return Column(
              children: [
                if (index > 0) Divider(height: 1, thickness: 0.5),
                CheckboxListTile(
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
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  activeColor: Colors.blue[700],
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // Build Offline Transaction Types Checkboxes
  Widget _buildOfflineTransactionTypes() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[300]!),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.store,
                  size: 20,
                  color: Colors.green[700],
                ),
                SizedBox(width: 8),
                Text(
                  'Offline Transaction Types',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                Spacer(),
                if (_selectedOfflineTypes.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[700],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedOfflineTypes.length} selected',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Checkboxes
          ...List.generate(_offlineTransactionTypes.length, (index) {
            final transactionType = _offlineTransactionTypes[index];
            final isSelected = _selectedOfflineTypes.contains(transactionType);
            
            return Column(
              children: [
                if (index > 0) Divider(height: 1, thickness: 0.5),
                CheckboxListTile(
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
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  activeColor: Colors.green[700],
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Future<void> _updateStore() async {
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate()) {
      _showSnackBar(message: 'Please fix the form errors', isError: true);
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

    final bool? confirmUpdate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Confirm Update'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Updating this store will reset the approval status.'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                      SizedBox(width: 8),
                      Text(
                        'The store will need to be re-approved:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange[700]),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('• Approval will be reset by backend', style: TextStyle(fontSize: 12, color: Colors.orange[900])),
                  Text('• Both approvers must approve again', style: TextStyle(fontSize: 12, color: Colors.orange[900])),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text('Do you want to continue?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
              foregroundColor: Colors.white,
            ),
            child: Text('Update Store'),
          ),
        ],
      ),
    );

    if (confirmUpdate != true) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final storeId = widget.storeData['store_id'];

      final url = AppConfig.api('/api/iostore/$storeId');
      
      // ✅ COMBINE TRANSACTION TYPES INTO store_type
      List<String> allTransactionTypes = [];
      
      if (_storeMode == 'online' || _storeMode == 'hybrid') {
        allTransactionTypes.addAll(_selectedOnlineTypes);
      }
      
      if (_storeMode == 'offline' || _storeMode == 'hybrid') {
        allTransactionTypes.addAll(_selectedOfflineTypes);
      }
      
      final combinedStoreType = allTransactionTypes.isNotEmpty 
          ? allTransactionTypes.join(', ') 
          : null;
      
      final storeData = {
        'company_id': CompanyConfig.getCompanyId(),
        'store_name': _storeNameController.text.trim(),
        'store_code': _getTextOrNull(_storeCodeController),
        'store_manager': _getTextOrNull(_storeManagerController),
        'email': _getTextOrNull(_emailController),
        'phone': _getTextOrNull(_phoneController),
        'address': _getTextOrNull(_addressController),
        'city': _getTextOrNull(_cityController),
        'state': _getTextOrNull(_stateController),
        'country': _getTextOrNull(_countryController),
        'postal_code': _getTextOrNull(_postalCodeController),
        'mcc': _selectedMccCode?.code,
        'store_type': combinedStoreType,  // ✅ Combined transaction types here
        'status': _getTextOrNull(_statusController),
        'opening_hours': _getTextOrNull(_openingHoursController),
        'square_footage': _parseIntOrNull(_squareFootageController),
        'notes': _getTextOrNull(_notesController),
        'upi_percentage': _parseDoubleOrNull(_upiPercentageController),
        'visa_percentage': _parseDoubleOrNull(_visaPercentageController),
        'master_percentage': _parseDoubleOrNull(_masterPercentageController),
        'account': _getTextOrNull(_accountController),
        'account2': _getTextOrNull(_account2Controller),
        'store_mode': _storeMode,
        'web': _getTextOrNull(_webController),
        'email1': _getTextOrNull(_email1Controller),
        'email2': _getTextOrNull(_email2Controller),
        'email3': _getTextOrNull(_email3Controller),
        'email4': _getTextOrNull(_email4Controller),
        'email5': _getTextOrNull(_email5Controller),
        'account_name': _getTextOrNull(_account_nameController),
        'cif': _getTextOrNull(_cifController),
      };

      print('📤 ========== SAVING STORE DATA ==========');
      print('Store ID: $storeId');
      print('Store Name: ${storeData['store_name']}');
      print('Store Mode: ${storeData['store_mode']}');
      print('Store Type (Transaction Types): ${storeData['store_type']}');
      print('  Online Types: ${_selectedOnlineTypes.join(', ')}');
      print('  Offline Types: ${_selectedOfflineTypes.join(', ')}');
      print('==========================================');

      if (_base64Image != null) {
        storeData['image'] = _base64Image!;
      }

      final response = await http.put(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(storeData),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
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

  Future<void> _deleteStore() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete Store'),
          ],
        ),
        content: Text('Are you sure you want to delete "${_storeNameController.text}"? This action cannot be undone.'),
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
      ),
    );

    if (confirm != true) return;

    if (mounted) setState(() => _isDeleting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final storeId = widget.storeData['store_id'];

      final url = AppConfig.api('/api/iostore/$storeId');

      final response = await http.delete(
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
          _showSnackBar(message: 'Store deleted successfully!', isError: false);
          Navigator.pop(context, 'deleted');
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
      if (mounted) setState(() => _isDeleting = false);
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

  int? _parseIntOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : int.tryParse(text);
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
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
            Text('Store "${_storeNameController.text}" has been updated successfully!'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This store now requires re-approval from both approvers.',
                      style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        content: Text('Failed to update store:\n$error'),
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

  // ignore: unused_element
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
          RadioListTile<String>(
            title: Text('Online'),
            value: 'online',
            groupValue: _storeMode,
            onChanged: (String? value) {
              setState(() {
                _storeMode = value;
                _storeModeController.text = value ?? '';
              });
            },
            activeColor: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          Divider(height: 1),
          RadioListTile<String>(
            title: Text('Offline'),
            value: 'offline',
            groupValue: _storeMode,
            onChanged: (String? value) {
              setState(() {
                _storeMode = value;
                _storeModeController.text = value ?? '';
              });
            },
            activeColor: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          Divider(height: 1),
          RadioListTile<String>(
            title: Text('Online + Offline'),
            value: 'hybrid',
            groupValue: _storeMode,
            onChanged: (String? value) {
              setState(() {
                _storeMode = value;
                _storeModeController.text = value ?? '';
              });
            },
            activeColor: ThemeConfig.getPrimaryColor(currentTheme),
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
          'Edit Store',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _isLoading || _isDeleting ? null : _deleteStore,
            icon: _isDeleting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete Store',
          ),
        ],
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
                                color: (_webImageBytes != null || _imageFile != null || _currentImageUrl != null)
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
                        controller: _storeCodeController,
                        label: 'Store Code',
                        icon: Icons.qr_code,
                        hint: 'Enter store code',
                        enabled: false,
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

                      // Transaction Types Section (Conditional)
                      if (_storeMode == 'online' || _storeMode == 'hybrid') ...[
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              'Online Transaction Types',
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
                        _buildOnlineTransactionTypes(),
                      ],

                      if (_storeMode == 'offline' || _storeMode == 'hybrid') ...[
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              'Offline Transaction Types',
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
                        _buildOfflineTransactionTypes(),
                      ],
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
                        controller: _statusController,
                        label: 'Status',
                        icon: Icons.info,
                        hint: 'e.g., active, inactive',
                      ),

                      _buildTextField(
                        controller: _openingHoursController,
                        label: 'Opening Hours',
                        icon: Icons.access_time,
                        hint: 'e.g., Mon-Fri: 9AM-6PM',
                      ),

                      _buildTextField(
                        controller: _squareFootageController,
                        label: 'Square Footage',
                        icon: Icons.square_foot,
                        keyboardType: TextInputType.number,
                        hint: 'Store size in sq ft',
                      ),

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
                      Text(
                        'Payment Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ThemeConfig.getPrimaryColor(currentTheme),
                        ),
                      ),
                      SizedBox(height: 16),

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
                              icon: Icons.payment,
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
                          SizedBox(width: 12),
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

                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _accountController,
                              label: 'Primary Account (LAK) *',
                              icon: Icons.account_balance,
                              hint: 'LAK account number',
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Primary account is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _account2Controller,
                              label: 'Secondary Account',
                              icon: Icons.account_balance_wallet,
                              hint: 'Other account number',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 30),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _updateStore,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
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
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Updating...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save, size: 24, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text(
                                      'Update Store',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}