import 'dart:developer';

import 'package:repository/src/infra/repository_cache_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// {@template shared_preferences_repository_cache_storage}
/// A [RepositoryCacheStorage] that uses `shared_preferences` to cache data.
/// {@endtemplate}
class SharedPreferencesRepositoryCacheStorage extends RepositoryCacheStorage {
  /// {@macro shared_preferences_repository_cache_storage}
  const SharedPreferencesRepositoryCacheStorage();

  static late final SharedPreferences? _instance;

  /// Hashes a key to be used as a cache key.
  String _generateContextBasedKey(String key) => hash(key);

  @override
  Future<void> delete({required String key}) async {
    _instance ??= await SharedPreferences.getInstance();
    final cbk = _generateContextBasedKey(key);
    await _instance?.remove(_generateContextBasedKey(cbk));
  }

  @override
  Future<String?> read({required String key}) async {
    _instance ??= await SharedPreferences.getInstance();
    final cbk = _generateContextBasedKey(key);
    try {
      return _instance?.getString(cbk);
    } catch (e) {
      log('[Repository] Error reading from cache: $e. Clearing cache...');
      await _instance?.remove(cbk);

      return null;
    }
  }

  @override
  Future<void> write({required String key, required String value}) async {
    final cbk = _generateContextBasedKey(key);

    _instance ??= await SharedPreferences.getInstance();
    await _instance?.setString(_generateContextBasedKey(cbk), value);
  }
}
