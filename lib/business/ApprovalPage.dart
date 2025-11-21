import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ApprovalPage extends StatefulWidget {
  const ApprovalPage({Key? key}) : super(key: key);

  @override
  State<ApprovalPage> createState() => _ApprovalPageState();
}

class _ApprovalPageState extends State<ApprovalPage> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _allStores = [];
  List<Map<String, dynamic>> _allTerminals = [];
  
  bool _isLoadingStores = false;
  bool _isLoadingTerminals = false;
  String currentTheme = ThemeConfig.defaultTheme;
  String? _currentUserPhone;
  String? _cachedToken;
  
  late TabController _tabController;
  
  // Pagination for Stores
  int _currentStorePage = 1;
  int _storesPerPage = 10;
  final List<int> _itemsPerPageOptions = const [5, 10, 20, 50, 100];
  
  // Pagination for Terminals
  int _currentTerminalPage = 1;
  int _terminalsPerPage = 10;
  
  // Cache computed values
  List<Map<String, dynamic>>? _cachedPaginatedStores;
  List<Map<String, dynamic>>? _cachedPaginatedTerminals;
  int _lastStorePageComputed = -1;
  int _lastTerminalPageComputed = -1;
  
  // Visible columns cache
  List<Map<String, dynamic>>? _visibleStoreColumns;
  List<Map<String, dynamic>>? _visibleTerminalColumns;
  
  // Paginated stores getter with caching
  List<Map<String, dynamic>> get _paginatedStores {
    if (_cachedPaginatedStores != null && _lastStorePageComputed == _currentStorePage) {
      return _cachedPaginatedStores!;
    }
    
    final startIndex = (_currentStorePage - 1) * _storesPerPage;
    final endIndex = startIndex + _storesPerPage;
    
    if (startIndex >= _allStores.length) {
      _cachedPaginatedStores = [];
    } else {
      _cachedPaginatedStores = _allStores.sublist(
        startIndex,
        endIndex > _allStores.length ? _allStores.length : endIndex,
      );
    }
    
    _lastStorePageComputed = _currentStorePage;
    return _cachedPaginatedStores!;
  }
  
  int get _totalStorePages => _allStores.isEmpty ? 0 : (_allStores.length / _storesPerPage).ceil();
  
  // Paginated terminals getter with caching
  List<Map<String, dynamic>> get _paginatedTerminals {
    if (_cachedPaginatedTerminals != null && _lastTerminalPageComputed == _currentTerminalPage) {
      return _cachedPaginatedTerminals!;
    }
    
    final startIndex = (_currentTerminalPage - 1) * _terminalsPerPage;
    final endIndex = startIndex + _terminalsPerPage;
    
    if (startIndex >= _allTerminals.length) {
      _cachedPaginatedTerminals = [];
    } else {
      _cachedPaginatedTerminals = _allTerminals.sublist(
        startIndex,
        endIndex > _allTerminals.length ? _allTerminals.length : endIndex,
      );
    }
    
    _lastTerminalPageComputed = _currentTerminalPage;
    return _cachedPaginatedTerminals!;
  }
  
  int get _totalTerminalPages => _allTerminals.isEmpty ? 0 : (_allTerminals.length / _terminalsPerPage).ceil();
  
  // Store columns
  List<Map<String, dynamic>> _storeColumns = [
    {'key': 'image', 'label': 'Image', 'visible': true},
    {'key': 'store_name', 'label': 'Store Name', 'visible': true},
    {'key': 'store_code', 'label': 'Store Code', 'visible': true},
    {'key': 'manager', 'label': 'Manager', 'visible': true},
    {'key': 'address', 'label': 'Address', 'visible': true},
    {'key': 'upi', 'label': 'UPI %', 'visible': true},
    {'key': 'visa', 'label': 'VISA %', 'visible': true},
    {'key': 'mc', 'label': 'MC %', 'visible': true},
    {'key': 'approve1', 'label': 'Approver 1', 'visible': true},
    {'key': 'approve2', 'label': 'Approver 2', 'visible': true},
    {'key': 'approval_status', 'label': 'Status', 'visible': true},
    {'key': 'created', 'label': 'Created', 'visible': true},
    {'key': 'actions', 'label': 'Actions', 'visible': true},
  ];

  // Terminal columns
  List<Map<String, dynamic>> _terminalColumns = [
    {'key': 'image', 'label': 'Image', 'visible': true},
    {'key': 'terminal_name', 'label': 'Terminal Name', 'visible': true},
    {'key': 'terminal_code', 'label': 'Terminal Code', 'visible': true},
    {'key': 'store_name', 'label': 'Store', 'visible': true},
    {'key': 'serial_number', 'label': 'Serial #', 'visible': true},
    {'key': 'sim_number', 'label': 'SIM #', 'visible': true},
    {'key': 'expire_date', 'label': 'Expire Date', 'visible': true},
    {'key': 'phone', 'label': 'Phone', 'visible': false},
    {'key': 'approve1', 'label': 'Approver 1', 'visible': true},
    {'key': 'approve2', 'label': 'Approver 2', 'visible': true},
    {'key': 'approval_status', 'label': 'Status', 'visible': true},
    {'key': 'created', 'label': 'Created', 'visible': true},
    {'key': 'actions', 'label': 'Actions', 'visible': true},
  ];
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadCurrentTheme();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('access_token');
    if (mounted) {
      setState(() {
        currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserPhone = prefs.getString('phone');
    await Future.wait([_loadStores(), _loadTerminals()]);
  }

  void _invalidateCache() {
    _cachedPaginatedStores = null;
    _cachedPaginatedTerminals = null;
    _lastStorePageComputed = -1;
    _lastTerminalPageComputed = -1;
  }

  List<Map<String, dynamic>> _getVisibleColumns(bool isStore) {
    if (isStore) {
      return _visibleStoreColumns ??= _storeColumns.where((c) => c['visible'] == true).toList();
    } else {
      return _visibleTerminalColumns ??= _terminalColumns.where((c) => c['visible'] == true).toList();
    }
  }

  void _invalidateColumnCache() {
    _visibleStoreColumns = null;
    _visibleTerminalColumns = null;
  }

  // Pagination methods for Stores
  void _goToStorePage(int page) {
    if (page >= 1 && page <= _totalStorePages && page != _currentStorePage) {
      setState(() => _currentStorePage = page);
    }
  }

  void _changeStoresPerPage(int? newValue) {
    if (newValue != null && newValue != _storesPerPage) {
      setState(() {
        _storesPerPage = newValue;
        _currentStorePage = 1;
        _invalidateCache();
      });
    }
  }

  // Pagination methods for Terminals
  void _goToTerminalPage(int page) {
    if (page >= 1 && page <= _totalTerminalPages && page != _currentTerminalPage) {
      setState(() => _currentTerminalPage = page);
    }
  }

  void _changeTerminalsPerPage(int? newValue) {
    if (newValue != null && newValue != _terminalsPerPage) {
      setState(() {
        _terminalsPerPage = newValue;
        _currentTerminalPage = 1;
        _invalidateCache();
      });
    }
  }

  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_cachedToken != null) 'Authorization': 'Bearer $_cachedToken',
    };
  }

  Future<void> _loadStores() async {
    if (_isLoadingStores) return;
    
    setState(() {
      _isLoadingStores = true;
      _currentStorePage = 1;
      _invalidateCache();
    });

    try {
      final companyId = CompanyConfig.getCompanyId();
      final url = AppConfig.api('/api/iostore?company_id=$companyId');
      
      final response = await http.get(
        Uri.parse(url.toString()),
        headers: _getHeaders(),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          setState(() {
            _allStores = List<Map<String, dynamic>>.from(responseData['data']);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error loading stores: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingStores = false);
      }
    }
  }

  Future<void> _loadTerminals() async {
    if (_isLoadingTerminals) return;
    
    setState(() {
      _isLoadingTerminals = true;
      _currentTerminalPage = 1;
      _invalidateCache();
    });

    try {
      final companyId = CompanyConfig.getCompanyId();
      final url = AppConfig.api('/api/ioterminal?company_id=$companyId');
      
      final response = await http.get(
        Uri.parse(url.toString()),
        headers: _getHeaders(),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          setState(() {
            _allTerminals = List<Map<String, dynamic>>.from(responseData['data']);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error loading terminals: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingTerminals = false);
      }
    }
  }

  void _showColumnSettings() {
    final isStoreTab = _tabController.index == 0;
    final columns = isStoreTab ? _storeColumns : _terminalColumns;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.view_column, color: ThemeConfig.getPrimaryColor(currentTheme)),
                  const SizedBox(width: 8),
                  Text('Manage ${isStoreTab ? "Store" : "Terminal"} Columns'),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Drag to reorder columns',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ReorderableListView(
                        onReorder: (oldIndex, newIndex) {
                          setDialogState(() {
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            final item = columns.removeAt(oldIndex);
                            columns.insert(newIndex, item);
                          });
                          setState(() => _invalidateColumnCache());
                        },
                        children: columns.map((column) {
                          return CheckboxListTile(
                            key: ValueKey(column['key']),
                            dense: true,
                            title: Row(
                              children: [
                                const Icon(Icons.drag_handle, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(child: Text(column['label'], style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                            value: column['visible'],
                            onChanged: (value) {
                              setDialogState(() {
                                column['visible'] = value ?? true;
                              });
                              setState(() => _invalidateColumnCache());
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      for (var column in columns) {
                        column['visible'] = true;
                      }
                    });
                    setState(() => _invalidateColumnCache());
                  },
                  child: const Text('Show All'),
                ),
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      for (var column in columns) {
                        column['visible'] = false;
                      }
                    });
                    setState(() => _invalidateColumnCache());
                  },
                  child: const Text('Hide All'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPaginationControls({
  required int currentPage,
  required int totalPages,
  required int itemsPerPage,
  required int totalItems,
  required Function(int) onPageChanged,
  required Function(int?) onItemsPerPageChanged,
  required Color primaryColor,
}) {
  if (totalItems == 0) return const SizedBox.shrink();

  final startItem = (currentPage - 1) * itemsPerPage + 1;
  final endItem = (currentPage * itemsPerPage).clamp(0, totalItems);

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      border: Border(top: BorderSide(color: Colors.grey[300]!)),
    ),
    child: Column(
      children: [
        // Top row: Items per page and info
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Items per page selector
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Show', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<int>(
                    value: itemsPerPage,
                    underline: const SizedBox(),
                    items: _itemsPerPageOptions.map((value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      );
                    }).toList(),
                    onChanged: onItemsPerPageChanged,
                  ),
                ),
              ],
            ),
            // Page info
            Flexible(
              child: Text(
                '$startItem-$endItem of $totalItems',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Bottom row: Page navigation (centered)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PaginationButton(
              icon: Icons.first_page,
              onPressed: currentPage > 1 ? () => onPageChanged(1) : null,
              tooltip: 'First page',
            ),
            _PaginationButton(
              icon: Icons.chevron_left,
              onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
              tooltip: 'Previous',
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Page $currentPage / $totalPages',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  fontSize: 14,
                ),
              ),
            ),
            _PaginationButton(
              icon: Icons.chevron_right,
              onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
              tooltip: 'Next',
            ),
            _PaginationButton(
              icon: Icons.last_page,
              onPressed: currentPage < totalPages ? () => onPageChanged(totalPages) : null,
              tooltip: 'Last page',
            ),
          ],
        ),
      ],
    ),
  );
}
  // Approval methods remain the same but use cached headers
  Future<void> _approveStore(Map<String, dynamic> store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Approval'),
        content: Text('Are you sure you want to approve "${store['store_name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final storeId = store['store_id'];
      final url = AppConfig.api('/api/iostore/$storeId/approval');
      
      final currentApprove1 = store['approve1']?.toString();
      final currentApprove2 = store['approve2']?.toString();
      
      if (currentApprove1 == _currentUserPhone || currentApprove2 == _currentUserPhone) {
        _showSnackBar(message: 'You have already approved this store', isError: true);
        return;
      }
      
      final isFirstApproval = (currentApprove1 == null || currentApprove1.isEmpty);
      final isSecondApproval = (currentApprove1?.isNotEmpty ?? false) && 
                              (currentApprove2 == null || currentApprove2.isEmpty);
      
      if (!isFirstApproval && !isSecondApproval) {
        _showSnackBar(message: 'Store already fully approved', isError: true);
        return;
      }
      
      final requestBody = {
        'approved_by': _currentUserPhone ?? 'unknown',
        'approved_at': DateTime.now().toIso8601String(),
        if (isFirstApproval) ...{
          'approval_status': 'pending',
          'approve1': _currentUserPhone,
        } else ...{
          'approval_status': 'approved',
          'approve1': currentApprove1,
          'approve2': _currentUserPhone,
        },
      };
      
      final response = await http.put(
        Uri.parse(url.toString()),
        headers: _getHeaders(),
        body: jsonEncode(requestBody),
      );

      if (!mounted) return;

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200 && responseData['status'] == 'success') {
        _showSnackBar(
          message: isSecondApproval 
            ? 'Store fully approved! (2/2 approvals)' 
            : 'Store approved! Waiting for second approver (1/2)',
          isError: false,
        );
        await _loadStores();
      } else {
        _showSnackBar(
          message: responseData['message'] ?? 'Failed to approve store',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error approving store: $e', isError: true);
      }
    }
  }

  Future<void> _rejectStore(Map<String, dynamic> store) async {
    final TextEditingController reasonController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 8),
            Text('Reject Store'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Store: ${store['store_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Code: ${store['store_code']}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Rejection Reason *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 5,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Please provide a detailed reason for rejection...',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '* This reason will be visible to the store and other approvers',
              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a rejection reason'), backgroundColor: Colors.red),
                );
                return;
              }
              if (reason.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rejection reason must be at least 10 characters'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Reject Store', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    try {
      final storeId = store['store_id'];
      final url = AppConfig.api('/api/iostore/$storeId/approval');
      
      final response = await http.put(
        Uri.parse(url.toString()),
        headers: _getHeaders(),
        body: jsonEncode({
          'approval_status': 'rejected',
          'approved_by': _currentUserPhone ?? 'unknown',
          'approved_at': DateTime.now().toIso8601String(),
          'rejection_reason': reasonController.text.trim(),
          'approve1': store['approve1'],
          'approve2': store['approve2'],
        }),
      );

      if (!mounted) return;

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200 && responseData['status'] == 'success') {
        _showSnackBar(message: 'Store rejected successfully', isError: false);
        await _loadStores();
      } else {
        _showSnackBar(message: responseData['message'] ?? 'Failed to reject store', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error rejecting store: $e', isError: true);
      }
    }
  }

  Future<void> _approveTerminal(Map<String, dynamic> terminal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Approval'),
        content: Text('Are you sure you want to approve "${terminal['terminal_name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final terminalId = terminal['terminal_id'];
      final url = AppConfig.api('/api/ioterminal/$terminalId/approve');
      
      final currentApprove1 = terminal['approve1']?.toString();
      final currentApprove2 = terminal['approve2']?.toString();
      
      if (currentApprove1 == _currentUserPhone || currentApprove2 == _currentUserPhone) {
        _showSnackBar(message: 'You have already approved this terminal', isError: true);
        return;
      }
      
      final isFirstApproval = (currentApprove1 == null || currentApprove1.isEmpty);
      final isSecondApproval = (currentApprove1?.isNotEmpty ?? false) && 
                              (currentApprove2 == null || currentApprove2.isEmpty);
      
      if (!isFirstApproval && !isSecondApproval) {
        _showSnackBar(message: 'Terminal already fully approved', isError: true);
        return;
      }
      
      final requestBody = {
        'approved_by': _currentUserPhone ?? 'unknown',
        'approved_at': DateTime.now().toIso8601String(),
        if (isFirstApproval) ...{
          'approval_status': 'pending',
          'approve1': _currentUserPhone,
        } else ...{
          'approval_status': 'approved',
          'approve1': currentApprove1,
          'approve2': _currentUserPhone,
        },
      };
      
      final response = await http.patch(
        Uri.parse(url.toString()),
        headers: _getHeaders(),
        body: jsonEncode(requestBody),
      );

      if (!mounted) return;

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200 && responseData['status'] == 'success') {
        _showSnackBar(
          message: isSecondApproval 
            ? 'Terminal fully approved! (2/2 approvals)' 
            : 'Terminal approved! Waiting for second approver (1/2)',
          isError: false,
        );
        await _loadTerminals();
      } else {
        _showSnackBar(
          message: responseData['message'] ?? 'Failed to approve terminal',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error approving terminal: $e', isError: true);
      }
    }
  }

  Future<void> _rejectTerminal(Map<String, dynamic> terminal) async {
    final TextEditingController reasonController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 8),
            Text('Reject Terminal'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Terminal: ${terminal['terminal_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Code: ${terminal['terminal_code']}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Rejection Reason *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 5,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Please provide a detailed reason for rejection...',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '* This reason will be visible to the terminal and other approvers',
              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a rejection reason'), backgroundColor: Colors.red),
                );
                return;
              }
              if (reason.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rejection reason must be at least 10 characters'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Reject Terminal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    try {
      final terminalId = terminal['terminal_id'];
      final url = AppConfig.api('/api/ioterminal/$terminalId/approve');
      
      final response = await http.patch(
        Uri.parse(url.toString()),
        headers: _getHeaders(),
        body: jsonEncode({
          'approval_status': 'rejected',
          'approved_by': _currentUserPhone ?? 'unknown',
          'approved_at': DateTime.now().toIso8601String(),
          'rejection_reason': reasonController.text.trim(),
          'approve1': terminal['approve1'],
          'approve2': terminal['approve2'],
        }),
      );

      if (!mounted) return;

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200 && responseData['status'] == 'success') {
        _showSnackBar(message: 'Terminal rejected successfully', isError: false);
        await _loadTerminals();
      } else {
        _showSnackBar(message: responseData['message'] ?? 'Failed to reject terminal', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(message: 'Error rejecting terminal: $e', isError: true);
      }
    }
  }

  void _showSnackBar({required String message, required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getStatus(Map<String, dynamic> item) {
    final approve1 = item['approve1'];
    final approve2 = item['approve2'];
    final approvalStatus = item['approval_status']?.toString().toLowerCase();
    
    if (approvalStatus == 'rejected') return 'REJECTED';
    
    if (approvalStatus == 'approved' && 
        approve1 != null && approve1.toString().isNotEmpty &&
        approve2 != null && approve2.toString().isNotEmpty) {
      return 'APPROVED';
    }
    
    if (approve1 != null && approve1.toString().isNotEmpty &&
        (approve2 == null || approve2.toString().isEmpty)) {
      return 'WAITING FOR 2ND APPROVAL';
    }
    
    return 'PENDING';
  }

  DataCell _buildStoreCell(String columnKey, Map<String, dynamic> store, Color primaryColor) {
    final status = _getStatus(store);
    final approve1 = store['approve1']?.toString();
    final approve2 = store['approve2']?.toString();
    final userAlreadyApproved = (approve1 == _currentUserPhone || approve2 == _currentUserPhone);
    final canApprove = !userAlreadyApproved && status != 'APPROVED' && status != 'REJECTED';
    
    final statusColor = switch (status) {
      'APPROVED' => Colors.green,
      'REJECTED' => Colors.red,
      'WAITING FOR 2ND APPROVAL' => Colors.blue,
      _ => Colors.orange,
    };

    return switch (columnKey) {
      'image' => DataCell(
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: primaryColor.withOpacity(0.1),
          ),
          child: store['image_url'] != null && store['image_url'].toString().isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    store['image_url'],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.store, color: primaryColor, size: 24),
                  ),
                )
              : Icon(Icons.store, color: primaryColor, size: 24),
        ),
      ),
      'store_name' => DataCell(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            store['store_name'] ?? 'N/A',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      'store_code' => DataCell(Text(store['store_code'] ?? 'N/A')),
      'manager' => DataCell(Text(store['store_manager'] ?? 'N/A')),
      'address' => DataCell(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(store['address'] ?? 'N/A', overflow: TextOverflow.ellipsis),
        ),
      ),
      'upi' => DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            store['upi_percentage']?.toString() ?? '-',
            style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.w600),
          ),
        ),
      ),
      'visa' => DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.indigo[50],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            store['visa_percentage']?.toString() ?? '-',
            style: TextStyle(color: Colors.indigo[800], fontWeight: FontWeight.w600),
          ),
        ),
      ),
      'mc' => DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            store['master_percentage']?.toString() ?? '-',
            style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.w600),
          ),
        ),
      ),
      'approve1' => DataCell(_ApproverBadge(approver: approve1)),
      'approve2' => DataCell(_ApproverBadge(approver: approve2)),
      'approval_status' => DataCell(_StatusBadge(status: status, color: statusColor)),
      'created' => DataCell(
        Text(
          store['created_date'] != null 
            ? DateFormat('MMM dd, yyyy').format(DateTime.parse(store['created_date']))
            : 'N/A',
          style: const TextStyle(fontSize: 11),
        ),
      ),
      'actions' => DataCell(
        canApprove
          ? _ActionButtons(
              onApprove: () => _approveStore(store),
              onReject: () => _rejectStore(store),
            )
          : Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                userAlreadyApproved ? '✓ Done' : '-',
                style: TextStyle(
                  color: userAlreadyApproved ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
      ),
      _ => const DataCell(Text('-')),
    };
  }

  DataCell _buildTerminalCell(String columnKey, Map<String, dynamic> terminal, Color primaryColor) {
    final status = _getStatus(terminal);
    final approve1 = terminal['approve1']?.toString();
    final approve2 = terminal['approve2']?.toString();
    final userAlreadyApproved = (approve1 == _currentUserPhone || approve2 == _currentUserPhone);
    final canApprove = !userAlreadyApproved && status != 'APPROVED' && status != 'REJECTED';
    
    final statusColor = switch (status) {
      'APPROVED' => Colors.green,
      'REJECTED' => Colors.red,
      'WAITING FOR 2ND APPROVAL' => Colors.blue,
      _ => Colors.orange,
    };

    return switch (columnKey) {
      'image' => DataCell(
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: primaryColor.withOpacity(0.1),
          ),
          child: terminal['image_url'] != null && terminal['image_url'].toString().isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    terminal['image_url'],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.phone_android, color: primaryColor, size: 24),
                  ),
                )
              : Icon(Icons.phone_android, color: primaryColor, size: 24),
        ),
      ),
      'terminal_name' => DataCell(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            terminal['terminal_name'] ?? 'N/A',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      'terminal_code' => DataCell(Text(terminal['terminal_code'] ?? 'N/A')),
      'store_name' => DataCell(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(terminal['store_name'] ?? '-', overflow: TextOverflow.ellipsis),
        ),
      ),
      'serial_number' => DataCell(Text(terminal['serial_number'] ?? '-')),
      'sim_number' => DataCell(Text(terminal['sim_number'] ?? '-')),
      'expire_date' => DataCell(
        terminal['expire_date'] != null
          ? Text(
              DateFormat('MMM dd, yyyy').format(DateTime.parse(terminal['expire_date'])),
              style: const TextStyle(fontSize: 11),
            )
          : const Text('-'),
      ),
      'phone' => DataCell(Text(terminal['phone'] ?? '-')),
      'approve1' => DataCell(_ApproverBadge(approver: approve1)),
      'approve2' => DataCell(_ApproverBadge(approver: approve2)),
      'approval_status' => DataCell(_StatusBadge(status: status, color: statusColor)),
      'created' => DataCell(
        Text(
          terminal['created_date'] != null 
            ? DateFormat('MMM dd, yyyy').format(DateTime.parse(terminal['created_date']))
            : 'N/A',
          style: const TextStyle(fontSize: 11),
        ),
      ),
      'actions' => DataCell(
        canApprove
          ? _ActionButtons(
              onApprove: () => _approveTerminal(terminal),
              onReject: () => _rejectTerminal(terminal),
            )
          : Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                userAlreadyApproved ? '✓ Done' : '-',
                style: TextStyle(
                  color: userAlreadyApproved ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
      ),
      _ => const DataCell(Text('-')),
    };
  }

  Widget _buildStoreTable() {
    if (_isLoadingStores && _allStores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(ThemeConfig.getPrimaryColor(currentTheme)),
            ),
            const SizedBox(height: 16),
            Text('Loading stores...', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    if (_allStores.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('No stores found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final visibleColumns = _getVisibleColumns(true);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadStores,
            color: primaryColor,
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(primaryColor.withOpacity(0.1)),
                    headingRowHeight: 56,
                    dataRowHeight: 80,
                    border: TableBorder.all(color: Colors.grey[300]!, width: 1),
                    columnSpacing: 16,
                    horizontalMargin: 12,
                    headingTextStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: primaryColor,
                    ),
                    dataTextStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                    columns: visibleColumns.map((col) => DataColumn(label: Text(col['label']))).toList(),
                    rows: _paginatedStores.map((store) {
                      return DataRow(
                        cells: visibleColumns
                          .map((col) => _buildStoreCell(col['key'], store, primaryColor))
                          .toList(),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildPaginationControls(
          currentPage: _currentStorePage,
          totalPages: _totalStorePages,
          itemsPerPage: _storesPerPage,
          totalItems: _allStores.length,
          onPageChanged: _goToStorePage,
          onItemsPerPageChanged: _changeStoresPerPage,
          primaryColor: primaryColor,
        ),
      ],
    );
  }

  Widget _buildTerminalTable() {
    if (_isLoadingTerminals && _allTerminals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(ThemeConfig.getPrimaryColor(currentTheme)),
            ),
            const SizedBox(height: 16),
            Text('Loading terminals...', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    if (_allTerminals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_android, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('No terminals found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final visibleColumns = _getVisibleColumns(false);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadTerminals,
            color: primaryColor,
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(primaryColor.withOpacity(0.1)),
                    headingRowHeight: 56,
                    dataRowHeight: 80,
                    border: TableBorder.all(color: Colors.grey[300]!, width: 1),
                    columnSpacing: 16,
                    horizontalMargin: 12,
                    headingTextStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: primaryColor,
                    ),
                    dataTextStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                    columns: visibleColumns.map((col) => DataColumn(label: Text(col['label']))).toList(),
                    rows: _paginatedTerminals.map((terminal) {
                      return DataRow(
                        cells: visibleColumns
                          .map((col) => _buildTerminalCell(col['key'], terminal, primaryColor))
                          .toList(),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildPaginationControls(
          currentPage: _currentTerminalPage,
          totalPages: _totalTerminalPages,
          itemsPerPage: _terminalsPerPage,
          totalItems: _allTerminals.length,
          onPageChanged: _goToTerminalPage,
          onItemsPerPageChanged: _changeTerminalsPerPage,
          primaryColor: primaryColor,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final primaryColor = ThemeConfig.getPrimaryColor(currentTheme);
    final isStoreTab = _tabController.index == 0;
    final itemCount = isStoreTab ? _allStores.length : _allTerminals.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Approval Management',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(icon: Icon(Icons.store), text: 'Stores'),
            Tab(icon: Icon(Icons.phone_android), text: 'Terminals'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_column),
            onPressed: _showColumnSettings,
            tooltip: 'Manage Columns',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) {
                _loadStores();
              } else {
                _loadTerminals();
              }
            },
            tooltip: 'Refresh',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 16, bottom: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$itemCount ${itemCount == 1 ? (isStoreTab ? 'Store' : 'Terminal') : (isStoreTab ? 'Stores' : 'Terminals')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStoreTable(),
          _buildTerminalTable(),
        ],
      ),
    );
  }
}

// Extracted widgets for better performance
class _PaginationButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  const _PaginationButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}

class _ApproverBadge extends StatelessWidget {
  final String? approver;

  const _ApproverBadge({required this.approver});

  @override
  Widget build(BuildContext context) {
    final hasApprover = approver != null && approver!.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasApprover ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: hasApprover ? Colors.green[300]! : Colors.orange[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasApprover) ...[
            Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
            const SizedBox(width: 4),
          ],
          Text(
            approver ?? 'Pending',
            style: TextStyle(
              fontSize: 11,
              color: hasApprover ? Colors.green[800] : Colors.orange[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusBadge({
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ActionButtons({
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: onApprove,
          icon: const Icon(Icons.check_circle, size: 16),
          label: const Text('Approve', style: TextStyle(fontSize: 11)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(90, 36),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: onReject,
          icon: const Icon(Icons.cancel, size: 16),
          label: const Text('Reject', style: TextStyle(fontSize: 11)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: const Size(90, 36),
          ),
        ),
      ],
    );
  }
}