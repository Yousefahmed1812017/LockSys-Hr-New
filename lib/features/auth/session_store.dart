import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_api.dart';

/// Keeps the signed-in session on the phone, so the employee signs in once and
/// not every time the app opens. Sign out (or a token the server no longer
/// accepts) clears it.
abstract interface class SessionStore {
  Future<AuthSession?> load();
  Future<void> save(AuthSession session);
  Future<void> clear();
}

/// Nothing is kept (tests, previews).
class MemorySessionStore implements SessionStore {
  AuthSession? _session;

  @override
  Future<AuthSession?> load() async => _session;

  @override
  Future<void> save(AuthSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}

/// The token is a key to the employee's data, so it goes in the phone's secure
/// storage (Android Keystore / iOS Keychain), not in plain preferences.
class SecureSessionStore implements SessionStore {
  const SecureSessionStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;
  static const _key = 'session';

  @override
  Future<AuthSession?> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Unreadable (reinstall, changed keys): the employee signs in again.
      await clear();
      return null;
    }
  }

  @override
  Future<void> save(AuthSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Nothing to clear.
    }
  }
}
