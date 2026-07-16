import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// CredentialManager — the ONLY place roster-provider credentials live.
///
/// Security contract (feature spec, verbatim intent):
///   * Storage backend is the platform secure enclave via
///     flutter_secure_storage → iOS Keychain / Android Keystore
///     (EncryptedSharedPreferences). Never Firestore, never any backend,
///     never plaintext files.
///   * Values are NEVER logged, NEVER interpolated into exceptions, and
///     NEVER placed in any object that is serialized to the network. The
///     server enforces the same wall independently
///     (roster_sync.assert_no_credentials rejects credential-shaped keys in
///     any /v1/roster-sync payload).
///   * [wipeProvider] (used by disconnect) deletes every key for that
///     provider; [wipeAll] clears the whole namespace.
///
/// The storage backend is injectable so pure-Dart unit tests can verify the
/// contract without platform channels.
abstract class SecureKeyValueStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<Map<String, String>> readAll();
}

/// Production backend: flutter_secure_storage.
class PlatformSecureStore implements SecureKeyValueStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();
}

class CredentialManager {
  static const _namespace = 'najm.roster_sync';
  final SecureKeyValueStore _store;

  CredentialManager({SecureKeyValueStore? store})
      : _store = store ?? PlatformSecureStore();

  String _key(String providerId, String field) =>
      '$_namespace.$providerId.$field';

  bool _inNamespace(String key, [String? providerId]) => providerId == null
      ? key.startsWith('$_namespace.')
      : key.startsWith('$_namespace.$providerId.');

  /// Store one credential field (e.g. "prn", "password", "feed_url").
  Future<void> store(String providerId, String field, String value) =>
      _store.write(_key(providerId, field), value);

  Future<String?> readField(String providerId, String field) =>
      _store.read(_key(providerId, field));

  /// All fields for a provider (field name → value). Callers must treat the
  /// returned map as sensitive: use, then drop the reference.
  Future<Map<String, String>> readProvider(String providerId) async {
    final all = await _store.readAll();
    final out = <String, String>{};
    all.forEach((k, v) {
      if (_inNamespace(k, providerId)) {
        out[k.substring(_key(providerId, '').length)] = v;
      }
    });
    return out;
  }

  Future<bool> hasCredentials(String providerId) async =>
      (await readProvider(providerId)).isNotEmpty;

  /// Disconnect contract: securely erase EVERY stored credential for the
  /// provider. Returns the number of fields wiped.
  Future<int> wipeProvider(String providerId) async {
    final all = await _store.readAll();
    var wiped = 0;
    for (final k in all.keys) {
      if (_inNamespace(k, providerId)) {
        await _store.delete(k);
        wiped++;
      }
    }
    return wiped;
  }

  Future<int> wipeAll() async {
    final all = await _store.readAll();
    var wiped = 0;
    for (final k in all.keys) {
      if (_inNamespace(k)) {
        await _store.delete(k);
        wiped++;
      }
    }
    return wiped;
  }
}
