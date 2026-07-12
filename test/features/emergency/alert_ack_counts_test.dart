import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/emergency/domain/emergency_alert.dart';

EmergencyAlert _alert({required String senderId, List<String> acked = const []}) {
  return EmergencyAlert(
    id: 'a1',
    message: 'test',
    senderId: senderId,
    senderName: 'Sender',
    acknowledgedBy: acked,
    timestamp: DateTime(2026, 7, 12),
  );
}

void main() {
  test('sender is excluded from the total', () {
    final (confirmed, total) =
        alertAckCounts(_alert(senderId: 'u1'), ['u1', 'u2', 'u3']);
    expect(total, 2);
    expect(confirmed, 0);
  });

  test('all other guides confirming reaches total of total', () {
    final (confirmed, total) = alertAckCounts(
        _alert(senderId: 'u1', acked: ['u2', 'u3']), ['u1', 'u2', 'u3']);
    expect(confirmed, 2);
    expect(total, 2);
  });

  test('a stray self-ack is not counted', () {
    final (confirmed, total) = alertAckCounts(
        _alert(senderId: 'u1', acked: ['u1', 'u2']), ['u1', 'u2', 'u3']);
    expect(confirmed, 1);
    expect(total, 2);
  });
}
