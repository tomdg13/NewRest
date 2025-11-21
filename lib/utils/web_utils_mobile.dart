import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class WebUtils {
  static void downloadFile(Uint8List bytes, String filename) {
    print('Download not available on mobile platform');
  }
  
  static Future<void> pickFile(Function(dynamic) onFileSelected) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final File file = File(image.path);
      final bytes = await file.readAsBytes();
      onFileSelected(bytes);
    }
  }
}
