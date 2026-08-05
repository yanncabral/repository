import 'package:repository/repository.dart';
import 'package:test/test.dart';

void main() {
  test(
    'repository uses the transport and cache configured by its client',
    () async {
      final transport = _FakeHttpClient('42');
      final storage = _InMemoryCacheStorage();
      final client = RepositoryClient(
        httpClient: transport,
        storage: storage,
      );
      final repository = Repository<int>(
        client: client,
        endpoint: Uri.parse('https://example.com/value'),
        fromJson: int.parse,
        resolveOnCreate: false,
      );

      await repository.refresh();

      expect(repository.currentValue, 42);
      expect(transport.requests, hasLength(1));
      expect(
        await storage.read(key: 'https://example.com/value'),
        '42',
      );

      repository.dispose();
    },
  );

  test('repository clients keep cache and transport state isolated', () async {
    final firstStorage = _InMemoryCacheStorage();
    final secondStorage = _InMemoryCacheStorage();
    final first = Repository<int>(
      client: RepositoryClient(
        httpClient: _FakeHttpClient('1'),
        storage: firstStorage,
      ),
      endpoint: Uri.parse('https://example.com/value'),
      fromJson: int.parse,
      resolveOnCreate: false,
    );
    final second = Repository<int>(
      client: RepositoryClient(
        httpClient: _FakeHttpClient('2'),
        storage: secondStorage,
      ),
      endpoint: Uri.parse('https://example.com/value'),
      fromJson: int.parse,
      resolveOnCreate: false,
    );

    await Future.wait([first.refresh(), second.refresh()]);

    expect(first.currentValue, 1);
    expect(second.currentValue, 2);
    expect(await firstStorage.read(key: first.key), '1');
    expect(await secondStorage.read(key: second.key), '2');

    first.dispose();
    second.dispose();
  });
}

class _FakeHttpClient extends RepositoryHttpClient {
  _FakeHttpClient(this.body);

  final String body;
  final requests = <RepositoryHttpRequest>[];

  @override
  Future<RepositoryHttpResponse> call({
    required RepositoryHttpRequest request,
  }) async {
    requests.add(request);
    return RepositoryHttpResponse(
      statusCode: 200,
      headers: const {},
      body: body,
    );
  }
}

class _InMemoryCacheStorage extends RepositoryCacheStorage {
  final values = <String, String>{};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
