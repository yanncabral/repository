import 'dart:developer';

import 'package:repository/src/infra/repository_cache_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// {@template shared_preferences_repository_cache_storage}
/// A [RepositoryCacheStorage] that uses `shared_preferences` to cache data.
/// {@endtemplate}
class SharedPreferencesRepositoryCacheStorage extends RepositoryCacheStorage {
  /// {@macro shared_preferences_repository_cache_storage}
  const SharedPreferencesRepositoryCacheStorage();

  @override
  String get id => throw UnimplementedError();

  static late final SharedPreferences? _instance;

  String _generateContextBasedKey(String key) {
    return 'repository/$id/$key';
  }

  @override
  Future<void> delete({required String key}) async {
    _instance ??= await SharedPreferences.getInstance();
    await _instance?.remove(_generateContextBasedKey(key));
  }

  @override
  Future<String?> read({required String key}) async {
    _instance ??= await SharedPreferences.getInstance();
    try {
      return _instance?.getString(_generateContextBasedKey(key));
    } catch (e) {
      log('[Repository] Error reading from cache: $e. Clearing cache...');
      await _instance?.remove(key);

      return null;
    }
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _instance ??= await SharedPreferences.getInstance();
    await _instance?.setString(_generateContextBasedKey(key), value);
  }
}
