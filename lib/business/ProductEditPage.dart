import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/config/company_config.dart';
import 'package:inventory/config/config.dart';
import 'package:inventory/config/theme.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ProductEditPage extends StatefulWidget {
  final Map<String, dynamic> productData;

  const ProductEditPage({Key? key, required this.productData})
    : super(key: key);

  @override
  State<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends State<ProductEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _productNameController;
  late final TextEditingController _productCodeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _brandController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _supplierIdController;
  late final TextEditingController _notesController;
  late final TextEditingController _unitController;

  String _selectedStatus = 'active';
  String? _base64Image;
  String? _currentImageUrl;
  File? _imageFile;
  bool _isLoading = false;
  bool _isDeleting = false;
  String currentTheme = ThemeConfig.defaultTheme;

  final List<String> _statusOptions = [
    'active',
    'inactive',
    'pending',
    'deleted',
  ];

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
    _productNameController = TextEditingController(
      text: widget.productData['product_name'] ?? '',
    );
    _productCodeController = TextEditingController(
      text: widget.productData['product_code'] ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.productData['description'] ?? '',
    );
    _categoryController = TextEditingController(
      text: widget.productData['category'] ?? '',
    );
    _brandController = TextEditingController(
      text: widget.productData['brand'] ?? '',
    );
    _barcodeController = TextEditingController(
      text: widget.productData['barcode'] ?? '',
    );
    _supplierIdController = TextEditingController(
      text: widget.productData['supplier_id']?.toString() ?? '',
    );
    _notesController = TextEditingController(
      text: widget.productData['notes'] ?? '',
    );
    _unitController = TextEditingController(
      text: widget.productData['unit']?.toString() ?? '',
    );

    _selectedStatus = widget.productData['status'] ?? 'active';
    _currentImageUrl = widget.productData['image_url'];

    print(
      'DEBUG: Initialized edit form with product: ${widget.productData['product_name']}',
    );
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _productCodeController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _supplierIdController.dispose();
    _notesController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  // Barcode Scanner Methods
  Future<void> _scanBarcode(String fieldType) async {
    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => BarcodeScannerPage(fieldType: fieldType),
        ),
      );

      if (result != null && result.isNotEmpty) {
        setState(() {
          if (fieldType == 'product_code') {
            _productCodeController.text = result;
          } else if (fieldType == 'barcode') {
            _barcodeController.text = result;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Barcode scanned: $result'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Error scanning barcode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error scanning barcode: $e')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      // Show image source selection dialog
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

        print('DEBUG: New image selected for product update');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Image selected successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Error picking image: $e');
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

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final productId = widget.productData['product_id'];

      final url = AppConfig.api('/api/ioproduct/$productId');
      print('DEBUG: Updating product at: $url');

      final productData = <String, dynamic>{
        'company_id': CompanyConfig.getCompanyId(),
      };

      // Only include fields that have values
      if (_productNameController.text.trim().isNotEmpty) {
        productData['product_name'] = _productNameController.text.trim();
      }
      if (_productCodeController.text.trim().isNotEmpty) {
        productData['product_code'] = _productCodeController.text.trim();
      }
      if (_descriptionController.text.trim().isNotEmpty) {
        productData['description'] = _descriptionController.text.trim();
      }
      if (_categoryController.text.trim().isNotEmpty) {
        productData['category'] = _categoryController.text.trim();
      }
      if (_brandController.text.trim().isNotEmpty) {
        productData['brand'] = _brandController.text.trim();
      }
      if (_barcodeController.text.trim().isNotEmpty) {
        productData['barcode'] = _barcodeController.text.trim();
      }
      if (_supplierIdController.text.trim().isNotEmpty) {
        productData['supplier_id'] = int.tryParse(
          _supplierIdController.text.trim(),
        );
      }
      if (_notesController.text.trim().isNotEmpty) {
        productData['notes'] = _notesController.text.trim();
      }
      if (_unitController.text.trim().isNotEmpty) {
        productData['unit'] = int.tryParse(_unitController.text.trim());
      }

      productData['status'] = _selectedStatus;

      if (_base64Image != null) {
        productData['image_url'] = _base64Image;
      }

      print('DEBUG: Update data: ${productData.toString()}');

      final response = await http.put(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(productData),
      );

      print('DEBUG: Update Response Status: ${response.statusCode}');
      print('DEBUG: Update Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product updated successfully!'),
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
      print('DEBUG: Error updating product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteProduct() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Delete Product'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${_productNameController.text}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                backgroundColor: Colors.red.withOpacity(0.1),
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
      final productId = widget.productData['product_id'];

      final url = AppConfig.api('/api/ioproduct/$productId');
      print('DEBUG: Deleting product at: $url');

      final response = await http.delete(
        Uri.parse(url.toString()),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('DEBUG: Delete Response Status: ${response.statusCode}');
      print('DEBUG: Delete Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Product deleted successfully!'),
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
      print('DEBUG: Error deleting product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  Widget _buildImageSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
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
                  'Product Image',
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
                      color: _imageFile != null || (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
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
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      color: ThemeConfig.getPrimaryColor(currentTheme),
                                    ),
                                  );
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
        SizedBox(height: 4),
        Text(
          'Recommended: 800x800px',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildBarcodeField({
    required TextEditingController controller,
    required String label,
    required String scanType,
    required IconData prefixIcon,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
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
              prefixIcon: Icon(
                prefixIcon,
                color: ThemeConfig.getPrimaryColor(currentTheme),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ),
        SizedBox(width: 12),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: ThemeConfig.getPrimaryColor(currentTheme),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.3),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
            onPressed: () => _scanBarcode(scanType),
            tooltip: 'Scan $label',
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
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
                  SizedBox(width: 12),
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
            SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'deleted':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Edit Product'),
        backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
        foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _isLoading || _isDeleting ? null : _deleteProduct,
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
            tooltip: 'Delete Product',
          ),
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
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Image Section
              _buildImageSection(),

              SizedBox(height: 20),

              // Basic Information
              _buildSectionCard(
                title: 'Basic Information',
                icon: Icons.info_outline,
                children: [
                  _buildTextField(
                    controller: _productNameController,
                    label: 'Product Name *',
                    icon: Icons.inventory,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Product name is required';
                      }
                      return null;
                    },
                  ),

                  _buildBarcodeField(
                    controller: _productCodeController,
                    label: 'Product Code',
                    scanType: 'product_code',
                    prefixIcon: Icons.qr_code,
                  ),

                  SizedBox(height: 16),

                  _buildTextField(
                    controller: _categoryController,
                    label: 'Category',
                    icon: Icons.category,
                  ),

                  _buildTextField(
                    controller: _brandController,
                    label: 'Brand',
                    icon: Icons.branding_watermark,
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Additional Information
              _buildSectionCard(
                title: 'Additional Details',
                icon: Icons.more_horiz,
                children: [
                  _buildBarcodeField(
                    controller: _barcodeController,
                    label: 'Barcode',
                    scanType: 'barcode',
                    prefixIcon: Icons.qr_code_scanner,
                  ),

                  SizedBox(height: 16),

                  _buildTextField(
                    controller: _supplierIdController,
                    label: 'Supplier ID',
                    icon: Icons.business,
                    keyboardType: TextInputType.number,
                  ),

                  _buildTextField(
                    controller: _unitController,
                    label: 'Unit Quantity',
                    icon: Icons.numbers,
                    keyboardType: TextInputType.number,
                  ),

                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(
                          Icons.info,
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
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: _statusOptions.map((String status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(status.toUpperCase()),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedStatus = newValue!;
                        });
                      },
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Description
              _buildSectionCard(
                title: 'Description & Notes',
                icon: Icons.description,
                children: [
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    icon: Icons.description,
                    maxLines: 3,
                  ),

                  _buildTextField(
                    controller: _notesController,
                    label: 'Notes',
                    icon: Icons.note,
                    maxLines: 3,
                  ),
                ],
              ),

              SizedBox(height: 30),

              // Update Button
              Container(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading || _isDeleting ? null : _updateProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.getPrimaryColor(currentTheme),
                    foregroundColor: ThemeConfig.getButtonTextColor(currentTheme),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: ThemeConfig.getPrimaryColor(currentTheme).withOpacity(0.3),
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
                              'Updating Product...',
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
                              'Update Product',
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

// Barcode Scanner Page
class BarcodeScannerPage extends StatefulWidget {
  final String fieldType;

  const BarcodeScannerPage({Key? key, required this.fieldType}) : super(key: key);

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage>
    with WidgetsBindingObserver {
  late MobileScannerController _cameraController;
  bool _isScanned = false;
  bool _isInitialized = false;
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.dispose();
    super.dispose();
  }

  void _initializeCamera() {
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _cameraController.stop();
        break;
      case AppLifecycleState.resumed:
        _cameraController.start();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isScanned || !mounted) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;

    final String code = barcodes.first.rawValue!;
    
    print('DEBUG: Barcode detected - Type: ${barcodes.first.type}, Value: $code');

    setState(() => _isScanned = true);

    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      print('Haptic feedback not available');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Barcode scanned: $code'),
        duration: Duration(milliseconds: 1500),
        backgroundColor: Colors.green,
      ),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.pop(context, code);
      }
    });
  }

  void _toggleFlash() async {
    try {
      await _cameraController.toggleTorch();
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      print('DEBUG: Error toggling flash: $e');
    }
  }

  void _switchCamera() async {
    try {
      await _cameraController.switchCamera();
    } catch (e) {
      print('DEBUG: Error switching camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: !_isInitialized ? _buildInitializingState() : _buildScannerContent(),
    );
  }

  Widget _buildInitializingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(
            'Initializing camera...',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerContent() {
    return Stack(
      children: [
        MobileScanner(
          controller: _cameraController,
          onDetect: _onBarcodeDetected,
          errorBuilder: _buildErrorState,
        ),
        CustomPaint(
          painter: ScannerOverlay(
            scanAreaSize: 250,
            borderColor: _isScanned ? Colors.green : Colors.white,
            borderWidth: 3,
          ),
          child: const SizedBox.expand(),
        ),
        if (_isScanned) _buildSuccessIndicator(),
        _buildAppBar(),
        _buildBottomInstructions(),
      ],
    );
  }

  Widget _buildAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.fieldType == 'product_code'
              ? 'Scan Product Code'
              : 'Scan Barcode',
        ),
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_off : Icons.flash_on),
            onPressed: _toggleFlash,
          ),
          IconButton(
            icon: Icon(Icons.flip_camera_ios),
            onPressed: _switchCamera,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, MobileScannerException error) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Camera Error',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Barcode detected!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInstructions() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner, size: 48, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              widget.fieldType == 'product_code'
                  ? 'Position the product code within the frame to scan'
                  : 'Position the barcode within the frame to scan',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Supports QR codes, EAN, UPC, Code128, and more',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Scanner Overlay Painter
class ScannerOverlay extends CustomPainter {
  final double scanAreaSize;
  final Color borderColor;
  final double borderWidth;

  const ScannerOverlay({
    required this.scanAreaSize,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final scanAreaPath = Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: scanAreaSize,
            height: scanAreaSize,
          ),
          const Radius.circular(12),
        ),
      );

    final overlayPath = Path.combine(PathOperation.difference, backgroundPath, scanAreaPath);
    canvas.drawPath(overlayPath, Paint()..color = Colors.black.withOpacity(0.5));

    _drawCornerBrackets(canvas, size);
  }

  void _drawCornerBrackets(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;

    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanAreaSize,
      height: scanAreaSize,
    );

    const cornerLength = 20.0;
    
    _drawCorner(canvas, paint, scanRect.topLeft, cornerLength, true, true);
    _drawCorner(canvas, paint, scanRect.topRight, cornerLength, false, true);
    _drawCorner(canvas, paint, scanRect.bottomLeft, cornerLength, true, false);
    _drawCorner(canvas, paint, scanRect.bottomRight, cornerLength, false, false);
  }

  void _drawCorner(Canvas canvas, Paint paint, Offset corner, double length, 
                  bool isLeft, bool isTop) {
    final horizontalStart = isLeft ? corner : Offset(corner.dx - length, corner.dy);
    final horizontalEnd = isLeft ? Offset(corner.dx + length, corner.dy) : corner;
    
    final verticalStart = isTop ? corner : Offset(corner.dx, corner.dy - length);
    final verticalEnd = isTop ? Offset(corner.dx, corner.dy + length) : corner;

    canvas.drawLine(horizontalStart, horizontalEnd, paint);
    canvas.drawLine(verticalStart, verticalEnd, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}