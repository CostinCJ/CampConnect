import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../domain/journal_entry.dart';

class JournalPdfService {
  /// Generate a PDF document from journal entries.
  /// Returns the raw PDF bytes for sharing/saving via the system share sheet.
  Future<Uint8List> generatePdf({
    required List<JournalEntry> entries,
    required String campName,
    required String dateRange,
    required String journalTitle,
  }) async {
    final pdf = pw.Document();

    // Title page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(
                width: 80,
                height: 80,
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(40),
                ),
                child: pw.Center(
                  child: pw.Icon(
                    const pw.IconData(0xe865),
                    size: 48,
                    color: PdfColors.green800,
                  ),
                ),
              ),
              pw.SizedBox(height: 32),
              pw.Text(
                journalTitle,
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green900,
                ),
              ),
              pw.SizedBox(height: 16),
              if (campName.isNotEmpty)
                pw.Text(
                  campName,
                  style: const pw.TextStyle(
                    fontSize: 18,
                    color: PdfColors.grey700,
                  ),
                ),
              pw.SizedBox(height: 8),
              if (dateRange.isNotEmpty)
                pw.Text(
                  dateRange,
                  style: const pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // Sort entries chronologically (oldest first for the PDF)
    final sortedEntries = List<JournalEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Build all entry widgets into a single MultiPage
    final allWidgets = <pw.Widget>[];
    final dateFormat = DateFormat('dd MMMM yyyy');

    for (var i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];

      // Separator between entries (not before the first one)
      if (i > 0) {
        allWidgets.add(pw.SizedBox(height: 16));
        allWidgets.add(
          pw.Divider(color: PdfColors.grey300, thickness: 1),
        );
        allWidgets.add(pw.SizedBox(height: 16));
      }

      // Date heading
      allWidgets.add(
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.green300, width: 2),
            ),
          ),
          child: pw.Text(
            dateFormat.format(entry.date),
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.green800,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      );
      allWidgets.add(pw.SizedBox(height: 12));

      // Title
      allWidgets.add(
        pw.Text(
          entry.title,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
      allWidgets.add(pw.SizedBox(height: 12));

      // Body text
      if (entry.body.isNotEmpty) {
        allWidgets.add(
          pw.Text(
            entry.body,
            style: const pw.TextStyle(
              fontSize: 12,
              lineSpacing: 6,
            ),
          ),
        );
        allWidgets.add(pw.SizedBox(height: 16));
      }

      // Photos
      for (final photoPath in entry.photos) {
        final file = File(photoPath);
        if (await file.exists()) {
          try {
            final imageBytes = await file.readAsBytes();
            final image = pw.MemoryImage(imageBytes);
            allWidgets.add(
              pw.Center(
                child: pw.ClipRRect(
                  horizontalRadius: 8,
                  verticalRadius: 8,
                  child: pw.Image(
                    image,
                    width: 400,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
            );
            allWidgets.add(pw.SizedBox(height: 12));
          } catch (_) {
            // Skip photos that can't be read
          }
        }
      }
    }

    if (allWidgets.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => allWidgets,
        ),
      );
    }

    return pdf.save();
  }
}
