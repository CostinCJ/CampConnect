import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/shared/widgets/confetti_burst.dart';

void main() {
  testWidgets('renders and completes without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConfettiBurst(color: Colors.red),
        ),
      ),
    );
    // Run the whole animation to completion.
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byType(ConfettiBurst), findsOneWidget);
  });

  testWidgets('renders nothing animated when animations are disabled',
      (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          // Disabled so the debug "checked mode" ribbon (which is itself
          // painted via a CustomPaint) doesn't produce a false positive
          // for the assertion below — it is unrelated to ConfettiBurst.
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: ConfettiBurst(color: Colors.red)),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CustomPaint), findsNothing);
  });
}
