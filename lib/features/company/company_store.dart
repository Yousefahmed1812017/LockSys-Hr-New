import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'company.dart';

/// Remembers the company on this device. Once saved, the company-code screen
/// is never shown again (until [clear] is called, e.g. "change company").
class CompanyStore {
  CompanyStore(this._prefs);
  final SharedPreferences _prefs;

  static const _key = 'company';

  Company? get current {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return Company.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // corrupted value: ask for the code again
    }
  }

  bool get hasCompany => current != null;

  Future<void> save(Company company) =>
      _prefs.setString(_key, jsonEncode(company.toJson()));

  Future<void> clear() => _prefs.remove(_key);
}
