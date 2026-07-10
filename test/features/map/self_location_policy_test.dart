import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/features/map/domain/self_location_policy.dart';
import 'package:camp_connect/features/settings/domain/app_settings.dart';

void main() {
  AppUser user(String role) => AppUser(
        uid: 'u1',
        role: role,
        displayName: 'Test',
        campId: 'c1',
        createdAt: DateTime(2026, 1, 1),
      );

  test('null user never tracks', () {
    expect(
      shouldTrackSelfLocation(null, const AppSettings()),
      isFalse,
    );
  });

  test('guides always track', () {
    expect(
      shouldTrackSelfLocation(user('guide'), const AppSettings()),
      isTrue,
    );
  });

  test('kids track only when opted in', () {
    expect(
      shouldTrackSelfLocation(user('kid'), const AppSettings()),
      isFalse,
    );
    expect(
      shouldTrackSelfLocation(
        user('kid'),
        const AppSettings(kidLocationEnabled: true),
      ),
      isTrue,
    );
  });
}
