import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:camp_connect/features/journal/data/journal_pdf_service.dart';
import 'package:camp_connect/features/journal/domain/journal_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generatePdf embeds a JPEG photo into the document', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'journal_pdf_photo_test_',
    );

    try {
      final photo = File('${tempDir.path}/src_image.jpg');
      final image = img.Image(width: 8, height: 8);
      img.fill(image, color: img.ColorRgb8(46, 125, 50));
      await photo.writeAsBytes(img.encodeJpg(image));

      final entry = JournalEntry(
        id: 'e1',
        date: DateTime(2026, 7, 9),
        title: 'Airsoft',
        body: 'Azi am tras cu pusca airsoft',
        photos: [photo.path],
        createdAt: DateTime(2026, 7, 9),
        updatedAt: DateTime(2026, 7, 9),
      );

      final bytes = await JournalPdfService().generatePdf(
        entries: [entry],
        campName: 'Seria 1',
        dateRange: '08/07/2026 - 15/07/2026',
        journalTitle: 'Jurnalul meu de tabara',
        localeName: 'ro',
      );

      // A JPEG embedded by the pdf package shows up as a DCTDecode-filtered
      // XObject. If the photo was silently skipped, this marker is absent.
      final raw = latin1.decode(bytes, allowInvalid: true);
      expect(
        raw.contains('DCTDecode'),
        isTrue,
        reason: 'photo was not embedded in the PDF',
      );
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
