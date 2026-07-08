import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/shared/services/file_saver_service.dart';
import '../data/journal_pdf_service.dart';

class JournalExportScreen extends ConsumerStatefulWidget {
  const JournalExportScreen({super.key});

  @override
  ConsumerState<JournalExportScreen> createState() =>
      _JournalExportScreenState();
}

class _JournalExportScreenState extends ConsumerState<JournalExportScreen> {
  bool _generating = false;
  bool _saving = false;
  Uint8List? _pdfBytes;
  String? _error;
  String _filename = 'camp_journal.pdf';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateAndSave());
  }

  Future<void> _generateAndSave() async {
    final l10n = AppL10n.of(context);
    final localeName = Localizations.localeOf(context).toString();
    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      final entries = ref.read(journalProvider).valueOrNull ?? [];
      if (entries.isEmpty) {
        setState(() {
          _generating = false;
          _error = l10n.noJournalEntries;
        });
        return;
      }

      final campSession = await ref.read(activeCampSessionProvider.future);
      final campName = campSession?.name ?? '';
      final orgName = campSession?.orgName ?? '';
      final dateFormat = DateFormat('dd/MM/yyyy', localeName);
      final dateRange = campSession != null
          ? '${dateFormat.format(campSession.startDate)} - ${dateFormat.format(campSession.endDate)}'
          : '';

      // The camp logo lives at a known org-scoped Storage path; kids may read
      // their own org's logo. Absent/unreadable logo just means no logo.
      Uint8List? logoBytes;
      final orgId = ref.read(appUserProvider).valueOrNull?.orgId;
      if (orgId != null) {
        try {
          logoBytes = await ref
              .read(firebaseStorageProvider)
              .ref('organizations/$orgId/logo.jpg')
              .getData(5 * 1024 * 1024);
        } catch (_) {
          logoBytes = null;
        }
      }

      final pdfService = JournalPdfService();
      final bytes = await pdfService.generatePdf(
        entries: entries,
        campName: campName,
        dateRange: dateRange,
        journalTitle: l10n.myCampJournal,
        orgName: orgName,
        logoBytes: logoBytes,
        localeName: localeName,
      );

      final timestamp = DateFormat('yyyyMMdd').format(DateTime.now());
      final filename = 'camp_journal_$timestamp.pdf';

      setState(() {
        _generating = false;
        _saving = true;
        _pdfBytes = bytes;
        _filename = filename;
      });

      if (Platform.isAndroid) {
        await FileSaverService.saveToDownloads(bytes: bytes, filename: filename);
      } else {
        // iOS has no Downloads folder — present the system share sheet instead.
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }

      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.pdfExported} ($filename)')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _generating = false;
          _saving = false;
          _error = l10n.pdfExportError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    if (_generating || _saving) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.exportPdf)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _saving ? l10n.pdfExported : l10n.exportingPdf,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.exportPdf)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _generateAndSave,
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    // Show PDF preview with share option
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.exportPdf),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: l10n.exportPdf,
            onPressed: () async {
              if (_pdfBytes != null) {
                await Printing.sharePdf(bytes: _pdfBytes!, filename: _filename);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Success banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(Icons.check_circle,
                    color: theme.colorScheme.onPrimaryContainer, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Platform.isAndroid
                        ? '${l10n.pdfExported}\nDownloads/$_filename'
                        : l10n.pdfExported,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text(l10n.ok),
                ),
              ],
            ),
          ),
          // PDF preview
          Expanded(
            child: PdfPreview(
              build: (format) async => _pdfBytes!,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              pdfFileName: _filename,
              allowSharing: false,
              allowPrinting: false,
            ),
          ),
        ],
      ),
    );
  }
}
