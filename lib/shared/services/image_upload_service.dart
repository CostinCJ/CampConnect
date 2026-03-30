// lib/shared/services/image_upload_service.dart
import 'dart:ui' as ui;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ImageUploadService {
  final FirebaseStorage _storage;

  ImageUploadService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Upload an image to Firebase Storage. Compresses to max 1200px width.
  /// Returns the download URL.
  Future<String> uploadImage({
    required XFile imageFile,
    required String storagePath,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final compressed = await _compressImage(bytes);

    final ref = _storage.ref().child(storagePath);
    final uploadTask = ref.putData(
      compressed,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }

  /// Delete an image from Firebase Storage by its download URL.
  Future<void> deleteImage(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (_) {
      // Ignore if file doesn't exist
    }
  }

  /// Compress and resize image to max 1200px width.
  Future<Uint8List> _compressImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 1200,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();

    if (byteData == null) return bytes;
    return byteData.buffer.asUint8List();
  }
}
