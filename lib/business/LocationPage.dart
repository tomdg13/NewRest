import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:http/http.dart' as http;
import 'package:Restaurant/config/company_config.dart';
import 'LocationAddPage.dart';
import 'LocationEditPage.dart';
import 'package:Restaurant/config/config.dart';
import 'package:Restaurant/config/theme.dart';
import 'dart:convert';
import '../utils/simple_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({Key? key}) : super(key: key);

  @override
  State<LocationPage> createState() => _LocationPageState();
}

String langCode = 'en';

class _LocationPageState extends State<LocationPage> {
  List<IoLocation> locations = [];
  List<IoLocation> filteredLocations = [];
  bool loading = true;
  String? error;
  String currentTheme = ThemeConfig.defaultTheme;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print('🚀 DEBUG: LocationPage initState() called');
    debugPrint('Language code: $langCode');
    debugPrint('Running on web: ${kIsWeb}');

    _loadLangCode();
    _loadCurrentTheme();
    fetchLocations();
    
    _searchController.addListener(() {
      print('🔍 DEBUG: Search query: ${_searchController.text}');
      filterLocations(_searchController.text);
    });
  }

  void _loadLangCode() async {
    print('📱 DEBUG: Loading language code...');
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      langCode = prefs.getString('languageCode') ?? 'en';
      print('🌐 DEBUG: Language code loaded: $langCode');
    });
  }

  void _loadCurrentTheme() async {
    print('🎨 DEBUG: Loading current theme...');
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentTheme = prefs.getString('selectedTheme') ?? ThemeConfig.defaultTheme;
      print('🎨 DEBUG: Theme loaded: $currentTheme');
    });
  }

  @override
  void dispose() {
    print('🗑️ DEBUG: LocationPage dispose() called');
    _searchController.dispose();
    super.dispose();
  }

  void filterLocations(String query) {
    print('🔍 DEBUG: Filtering locations with query: "$query"');
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredLocations = locations.where((location) {
        final nameLower = location.locationName.toLowerCase();
        bool matches = nameLower.contains(lowerQuery);
        return matches;
      }).toList();
      print('🔍 DEBUG: Filtered locations count: ${filteredLocations.length}');
    });
  }

  Future<void> fetchLocations() async {
    print('🔍 DEBUG: Starting fetchLocations()');
    
    if (!mounted) {
      print('⚠️ DEBUG: Widget not mounted, aborting fetchLocations()');
      return;
    }
    
    setState(() {
      loading = true;
      error = null;
    });

    // Correct API endpoint for your NestJS IoLocation API
    final url = AppConfig.api('/api/iolocation');
    print('🌐 DEBUG: API URL: $url');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final companyId = CompanyConfig.getCompanyId();
      
      print('🔑 DEBUG: Token: ${token != null ? '${token.substring(0, 20)}...' : 'null'}');
      print('🏢 DEBUG: Company ID: $companyId');
      
      // Build query parameters
      final queryParams = {
        'status': 'admin', // Use admin to see all locations
        'company_id': companyId.toString(),
      };
      
      final uri = Uri.parse(url.toString()).replace(queryParameters: queryParams);
      print('🔗 DEBUG: Full URI: $uri');
      
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      print('📋 DEBUG: Request headers: $headers');
      
      final response = await http.get(uri, headers: headers);

      print('📡 DEBUG: Response Status Code: ${response.statusCode}');
      print('📄 DEBUG: Response Headers: ${response.headers}');
      print('📝 DEBUG: Response Body: ${response.body}');

      if (!mounted) {
        print('⚠️ DEBUG: Widget not mounted after API call, aborting');
        return;
      }

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          print('✅ DEBUG: Parsed JSON successfully');
          print('📊 DEBUG: API Response structure: ${data.keys.toList()}');
          
          if (data['status'] == 'success') {
            final List<dynamic> rawLocations = data['data'] ?? [];
            print('📦 DEBUG: Raw locations count: ${rawLocations.length}');
            
            // Print first location for debugging
            if (rawLocations.isNotEmpty) {
              print('🔍 DEBUG: First location data: ${rawLocations[0]}');
            }
            
            locations = rawLocations.map((e) {
              try {
                return IoLocation.fromJson(e);
              } catch (parseError) {
                print('❌ DEBUG: Error parsing location: $parseError');
                print('📝 DEBUG: Problem location data: $e');
                rethrow;
              }
            }).toList();
            
            filteredLocations = List.from(locations);
            
            print('✅ DEBUG: Total locations loaded: ${locations.length}');
            print('✅ DEBUG: Filtered locations: ${filteredLocations.length}');
            
            setState(() => loading = false);
          } else {
            print('❌ DEBUG: API returned error status: ${data['status']}');
            print('❌ DEBUG: API error message: ${data['message']}');
            setState(() {
              loading = false;
              error = data['message'] ?? 'Unknown error from API';
            });
          }
        } catch (jsonError) {
          print('❌ DEBUG: JSON parsing error: $jsonError');
          print('📝 DEBUG: Raw response that failed to parse: ${response.body}');
          setState(() {
            loading = false;
            error = 'Failed to parse server response: $jsonError';
          });
        }
      } else {
        print('❌ DEBUG: HTTP Error ${response.statusCode}');
        print('❌ DEBUG: Error response body: ${response.body}');
        setState(() {
          loading = false;
          error = 'Server error: ${response.statusCode}\n${response.body}';
        });
      }
    } catch (e, stackTrace) {
      print('💥 DEBUG: Exception caught: $e');
      print('📚 DEBUG: Stack trace: $stackTrace');
      setState(() {
        loading = false;
        error = 'Failed to load data: $e';
      });
    }
  }

  void _onAddLocation() async {
    print('➕ DEBUG: Add Location button pressed');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LocationAddPage()),
    );

    print('📝 DEBUG: Add Location result: $result');
    if (result == true) {
      print('🔄 DEBUG: Refreshing locations after add');
      fetchLocations();
    }
  }

  Widget _buildLocationImage(IoLocation location) {
    print('🖼️ DEBUG: Building image for location: ${location.locationName}');
    print('🖼️ DEBUG: Image URL: ${location.imageUrl}');
    
    // Check if we have a valid image URL
    if (location.imageUrl == null || location.imageUrl!.isEmpty) {
      print('🖼️ DEBUG: No image URL, showing placeholder');
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[200],
        child: Icon(
          Icons.location_on,
          color: Colors.grey[600],
          size: 30,
        ),
      );
    }

    // Handle different image URL formats
    String imageUrl = location.imageUrl!;
    
    // If it's a relative URL, make it absolute
    if (!imageUrl.startsWith('http')) {
      // Get base URL from your config
      final baseUrl = AppConfig.api('').toString().replaceAll('/api', '');
      
      // Handle different path formats
      if (imageUrl.startsWith('/')) {
        imageUrl = '$baseUrl$imageUrl';
      } else {
        imageUrl = '$baseUrl/$imageUrl';
      }
    }
    
    print('🖼️ DEBUG: Final image URL: $imageUrl');

    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          // Web-specific configurations
          headers: kIsWeb ? null : {}, // Headers for web requests if needed
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              print('🖼️ DEBUG: Image loaded successfully for ${location.locationName}');
              return child;
            }
            print('🖼️ DEBUG: Loading image for ${location.locationName}...');
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
            print('❌ DEBUG: Error loading image for ${location.locationName}: $error');
            print('📝 DEBUG: Failed URL: $imageUrl');
            return Icon(
              Icons.location_on,
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
    print('🎨 DEBUG: Building LocationPage widget');
    print('📊 DEBUG: Current state - loading: $loading, error: $error, locations: ${locations.length}');
    
    // Get responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final horizontalPadding = isWideScreen ? 32.0 : 16.0;
    final cardMargin = isWideScreen ? 
        EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8) :
        EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    
    if (loading) {
      print('⏳ DEBUG: Showing loading indicator');
      return Scaffold(
        appBar: AppBar(
          title: Text('Locations'),
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
              Text('Loading Locations...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      print('❌ DEBUG: Showing error state: $error');
      return Scaffold(
        appBar: AppBar(
          title: Text('Locations'),
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
                    'Error Loading Locations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ThemeConfig.getThemeColors(currentTheme)['error'] ?? Colors.red,
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      print('🔄 DEBUG: Retry button pressed');
                      fetchLocations();
                    },
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

    if (locations.isEmpty) {
      print('📭 DEBUG: Showing empty state');
      return Scaffold(
        appBar: AppBar(
          title: Text('Locations (0)'),
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          actions: [
            IconButton(
              onPressed: () {
                print('🔄 DEBUG: Refresh button pressed from empty state');
                fetchLocations();
              },
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
                Icon(Icons.location_on_outlined, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Locations found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _onAddLocation,
                  icon: Icon(Icons.add),
                  label: Text('Add First Location'),
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
          onPressed: _onAddLocation,
          backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
          foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
          tooltip: SimpleTranslations.get(langCode, 'add_Location'),
          child: const Icon(Icons.add),
        ),
      );
    }

    print('📱 DEBUG: Rendering main location list with ${filteredLocations.length} locations');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${SimpleTranslations.get(langCode, 'Locations')} (${filteredLocations.length})'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        actions: [
          if (isWideScreen) ...[
            // Add button in app bar for wide screens
            IconButton(
              onPressed: _onAddLocation,
              icon: const Icon(Icons.add),
              tooltip: SimpleTranslations.get(langCode, 'add_Location'),
            ),
          ],
          IconButton(
            onPressed: () {
              print('🔄 DEBUG: Refresh button pressed from app bar');
              fetchLocations();
            },
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
                            onPressed: () {
                              print('🧹 DEBUG: Clear search button pressed');
                              _searchController.clear();
                            },
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
                child: filteredLocations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No Locations match your search'
                                  : 'No Locations found',
                              style: const TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            if (_searchController.text.isNotEmpty) ...[
                              SizedBox(height: 8),
                              Text(
                                'Try a different search term',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: fetchLocations,
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
        onPressed: _onAddLocation,
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        tooltip: SimpleTranslations.get(langCode, 'add_Location'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildListView(EdgeInsets cardMargin) {
    return ListView.builder(
      itemCount: filteredLocations.length,
      itemBuilder: (ctx, i) {
        final location = filteredLocations[i];
        print('🏗️ DEBUG: Building list item for location: ${location.locationName}');

        return Card(
          margin: cardMargin,
          elevation: 2,
          child: ListTile(
            leading: _buildLocationImage(location),
            title: Text(
              location.locationName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: _buildLocationSubtitle(location),
            trailing: Icon(
              Icons.edit,
              color: ThemeConfig.getPrimaryColor(currentTheme),
            ),
            onTap: () => _navigateToEdit(location),
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
      itemCount: filteredLocations.length,
      itemBuilder: (ctx, i) {
        final location = filteredLocations[i];
        print('🏗️ DEBUG: Building grid item for location: ${location.locationName}');

        return Card(
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _navigateToEdit(location),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildLocationImage(location),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          location.locationName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        _buildLocationSubtitle(location, compact: true),
                      ],
                    ),
                  ),
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

  Widget _buildLocationSubtitle(IoLocation location, {bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Company ID: ${location.companyId}',
          style: TextStyle(
            fontSize: compact ? 11 : 13,
            color: Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _navigateToEdit(IoLocation location) async {
    print('👆 DEBUG: Location tapped: ${location.locationName}');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationEditPage(
          LocationData: location.toJson(),
        ),
      ),
    );

    print('📝 DEBUG: Edit Location result: $result');
    if (result == true || result == 'deleted') {
      print('🔄 DEBUG: Location operation completed, refreshing list...');
      fetchLocations();
      
      if (result == 'deleted') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location removed from list'),
            backgroundColor: ThemeConfig.getThemeColors(currentTheme)['success'] ?? Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

// Updated IoLocation model to match your io_location table structure
class IoLocation {
  final int locationId;
  final int companyId;
  final String locationName;
  final String? imageUrl;
  
  IoLocation({
    required this.locationId,
    required this.companyId,
    required this.locationName,
    this.imageUrl,
  });
  
  factory IoLocation.fromJson(Map<String, dynamic> json) {
    print('🔄 DEBUG: Converting JSON to IoLocation');
    print('📝 DEBUG: JSON keys: ${json.keys.toList()}');
    print('📝 DEBUG: JSON data: $json');
    
    try {
      final location = IoLocation(
        locationId: json['location_id'] ?? 0,
        companyId: CompanyConfig.getCompanyId(), // Use centralized config instead
        locationName: json['location'] ?? '',
        imageUrl: json['image_url'],
      );
      print('✅ DEBUG: Successfully created IoLocation: ${location.locationName}');
      return location;
    } catch (e, stackTrace) {
      print('❌ DEBUG: Error parsing IoLocation JSON: $e');
      print('📚 DEBUG: Stack trace: $stackTrace');
      print('📝 DEBUG: Problem JSON: $json');
      rethrow;
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'location_id': locationId,
      'company_id': companyId,
      'location': locationName,
      'image_url': imageUrl,
    };
  }
}