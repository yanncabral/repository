/// {@template repository_cache_storage}
/// An abstract storage to cache data from repositories.
/// It is used by the `Repository` class and wraps
/// an implementation of a cache storage.
/// {@endtemplate}
abstract class RepositoryCacheStorage {
  /// {@macro repository_cache_storage}
  const RepositoryCacheStorage();

  /// Id of the cache storage
  String get id;

  /// Delete a value from the cache
  Future<void> delete({required String key});

  /// Read a value from the cache
  Future<String?> read({required String key});

  /// Write a value to the cache
  Future<void> write({
    required String key,
    required String value,
  });
}
