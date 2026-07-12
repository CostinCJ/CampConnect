import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/shared/providers/providers.dart';

AppUser _guide(String? campId) => AppUser(
      uid: 'u1',
      role: 'guide',
      displayName: 'G',
      email: 'g@x.com',
      orgId: 'org1',
      campId: campId,
      createdAt: DateTime(2026),
    );

void main() {
  test('a loading flicker of appUserProvider does not clear the camp', () async {
    final gate = StateProvider<int>((_) => 0);
    final container = ProviderContainer(overrides: [
      appUserProvider.overrideWith((ref) async {
        ref.watch(gate);
        return _guide('campA');
      }),
    ]);
    addTearDown(container.dispose);

    container.listen(activeCampIdProvider, (_, _) {});
    await container.read(appUserProvider.future);
    expect(container.read(activeCampIdProvider), 'campA');

    container.read(gate.notifier).state++;
    expect(container.read(activeCampIdProvider), 'campA');
    await container.read(appUserProvider.future);
    expect(container.read(activeCampIdProvider), 'campA');
  });

  test('a real profile campId change still propagates', () async {
    final profile = StateProvider<String?>((_) => 'campA');
    final container = ProviderContainer(overrides: [
      appUserProvider.overrideWith((ref) async {
        return _guide(ref.watch(profile));
      }),
    ]);
    addTearDown(container.dispose);

    container.listen(activeCampIdProvider, (_, _) {});
    await container.read(appUserProvider.future);
    expect(container.read(activeCampIdProvider), 'campA');

    container.read(profile.notifier).state = 'campB';
    await container.read(appUserProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(activeCampIdProvider), 'campB');
  });
}
