import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../domain/journal_entry.dart';

/// One passport stamp for the PDF keepsake page. Deliberately decoupled
/// from the map domain so the PDF service keeps zero feature imports.
class PdfPassportStamp {
  final String name;
  final DateTime visitedAt;

  const PdfPassportStamp({required this.name, required this.visitedAt});
}

class JournalPdfService {
  // Warm, playful palette. Days cycle through the accents so a multi-day
  // journal reads as a colourful little booklet rather than a grey report.
  static const _cream = PdfColor.fromInt(0xFFFBF7EF);
  static const _ink = PdfColor.fromInt(0xFF2B2B2B);
  static const _inkSoft = PdfColor.fromInt(0xFF5F5A52);
  static const _greenDark = PdfColor.fromInt(0xFF1B5E20);
  static const _green = PdfColor.fromInt(0xFF2E7D32);
  static const _greenLight = PdfColor.fromInt(0xFF66BB6A);

  static const List<PdfColor> _accents = [
    PdfColor.fromInt(0xFF2E7D32), // green
    PdfColor.fromInt(0xFFEF6C00), // orange
    PdfColor.fromInt(0xFF1E88E5), // blue
    PdfColor.fromInt(0xFF8E24AA), // purple
    PdfColor.fromInt(0xFF00897B), // teal
    PdfColor.fromInt(0xFFD81B60), // pink
    PdfColor.fromInt(0xFF5E35B1), // deep purple
  ];

  /// Generate a PDF document from journal entries.
  ///
  /// [orgName] brands the cover and page footers; [logoBytes], when provided,
  /// is the organiser's camp logo shown on the cover. [localeName] controls how
  /// dates are formatted (month/weekday names).
  ///
  /// Layout guarantee: each camp day is rendered as its own `MultiPage`, so a
  /// day always starts on a fresh page and flows onto extra pages when long —
  /// two days never share a page.
  Future<Uint8List> generatePdf({
    required List<JournalEntry> entries,
    required String campName,
    required String dateRange,
    required String journalTitle,
    String orgName = '',
    Uint8List? logoBytes,
    String localeName = 'ro',
    String passportTitle = '',
    List<PdfPassportStamp> passportStamps = const [],
  }) async {
    await initializeDateFormatting(localeName);
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    final pdf = pw.Document(theme: theme);

    final pw.ImageProvider? logo = logoBytes != null
        ? pw.MemoryImage(logoBytes)
        : null;

    // ---- Cover ------------------------------------------------------------
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => _buildCover(
          journalTitle: journalTitle,
          orgName: orgName,
          campName: campName,
          dateRange: dateRange,
          logo: logo,
        ),
      ),
    );

    // ---- Entries, grouped by day (one MultiPage per day) ------------------
    final sorted = List<JournalEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    final byDay = <DateTime, List<JournalEntry>>{};
    for (final e in sorted) {
      final key = DateTime(e.date.year, e.date.month, e.date.day);
      byDay.putIfAbsent(key, () => []).add(e);
    }
    final days = byDay.keys.toList()..sort();

    final dayFormat = DateFormat('d MMMM yyyy', localeName);
    final weekdayFormat = DateFormat('EEEE', localeName);

    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final accent = _accents[i % _accents.length];
      final dayEntries = byDay[day]!;

      final widgets = <pw.Widget>[
        _dayHeader(
          dayNumber: i + 1,
          weekday: _capitalize(weekdayFormat.format(day)),
          date: dayFormat.format(day),
          accent: accent,
        ),
        pw.SizedBox(height: 16),
      ];

      for (var j = 0; j < dayEntries.length; j++) {
        if (j > 0) {
          widgets.add(pw.SizedBox(height: 14));
          widgets.add(pw.Divider(color: PdfColors.grey300, thickness: 0.8));
          widgets.add(pw.SizedBox(height: 14));
        }
        widgets.addAll(await _entryWidgets(dayEntries[j], accent));
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
          footer: (context) => _footer(context, orgName),
          build: (context) => widgets,
        ),
      );
    }

    // ---- Explorer passport keepsake page -----------------------------------
    if (passportStamps.isNotEmpty) {
      final stampDate = DateFormat('d MMMM yyyy', localeName);
      final sortedStamps = List<PdfPassportStamp>.from(passportStamps)
        ..sort((a, b) => a.visitedAt.compareTo(b.visitedAt));
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
          footer: (context) => _footer(context, orgName),
          build: (context) => [
            _dayHeader(
              dayNumber: 0,
              weekday: '',
              date: passportTitle,
              accent: _green,
            ),
            pw.SizedBox(height: 16),
            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < sortedStamps.length; i++)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: _accents[i % _accents.length],
                        width: 1.5,
                      ),
                      borderRadius: pw.BorderRadius.circular(14),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          sortedStamps[i].name,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: _accents[i % _accents.length],
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          stampDate.format(sortedStamps[i].visitedAt),
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: _inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return pdf.save();
  }

  // ---- Cover ---------------------------------------------------------------

  pw.Widget _buildCover({
    required String journalTitle,
    required String orgName,
    required String campName,
    required String dateRange,
    required pw.ImageProvider? logo,
  }) {
    return pw.Container(
      color: _cream,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Colourful top band
          pw.Container(
            height: 320,
            decoration: const pw.BoxDecoration(
              gradient: pw.LinearGradient(
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight,
                colors: [_greenDark, _greenLight],
              ),
            ),
            child: pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  // Logo (or a friendly drawn mountain) in a white disc
                  pw.Container(
                    width: 104,
                    height: 104,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      shape: pw.BoxShape.circle,
                      boxShadow: [
                        pw.BoxShadow(
                          color: PdfColor.fromInt(0x33000000),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: logo != null
                        ? pw.ClipOval(
                            child: pw.Image(
                              logo,
                              width: 104,
                              height: 104,
                              fit: pw.BoxFit.cover,
                            ),
                          )
                        : pw.Center(
                            child: pw.CustomPaint(
                              size: const PdfPoint(56, 56),
                              painter: _mountainPainter,
                            ),
                          ),
                  ),
                  pw.SizedBox(height: 24),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 32),
                    child: pw.Text(
                      journalTitle,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 30,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  if (orgName.isNotEmpty) ...[
                    pw.SizedBox(height: 10),
                    pw.Text(
                      orgName,
                      style: pw.TextStyle(
                        fontSize: 15,
                        color: PdfColor.fromInt(0xEEFFFFFF),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Lower cream area with a details card + decorative dots
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(40),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  if (campName.isNotEmpty || dateRange.isNotEmpty)
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 22,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(18),
                        border: pw.Border.all(
                          color: PdfColor.fromInt(0xFFDDE7DA),
                          width: 1,
                        ),
                      ),
                      child: pw.Column(
                        children: [
                          if (campName.isNotEmpty)
                            pw.Text(
                              campName,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: _green,
                              ),
                            ),
                          if (dateRange.isNotEmpty) ...[
                            pw.SizedBox(height: 8),
                            pw.Text(
                              dateRange,
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(
                                fontSize: 13,
                                color: _inkSoft,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  pw.SizedBox(height: 28),
                  // Playful row of colourful dots
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      for (final c in _accents)
                        pw.Container(
                          width: 12,
                          height: 12,
                          margin: const pw.EdgeInsets.symmetric(horizontal: 4),
                          decoration: pw.BoxDecoration(
                            color: c,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Day header ----------------------------------------------------------

  pw.Widget _dayHeader({
    required int dayNumber,
    required String weekday,
    required String date,
    required PdfColor accent,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: pw.BoxDecoration(
        color: accent,
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Row(
        children: [
          if (dayNumber > 0) ...[
            pw.Container(
              width: 40,
              height: 40,
              decoration: const pw.BoxDecoration(
                color: PdfColors.white,
                shape: pw.BoxShape.circle,
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                '$dayNumber',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: accent,
                ),
              ),
            ),
            pw.SizedBox(width: 14),
          ],
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (weekday.isNotEmpty) ...[
                pw.Text(
                  weekday,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromInt(0xE6FFFFFF),
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 2),
              ],
              pw.Text(
                date,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Entry ---------------------------------------------------------------

  Future<List<pw.Widget>> _entryWidgets(
    JournalEntry entry,
    PdfColor accent,
  ) async {
    final widgets = <pw.Widget>[
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 10,
            height: 10,
            margin: const pw.EdgeInsets.only(top: 5, right: 8),
            decoration: pw.BoxDecoration(
              color: accent,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              entry.title,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    ];

    final prompt = entry.prompt;
    if (prompt != null && prompt.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 6));
      widgets.add(
        pw.Text(
          prompt,
          style: pw.TextStyle(
            fontSize: 10.5,
            fontStyle: pw.FontStyle.italic,
            color: accent,
          ),
        ),
      );
    }

    if (entry.body.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(
        pw.Text(
          entry.body,
          style: const pw.TextStyle(
            fontSize: 11.5,
            lineSpacing: 5,
            color: _inkSoft,
          ),
        ),
      );
    }

    // The concrete photo width: A4 minus the MultiPage margins (36 + 36).
    // It must be a finite number — `width: double.infinity` leaks an infinite
    // size into ClipRRect's rounded-rect path, which asserts in debug and
    // silently corrupts the image placement in release builds (photos came
    // out missing from exported PDFs while displaying fine in the app).
    final photoWidth = PdfPageFormat.a4.width - 72;

    for (final photoPath in entry.photos) {
      final file = File(photoPath);
      if (await file.exists()) {
        try {
          final bytes = await file.readAsBytes();
          widgets.add(pw.SizedBox(height: 12));
          widgets.add(
            pw.ClipRRect(
              horizontalRadius: 12,
              verticalRadius: 12,
              child: pw.Image(
                pw.MemoryImage(bytes),
                width: photoWidth,
                height: 240,
                fit: pw.BoxFit.cover,
              ),
            ),
          );
        } catch (_) {
          // Skip unreadable photos.
        }
      }
    }

    return widgets;
  }

  // ---- Footer --------------------------------------------------------------

  pw.Widget _footer(pw.Context context, String orgName) {
    final page = '${context.pageNumber} / ${context.pagesCount}';
    final text = orgName.isNotEmpty ? '$orgName   ·   $page' : page;
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    );
  }

  // ---- Helpers -------------------------------------------------------------

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static void _mountainPainter(PdfGraphics canvas, PdfPoint size) {
    final w = size.x;
    final h = size.y;
    // Sun
    canvas
      ..setColor(const PdfColor.fromInt(0xFFFDB813))
      ..drawEllipse(w * 0.72, h * 0.72, w * 0.12, h * 0.12)
      ..fillPath();
    // Back mountain
    canvas
      ..setColor(_greenLight)
      ..moveTo(0, h * 0.12)
      ..lineTo(w * 0.45, h * 0.85)
      ..lineTo(w * 0.9, h * 0.12)
      ..lineTo(0, h * 0.12)
      ..fillPath();
    // Front mountain
    canvas
      ..setColor(_greenDark)
      ..moveTo(w * 0.28, h * 0.12)
      ..lineTo(w * 0.62, h * 0.7)
      ..lineTo(w, h * 0.12)
      ..lineTo(w * 0.28, h * 0.12)
      ..fillPath();
  }
}
