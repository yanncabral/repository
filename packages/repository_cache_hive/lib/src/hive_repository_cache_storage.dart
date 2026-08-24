import 'package:hive/hive.dart';
import 'package:repository/repository.dart';

/// {@template hive_repository_cache_storage}
/// A [RepositoryCacheStorage] backed by a Hive string box.
/// {@endtemplate}
final class HiveRepositoryCacheStorage extends RepositoryCacheStorage {
  /// {@macro hive_repository_cache_storage}
  factory HiveRepositoryCacheStorage({required Box<String> box}) {
    return HiveRepositoryCacheStorage._(box);
  }

  HiveRepositoryCacheStorage._(this._box);

  final Box<String> _box;

  final Map<String, String> _inMemoryCache = {};

  /// Opens the default `repository-caches` box.
  static Future<HiveRepositoryCacheStorage> create() async {
    final box = await Hive.openBox<String>('repository-caches');
    return HiveRepositoryCacheStorage(box: box);
  }

  @override
  Future<void> delete({required String key}) async {
    final hashedKey = hashKey(key);
    _inMemoryCache.remove(hashedKey);
    await _box.delete(hashedKey);
  }

  @override
  Future<String?> read({required String key}) async {
    final hashedKey = hashKey(key);
    try {
      return _inMemoryCache[hashedKey] ?? _box.get(hashedKey);
    } on Object {
      await _box.delete(hashedKey);
      return null;
    }
  }

  @override
  Future<void> write({required String key, required String value}) async {
    final hashedKey = hashKey(key);
    _inMemoryCache[hashedKey] = value;
    await _box.put(hashedKey, value);
  }

  @override
  Future<void> clear() async {
    _inMemoryCache.clear();
    await _box.clear();
  }
}
