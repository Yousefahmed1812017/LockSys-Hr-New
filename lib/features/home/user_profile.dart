import '../auth/auth_api.dart';

/// What the sign-in returned about the employee, ready to show. Every text is
/// picked for [languageCode] and falls back to the other language, because the
/// ERP often fills only one of the two names.
class UserProfile {
  const UserProfile._(this._user, this.languageCode);

  /// Null when there is no signed-in session (tests, previews).
  static UserProfile? of(AuthSession? session, String languageCode) =>
      session == null ? null : UserProfile._(session.user, languageCode);

  final Map<String, dynamic> _user;
  final String languageCode;

  bool get _ar => languageCode == 'ar';

  static String? _clean(Object? v) {
    final s = v is String ? v.trim() : null;
    return (s == null || s.isEmpty) ? null : s;
  }

  String? _pick(
    Map<String, dynamic>? m, {
    String ar = 'nameAr',
    String en = 'nameEn',
  }) {
    if (m == null) return null;
    final a = _clean(m[ar]);
    final e = _clean(m[en]);
    return _ar ? (a ?? e) : (e ?? a);
  }

  Map<String, dynamic>? _map(Object? v) =>
      v is Map ? v.cast<String, dynamic>() : null;

  Map<String, dynamic>? get _employee => _map(_user['employee']);

  /// The account name, else the employee name.
  String? get name => _pick(_user) ?? _pick(_employee);

  /// The employee number (what people call the "code").
  String? get employeeCode =>
      _clean(_employee?['code']) ?? _clean(_user['username']);

  String? get job => _pick(_map(_employee?['job']));
  String? get department => _pick(_map(_employee?['department']));
  String? get category => _pick(_map(_employee?['category']));
  String? get site => _pick(_map(_employee?['site']));
  String? get manager => _pick(_map(_employee?['manager']));
  String? get status => _pick(_map(_employee?['status']));
  String? get company => _clean(_map(_user['company'])?['name']);
  String? get branch => _clean(_map(_user['branch'])?['name']);
  String? get phone => _clean(_user['phone']);
  String? get email => _clean(_user['email']);

  /// `YYYY-MM-DD` as sent by the server, or null.
  DateTime? get hireDate {
    final s = _clean(_employee?['hireDate']);
    return s == null ? null : DateTime.tryParse(s);
  }
}
