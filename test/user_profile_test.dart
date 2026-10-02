import 'package:flutter_test/flutter_test.dart';
import 'package:lock_sys_hr/features/auth/auth_api.dart';
import 'package:lock_sys_hr/features/home/user_profile.dart';

void main() {
  const session = AuthSession(
    token: 't',
    user: {
      'username': '10151',
      'nameAr': 'محمد الزرقاني',
      'nameEn': null,
      'phone': ' 01275002379 ',
      'email': null,
      'employee': {
        'code': '10151',
        'hireDate': '2020-03-15',
        'status': {'id': 1, 'nameAr': 'يعمل', 'nameEn': 'Active'},
        'category': {'nameAr': 'فئة ', 'nameEn': 'Cat\r\n'},
        'job': {'nameAr': 'مهندس', 'nameEn': null},
      },
      'company': {'id': 2, 'name': 'الدلتا'},
    },
  );

  test('picks the language and falls back to the other one', () {
    final ar = UserProfile.of(session, 'ar')!;
    final en = UserProfile.of(session, 'en')!;
    expect(ar.name, 'محمد الزرقاني');
    expect(en.name, 'محمد الزرقاني'); // no English name: falls back
    expect(ar.status, 'يعمل');
    expect(en.status, 'Active');
    expect(en.category, 'Cat'); // trailing CR/LF from the ERP is trimmed
    expect(en.job, 'مهندس');
  });

  test('reads code, phone, company and date; missing values are null', () {
    final p = UserProfile.of(session, 'ar')!;
    expect(p.employeeCode, '10151');
    expect(p.phone, '01275002379');
    expect(p.company, 'الدلتا');
    expect(p.hireDate, DateTime(2020, 3, 15));
    expect(p.email, isNull);
    expect(p.department, isNull);
  });

  test('no session, no profile', () {
    expect(UserProfile.of(null, 'ar'), isNull);
  });
}
