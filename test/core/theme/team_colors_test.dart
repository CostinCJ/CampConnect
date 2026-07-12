import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/core/theme/team_colors.dart';

void main() {
  test('firstUnusedPresetHex skips colors already in use', () {
    final used = ['#E53935', '#1E88E5', '#43A047', '#FDD835'];
    final next = TeamColors.firstUnusedPresetHex(used);
    expect(used.contains(next), isFalse);
    expect(TeamColors.presetHexes.contains(next), isTrue);
    expect(next, '#D81B60'); // first preset not among the defaults
  });

  test('firstUnusedPresetHex is case-insensitive', () {
    final next = TeamColors.firstUnusedPresetHex(['#e53935']);
    expect(next, isNot('#E53935'));
  });

  test('falls back to cycling when every preset is taken', () {
    final all = List.of(TeamColors.presetHexes);
    expect(TeamColors.firstUnusedPresetHex(all, fallbackIndex: 14),
        TeamColors.presetHexes[14 % TeamColors.presetHexes.length]);
  });
}
