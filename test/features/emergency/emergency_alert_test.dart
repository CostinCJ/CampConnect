import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/emergency/domain/emergency_alert.dart';

void main() {
  test('round-trips type and coordinates through Firestore', () async {
    final firestore = FakeFirebaseFirestore();
    final alert = EmergencyAlert(
      id: '',
      message: 'Copil dispărut',
      senderId: 'g1',
      senderName: 'Ana',
      acknowledgedBy: const [],
      type: 'missingChild',
      latitude: 46.77,
      longitude: 23.59,
      timestamp: DateTime(2026, 7, 10),
    );
    final ref = await firestore.collection('alerts').add(alert.toFirestore());
    final restored = EmergencyAlert.fromFirestore(await ref.get());
    expect(restored.type, 'missingChild');
    expect(restored.latitude, closeTo(46.77, 0.0001));
    expect(restored.longitude, closeTo(23.59, 0.0001));
  });

  test('legacy docs without new fields parse with defaults', () async {
    final firestore = FakeFirebaseFirestore();
    final ref = await firestore.collection('alerts').add({
      'message': 'old',
      'senderId': 'g1',
      'senderName': 'Ana',
      'acknowledgedBy': <String>[],
    });
    final restored = EmergencyAlert.fromFirestore(await ref.get());
    expect(restored.type, 'custom');
    expect(restored.latitude, isNull);
    expect(restored.longitude, isNull);
  });
}
