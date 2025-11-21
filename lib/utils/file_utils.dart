// lib/utils/file_utils.dart
// Mobile implementation using dart:io
import 'dart:io';
import 'dart:typed_data';

class PlatformFile {
  final File? file;
  final Uint8List? bytes;
  final String? name;
  
  PlatformFile({this.file, this.bytes, this.name});
  
  Future<Uint8List> readAsBytes() async {
    if (bytes != null) return bytes!;
    if (file != null) return await file!.readAsBytes();
    throw Exception('No file data available');
  }
}

class FileUtils {
  static bool get isWeb => false;
  
  static PlatformFile createFromFile(File file) {
    return PlatformFile(file: file);
  }
  
  static PlatformFile createFromBytes(Uint8List bytes, String name) {
    return PlatformFile(bytes: bytes, name: name);
  }
}