// lib/models/terminal_models.dart

// Enums
enum MessageType { success, error, warning }

// Data Models
class Terminal {
  final int terminalId;
  final String terminalName;
  final int companyId;
  final int storeId;
  final String? imageUrl;
  final String? terminalCode;
  final String? serialNumber;    // NEW FIELD
  final String? simNumber;       // NEW FIELD
  final DateTime? expireDate;    // NEW FIELD
  final String? approvalStatus; // ADD THIS FIELD

  const Terminal({
    required this.terminalId,
    required this.terminalName,
    required this.companyId,
    required this.storeId,
    this.imageUrl,
    this.terminalCode,
    this.serialNumber,    // NEW FIELD
    this.simNumber,       // NEW FIELD
    this.expireDate,      // NEW FIELD
    this.approvalStatus, // ADD TO CONSTRUCTOR
  }) : assert(terminalId > 0, 'Terminal ID must be positive'),
       assert(terminalName != '', 'Terminal name cannot be empty');

  factory Terminal.fromJson(Map<String, dynamic> json) {
    return Terminal(
      terminalId: json['terminal_id'] ?? 0,
      terminalName: json['terminal_name'] ?? '',
      companyId: json['company_id'] ?? 0,
      storeId: json['store_id'] ?? 0,
      imageUrl: json['image_url'],
      terminalCode: json['terminal_code'],
      serialNumber: json['serial_number'],    // NEW FIELD
      simNumber: json['sim_number'],          // NEW FIELD
      expireDate: json['expire_date'] != null 
          ? DateTime.tryParse(json['expire_date']) 
          : null,                             // NEW FIELD
      approvalStatus: json['approval_status'], // ADD THIS LINE
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'terminal_id': terminalId,
      'terminal_name': terminalName,
      'company_id': companyId,
      'store_id': storeId,
      'image_url': imageUrl,
      'terminal_code': terminalCode,
      'serial_number': serialNumber,          // NEW FIELD
      'sim_number': simNumber,                // NEW FIELD
      'expire_date': expireDate?.toIso8601String().split('T')[0], // NEW FIELD (YYYY-MM-DD format)
      'approval_status': approvalStatus, // ADD THIS LINE

    };
  }

  Terminal copyWith({
    int? terminalId,
    String? terminalName,
    int? companyId,
    int? storeId,
    String? imageUrl,
    String? terminalCode,
    String? serialNumber,    // NEW FIELD
    String? simNumber,       // NEW FIELD
    DateTime? expireDate,    // NEW FIELD
    String? approvalStatus, // ADD THIS
  }) {
    return Terminal(
      terminalId: terminalId ?? this.terminalId,
      terminalName: terminalName ?? this.terminalName,
      companyId: companyId ?? this.companyId,
      storeId: storeId ?? this.storeId,
      imageUrl: imageUrl ?? this.imageUrl,
      terminalCode: terminalCode ?? this.terminalCode,
      serialNumber: serialNumber ?? this.serialNumber,    // NEW FIELD
      simNumber: simNumber ?? this.simNumber,              // NEW FIELD
      expireDate: expireDate ?? this.expireDate,           // NEW FIELD
    );
  }

  // Helper methods for expiry status
  bool get isExpired {
    if (expireDate == null) return false;
    return DateTime.now().isAfter(expireDate!);
  }

  bool get isExpiringSoon {
    if (expireDate == null) return false;
    final now = DateTime.now();
    final daysUntilExpiry = expireDate!.difference(now).inDays;
    return daysUntilExpiry >= 0 && daysUntilExpiry <= 30;
  }

  int get daysUntilExpiry {
    if (expireDate == null) return -1;
    return expireDate!.difference(DateTime.now()).inDays;
  }

  String get expiryStatus {
    if (expireDate == null) return 'No expiry date';
    if (isExpired) return 'Expired';
    if (isExpiringSoon) return 'Expiring soon';
    return 'Active';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Terminal &&
          runtimeType == other.runtimeType &&
          terminalId == other.terminalId;

  @override
  int get hashCode => terminalId.hashCode;

  @override
  String toString() => 'Terminal(id: $terminalId, name: $terminalName, serial: $serialNumber)';
}

class Group {
  final int id;
  final String groupName;
  final int companyId;
  final String? imageUrl;
  final String? groupCode;

  const Group({
    required this.id,
    required this.groupName,
    required this.companyId,
    this.imageUrl,
    this.groupCode,
  }) : assert(id > 0, 'Group ID must be positive'),
       assert(groupName != '', 'Group name cannot be empty');

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['group_id'] ?? 0,
      groupName: json['group_name'] ?? '',
      companyId: json['company_id'] ?? 0,
      imageUrl: json['image_url'],
      groupCode: json['group_code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_id': id,
      'group_name': groupName,
      'company_id': companyId,
      'image_url': imageUrl,
      'group_code': groupCode,
    };
  }

  Group copyWith({
    int? id,
    String? groupName,
    int? companyId,
    String? imageUrl,
    String? groupCode,
  }) {
    return Group(
      id: id ?? this.id,
      groupName: groupName ?? this.groupName,
      companyId: companyId ?? this.companyId,
      imageUrl: imageUrl ?? this.imageUrl,
      groupCode: groupCode ?? this.groupCode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Group &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Group(id: $id, name: $groupName)';
}

class Merchant {
  final int merchantId;
  final String merchantName;
  final int companyId;
  final int groupId;
  final String? imageUrl;
  final String? merchantCode;

  const Merchant({
    required this.merchantId,
    required this.merchantName,
    required this.companyId,
    required this.groupId,
    this.imageUrl,
    this.merchantCode,
  }) : assert(merchantId > 0, 'Merchant ID must be positive'),
       assert(merchantName != '', 'Merchant name cannot be empty');

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      merchantId: json['merchant_id'] ?? 0,
      merchantName: json['merchant_name'] ?? '',
      companyId: json['company_id'] ?? 0,
      groupId: json['group_id'] ?? 0,
      imageUrl: json['image_url'],
      merchantCode: json['merchant_code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchant_id': merchantId,
      'merchant_name': merchantName,
      'company_id': companyId,
      'group_id': groupId,
      'image_url': imageUrl,
      'merchant_code': merchantCode,
    };
  }

  Merchant copyWith({
    int? merchantId,
    String? merchantName,
    int? companyId,
    int? groupId,
    String? imageUrl,
    String? merchantCode,
  }) {
    return Merchant(
      merchantId: merchantId ?? this.merchantId,
      merchantName: merchantName ?? this.merchantName,
      companyId: companyId ?? this.companyId,
      groupId: groupId ?? this.groupId,
      imageUrl: imageUrl ?? this.imageUrl,
      merchantCode: merchantCode ?? this.merchantCode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Merchant &&
          runtimeType == other.runtimeType &&
          merchantId == other.merchantId;

  @override
  int get hashCode => merchantId.hashCode;

  @override
  String toString() => 'Merchant(id: $merchantId, name: $merchantName)';
}

class Store {
  final int storeId;
  final String storeName;
  final int companyId;
  final int merchantId;
  final String? imageUrl;
  final String? storeCode;
  final String? approvalStatus; // ADD THIS FIELD


  const Store({
    required this.storeId,
    required this.storeName,
    required this.companyId,
    required this.merchantId,
    this.imageUrl,
    this.storeCode,
    this.approvalStatus, // ADD TO CONSTRUCTOR
  }) : assert(storeId > 0, 'Store ID must be positive'),
       assert(storeName != '', 'Store name cannot be empty');

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      storeId: json['store_id'] ?? 0,
      storeName: json['store_name'] ?? '',
      companyId: json['company_id'] ?? 0,
      merchantId: json['merchant_id'] ?? 0,
      imageUrl: json['image_url'],
      storeCode: json['store_code'],
      approvalStatus: json['approval_status'], // ADD THIS LINE
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'store_id': storeId,
      'store_name': storeName,
      'company_id': companyId,
      'merchant_id': merchantId,
      'image_url': imageUrl,
      'store_code': storeCode,
      'approval_status': approvalStatus, // ADD THIS LINE
    };
  }

  Store copyWith({
    int? storeId,
    String? storeName,
    int? companyId,
    int? merchantId,
    String? imageUrl,
    String? storeCode,
    String? approvalStatus, // ADD THIS
  }) {
    return Store(
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      companyId: companyId ?? this.companyId,
      merchantId: merchantId ?? this.merchantId,
      imageUrl: imageUrl ?? this.imageUrl,
      storeCode: storeCode ?? this.storeCode,
      approvalStatus: approvalStatus ?? this.approvalStatus, // ADD THIS
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Store &&
          runtimeType == other.runtimeType &&
          storeId == other.storeId;

  @override
  int get hashCode => storeId.hashCode;

  @override
  String toString() => 'Store(id: $storeId, name: $storeName)';
}

// NEW: Terminal statistics model
class TerminalStats {
  final int totalTerminals;
  final int terminalsWithImages;
  final int terminalsWithSerial;
  final int terminalsWithSim;
  final int terminalsWithExpireDate;
  final int expiredTerminals;
  final int expiringSoonTerminals;

  const TerminalStats({
    required this.totalTerminals,
    required this.terminalsWithImages,
    required this.terminalsWithSerial,
    required this.terminalsWithSim,
    required this.terminalsWithExpireDate,
    this.expiredTerminals = 0,
    this.expiringSoonTerminals = 0,
  });

  factory TerminalStats.fromJson(Map<String, dynamic> json) {
    return TerminalStats(
      totalTerminals: json['total_terminals'] ?? 0,
      terminalsWithImages: json['terminals_with_images'] ?? 0,
      terminalsWithSerial: json['terminals_with_serial'] ?? 0,
      terminalsWithSim: json['terminals_with_sim'] ?? 0,
      terminalsWithExpireDate: json['terminals_with_expire_date'] ?? 0,
      expiredTerminals: json['expired'] ?? 0,
      expiringSoonTerminals: json['expiring_soon'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_terminals': totalTerminals,
      'terminals_with_images': terminalsWithImages,
      'terminals_with_serial': terminalsWithSerial,
      'terminals_with_sim': terminalsWithSim,
      'terminals_with_expire_date': terminalsWithExpireDate,
      'expired': expiredTerminals,
      'expiring_soon': expiringSoonTerminals,
    };
  }
}

// NEW: Search and filter criteria
class TerminalSearchCriteria {
  final String? search;
  final int? companyId;
  final int? storeId;
  final int? merchantId;
  final int? groupId;
  final String? serialNumber;
  final String? simNumber;
  final DateTime? expireDateFrom;
  final DateTime? expireDateTo;
  final int? daysBeforeExpiry;
  final String? sortBy;
  final String? sortOrder;
  final int? page;
  final int? limit;

  const TerminalSearchCriteria({
    this.search,
    this.companyId,
    this.storeId,
    this.merchantId,
    this.groupId,
    this.serialNumber,
    this.simNumber,
    this.expireDateFrom,
    this.expireDateTo,
    this.daysBeforeExpiry,
    this.sortBy,
    this.sortOrder,
    this.page,
    this.limit,
  });

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    
    if (search != null) params['search'] = search;
    if (companyId != null) params['company_id'] = companyId;
    if (storeId != null) params['store_id'] = storeId;
    if (merchantId != null) params['merchant_id'] = merchantId;
    if (groupId != null) params['group_id'] = groupId;
    if (serialNumber != null) params['serial_number'] = serialNumber;
    if (simNumber != null) params['sim_number'] = simNumber;
    if (expireDateFrom != null) {
      params['date_from'] = expireDateFrom!.toIso8601String().split('T')[0];
    }
    if (expireDateTo != null) {
      params['date_to'] = expireDateTo!.toIso8601String().split('T')[0];
    }
    if (daysBeforeExpiry != null) params['days_before_expiry'] = daysBeforeExpiry;
    if (sortBy != null) params['sort_by'] = sortBy;
    if (sortOrder != null) params['sort_order'] = sortOrder;
    if (page != null) params['page'] = page;
    if (limit != null) params['limit'] = limit;
    
    return params;
  }

  TerminalSearchCriteria copyWith({
    String? search,
    int? companyId,
    int? storeId,
    int? merchantId,
    int? groupId,
    String? serialNumber,
    String? simNumber,
    DateTime? expireDateFrom,
    DateTime? expireDateTo,
    int? daysBeforeExpiry,
    String? sortBy,
    String? sortOrder,
    int? page,
    int? limit,
  }) {
    return TerminalSearchCriteria(
      search: search ?? this.search,
      companyId: companyId ?? this.companyId,
      storeId: storeId ?? this.storeId,
      merchantId: merchantId ?? this.merchantId,
      groupId: groupId ?? this.groupId,
      serialNumber: serialNumber ?? this.serialNumber,
      simNumber: simNumber ?? this.simNumber,
      expireDateFrom: expireDateFrom ?? this.expireDateFrom,
      expireDateTo: expireDateTo ?? this.expireDateTo,
      daysBeforeExpiry: daysBeforeExpiry ?? this.daysBeforeExpiry,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }
}