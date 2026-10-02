import 'company.dart';

/// The company code does not exist.
class CompanyNotFoundException implements Exception {
  const CompanyNotFoundException();
}

/// The registry could not be reached (offline, timeout, server error).
class CompanyRegistryUnavailableException implements Exception {
  const CompanyRegistryUnavailableException();
}

/// Turns a company code into the company's server + enabled features.
///
/// Production: implement this against the central endpoint that maps
/// `code -> { name, apiBaseUrl, features[] }`, throwing
/// [CompanyNotFoundException] for an unknown code and
/// [CompanyRegistryUnavailableException] for network / 5xx failures.
abstract interface class CompanyRegistry {
  Future<Company> resolve(String code);
}

/// Development registry with fake companies. Replace with the real one.
///   LOCKSYS -> attendance + leave + payslip, Arabic + English
///   DEMO    -> attendance + leave, English only
///   ALNOOR  -> attendance, Arabic only
class MockCompanyRegistry implements CompanyRegistry {
  const MockCompanyRegistry({this.delay = const Duration(milliseconds: 900)});
  final Duration delay;

  static const _companies = {
    'ALNOOR': Company(
      code: 'ALNOOR',
      name: 'Al Noor Trading',
      arabicName: 'شركة النور للتجارة',
      apiBaseUrl: 'https://alnoor.example.com',
      features: {AppFeature.attendance},
      multiLanguage: false,
      defaultLanguage: 'ar',
    ),
    'LOCKSYS': Company(
      code: 'LOCKSYS',
      name: 'LockSys Solutions',
      arabicName: 'لوك سيس للحلول',
      apiBaseUrl: 'https://api.locksys.co',
      features: {
        AppFeature.attendance,
        AppFeature.leave,
        AppFeature.payslip,
        AppFeature.auth,
        AppFeature.authPassword,
        AppFeature.authPhone,
        AppFeature.authPhoneViaSms,
        AppFeature.authPhoneViaWhatsapp,
      },
    ),
    'DEMO': Company(
      code: 'DEMO',
      name: 'Demo Company',
      arabicName: 'الشركة التجريبية',
      apiBaseUrl: 'https://demo.example.com',
      features: {
        AppFeature.attendance,
        AppFeature.leave,
        AppFeature.auth,
        AppFeature.authPassword,
      },
      multiLanguage: false,
      defaultLanguage: 'en',
    ),
  };

  @override
  Future<Company> resolve(String code) async {
    await Future<void>.delayed(delay);
    final company = _companies[code.trim().toUpperCase()];
    if (company == null) throw const CompanyNotFoundException();
    return company;
  }
}
