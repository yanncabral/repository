import 'package:repository/src/external/shared_preferences_repository_cache_storage.dart';

/// {@template repository_cache_storage}
/// An abstract storage to cache data from repositories.
/// It is used by the `Repository` class and wraps
/// an implementation of a cache storage.
/// {@endtemplate}
abstract class RepositoryCacheStorage {
  /// {@macro repository_cache_storage}
  const RepositoryCacheStorage();

  /// {@macro shared_preferences_repository_cache_storage}
  const factory RepositoryCacheStorage.sharedPreferences() =
      SharedPreferencesRepositoryCacheStorage;

  /// An id used to identify the cache storage.
  /// This is useful if you have multiple repositories that use the same key.
  /// For example, you don't want to get the same cached data
  /// from a different authentication sessions.
  String get id;

  /// Delete a value from the cache.
  Future<void> delete({required String key});

  /// Read a value from the cache.
  Future<String?> read({required String key});

  /// Write a value to the cache.
  Future<void> write({
    required String key,
    required String value,
  });
}
