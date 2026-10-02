import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lock_sys_hr/app.dart';
import 'package:lock_sys_hr/features/company/api_company_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('live directory: unknown, inactive, valid, save, login', (tester) async {
    // Isolate the test from the employee's saved preferences.
    SharedPreferences.setMockInitialValues({'onboarding_done': true, 'app_locale': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final registry = ApiCompanyRegistry(
      username: const String.fromEnvironment('API_USER'),
      password: const String.fromEnvironment('API_PASSWORD'),
    );
    await tester.pumpWidget(LockSysApp(prefs: prefs, registry: registry));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    Future<void> verify(String code, String expected) async {
      await tester.enterText(find.byType(TextFormField), code);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Verify code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify code'));
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (find.text(expected).evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.text(expected), findsOneWidget,
        reason: tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(' | '));
      await tester.pumpAndSettle();
    }

    await verify('NOPE', 'Invalid company code. Check it and try again.');
    expect(prefs.getString('company'), isNull);
    await verify('GULFTECH', 'This company is not active');
    expect(prefs.getString('company'), isNull);
    await verify('locksys', 'LockSys Solutions');
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Payslip'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    final saved = jsonDecode(prefs.getString('company')!) as Map;
    expect(saved['code'], 'LOCKSYS');
    expect(saved['apiBaseUrl'], 'https://api.locksys.co/ords/hr/');
    expect(saved['features'], containsAll(['attendance', 'leave', 'payslip']));
  });
}
