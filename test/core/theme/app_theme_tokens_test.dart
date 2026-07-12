import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/core/theme/app_theme.dart';

void main() {
  test('CampColors exposes achievementGold in both themes', () {
    final light = AppTheme.light().extension<CampColors>()!;
    final dark = AppTheme.dark().extension<CampColors>()!;
    expect(light.achievementGold, isNotNull);
    expect(dark.achievementGold, isNotNull);
    // Dark variant is lightened for legibility on dark surfaces.
    expect(light.achievementGold != dark.achievementGold, isTrue);
  });
}
