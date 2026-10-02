/// Features a company can enable, mirroring the server catalog
/// (GNL_APP_FEATURES). The tree is in the key: `auth.phone.via_sms` is a sub sub
/// feature of `auth.phone`, which is a sub feature of `auth`.
///
/// The server only sends features that are effectively on (own switch and every
/// ancestor), so `company.has(AppFeature.authPhone)` is all a screen needs.
/// Add a feature here with the same key as the database row.
enum AppFeature {
  // Main modules, shown to the user as services.
  attendance('attendance'),
  leave('leave'),
  payslip('payslip'),

  // Sign in: username + password, mobile number + OTP, e-mail + OTP. Each OTP
  // method has the same three delivery channels.
  auth('auth'),
  authPassword('auth.password'),
  authPhone('auth.phone'),
  authPhoneViaSms('auth.phone.via_sms'),
  authPhoneViaWhatsapp('auth.phone.via_whatsapp'),
  authPhoneViaEmail('auth.phone.via_email'),
  authEmail('auth.email'),
  authEmailViaSms('auth.email.via_sms'),
  authEmailViaWhatsapp('auth.email.via_whatsapp'),
  authEmailViaEmail('auth.email.via_email'),

  // Forgot password: identify by e-mail or by mobile number, then an OTP.
  authForgot('auth.forgot'),
  authForgotEmail('auth.forgot.email'),
  authForgotEmailViaSms('auth.forgot.email.via_sms'),
  authForgotEmailViaWhatsapp('auth.forgot.email.via_whatsapp'),
  authForgotEmailViaEmail('auth.forgot.email.via_email'),
  authForgotPhone('auth.forgot.phone'),
  authForgotPhoneViaSms('auth.forgot.phone.via_sms'),
  authForgotPhoneViaWhatsapp('auth.forgot.phone.via_whatsapp'),
  authForgotPhoneViaEmail('auth.forgot.phone.via_email');

  const AppFeature(this.key);

  /// Dotted path key, identical to GNL_APP_FEATURES.CODE.
  final String key;

  /// The modules listed as services on the company screen.
  static const modules = [attendance, leave, payslip];

  /// The enclosing feature, or null for a main feature.
  AppFeature? get parent {
    final dot = key.lastIndexOf('.');
    return dot < 0 ? null : fromKey(key.substring(0, dot));
  }

  static AppFeature? fromKey(String key) {
    for (final f in values) {
      if (f.key == key) return f;
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
    String? arabicName,
    required this.apiBaseUrl,
    required this.features,
    this.multiLanguage = true,
    this.defaultLanguage = 'ar',
  }) : arabicName = arabicName ?? name;

  /// Upper-case code the user typed, e.g. `LOCKSYS`.
  final String code;

  /// English name.
  final String name;

  /// Arabic name (falls back to [name] for companies saved by older builds).
  final String arabicName;

  /// Root of this company's API. Every request after sign-in uses it.
  final String apiBaseUrl;
  final Set<AppFeature> features;

  /// true: Arabic and English, the user may switch. false: only
  /// [defaultLanguage] (`ar` or `en`) and the app has no language switch.
  final bool multiLanguage;
  final String defaultLanguage;

  /// Whether [f] is on. A sub feature counts only while every feature above it
  /// is on too (the server already sends it that way; this keeps the app right
  /// even for a saved copy or a test double that does not).
  bool has(AppFeature f) =>
      features.contains(f) && (f.parent == null || has(f.parent!));

  /// The language the app must be locked to, or null when the user may choose.
  String? get forcedLanguage => multiLanguage ? null : defaultLanguage;

  /// The company name in [languageCode]. A single-language company always shows
  /// the name in its own language.
  String nameFor(String languageCode) =>
      (forcedLanguage ?? languageCode) == 'ar' ? arabicName : name;

  Map<String, Object> toJson() => {
    'code': code,
    'name': name,
    'arabicName': arabicName,
    'apiBaseUrl': apiBaseUrl,
    'features': features.map((f) => f.key).toList(),
    'multiLanguage': multiLanguage,
    'defaultLanguage': defaultLanguage,
  };

  /// Reads the API response and the saved copy alike. Fields missing from a copy
  /// saved by an older build take the old behaviour (both languages, Arabic).
  factory Company.fromJson(Map<String, dynamic> j) => Company(
    code: j['code'] as String,
    name: j['name'] as String,
    arabicName: j['arabicName'] as String?,
    apiBaseUrl: j['apiBaseUrl'] as String,
    features: {
      for (final k in (j['features'] as List).cast<String>())
        ?AppFeature.fromKey(k),
    },
    multiLanguage: j['multiLanguage'] as bool? ?? true,
    defaultLanguage: j['defaultLanguage'] == 'en' ? 'en' : 'ar',
  );
}
