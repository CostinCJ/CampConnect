import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:camp_connect/features/auth/data/auth_repository.dart';
import 'package:camp_connect/features/auth/data/camp_repository.dart';
import 'package:camp_connect/features/auth/data/session_auto_select.dart';
import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/features/auth/domain/camp_session.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class _FakeCampRepository extends Fake implements CampRepository {
  _FakeCampRepository(this.sessions);
  final List<CampSession> sessions;
  bool fail = false;

  @override
  Future<List<CampSession>> fetchCampSessionsForOrg(String orgId) async {
    if (fail) throw Exception('offline');
    return sessions;
  }
}

class _FakeAuthRepository extends Fake implements AuthRepository {
  final persisted = <String, String>{};

  @override
  Future<void> updateUserCampId(String uid, String campId) async {
    persisted[uid] = campId;
  }
}

CampSession _session(String id, {required bool running}) {
  final now = DateTime.now();
  return CampSession(
    id: id,
    name: id,
    startDate: running
        ? now.subtract(const Duration(days: 1))
        : now.add(const Duration(days: 10)),
    endDate: running
        ? now.add(const Duration(days: 1))
        : now.add(const Duration(days: 12)),
    teams: const [],
    createdBy: 'owner',
    orgId: 'org-1',
  );
}

AppUser _guide({String? campId, String? orgId = 'org-1'}) => AppUser(
      uid: 'guide-1',
      role: 'guide',
      displayName: 'Ana',
      campId: campId,
      orgId: orgId,
      createdAt: DateTime(2026, 9, 30),
    );

void main() {
  late _FakeAuthRepository auth;

  setUp(() => auth = _FakeAuthRepository());

  /// Runs autoSelectActiveSession with a real WidgetRef and returns the
  /// result plus the in-memory active camp id afterwards.
  Future<(CampSession?, String?)> run(
    WidgetTester tester,
    _FakeCampRepository camps,
    AppUser user,
  ) async {
    late WidgetRef capturedRef;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        campRepositoryProvider.overrideWithValue(camps),
        authRepositoryProvider.overrideWithValue(auth),
        appUserProvider.overrideWith((ref) async => null),
      ],
      child: Consumer(builder: (context, ref, _) {
        capturedRef = ref;
        ref.watch(activeCampIdProvider);
        return const SizedBox();
      }),
    ));
    final result = await autoSelectActiveSession(capturedRef, user);
    return (result, capturedRef.read(activeCampIdProvider));
  }

  testWidgets('selects and persists the single running session', (tester) async {
    final camps = _FakeCampRepository(
        [_session('now', running: true), _session('later', running: false)]);
    final (result, active) = await run(tester, camps, _guide());
    expect(result?.id, 'now');
    expect(active, 'now');
    expect(auth.persisted['guide-1'], 'now');
  });

  testWidgets('does not guess when two sessions are running', (tester) async {
    final camps = _FakeCampRepository(
        [_session('a', running: true), _session('b', running: true)]);
    final (result, active) = await run(tester, camps, _guide());
    expect(result, isNull);
    expect(active, isNull);
    expect(auth.persisted, isEmpty);
  });

  testWidgets('leaves a guide who already has a camp alone', (tester) async {
    final camps = _FakeCampRepository([_session('now', running: true)]);
    final (result, _) = await run(tester, camps, _guide(campId: 'mine'));
    expect(result, isNull);
    expect(auth.persisted, isEmpty);
  });

  testWidgets('never throws when loading sessions fails', (tester) async {
    final camps = _FakeCampRepository([_session('now', running: true)])
      ..fail = true;
    final (result, active) = await run(tester, camps, _guide());
    expect(result, isNull);
    expect(active, isNull);
  });
}
