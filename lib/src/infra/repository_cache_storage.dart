import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// {@template repository_cache_storage}
/// An abstract storage to cache data from repositories.
/// It is used by the `Repository` class and wraps
/// an implementation of a cache storage.
/// {@endtemplate}
abstract class RepositoryCacheStorage {
  /// {@macro repository_cache_storage}
  const RepositoryCacheStorage();

  /// Hashes a key to be used as a cache key.
  @protected
  String hashKey(String key) => md5.convert(key.codeUnits).toString();

  /// Delete a value from the cache.
  Future<void> delete({required String key});

  /// Read a value from the cache.
  Future<String?> read({required String key});

  /// Write a value to the cache.
  Future<void> write({
    required String key,
    required String value,
  });

  /// Clears the cache.
  Future<void> clear();
}
