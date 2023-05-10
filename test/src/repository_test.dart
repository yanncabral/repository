import 'package:repository/repository.dart';
import 'package:repository/src/infra/repository_cache_storage.dart';
import 'package:test/test.dart';

void main() {
  group('Repository', () {
    late Repository<int> repository;

    setUp(() {
      Repository.storage = _RepositoryCacheStorageMock();
      repository = _TestRepository();
    });

    test('should emit empty state on creation', () {
      expect(
        repository.currentState,
        const RepositoryState<int>.empty(),
      );
    });

    test('should emit ready state after hydrating', () async {
      await repository.hydrate();

      expect(repository.currentState, isA<RepositoryState<int>>());
      expect(repository.currentValue, equals(42));
    });

    test('should emit ready state after refreshing', () async {
      await repository.refresh();

      expect(repository.currentState, isA<RepositoryState<int>>());
      expect(repository.currentValue, equals(42));
    });

    tearDown(() {
      repository.dispose();
    });
  });
}

class _RepositoryCacheStorageMock extends RepositoryCacheStorage {
  final Map<String, String> _db = {};

  @override
  Future<void> clear() async {
    _db.clear();
  }

  @override
  Future<void> delete({required String key}) async {
    _db.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    return _db[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _db[key] = value;
  }
}

class _TestRepository extends Repository<int> {
  @override
  Future<String> resolve() async {
    return '42';
  }

  @override
  int fromJson(covariant int json) {
    return json;
  }

  @override
  String get key => 'test_repository';
}
