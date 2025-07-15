import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_frontend/main.dart';

void main() {
  testWidgets('App generation message displayed', (WidgetTester tester) async {
    await tester.pumpWidget(const AudiobooksApp());

    // The new design does not have 'mobile_frontend App is being generated...' message,
    // so let's check for one of the main tab titles as a smoke test.
    expect(find.text('Store'), findsWidgets);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });

  testWidgets('App bar has correct title', (WidgetTester tester) async {
    await tester.pumpWidget(const AudiobooksApp());

    expect(find.text('Store'), findsWidgets);
    expect(find.byType(AppBar), findsWidgets);
  });
}
