import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/business/ListDetailPage.dart' as detail;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'package:inventory/models/terminal_models.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/simple_translations.dart';
import 'dart:developer' as developer;

class ListterminalPage extends StatefulWidget {
  const ListterminalPage({Key? key}) : super(key: key);

  @override
  State<ListterminalPage> createState() => _ListterminalPageState();
}

class _ListterminalPageState extends State<ListterminalPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = false;
  String currentTheme = ThemeConfig.defaultTheme;
  String _langCode = 'en';

  List<Group> _groups = [];
  Group? _selectedGroup;
  bool _isLoadingGroups = false;

  List<Merchant> _merchants = [];
  Merchant? _selectedMerchant;
  bool _isLoadingMerchants = false;

  List<Store> _stores = [];
  Store? _selectedStore;
  bool _isLoadingStores = false;

  List<Terminal> _terminals = [];
  List<Terminal> _selectedTerminals = [];
  bool _isLoadingTerminals = false;

  int _sortColumnIndex = 0;
  bool _isAscending = true;

  bool get isMobile => MediaQuery.of(context).size.width < 768;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _initializeApp() {
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

  Future<void> _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme =
          prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
      _langCode = prefs.getString('languageCode') ?? 'en';
    });
  }

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<T>> _apiRequest<T>(
    String endpoint,
    T Function(Map<String, dynamic>) parser,
  ) async {
    final headers = await _getHeaders();

    // Log the API request
    developer.log('═══════════════════════════════════════');
    developer.log('📤 API GET REQUEST');
    developer.log('URL: $endpoint');
    developer.log('Headers: ${headers.toString()}');
    developer.log('═══════════════════════════════════════');

    final response = await http.get(Uri.parse(endpoint), headers: headers);

    // Log the API response
    developer.log('═══════════════════════════════════════');
    developer.log('📥 API GET RESPONSE');
    developer.log('Status Code: ${response.statusCode}');
    developer.log('URL: $endpoint');
    developer.log('Response Body: ${response.body}');
    developer.log('═══════════════════════════════════════');

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData['status'] == 'success' && responseData['data'] != null) {
        return (responseData['data'] as List)
            .map((json) => parser(json))
            .toList();
      }
    }
    throw Exception('Failed to load data: ${response.statusCode}');
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoadingGroups = true);

    try {
      final companyId = CompanyConfig.getCompanyId();
      final url = AppConfig.api('/api/iogroup?company_id=$companyId');

      final groups = await _apiRequest<Group>(url.toString(), Group.fromJson);

      setState(() => _groups = groups);
    } catch (e) {
      developer.log('❌ ERROR loading groups: $e');
      _showMessage(
        '${SimpleTranslations.get(_langCode, 'failed_to_load_groups')}: $e',
        detail.MessageType.error,
      );
    } finally {
      setState(() => _isLoadingGroups = false);
    }
  }

  Future<void> _loadMerchants() async {
    if (_selectedGroup == null) return;

    setState(() => _isLoadingMerchants = true);

    try {
      final companyId = CompanyConfig.getCompanyId();
      final url = AppConfig.api(
        '/api/iomerchant/company/$companyId/group/${_selectedGroup!.id}',
      );

      final merchants = await _apiRequest<Merchant>(
        url.toString(),
        Merchant.fromJson,
      );

      setState(() => _merchants = merchants);
    } catch (e) {
      developer.log('❌ ERROR loading merchants: $e');
      _showMessage(
        '${SimpleTranslations.get(_langCode, 'failed_to_load_merchants')}: $e',
        detail.MessageType.error,
      );
      setState(() => _merchants = []);
    } finally {
      setState(() => _isLoadingMerchants = false);
    }
  }

  Future<void> _loadStores() async {
    if (_selectedMerchant == null) return;

    setState(() => _isLoadingStores = true);

    try {
      final companyId = CompanyConfig.getCompanyId();
      final url = AppConfig.api(
        
        '/api/ioterminal/company/$companyId/merchant/${_selectedMerchant!.merchantId}',
      );

      final stores = await _apiRequest<Store>(url.toString(), Store.fromJson);

      // Filter to only show approved stores
      final approvedStores = stores.where((store) => 
        store.approvalStatus == 'approved'
      ).toList();

      setState(() => _stores = approvedStores);
      
      developer.log('✅ Loaded ${stores.length} stores, filtered to ${approvedStores.length} approved stores');
    } catch (e) {
      developer.log('❌ ERROR loading stores: $e');
      _showMessage(
        '${SimpleTranslations.get(_langCode, 'failed_to_load_stores')}: $e',
        detail.MessageType.error,
      );
      setState(() => _stores = []);
    } finally {
      setState(() => _isLoadingStores = false);
    }
  }

  
 Future<void> _loadTerminals() async {
  if (_selectedStore == null) return;

  setState(() => _isLoadingTerminals = true);

  try {
    final companyId = CompanyConfig.getCompanyId();
    final url = AppConfig.api(
      '/api/ioterminal/company/$companyId/store/${_selectedStore!.storeId}/terminals',
    );

    final terminals = await _apiRequest<Terminal>(
      url.toString(),
      Terminal.fromJson,
    );

    // Filter to only show approved terminals
    final approvedTerminals = terminals.where((terminal) => 
      terminal.approvalStatus == 'approved'
    ).toList();

    setState(() => _terminals = approvedTerminals); // Use the filtered list
    
    developer.log('✅ Loaded ${terminals.length} terminals, filtered to ${approvedTerminals.length} approved terminals');
    
  } catch (e) {
    developer.log('❌ ERROR loading terminals: $e');
    _showMessage(
      '${SimpleTranslations.get(_langCode, 'failed_to_load_terminals')}: $e',
      detail.MessageType.error,
    );
    setState(() => _terminals = []);
  } finally {
    setState(() => _isLoadingTerminals = false);
  }
}

  Future<void> _createBulkTerminals() async {
    if (_selectedTerminals.isEmpty) {
      _showMessage(
        SimpleTranslations.get(
          _langCode,
          'please_select_at_least_one_terminal',
        ),
        detail.MessageType.warning,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final terminalIds = _selectedTerminals.map((t) => t.terminalId).toList();
      final response = await _submitBulkTerminals(terminalIds);

      if (_isSuccessResponse(response)) {
        _navigateToDetailPage(response);
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      developer.log('❌ ERROR in bulk terminals: $e');
      _showErrorDialog(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<http.Response> _submitBulkTerminals(List<int> terminalIds) async {
    final headers = await _getHeaders();
    final apiUrl = AppConfig.api('/api/ioterminal/bulk').toString();

    final requestBody = {'terminalIds': terminalIds};

    // Log the POST request
    developer.log('═══════════════════════════════════════');
    developer.log('📤 API POST REQUEST');
    developer.log('URL: $apiUrl');
    developer.log('Headers: ${headers.toString()}');
    developer.log('Request Body: ${jsonEncode(requestBody)}');
    developer.log('Terminal IDs: $terminalIds');
    developer.log('═══════════════════════════════════════');

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: headers,
      body: jsonEncode(requestBody),
    );

    // Log the POST response
    developer.log('═══════════════════════════════════════');
    developer.log('📥 API POST RESPONSE');
    developer.log('Status Code: ${response.statusCode}');
    developer.log('URL: $apiUrl');
    developer.log('Response Body: ${response.body}');
    developer.log('═══════════════════════════════════════');

    return response;
  }

  void _navigateToDetailPage(http.Response response) {
    final responseData = jsonDecode(response.body);

    developer.log('✅ SUCCESS - Navigating to detail page');
    developer.log('Response Data: ${jsonEncode(responseData)}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => detail.ListDetailPage(
          data: responseData,
          selectedTerminals: _selectedTerminals,
        ),
      ),
    );
  }

  bool _isSuccessResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      return responseData['status'] == 'success';
    }
    return false;
  }

  void _handleErrorResponse(http.Response response) {
    final errorData = jsonDecode(response.body);
    String errorMessage;

    developer.log('❌ ERROR RESPONSE');
    developer.log('Status Code: ${response.statusCode}');
    developer.log('Error Data: ${jsonEncode(errorData)}');

    switch (response.statusCode) {
      case 409:
        errorMessage =
            '${SimpleTranslations.get(_langCode, 'terminal_already_exists')}: ${errorData['details'] ?? errorData['message']}';
        break;
      case 400:
        if (errorData['message'] is List) {
          errorMessage =
              '${SimpleTranslations.get(_langCode, 'validation_error')}: ${(errorData['message'] as List).join(', ')}';
        } else {
          errorMessage =
              '${SimpleTranslations.get(_langCode, 'validation_error')}: ${errorData['message']}';
        }
        break;
      default:
        errorMessage =
            errorData['message'] ??
            '${SimpleTranslations.get(_langCode, 'server_error')}: ${response.statusCode}';
    }

    throw Exception(errorMessage);
  }

  void _onGroupChanged(Group? value) {
    developer.log('🔄 Group changed: ${value?.groupName ?? "null"}');
    setState(() {
      _selectedGroup = value;
      _clearDependentSelections();
    });
    if (value != null) _loadMerchants();
  }

  void _onMerchantChanged(Merchant? value) {
    developer.log('🔄 Merchant changed: ${value?.merchantName ?? "null"}');
    setState(() {
      _selectedMerchant = value;
      _selectedStore = null;
      _selectedTerminals.clear();
      _stores.clear();
      _terminals.clear();
    });
    if (value != null) _loadStores();
  }

  void _onStoreChanged(Store? value) {
    developer.log('🔄 Store changed: ${value?.storeName ?? "null"}');
    setState(() {
      _selectedStore = value;
      _selectedTerminals.clear();
      _terminals.clear();
    });
    if (value != null) _loadTerminals();
  }

  void _clearDependentSelections() {
    _selectedMerchant = null;
    _selectedStore = null;
    _selectedTerminals.clear();
    _merchants.clear();
    _stores.clear();
    _terminals.clear();
  }

  void _onTerminalChanged(Terminal terminal, bool isSelected) {
    developer.log(
      '✓ Terminal ${isSelected ? "selected" : "deselected"}: ${terminal.terminalName} (ID: ${terminal.terminalId})',
    );
    setState(() {
      if (isSelected) {
        _selectedTerminals.add(terminal);
      } else {
        _selectedTerminals.removeWhere(
          (t) => t.terminalId == terminal.terminalId,
        );
      }
    });
    developer.log('Selected terminals count: ${_selectedTerminals.length}');
  }

  void _onSelectAllTerminals(bool selectAll) {
    developer.log(
      '${selectAll ? "✓" : "✗"} ${selectAll ? "Select All" : "Clear All"} terminals',
    );
    setState(() {
      _selectedTerminals = selectAll ? List.from(_terminals) : [];
    });
    developer.log('Selected terminals count: ${_selectedTerminals.length}');
  }

  void _sortTerminals(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _isAscending = ascending;

      _terminals.sort((a, b) {
        dynamic aValue, bValue;

        switch (columnIndex) {
          case 1:
            aValue = a.terminalName;
            bValue = b.terminalName;
            break;
          case 2:
            aValue = a.terminalCode ?? '';
            bValue = b.terminalCode ?? '';
            break;
          case 3:
            aValue = a.terminalId;
            bValue = b.terminalId;
            break;
          case 4:
            aValue = a.companyId;
            bValue = b.companyId;
            break;
          case 5:
            aValue = a.storeId;
            bValue = b.storeId;
            break;
          default:
            return 0;
        }

        if (aValue is String && bValue is String) {
          return ascending
              ? aValue.compareTo(bValue)
              : bValue.compareTo(aValue);
        } else if (aValue is int && bValue is int) {
          return ascending
              ? aValue.compareTo(bValue)
              : bValue.compareTo(aValue);
        }
        return 0;
      });
    });
  }

  void _showMessage(String message, detail.MessageType type) {
    final colors = {
      detail.MessageType.success: Colors.green,
      detail.MessageType.error: Colors.red,
      detail.MessageType.warning: Colors.orange,
    };

    final icons = {
      detail.MessageType.success: Icons.check_circle,
      detail.MessageType.error: Icons.error,
      detail.MessageType.warning: Icons.warning,
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icons[type]!, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colors[type],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Text(SimpleTranslations.get(_langCode, 'error')),
          ],
        ),
        content: Text(
          '${SimpleTranslations.get(_langCode, 'failed_to_process_terminals')}:\n$error',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              SimpleTranslations.get(_langCode, 'try_again'),
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

  Widget _buildMobileFiltersSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info,
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  SimpleTranslations.get(_langCode, 'terminal_selection'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildMobileDropdown<Group>(
              label: SimpleTranslations.get(_langCode, 'group'),
              hint: _isLoadingGroups
                  ? SimpleTranslations.get(_langCode, 'loading_groups')
                  : SimpleTranslations.get(
                      _langCode,
                      'select_a_group_optional',
                    ),
              icon: Icons.group,
              value: _selectedGroup,
              items: _groups,
              itemBuilder: (group) => _buildListTile(
                title: group.groupName,
                icon: Icons.group,
                imageUrl: group.imageUrl,
                subtitle: group.groupCode,
              ),
              selectedItemBuilder: (group) => _buildCompactSelectedItem(
                title: group.groupName,
                icon: Icons.group,
                imageUrl: group.imageUrl,
              ),
              onChanged: _onGroupChanged,
              isLoading: _isLoadingGroups,
            ),
            _buildMobileDropdown<Merchant>(
              label: SimpleTranslations.get(_langCode, 'merchant'),
              hint: _selectedGroup == null
                  ? SimpleTranslations.get(_langCode, 'select_group_first')
                  : _isLoadingMerchants
                  ? SimpleTranslations.get(_langCode, 'loading_merchants')
                  : SimpleTranslations.get(
                      _langCode,
                      'select_a_merchant_optional',
                    ),
              icon: Icons.business,
              value: _selectedMerchant,
              items: _merchants,
              itemBuilder: (merchant) => _buildListTile(
                title: merchant.merchantName,
                icon: Icons.business,
                imageUrl: merchant.imageUrl,
                subtitle: merchant.merchantCode,
              ),
              selectedItemBuilder: (merchant) => _buildCompactSelectedItem(
                title: merchant.merchantName,
                icon: Icons.business,
                imageUrl: merchant.imageUrl,
              ),
              onChanged: _onMerchantChanged,
              isLoading: _isLoadingMerchants,
              isEnabled: _selectedGroup != null,
            ),
            _buildMobileDropdown<Store>(
              label: SimpleTranslations.get(_langCode, 'store'),
              hint: _selectedMerchant == null
                  ? SimpleTranslations.get(_langCode, 'select_merchant_first')
                  : _isLoadingStores
                  ? SimpleTranslations.get(_langCode, 'loading_stores')
                  : SimpleTranslations.get(
                      _langCode,
                      'select_a_store_optional',
                    ),
              icon: Icons.store,
              value: _selectedStore,
              items: _stores,
              itemBuilder: (store) => _buildListTile(
                title: store.storeName,
                icon: Icons.store,
                imageUrl: store.imageUrl,
                subtitle: store.storeCode,
              ),
              selectedItemBuilder: (store) => _buildCompactSelectedItem(
                title: store.storeName,
                icon: Icons.store,
                imageUrl: store.imageUrl,
              ),
              onChanged: _onStoreChanged,
              isLoading: _isLoadingStores,
              isEnabled: _selectedMerchant != null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTerminalsList() {
    if (_terminals.isEmpty) {
      return Card(
        child: Container(
          height: 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.computer_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedStore == null
                      ? SimpleTranslations.get(
                          _langCode,
                          'select_a_store_to_view_terminals',
                        )
                      : SimpleTranslations.get(_langCode, 'no_terminals_found'),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  '${SimpleTranslations.get(_langCode, 'select_terminals')} (${_selectedTerminals.length}/${_terminals.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildSelectButton(
                      SimpleTranslations.get(_langCode, 'all'),
                      () => _onSelectAllTerminals(true),
                    ),
                    _buildSelectButton(
                      SimpleTranslations.get(_langCode, 'clear'),
                      () => _onSelectAllTerminals(false),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...(_terminals.map(_buildMobileTerminalCheckbox).toList()),
        ],
      ),
    );
  }

  Widget _buildMobileTerminalCheckbox(Terminal terminal) {
    final isSelected = _selectedTerminals.any(
      (t) => t.terminalId == terminal.terminalId,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? ThemeConfig.getPrimaryColor(currentTheme)
              : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: ThemeConfig.getPrimaryColor(
                    currentTheme,
                  ).withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onTerminalChanged(terminal, !isSelected),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildCustomCheckbox(isSelected),
                const SizedBox(width: 16),
                _buildImageContainer(
                  size: 48,
                  icon: Icons.computer,
                  imageUrl: terminal.imageUrl,
                  backgroundColor: isSelected
                      ? ThemeConfig.getPrimaryColor(
                          currentTheme,
                        ).withOpacity(0.15)
                      : Colors.grey[100],
                  borderColor: isSelected
                      ? ThemeConfig.getPrimaryColor(currentTheme)
                      : Colors.grey[300]!,
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildTerminalInfo(terminal, isSelected)),
                if (isSelected) _buildSelectionIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebFiltersSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.filter_list,
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  SimpleTranslations.get(_langCode, 'filters'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildCompactDropdown<Group>(
                    label: SimpleTranslations.get(_langCode, 'group'),
                    hint: _isLoadingGroups
                        ? SimpleTranslations.get(_langCode, 'loading')
                        : SimpleTranslations.get(_langCode, 'select_group'),
                    icon: Icons.group_outlined,
                    value: _selectedGroup,
                    items: _groups,
                    displayText: (group) => group.groupName,
                    onChanged: _onGroupChanged,
                    isLoading: _isLoadingGroups,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCompactDropdown<Merchant>(
                    label: SimpleTranslations.get(_langCode, 'merchant'),
                    hint: _selectedGroup == null
                        ? SimpleTranslations.get(
                            _langCode,
                            'select_group_first',
                          )
                        : _isLoadingMerchants
                        ? SimpleTranslations.get(_langCode, 'loading')
                        : SimpleTranslations.get(_langCode, 'select_merchant'),
                    icon: Icons.business_outlined,
                    value: _selectedMerchant,
                    items: _merchants,
                    displayText: (merchant) => merchant.merchantName,
                    onChanged: _onMerchantChanged,
                    isLoading: _isLoadingMerchants,
                    isEnabled: _selectedGroup != null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCompactDropdown<Store>(
                    label: SimpleTranslations.get(_langCode, 'store'),
                    hint: _selectedMerchant == null
                        ? SimpleTranslations.get(
                            _langCode,
                            'select_merchant_first',
                          )
                        : _isLoadingStores
                        ? SimpleTranslations.get(_langCode, 'loading')
                        : SimpleTranslations.get(_langCode, 'select_store'),
                    icon: Icons.store_outlined,
                    value: _selectedStore,
                    items: _stores,
                    displayText: (store) => store.storeName,
                    onChanged: _onStoreChanged,
                    isLoading: _isLoadingStores,
                    isEnabled: _selectedMerchant != null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebTerminalsTable() {
    if (_terminals.isEmpty) {
      return Card(
        child: Container(
          height: 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.computer_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedStore == null
                      ? SimpleTranslations.get(
                          _langCode,
                          'select_a_store_to_view_terminals',
                        )
                      : SimpleTranslations.get(_langCode, 'no_terminals_found'),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTableHeader(),
          _buildDataTable(),
          if (_selectedTerminals.isNotEmpty) _buildTableFooter(),
        ],
      ),
    );
  }

  Widget _buildCompactDropdown<T>({
    required String label,
    required String hint,
    required IconData icon,
    required T? value,
    required List<T> items,
    required String Function(T) displayText,
    required void Function(T?) onChanged,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(
            icon,
            size: 20,
            color: ThemeConfig.getPrimaryColor(currentTheme),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
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
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(
                  displayText(item),
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: isEnabled && !isLoading ? onChanged : null,
      ),
    );
  }

  Widget _buildMobileDropdown<T>({
    required String label,
    required String hint,
    required IconData icon,
    required T? value,
    required List<T> items,
    required Widget Function(T) itemBuilder,
    required Widget Function(T) selectedItemBuilder,
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
          suffixIcon: isLoading ? _buildLoadingIndicator() : null,
        ),
        selectedItemBuilder: (context) =>
            items.map(selectedItemBuilder).toList(),
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

  Widget _buildImageContainer({
    required double size,
    required IconData icon,
    String? imageUrl,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Colors.grey[200],
        border: borderColor != null ? Border.all(color: borderColor) : null,
      ),
      child: _buildImageContent(size, icon, imageUrl),
    );
  }

  Widget _buildImageContent(double size, IconData icon, String? imageUrl) {
    if (imageUrl?.isNotEmpty == true && !imageUrl!.contains('undefined')) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Icon(icon, color: Colors.grey[600], size: size * 0.5),
        ),
      );
    }
    return Icon(icon, color: Colors.grey[600], size: size * 0.5);
  }

  Widget _buildCompactSelectedItem({
    required String title,
    required IconData icon,
    String? imageUrl,
  }) {
    return Row(
      children: [
        _buildImageContainer(size: 24, icon: icon, imageUrl: imageUrl),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required String title,
    required IconData icon,
    String? imageUrl,
    String? subtitle,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: _buildImageContainer(size: 36, icon: icon, imageUrl: imageUrl),
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            )
          : null,
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: 20,
      height: 20,
      padding: const EdgeInsets.all(12),
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          ThemeConfig.getPrimaryColor(currentTheme),
        ),
      ),
    );
  }

  Widget _buildCustomCheckbox(bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected
            ? ThemeConfig.getPrimaryColor(currentTheme)
            : Colors.transparent,
        border: Border.all(
          color: isSelected
              ? ThemeConfig.getPrimaryColor(currentTheme)
              : Colors.grey[400]!,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }

  Widget _buildTerminalInfo(Terminal terminal, bool isSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          terminal.terminalName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isSelected
                ? ThemeConfig.getPrimaryColor(currentTheme)
                : Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (terminal.terminalCode?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          _buildTerminalCodeChip(terminal.terminalCode!, isSelected),
          const SizedBox(height: 4),
        ],
        Text(
          '${SimpleTranslations.get(_langCode, 'company_id_label')}: ${terminal.companyId}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildTerminalCodeChip(String terminalCode, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.1)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected
              ? ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.3)
              : Colors.grey[300]!,
        ),
      ),
      child: Text(
        '${SimpleTranslations.get(_langCode, 'code_label')}: $terminalCode',
        style: TextStyle(
          fontSize: 12,
          color: isSelected
              ? ThemeConfig.getPrimaryColor(currentTheme)
              : Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSelectionIndicator() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: ThemeConfig.getPrimaryColor(currentTheme),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, size: 16, color: Colors.white),
    );
  }

  Widget _buildSelectButton(String text, VoidCallback onPressed) {
    return Flexible(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 32),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.computer,
                color: ThemeConfig.getPrimaryColor(currentTheme),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                '${SimpleTranslations.get(_langCode, 'terminals')} (${_terminals.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ThemeConfig.getPrimaryColor(currentTheme),
                ),
              ),
              if (_selectedTerminals.isNotEmpty) ...[
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedTerminals.length} ${SimpleTranslations.get(_langCode, 'selected')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _onSelectAllTerminals(true),
                icon: const Icon(Icons.select_all, size: 18),
                label: Text(SimpleTranslations.get(_langCode, 'select_all')),
                style: TextButton.styleFrom(
                  foregroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _onSelectAllTerminals(false),
                icon: const Icon(Icons.clear, size: 18),
                label: Text(SimpleTranslations.get(_langCode, 'clear')),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 32,
        ),
        child: DataTable(
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _isAscending,
          showCheckboxColumn: false,
          headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
          dataRowHeight: 56,
          headingRowHeight: 48,
          columns: [
            DataColumn(
              label: Container(
                width: 50,
                child: Checkbox(
                  value:
                      _selectedTerminals.length == _terminals.length &&
                      _terminals.isNotEmpty,
                  tristate: true,
                  onChanged: (value) => _onSelectAllTerminals(value ?? false),
                  activeColor: ThemeConfig.getPrimaryColor(currentTheme),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                SimpleTranslations.get(_langCode, 'terminal_name'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onSort: (columnIndex, ascending) =>
                  _sortTerminals(columnIndex, ascending),
            ),
            DataColumn(
              label: Text(
                SimpleTranslations.get(_langCode, 'code'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onSort: (columnIndex, ascending) =>
                  _sortTerminals(columnIndex, ascending),
            ),
            DataColumn(
              label: Text(
                SimpleTranslations.get(_langCode, 'terminal_id'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onSort: (columnIndex, ascending) =>
                  _sortTerminals(columnIndex, ascending),
            ),
            DataColumn(
              label: Text(
                SimpleTranslations.get(_langCode, 'company_id'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onSort: (columnIndex, ascending) =>
                  _sortTerminals(columnIndex, ascending),
            ),
            DataColumn(
              label: Text(
                SimpleTranslations.get(_langCode, 'store_id'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onSort: (columnIndex, ascending) =>
                  _sortTerminals(columnIndex, ascending),
            ),
            DataColumn(
              label: Text(
                SimpleTranslations.get(_langCode, 'status'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: _terminals.map((terminal) {
            final isSelected = _selectedTerminals.any(
              (t) => t.terminalId == terminal.terminalId,
            );

            return DataRow(
              selected: isSelected,
              color: MaterialStateProperty.resolveWith<Color?>((states) {
                if (states.contains(MaterialState.selected)) {
                  return ThemeConfig.getPrimaryColor(
                    currentTheme,
                  ).withOpacity(0.08);
                }
                return null;
              }),
              cells: [
                DataCell(
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) =>
                        _onTerminalChanged(terminal, value ?? false),
                    activeColor: ThemeConfig.getPrimaryColor(currentTheme),
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isSelected
                            ? ThemeConfig.getPrimaryColor(currentTheme)
                            : Colors.grey[300],
                        child: Icon(
                          Icons.computer,
                          size: 16,
                          color: isSelected ? Colors.white : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              terminal.terminalName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? ThemeConfig.getPrimaryColor(currentTheme)
                                    : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (terminal.imageUrl?.isNotEmpty == true)
                              Text(
                                SimpleTranslations.get(_langCode, 'has_image'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: terminal.terminalCode?.isNotEmpty == true
                          ? Colors.blue[50]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: terminal.terminalCode?.isNotEmpty == true
                            ? Colors.blue[200]!
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Text(
                      terminal.terminalCode ??
                          SimpleTranslations.get(_langCode, 'n_a'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: terminal.terminalCode?.isNotEmpty == true
                            ? Colors.blue[700]
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    terminal.terminalId.toString(),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                DataCell(
                  Text(
                    terminal.companyId.toString(),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                DataCell(
                  Text(
                    terminal.storeId.toString(),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Text(
                      SimpleTranslations.get(_langCode, 'active'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTableFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_selectedTerminals.length} ${SimpleTranslations.get(_langCode, 'of')} ${_terminals.length} ${SimpleTranslations.get(_langCode, 'terminals_selected')}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _createBulkTerminals,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.batch_prediction),
            label: Text(
              _isLoading
                  ? SimpleTranslations.get(_langCode, 'processing')
                  : '${SimpleTranslations.get(_langCode, 'process_selected')} (${_selectedTerminals.length})',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          if (_selectedTerminals.isNotEmpty) ...[
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _createBulkTerminals,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.batch_prediction),
              label: Text(
                _isLoading
                    ? SimpleTranslations.get(_langCode, 'processing')
                    : '${SimpleTranslations.get(_langCode, 'process_selected')} (${_selectedTerminals.length})',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          SimpleTranslations.get(_langCode, 'terminal_management'),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTerminals,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isMobile) ...[
                  _buildMobileFiltersSection(),
                  if (_selectedStore != null && _terminals.isNotEmpty)
                    _buildMobileTerminalsList(),
                  _buildMobileActionButtons(),
                ] else ...[
                  _buildWebFiltersSection(),
                  const SizedBox(height: 16),
                  if (_isLoadingTerminals)
                    Card(
                      child: Container(
                        height: 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                SimpleTranslations.get(
                                  _langCode,
                                  'loading_terminals',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    _buildWebTerminalsTable(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
