import 'dart:typed_data';

class WebUtils {
  static void downloadFile(Uint8List bytes, String filename) {
    throw UnsupportedError('File download not supported on this platform');
  }
  
  static Future<void> pickFile(Function(dynamic) onFileSelected) async {
    throw UnsupportedError('File picker not supported on this platform');
  }
}