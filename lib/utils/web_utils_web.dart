import 'dart:html' as html;
import 'dart:typed_data';

class WebUtils {
  static void downloadFile(Uint8List bytes, String filename) {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = filename;
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }
  
  static Future<void> pickFile(Function(dynamic) onFileSelected) async {
    final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*';
    uploadInput.click();

    await uploadInput.onChange.first;
    final files = uploadInput.files;
    if (files!.isEmpty) return;

    final html.File file = files[0];
    final html.FileReader reader = html.FileReader();
    reader.readAsDataUrl(file);
    reader.onLoadEnd.listen((e) => onFileSelected(reader.result));
  }
}