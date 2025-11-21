// lib/utils/file_utils_web.dart
// Web implementation without dart:io
import 'dart:typed_data';

class PlatformFile {
  final dynamic file; // Web File object
  final Uint8List? bytes;
  final String? name;
  
  PlatformFile({this.file, this.bytes, this.name});
  
  Future<Uint8List> readAsBytes() async {
    if (bytes != null) return bytes!;
    throw Exception('No file data available for web');
  }
}

class FileUtils {
  static bool get isWeb => true;
  
  static PlatformFile createFromFile(dynamic file) {
    return PlatformFile(file: file);
  }
  
  static PlatformFile createFromBytes(Uint8List bytes, String name) {
    return PlatformFile(bytes: bytes, name: name);
  }
}