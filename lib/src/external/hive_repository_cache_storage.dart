import 'package:hive/hive.dart';
import 'package:meta/meta.dart';
import 'package:repository/src/infra/repository_cache_storage.dart';

/// {@template hive_repository_cache_storage}
/// A cache storage implementation that uses Hive.
///
/// This class stores the data in a [Box] using the hashed key as the key.
/// The data is stored as a [String].
/// {@endtemplate}
class HiveRepositoryCacheStorage extends RepositoryCacheStorage {
  /// {@macro hive_repository_cache_storage}
  HiveRepositoryCacheStorage({required Box<String> box}) : _box = box;

  @protected
  late final Box<String> _box;

  /// Creates a [HiveRepositoryCacheStorage]
  /// with a default [Box] named `repository-caches`.
  static Future<HiveRepositoryCacheStorage> create() async {
    final box = await Hive.openBox<String>('repository-caches');
    return HiveRepositoryCacheStorage(box: box);
  }

  @override
  Future<void> delete({required String key}) async {
    final hashedKey = hashKey(key);
    await _box.delete(hashedKey);
  }

  final Map<String, String> _inMemoryCache = {};

  @override
  Future<String?> read({required String key}) async {
    final hashedKey = hashKey(key);
    try {
      return _inMemoryCache[hashedKey] ?? _box.get(hashedKey);
    } catch (e) {
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
    await _box.clear();
  }
}
