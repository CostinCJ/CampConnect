import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:camp_connect/core/constants/app_constants.dart';

class ModelDownloader {
  /// Download progress callback: value between 0.0 and 1.0
  final void Function(double progress)? onProgress;

  ModelDownloader({this.onProgress});

  // Qwen2.5-0.5B-Instruct Q4_K_M GGUF from HuggingFace (~490MB)
  // Works on all ARMv8 with software dot-product (no +dotprod in build)
  static const _modelUrl =
      'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf';

  Future<String> get _destinationPath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/${AppConstants.llmModelFileName}';
  }

  Future<bool> get isDownloaded async {
    final path = await _destinationPath;
    return File(path).existsSync();
  }

  /// Download the model file. Returns the local file path on success.
  Future<String> download() async {
    final path = await _destinationPath;
    final file = File(path);

    // Skip if already downloaded
    if (file.existsSync()) return path;

    final tempPath = '$path.tmp';
    final tempFile = File(tempPath);

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(_modelUrl));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw HttpException(
          'Download failed with status ${response.statusCode}',
        );
      }

      final totalBytes = response.contentLength;
      var receivedBytes = 0;

      final sink = tempFile.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress?.call(receivedBytes / totalBytes);
        }
      }
      await sink.close();
      client.close();

      // Rename temp to final only after complete download
      await tempFile.rename(path);
      return path;
    } catch (e) {
      // Clean up partial download
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }

  /// Delete the downloaded model file.
  Future<void> delete() async {
    final path = await _destinationPath;
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
