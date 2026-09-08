import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sigraforce_mobile/main.dart';

void main() {
  testWidgets('App boots to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SigraForceApp());
    await tester.pump();

    expect(find.text('SIGRA FORCE'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Masuk'), findsOneWidget);
  });
}
