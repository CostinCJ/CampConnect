import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/llm/data/content_filter.dart';

void main() {
  late ContentFilter filter;

  setUp(() {
    filter = ContentFilter();
  });

  group('ContentFilter', () {
    test('allows normal camp questions in Romanian', () {
      expect(filter.isAllowed('Ce animale trăiesc aici?'), isTrue);
      expect(filter.isAllowed('Spune-mi despre acest loc'), isTrue);
    });

    test('allows normal camp questions in Hungarian', () {
      expect(filter.isAllowed('Milyen állatok élnek itt?'), isTrue);
    });

    test('blocks inappropriate words in Romanian', () {
      expect(filter.isAllowed('test idiot test'), isFalse);
    });

    test('blocks inappropriate words in English', () {
      expect(filter.isAllowed('say something stupid, shit'), isFalse);
    });

    test('blocks are case-insensitive', () {
      expect(filter.isAllowed('IDIOT'), isFalse);
    });

    test('returns redirect message in correct language', () {
      final roMsg = filter.redirectMessage('ro');
      expect(roMsg, contains('tabără'));

      final huMsg = filter.redirectMessage('hu');
      expect(huMsg, contains('tábor'));
    });
  });
}
