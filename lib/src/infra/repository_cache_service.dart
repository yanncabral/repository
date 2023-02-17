/// {@template repository_cache_service}
/// An abstract service to cache data from repositories.
/// It is used by the `Repository` class and wraps
/// an implementation of a cache service.
/// {@endtemplate}
abstract class RepositoryCacheService {
  /// {@macro repository_cache_service}
  const RepositoryCacheService();

  /// Id of the cache service
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
