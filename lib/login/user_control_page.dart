import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/config.dart';
import 'package:inventory/login/login_page.dart';
import 'dart:convert';

import '../utils/simple_translations.dart'; // adjust path if needed
import 'package:shared_preferences/shared_preferences.dart'; // for loading language

class UserControlPage extends StatefulWidget {
  const UserControlPage({Key? key}) : super(key: key);

  @override
  State<UserControlPage> createState() => _UserControlPageState();
}

String langCode = 'en';

class _UserControlPageState extends State<UserControlPage> {
  List<User> users = [];
  List<User> filteredUsers = [];
  bool loading = true;
  String? error;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    debugPrint('Language code: $langCode');

    _loadLangCode(); // Call it here if you want
    // other initialization...

    fetchUsersByRole('Admin');
    _searchController.addListener(() {
      filterUsers(_searchController.text);
    });
  }

  void _loadLangCode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCode = prefs.getString('langCode') ?? 'en';
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void filterUsers(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredUsers = users.where((user) {
        final nameLower = user.name.toLowerCase();
        final phoneLower = user.phone.toLowerCase();
        return nameLower.contains(lowerQuery) ||
            phoneLower.contains(lowerQuery);
      }).toList();
    });
  }

  Future<void> fetchUsersByRole(String role) async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    final url = AppConfig.api('/api/user/userRole');
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token}',
        },
        body: jsonEncode({'role': role}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final List<dynamic> rawUsers = data['data'] ?? [];
          users = rawUsers.map((e) => User.fromJson(e)).toList();
          filteredUsers = users;
          setState(() => loading = false);
        } else {
          setState(() {
            loading = false;
            error = data['message'] ?? 'Unknown error';
          });
        }
      } else {
        setState(() {
          loading = false;
          error = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        error = 'Failed to load data: $e';
      });
    }
  }

  void _onAddUser() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );

    if (result == true) {
      fetchUsersByRole('Admin'); // Refresh list
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Text(error!, style: const TextStyle(color: Colors.red)),
      );
    }

    if (users.isEmpty) {
      return const Center(child: Text('No users found.'));
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: SimpleTranslations.get(langCode, 'search'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredUsers.isEmpty
                ? Center(
                    child: Text(
                      SimpleTranslations.get(langCode, 'no_users_found'),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (ctx, i) {
                      final u = filteredUsers[i];

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: u.photo.isNotEmpty
                              ? NetworkImage(u.photo)
                              : const AssetImage(
                                      'assets/images/default_user.png',
                                    )
                                    as ImageProvider,
                        ),
                        title: Text(u.name),
                        subtitle: Text(u.phone),
                        onTap: () {
                          // Navigator.push(
                          //   context,
                          //MaterialPageRoute(
                          // builder: (_) => UserInfoPage(
                          //   userData: {
                          //     'username': u.username,
                          //     'phone': u.phone,
                          //     'email': u.email,
                          //     'name': u.name,
                          //     'photo': u.photo,
                          //     'photo_id': u.photo_id,
                          //     'document_id': u.documentId ?? '',
                          //     'bank_name': u.bankName ?? '',
                          //     'province_name': u.provinceName ?? '',
                          //     'district_name': u.districtName ?? '',
                          //     'village_name': u.villageName ?? '',
                          //     'account_no': u.accountNo ?? '',
                          //     'account_name': u.accountName ?? '',
                          //   },
                          // ),
                          //),
                          // );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _onAddUser,
        backgroundColor: Colors.blue,
        tooltip: SimpleTranslations.get(langCode, 'add_user'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class User {
  final String username;
  final String name;
  final String email;
  final String phone;
  final String photo;
  final String photo_id;
  final String? documentId;
  final String? bankName;
  final String? provinceName;
  final String? districtName;
  final String? villageName;
  final String? accountNo;
  final String? accountName;
  User({
    required this.username,
    required this.name,
    required this.email,
    required this.phone,
    required this.photo,
    required this.photo_id,
    this.documentId,
    this.bankName,
    this.provinceName,
    this.districtName,
    this.villageName,
    this.accountNo,
    this.accountName,
  });
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      photo: json['photo'] ?? '',
      photo_id: json['photo_id'] ?? '',
      documentId: json['document_id'],
      bankName: json['bank_name'],
      provinceName: json['province_name'],
      districtName: json['district_name'],
      villageName: json['village_name'],
      accountNo: json['account_no'],
      accountName: json['account_name'],
    );
  }
}
