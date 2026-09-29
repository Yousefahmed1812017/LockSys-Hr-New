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

/// Development registry with two fake companies. Replace with the real one.
///   LOCKSYS -> attendance + leave + payslip
///   DEMO    -> attendance + leave
class MockCompanyRegistry implements CompanyRegistry {
  const MockCompanyRegistry({this.delay = const Duration(milliseconds: 900)});
  final Duration delay;

  static const _companies = {
    'LOCKSYS': Company(
      code: 'LOCKSYS',
      name: 'LockSys Solutions',
      apiBaseUrl: 'https://api.locksys.co',
      features: {
        AppFeature.attendance,
        AppFeature.leave,
        AppFeature.payslip,
      },
    ),
    'DEMO': Company(
      code: 'DEMO',
      name: 'Demo Company',
      apiBaseUrl: 'https://demo.example.com',
      features: {AppFeature.attendance, AppFeature.leave},
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
