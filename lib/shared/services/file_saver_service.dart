import 'package:flutter/services.dart';

class FileSaverService {
  static const _channel = MethodChannel('com.campconnect/file_saver');

  /// Save bytes to the device's Downloads folder via Android MediaStore.
  /// Returns the filename on success.
  static Future<String> saveToDownloads({
    required Uint8List bytes,
    required String filename,
    String mimeType = 'application/pdf',
  }) async {
    final result = await _channel.invokeMethod<String>('saveToDownloads', {
      'bytes': bytes,
      'filename': filename,
      'mimeType': mimeType,
    });
    return result ?? filename;
  }
}
