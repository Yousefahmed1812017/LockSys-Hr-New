import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Why a code is being asked for.
enum OtpPurpose { login, reset }

/// A failed call. [code] is the server's error code (`INVALID_CREDENTIALS`,
/// `OTP_EXPIRED`...); [network] is true when the server could not be reached or
/// did not answer with the expected JSON.
class AuthException implements Exception {
  const AuthException({
    required this.code,
    required this.messageAr,
    required this.messageEn,
    this.retryAfterSeconds,
    this.attemptsLeft,
    this.network = false,
  });

  const AuthException.network()
    : this(
        code: 'NETWORK',
        messageAr: 'تعذّر الاتصال بالخادم',
        messageEn: 'Could not reach the server',
        network: true,
      );

  final String code;
  final String messageAr;
  final String messageEn;
  final int? retryAfterSeconds;
  final int? attemptsLeft;
  final bool network;

  String message(String languageCode) =>
      languageCode == 'ar' ? messageAr : messageEn;

  @override
  String toString() => 'AuthException($code)';
}

/// What the server returns after a successful sign-in.
class AuthSession {
  const AuthSession({
    required this.token,
    this.expiresAt,
    this.mustChangePassword = false,
    this.user = const {},
  });

  final String token;
  final String? expiresAt;
  final bool mustChangePassword;
  final Map<String, dynamic> user;

  Map<String, dynamic> toJson() => {
    'token': token,
    'expiresAt': expiresAt,
    'mustChangePassword': mustChangePassword,
    'user': user,
  };

  /// Whether the server's expiry time has passed (unknown = not expired).
  bool get isExpired {
    final at = DateTime.tryParse(expiresAt ?? '');
    return at != null && at.isBefore(DateTime.now());
  }

  AuthSession withUser(Map<String, dynamic> user) => AuthSession(
    token: token,
    expiresAt: expiresAt,
    mustChangePassword: mustChangePassword,
    user: user,
  );

  String? get nameAr => user['nameAr'] as String?;
  String? get nameEn => user['nameEn'] as String?;

  factory AuthSession.fromJson(Map<String, dynamic> j) => AuthSession(
    token: j['token'] as String,
    expiresAt: j['expiresAt'] as String?,
    mustChangePassword: j['mustChangePassword'] == true,
    user: (j['user'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
}

/// A code that was requested: [otpId] goes back with the code the user types.
/// [devCode] is only present while the server is in test mode (nothing is sent,
/// the app shows the code instead).
class OtpTicket {
  const OtpTicket({
    required this.otpId,
    required this.destinationMasked,
    this.expiresInSeconds = 300,
    this.resendAfterSeconds = 60,
    this.devCode,
  });

  final String otpId;
  final String destinationMasked;
  final int expiresInSeconds;
  final int resendAfterSeconds;
  final String? devCode;

  factory OtpTicket.fromJson(Map<String, dynamic> j) => OtpTicket(
    otpId: j['otpId'] as String,
    destinationMasked: j['destinationMasked'] as String? ?? '',
    expiresInSeconds: (j['expiresInSeconds'] as num?)?.toInt() ?? 300,
    resendAfterSeconds: (j['resendAfterSeconds'] as num?)?.toInt() ?? 60,
    devCode: j['devCode'] as String?,
  );
}

/// The sign-in calls of the company server (module `MobileAuth`).
abstract interface class AuthApi {
  Future<AuthSession> loginPassword({
    required String username,
    required String password,
  });

  /// [channel] is `sms`, `whatsapp` or `email`.
  Future<OtpTicket> requestOtp({
    required OtpPurpose purpose,
    required bool byPhone,
    required String identifier,
    required String channel,
  });

  Future<AuthSession> verifyLoginOtp({
    required String otpId,
    required String code,
  });

  /// Returns the reset token for [resetPassword].
  Future<String> verifyResetOtp({required String otpId, required String code});

  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  });

  Future<void> logout(String token);

  /// The signed-in employee's data. Throws [AuthException] (`TOKEN_INVALID`...)
  /// when the server no longer accepts the token.
  Future<Map<String, dynamic>> me(String token);
}

/// A random id kept on this device; the server binds the account to it.
String deviceIdFrom(SharedPreferences prefs) {
  const key = 'deviceUuid';
  final saved = prefs.getString(key);
  if (saved != null && saved.isNotEmpty) return saved;
  final rnd = Random.secure();
  final id = List.generate(
    16,
    (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  prefs.setString(key, id);
  return id;
}

/// The real thing. [baseUrl] is the company's `apiBaseUrl`
/// (`https://host/ords/alias/`); the module lives under `mobile/auth/v1/`.
class HttpAuthApi implements AuthApi {
  HttpAuthApi({
    required String baseUrl,
    required this.deviceId,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _base = '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/mobile/auth/v1',
       _client = client;

  final String _base;
  final String Function() deviceId;
  final Duration timeout;
  final http.Client? _client;

  Future<Map<String, dynamic>> _call(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? token,
  }) async {
    final uri = Uri.parse('$_base/$path');
    if (uri.scheme != 'https') throw const AuthException.network();
    final client = _client ?? http.Client();
    try {
      final request = http.Request(method, uri)
        ..followRedirects = false
        ..headers.addAll({
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'User-Agent': 'LockSysHR/1.0',
          'Authorization': ?(token == null ? null : 'Bearer $token'),
        });
      if (body != null) request.body = jsonEncode(body);
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(timeout);
      final Object? json;
      try {
        json = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw const AuthException.network();
      }
      if (json is! Map<String, dynamic>) throw const AuthException.network();
      if (json['success'] == true && json['data'] is Map<String, dynamic>) {
        return json['data'] as Map<String, dynamic>;
      }
      final error = json['error'];
      if (error is Map<String, dynamic>) {
        throw AuthException(
          code: error['code'] as String? ?? 'ERROR',
          messageAr: error['message_ar'] as String? ?? '',
          messageEn: error['message_en'] as String? ?? '',
          retryAfterSeconds: (error['retryAfterSeconds'] as num?)?.toInt(),
          attemptsLeft: (error['attemptsLeft'] as num?)?.toInt(),
        );
      }
      throw const AuthException.network();
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException.network();
    } finally {
      if (_client == null) client.close();
    }
  }

  @override
  Future<AuthSession> loginPassword({
    required String username,
    required String password,
  }) async => AuthSession.fromJson(
    await _call(
      'POST',
      'login/password',
      body: {
        'username': username,
        'password': password,
        'deviceUuid': deviceId(),
      },
    ),
  );

  @override
  Future<OtpTicket> requestOtp({
    required OtpPurpose purpose,
    required bool byPhone,
    required String identifier,
    required String channel,
  }) async => OtpTicket.fromJson(
    await _call(
      'POST',
      purpose == OtpPurpose.login
          ? 'login/otp/request'
          : 'password/forgot/request',
      body: {
        'identifierType': byPhone ? 'phone' : 'email',
        'identifier': identifier,
        'channel': channel,
      },
    ),
  );

  @override
  Future<AuthSession> verifyLoginOtp({
    required String otpId,
    required String code,
  }) async => AuthSession.fromJson(
    await _call(
      'POST',
      'login/otp/verify',
      body: {'otpId': otpId, 'code': code, 'deviceUuid': deviceId()},
    ),
  );

  @override
  Future<String> verifyResetOtp({
    required String otpId,
    required String code,
  }) async =>
      (await _call(
            'POST',
            'password/forgot/verify',
            body: {'otpId': otpId, 'code': code},
          ))['resetToken']
          as String;

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    await _call(
      'POST',
      'password/reset',
      body: {'resetToken': resetToken, 'newPassword': newPassword},
    );
  }

  @override
  Future<Map<String, dynamic>> me(String token) async {
    final data = await _call('GET', 'me', token: token);
    return (data['user'] as Map?)?.cast<String, dynamic>() ?? const {};
  }

  @override
  Future<void> logout(String token) async {
    try {
      // ORDS answers 400 to a POST without a body.
      await _call('POST', 'logout', body: const {}, token: token);
    } on AuthException {
      // The session is dropped on the device either way.
    }
  }
}

/// Development stand-in (tests, running without a server): any password of six
/// characters or more signs in, and any six digit code is accepted.
class MockAuthApi implements AuthApi {
  const MockAuthApi({this.delay = const Duration(milliseconds: 900)});
  final Duration delay;

  static const _session = AuthSession(token: 'mock-token');

  @override
  Future<AuthSession> loginPassword({
    required String username,
    required String password,
  }) async {
    await Future<void>.delayed(delay + const Duration(milliseconds: 300));
    return _session;
  }

  @override
  Future<OtpTicket> requestOtp({
    required OtpPurpose purpose,
    required bool byPhone,
    required String identifier,
    required String channel,
  }) async => const OtpTicket(
    otpId: 'mock-otp',
    destinationMasked: '',
    resendAfterSeconds: 30,
  );

  @override
  Future<AuthSession> verifyLoginOtp({
    required String otpId,
    required String code,
  }) async {
    await Future<void>.delayed(delay);
    return _session;
  }

  @override
  Future<String> verifyResetOtp({
    required String otpId,
    required String code,
  }) async {
    await Future<void>.delayed(delay);
    return 'mock-reset';
  }

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) => Future<void>.delayed(delay);

  @override
  Future<void> logout(String token) async {}

  @override
  Future<Map<String, dynamic>> me(String token) async => const {};
}
