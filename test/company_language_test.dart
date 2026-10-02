import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lock_sys_hr/app.dart';
import 'package:lock_sys_hr/core/l10n/locale_controller.dart';
import 'package:lock_sys_hr/features/company/api_company_registry.dart';
import 'package:lock_sys_hr/features/company/company.dart';
import 'package:lock_sys_hr/features/company/company_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fast = MockCompanyRegistry(delay: Duration(milliseconds: 50));

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(Duration(milliseconds: ms));
}

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Company _company({bool multi = true, String lang = 'ar'}) => Company(
  code: '1000',
  name: 'Delta Fertilizers',
  arabicName: 'شركة الدلتا للأسمدة',
  apiBaseUrl: 'https://x.example/',
  features: const {},
  multiLanguage: multi,
  defaultLanguage: lang,
);

Future<void> _enterCode(WidgetTester t, String code, String verify) async {
  await t.enterText(find.byType(TextFormField), code);
  await t.ensureVisible(find.text(verify));
  await t.tap(find.text(verify));
  await settle(t);
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('Company language policy', () {
    test('multi-language shows the name in the requested language', () {
      final c = _company();
      expect(c.forcedLanguage, isNull);
      expect(c.nameFor('ar'), 'شركة الدلتا للأسمدة');
      expect(c.nameFor('en'), 'Delta Fertilizers');
    });

    test('Arabic-only always shows the Arabic name and locks to ar', () {
      final c = _company(multi: false, lang: 'ar');
      expect(c.forcedLanguage, 'ar');
      expect(c.nameFor('en'), 'شركة الدلتا للأسمدة');
    });

    test('English-only always shows the English name and locks to en', () {
      final c = _company(multi: false, lang: 'en');
      expect(c.forcedLanguage, 'en');
      expect(c.nameFor('ar'), 'Delta Fertilizers');
    });

    test('a copy saved by an older build keeps the old behaviour', () {
      final c = Company.fromJson({
        'code': 'LOCKSYS',
        'name': 'LockSys',
        'apiBaseUrl': 'https://x.example/',
        'features': <String>[],
      });
      expect(c.multiLanguage, isTrue);
      expect(c.defaultLanguage, 'ar');
      expect(c.nameFor('ar'), 'LockSys'); // no Arabic name saved: use the name
    });

    test('save and load keeps both names and the policy', () {
      final c = Company.fromJson(
        _company(multi: false, lang: 'en').toJson().cast<String, dynamic>(),
      );
      expect(c.arabicName, 'شركة الدلتا للأسمدة');
      expect(c.multiLanguage, isFalse);
      expect(c.defaultLanguage, 'en');
    });

    test('an unknown default language falls back to Arabic', () {
      final c = Company.fromJson({
        'code': 'X1',
        'name': 'X',
        'apiBaseUrl': 'https://x.example/',
        'features': <String>[],
        'multiLanguage': false,
        'defaultLanguage': 'fr',
      });
      expect(c.defaultLanguage, 'ar');
    });

    test(
      'API fields arabicName / multiLanguage / defaultLanguage are read',
      () async {
        final registry = ApiCompanyRegistry(
          username: 'u',
          password: 'p',
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'code': '1000',
                  'name':
                      'Delta Company for Fertilizers and Chemical Industries',
                  'arabicName': 'شركة الدلتا للأسمدة والصناعات الكيماوية',
                  'baseUrl': 'https://semaderp.locksys.co/ords/locksysapp/',
                  'multiLanguage': false,
                  'defaultLanguage': 'ar',
                  'features': <String>[],
                  'maintenance': false,
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        );
        final c = await registry.resolve('1000');
        expect(c.nameFor('en'), 'شركة الدلتا للأسمدة والصناعات الكيماوية');
        expect(c.forcedLanguage, 'ar');
      },
    );
  });

  group('LocaleController', () {
    test(
      'a forced language wins over the user choice and cannot be switched',
      () async {
        SharedPreferences.setMockInitialValues({'app_locale': 'en'});
        final prefs = await SharedPreferences.getInstance();
        final c = LocaleController(prefs);
        expect(c.locale.languageCode, 'en');

        c.forceLanguage('ar');
        expect(c.locale.languageCode, 'ar');
        expect(c.canSwitch, isFalse);

        await c.toggle();
        await c.setLocale(const Locale('en'));
        expect(c.locale.languageCode, 'ar');
        expect(prefs.getString('app_locale'), 'en'); // user choice untouched

        c.forceLanguage(null);
        expect(c.canSwitch, isTrue);
        expect(c.locale.languageCode, 'en'); // the user's own choice is back
      },
    );

    test(
      'an unsupported language lifts the lock instead of locking to it',
      () async {
        final c = LocaleController(await SharedPreferences.getInstance());
        c.forceLanguage('fr');
        expect(c.canSwitch, isTrue);
      },
    );
  });

  group('screens', () {
    testWidgets('multi-language: name follows the language switch', (t) async {
      phone(t);
      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      final prefs = await SharedPreferences.getInstance();
      await t.pumpWidget(LockSysApp(prefs: prefs, registry: _fast));
      await t.pump(const Duration(milliseconds: 2700));
      await settle(t, 800);

      await _enterCode(t, 'locksys', 'تحقق من الكود');
      expect(find.text('لوك سيس للحلول'), findsOneWidget);
      expect(find.text('LockSys Solutions'), findsNothing);

      await t.tap(find.text('English'));
      await settle(t);
      expect(find.text('LockSys Solutions'), findsOneWidget);
      expect(find.text('لوك سيس للحلول'), findsNothing);
    });

    testWidgets(
      'Arabic-only company: Arabic is forced and there is no switch',
      (t) async {
        phone(t);
        SharedPreferences.setMockInitialValues({
          'onboarding_done': true,
          'app_locale': 'en',
        });
        final prefs = await SharedPreferences.getInstance();
        await t.pumpWidget(LockSysApp(prefs: prefs, registry: _fast));
        await t.pump(const Duration(milliseconds: 2700));
        await settle(t, 800);

        await _enterCode(
          t,
          'alnoor',
          'Verify code',
        ); // user is still in English
        expect(find.text('شركة النور للتجارة'), findsOneWidget);
        await t.tap(find.text('Continue'));
        await settle(t, 800);

        expect(find.text('تسجيل الدخول'), findsWidgets); // login, now in Arabic
        expect(find.text('English'), findsNothing);
        expect(find.text('العربية'), findsNothing);
        expect(
          prefs.getString('app_locale'),
          'en',
        ); // the lock did not overwrite it
      },
    );

    testWidgets(
      'English-only company: English is forced and there is no switch',
      (t) async {
        phone(t);
        SharedPreferences.setMockInitialValues({'onboarding_done': true});
        final prefs = await SharedPreferences.getInstance();
        await t.pumpWidget(LockSysApp(prefs: prefs, registry: _fast));
        await t.pump(const Duration(milliseconds: 2700));
        await settle(t, 800);

        await _enterCode(t, 'demo', 'تحقق من الكود'); // user starts in Arabic
        expect(find.text('Demo Company'), findsOneWidget);
        await t.tap(find.text('متابعة'));
        await settle(t, 800);

        expect(find.text('Welcome back'), findsOneWidget);
        expect(find.text('English'), findsNothing);
        expect(find.text('العربية'), findsNothing);
      },
    );

    testWidgets(
      'a saved single-language company locks the language at launch',
      (t) async {
        phone(t);
        SharedPreferences.setMockInitialValues({
          'onboarding_done': true,
          'app_locale': 'en',
          'company': jsonEncode(
            _company(multi: false, lang: 'ar').toJson()
              ..['features'] = <String>[],
          ),
        });
        final prefs = await SharedPreferences.getInstance();
        final same = _company(multi: false, lang: 'ar');
        await t.pumpWidget(LockSysApp(prefs: prefs, registry: _Fixed(same)));
        await t.pump(const Duration(milliseconds: 2700));
        await settle(t, 800);

        expect(find.text('تسجيل الدخول'), findsWidgets);
        expect(find.text('English'), findsNothing);
      },
    );
  });

  group('refresh on every launch', () {
    Future<SharedPreferences> saved(Company c, {String locale = 'ar'}) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_done': true,
        'app_locale': locale,
        'company': jsonEncode(c.toJson()),
      });
      return SharedPreferences.getInstance();
    }

    Future<void> launch(
      WidgetTester t,
      SharedPreferences p,
      CompanyRegistry r,
    ) async {
      await t.pumpWidget(LockSysApp(prefs: p, registry: r));
      await t.pump(const Duration(milliseconds: 2700));
      await settle(t, 800);
    }

    testWidgets('server change of the language policy reaches the device', (
      t,
    ) async {
      phone(t);
      // Saved as multi-language; the server now says English only.
      final prefs = await saved(_company(multi: true));
      await launch(t, prefs, _Fixed(_company(multi: false, lang: 'en')));

      expect(find.text('Welcome back'), findsOneWidget); // locked to English
      expect(find.text('العربية'), findsNothing); // no switch
      final stored = jsonDecode(prefs.getString('company')!) as Map;
      expect(stored['multiLanguage'], false);
      expect(stored['defaultLanguage'], 'en');
    });

    testWidgets('server lifting the lock gives the switch back', (t) async {
      phone(t);
      final prefs = await saved(
        _company(multi: false, lang: 'ar'),
        locale: 'en',
      );
      await launch(t, prefs, _Fixed(_company(multi: true)));

      expect(
        find.text('Welcome back'),
        findsOneWidget,
      ); // the user's own English
      expect(find.text('العربية'), findsOneWidget);
    });

    testWidgets('offline: the saved company and its lock are kept', (t) async {
      phone(t);
      final prefs = await saved(
        _company(multi: false, lang: 'ar'),
        locale: 'en',
      );
      await launch(t, prefs, _Offline());

      expect(find.text('تسجيل الدخول'), findsWidgets);
      expect(find.text('English'), findsNothing);
      expect(prefs.getString('company'), isNotNull);
    });

    testWidgets('a code the server no longer knows asks for the code again', (
      t,
    ) async {
      phone(t);
      final prefs = await saved(
        _company(multi: false, lang: 'ar'),
        locale: 'en',
      );
      await launch(t, prefs, _Gone());

      expect(
        find.text('Company code'),
        findsWidgets,
      ); // back on the code screen, lock lifted
      expect(prefs.getString('company'), isNull);
    });
  });
}

class _Fixed implements CompanyRegistry {
  _Fixed(this.company);
  final Company company;
  @override
  Future<Company> resolve(String code) async => company;
}

class _Offline implements CompanyRegistry {
  @override
  Future<Company> resolve(String code) async =>
      throw const CompanyRegistryUnavailableException();
}

class _Gone implements CompanyRegistry {
  @override
  Future<Company> resolve(String code) async =>
      throw const CompanyNotFoundException();
}
