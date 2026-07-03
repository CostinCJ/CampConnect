import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:camp_connect/core/constants/app_constants.dart';

enum LlmTier {
  /// Device cannot run LLM (< 2GB RAM or missing CPU features)
  unsupported,
  /// Device can run Q2_K quantization (2-3GB RAM)
  lowRam,
  /// Device can run Q4_K_S quantization (> 3GB RAM)
  highRam,
}

class DeviceCapability {
  DeviceCapability._();

  static Future<LlmTier> checkTier() async {
    if (Platform.isAndroid) {
      // Check CPU features first fllama loads libfllama_v8_2_fp16.so
      // which requires ARMv8.2 FP16 support. Devices without it SIGSEGV.
      final hasFp16 = await _hasRequiredCpuFeatures();
      if (!hasFp16) {
        debugPrint('[LLM] Device missing required CPU features (fphp/asimdhp)');
        return LlmTier.unsupported;
      }
    }

    final ramMb = await _getDeviceRamMb();
    if (ramMb < AppConstants.llmMinRamMb) {
      return LlmTier.unsupported;
    }
    if (ramMb <= 3072) {
      return LlmTier.lowRam;
    }
    return LlmTier.highRam;
  }

  static Future<bool> isCapable() async {
    final tier = await checkTier();
    return tier != LlmTier.unsupported;
  }

  /// Check if Android CPU supports the features fllama's native lib needs.
  /// fllama selects libfllama_v8_2_fp16.so which requires ARMv8.2 FP16:
  /// look for 'fphp' or 'asimdhp' in /proc/cpuinfo Features line.
  static Future<bool> _hasRequiredCpuFeatures() async {
    try {
      final result = await Process.run('cat', ['/proc/cpuinfo']);
      final output = result.stdout as String;

      // Find the Features line (e.g., "Features : fp asimd ... fphp asimdhp ...")
      final featuresMatch =
          RegExp(r'Features\s*:\s*(.+)', multiLine: true).firstMatch(output);
      if (featuresMatch == null) {
        debugPrint('[LLM] Could not read CPU features, assuming capable');
        return true;
      }

      final features = featuresMatch.group(1)!;
      final featureList = features.split(RegExp(r'\s+'));
      debugPrint('[LLM] CPU features: $features');

      // fllama needs FP16 (fphp + asimdhp)
      final hasFphp = featureList.contains('fphp');
      final hasAsimdhp = featureList.contains('asimdhp');
      debugPrint('[LLM] fphp=$hasFphp, asimdhp=$hasAsimdhp');

      return hasFphp && hasAsimdhp;
    } catch (e) {
      debugPrint('[LLM] Error reading CPU features: $e');
      // Can't determine assume capable to avoid false negatives
      return true;
    }
  }

  static Future<int> _getDeviceRamMb() async {
    if (Platform.isAndroid) {
      return _getAndroidRamMb();
    }
    return 4096;
  }

  static Future<int> _getAndroidRamMb() async {
    try {
      final result = await Process.run('cat', ['/proc/meminfo']);
      final output = result.stdout as String;
      final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(output);
      if (match != null) {
        final totalKb = int.parse(match.group(1)!);
        return totalKb ~/ 1024;
      }
    } catch (_) {
      // Fall through to default
    }
    return 2048;
  }
}
