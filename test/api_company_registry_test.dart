import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lock_sys_hr/features/company/api_company_registry.dart';
import 'package:lock_sys_hr/features/company/company.dart';
import 'package:lock_sys_hr/features/company/company_registry.dart';

void main() {
  test('maps API baseUrl and ignores unknown feature keys', () async {
    final registry = ApiCompanyRegistry(
      username: 'test',
      password: 'secret',
      client: MockClient((request) async {
        expect(request.url.path, '/ords/locksys/app/v1/companies/LOCKSYS');
        expect(
          request.headers['Authorization'],
          'Basic ${base64Encode(utf8.encode('test:secret'))}',
        );
        expect(request.headers['User-Agent'], 'LockSysHR/1.0');
        expect(request.followRedirects, false);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'code': 'LOCKSYS',
              'name': 'LockSys',
              'baseUrl': 'https://example.com/ords/hr/',
              'features': ['attendance', 'future_feature'],
              'maintenance': false,
            },
          }),
          200,
        );
      }),
    );
    final company = await registry.resolve(' locksys ');
    expect(company.apiBaseUrl, 'https://example.com/ords/hr/');
    expect(company.features, {AppFeature.attendance});
    expect(Company.fromJson(company.toJson()).apiBaseUrl, company.apiBaseUrl);
  });
  for (final entry in {
    404: 'COMPANY_NOT_FOUND',
    403: 'COMPANY_INACTIVE',
    401: 'UNAUTHORIZED',
  }.entries) {
    test('handles ${entry.key} ${entry.value}', () async {
      final registry = ApiCompanyRegistry(
        username: 'test',
        password: 'secret',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': false,
              'error': {
                'code': entry.value,
                'message_ar': 'رسالة',
                'message_en': 'Message',
              },
            }),
            entry.key,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      await expectLater(
        registry.resolve('LOCKSYS'),
        throwsA(
          entry.key == 404
              ? isA<CompanyNotFoundException>()
              : isA<CompanyApiException>(),
        ),
      );
    });
  }
  test('proxy HTML is a service failure, not an inactive company', () async {
    final registry = ApiCompanyRegistry(
      username: 'test',
      password: 'secret',
      client: MockClient(
        (_) async => http.Response('<html>Denied</html>', 403),
      ),
    );
    await expectLater(
      registry.resolve('LOCKSYS'),
      throwsA(isA<CompanyRegistryUnavailableException>()),
    );
  });
  test('rejects oversized codes before sending', () async {
    final registry = ApiCompanyRegistry(
      username: 'test',
      password: 'secret',
      client: MockClient((_) async => throw StateError('Should not send')),
    );
    await expectLater(
      registry.resolve('X' * 51),
      throwsA(isA<CompanyNotFoundException>()),
    );
  });
}
