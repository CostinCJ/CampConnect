// lib/shared/services/image_upload_service.dart
import 'dart:ui' as ui;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
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
      // Long max-age lets Google's edge cache and device caches absorb repeat
      // downloads (egress is billed). Safe despite overwrites at the same
      // path: overwriting rotates the download token, so the URL — and thus
      // the cache key — changes, and callers store the fresh URL.
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      ),
    );

    final snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }

  /// Delete an image from Firebase Storage by its download URL.
  Future<void> deleteImage(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } on FirebaseException catch (e) {
      // An already-missing object is fine (the goal state is "gone"); anything
      // else — e.g. a rules denial — must reach the caller instead of silently
      // orphaning the file in Storage.
      if (e.code != 'object-not-found') rethrow;
    }
  }

  /// Compress and resize an image to max 1200px width, encoded as JPEG (the
  /// content-type and `*.jpg` storage paths the rules expect). Decoding goes
  /// through dart:ui so platform-native formats (incl. HEIC from the iOS
  /// picker) are handled; JPEG encoding is done by the `image` package since
  /// dart:ui can only emit PNG/raw pixels.
  Future<Uint8List> _compressImage(Uint8List bytes) async {
    // Decode at native resolution to avoid upscaling small images.
    final descriptor = await ui.ImageDescriptor.encoded(
      await ui.ImmutableBuffer.fromUint8List(bytes),
    );
    final targetWidth = descriptor.width > 1200 ? 1200 : descriptor.width;
    final codec = await descriptor.instantiateCodec(targetWidth: targetWidth);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    final width = image.width;
    final height = image.height;
    image.dispose();
    descriptor.dispose();

    if (byteData == null) return bytes;

    final rgba = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: byteData.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    return Uint8List.fromList(img.encodeJpg(rgba, quality: 85));
  }
}
