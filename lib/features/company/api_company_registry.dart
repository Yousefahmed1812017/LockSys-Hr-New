import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'company.dart';
import 'company_registry.dart';

class CompanyApiException implements Exception {
  const CompanyApiException(this.code, this.arabicMessage, this.message);
  final String code;
  final String arabicMessage;
  final String message;
}

/// Central directory credentials identify the app, never an employee session.
class ApiCompanyRegistry implements CompanyRegistry {
  ApiCompanyRegistry({
    required this.username,
    required this.password,
    this.baseUrl = 'https://erp.lock-sys.com/ords/locksys/app/v1',
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client;

  final String username;
  final String password;
  final String baseUrl;
  final Duration timeout;
  final http.Client? _client;

  @override
  Future<Company> resolve(String code) async {
    final normalized = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9_-]{2,50}$').hasMatch(normalized)) {
      throw const CompanyNotFoundException();
    }
    if (username.isEmpty || password.isEmpty) {
      throw const CompanyApiException(
        'CONFIGURATION',
        'الخدمة غير مهيأة. تواصل مع الدعم.',
        'Service is not configured. Contact support.',
      );
    }
    final client = _client ?? http.Client();
    try {
      final uri = Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/companies/$normalized',
      );
      if (uri.scheme != 'https') throw const FormatException('HTTPS required');
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..headers.addAll({
          'Accept': 'application/json',
          'User-Agent': 'LockSysHR/1.0',
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$username:$password'))}',
        });
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(timeout);
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode != 200 || json['success'] != true) {
        final error = json['error'];
        if (error is Map<String, dynamic>) {
          if (response.statusCode == 404 &&
              error['code'] == 'COMPANY_NOT_FOUND') {
            throw const CompanyNotFoundException();
          }
          if (response.statusCode == 401 || response.statusCode == 403) {
            throw CompanyApiException(
              error['code'] as String,
              error['message_ar'] as String,
              error['message_en'] as String,
            );
          }
        }
        throw const CompanyRegistryUnavailableException();
      }
      final data = json['data'] as Map<String, dynamic>;
      if (data['code'] != normalized) {
        throw const FormatException('Company mismatch');
      }
      final url = Uri.parse(data['baseUrl'] as String);
      if (url.scheme != 'https' ||
          url.host.isEmpty ||
          url.userInfo.isNotEmpty) {
        throw const FormatException('Invalid company URL');
      }
      if (data['maintenance'] == true) {
        throw const CompanyApiException(
          'MAINTENANCE',
          'خدمة الشركة تحت الصيانة. حاول لاحقًا.',
          'Company service is under maintenance. Try again later.',
        );
      }
      return Company.fromJson({...data, 'apiBaseUrl': data['baseUrl']});
    } on CompanyNotFoundException {
      rethrow;
    } on CompanyApiException {
      rethrow;
    } catch (_) {
      throw const CompanyRegistryUnavailableException();
    } finally {
      if (_client == null) client.close();
    }
  }
}
