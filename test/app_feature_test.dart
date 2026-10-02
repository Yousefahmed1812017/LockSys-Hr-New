import 'package:flutter_test/flutter_test.dart';
import 'package:lock_sys_hr/features/company/company.dart';

void main() {
  test('keys are unique and match the database CODE rule', () {
    final keys = AppFeature.values.map((f) => f.key).toList();
    expect(keys.toSet().length, keys.length);
    final rule = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$');
    for (final k in keys) {
      expect(rule.hasMatch(k), isTrue, reason: k);
    }
  });

  test('every sub feature has its parent declared, one segment up', () {
    for (final f in AppFeature.values) {
      if (!f.key.contains('.')) {
        expect(f.parent, isNull, reason: f.key);
      } else {
        expect(f.parent, isNotNull, reason: '${f.key} has no parent');
        expect(f.key, startsWith('${f.parent!.key}.'));
        expect(
          f.key.substring(f.parent!.key.length + 1).contains('.'),
          isFalse,
        );
      }
    }
  });

  test('modules are main features', () {
    for (final f in AppFeature.modules) {
      expect(f.parent, isNull);
    }
  });

  test('Company.has works on sub features and survives a save/load', () {
    final company = Company.fromJson({
      'code': 'LOCKSYS',
      'name': 'LockSys',
      'apiBaseUrl': 'https://x.example/',
      'features': [
        'attendance',
        'auth',
        'auth.phone',
        'auth.phone.via_sms',
        'auth.phone.via_voice', // not in this build: ignored
      ],
    });
    expect(company.has(AppFeature.authPhone), isTrue);
    expect(company.has(AppFeature.authPhoneViaSms), isTrue);
    expect(company.has(AppFeature.authPhoneViaWhatsapp), isFalse);
    expect(company.has(AppFeature.payslip), isFalse);

    final again = Company.fromJson(company.toJson());
    expect(again.features, company.features);
    expect(company.toJson()['features'], contains('auth.phone.via_sms'));
  });
}
