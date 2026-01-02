// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:receipt_scanner/app/app.dart';

void main() {
  testWidgets('Receipt Scanner app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: ReceiptScannerApp(),
      ),
    );

    // Verify that the camera screen loads
    expect(find.text('Receipt Scanner'), findsOneWidget);
    
    // Wait for widget to settle
    await tester.pumpAndSettle();
  });
}
