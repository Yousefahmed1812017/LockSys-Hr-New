import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lock_sys_hr/features/auth/auth_api.dart';

HttpAuthApi _api(http.Client c) => HttpAuthApi(
  baseUrl: 'https://h.example/ords/x/',
  deviceId: () => 'dev-1',
  client: c,
);

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('login sends the device id and reads the session', () async {
    late http.Request seen;
    final api = _api(
      MockClient((r) async {
        seen = r;
        return _json({
          'success': true,
          'data': {
            'token': 'abc',
            'mustChangePassword': false,
            'user': {'nameAr': 'أحمد', 'nameEn': 'Ahmed'},
          },
        });
      }),
    );
    final s = await api.loginPassword(username: 'u', password: 'secret1');
    expect(
      seen.url.toString(),
      'https://h.example/ords/x/mobile/auth/v1/login/password',
    );
    expect(jsonDecode(seen.body), {
      'username': 'u',
      'password': 'secret1',
      'deviceUuid': 'dev-1',
    });
    expect(s.token, 'abc');
    expect(s.nameAr, 'أحمد');
  });

  test('server errors keep code, both messages and attempts', () async {
    final api = _api(
      MockClient(
        (_) async => _json({
          'success': false,
          'error': {
            'code': 'INVALID_OTP',
            'message_ar': 'الرمز غير صحيح',
            'message_en': 'The code is not correct',
            'attemptsLeft': 3,
          },
        }, 400),
      ),
    );
    await expectLater(
      api.verifyLoginOtp(otpId: 'i', code: '111111'),
      throwsA(
        isA<AuthException>()
            .having((e) => e.code, 'code', 'INVALID_OTP')
            .having((e) => e.attemptsLeft, 'left', 3)
            .having((e) => e.message('ar'), 'ar', 'الرمز غير صحيح'),
      ),
    );
  });

  test('otp request returns the test code and wait', () async {
    final api = _api(
      MockClient(
        (_) async => _json({
          'success': true,
          'data': {
            'otpId': 'o1',
            'destinationMasked': '•••• 8621',
            'expiresInSeconds': 300,
            'resendAfterSeconds': 60,
            'devCode': '712014',
          },
        }),
      ),
    );
    final t = await api.requestOtp(
      purpose: OtpPurpose.reset,
      byPhone: true,
      identifier: '01012345678',
      channel: 'sms',
    );
    expect(t.devCode, '712014');
    expect(t.resendAfterSeconds, 60);
  });

  test('network failure and non-JSON become a network error', () async {
    final down = _api(MockClient((_) async => throw Exception('offline')));
    await expectLater(
      down.loginPassword(username: 'u', password: 'secret1'),
      throwsA(isA<AuthException>().having((e) => e.network, 'network', true)),
    );
    final html = _api(MockClient((_) async => http.Response('<html>', 502)));
    await expectLater(
      html.loginPassword(username: 'u', password: 'secret1'),
      throwsA(isA<AuthException>().having((e) => e.network, 'network', true)),
    );
  });
}
