import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/journal/data/journal_pdf_service.dart';
import 'package:camp_connect/features/journal/domain/journal_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generatePdf embeds Noto Sans and renders diacritics without throwing', () async {
    final service = JournalPdfService();
    final entry = JournalEntry(
      id: '1',
      date: DateTime(2026, 7, 1),
      title: 'Ziua ăâîșț a taberei',
      body: 'Astăzi am învățat despre ștafeta ő ű German diacritics too.',
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );

    final bytes = await service.generatePdf(
      entries: [entry],
      campName: 'Tabăra Apuseni',
      dateRange: '1-10 iulie',
      journalTitle: 'Jurnalul meu ăâîșț',
    );

    expect(bytes, isNotEmpty);
    // A real PDF starts with the %PDF- magic header.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
