/// Modules a company can enable. The app only shows the enabled ones.
enum AppFeature {
  attendance,
  leave,
  payslip;

  static AppFeature? fromKey(String key) {
    for (final f in values) {
      if (f.name == key) return f;
    }
    return null; // unknown keys from newer servers are ignored
  }
}

/// A company the app is connected to. Resolved once from its company code
/// and saved on the device (see CompanyStore).
class Company {
  const Company({
    required this.code,
    required this.name,
    required this.apiBaseUrl,
    required this.features,
  });

  /// Upper-case code the user typed, e.g. `LOCKSYS`.
  final String code;
  final String name;

  /// Root of this company's API. Every request after sign-in uses it.
  final String apiBaseUrl;
  final Set<AppFeature> features;

  bool has(AppFeature f) => features.contains(f);

  Map<String, Object> toJson() => {
        'code': code,
        'name': name,
        'apiBaseUrl': apiBaseUrl,
        'features': features.map((f) => f.name).toList(),
      };

  factory Company.fromJson(Map<String, dynamic> j) => Company(
        code: j['code'] as String,
        name: j['name'] as String,
        apiBaseUrl: j['apiBaseUrl'] as String,
        features: {
          for (final k in (j['features'] as List).cast<String>())
            ?AppFeature.fromKey(k),
        },
      );
}
