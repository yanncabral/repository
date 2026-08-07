import 'package:repository/repository.dart';
import 'package:test/test.dart';

void main() {
  test('repository uses the globally configured client by default', () async {
    final transport = _FakeHttpClient('42');
    final storage = _InMemoryCacheStorage();
    BaseRepository.config(
      baseUrl: Uri.parse('https://example.com'),
      httpClient: transport,
      storage: storage,
    );
    final repository = Repository<int, NoRepositoryActions>(
      endpoint: const .relative('/value'),
      fromJson: int.parse,
      actions: () => (),
      resolveOnCreate: false,
    );

    await repository.refresh();

    expect(repository.currentValue, 42);
    expect(transport.requests, hasLength(1));
    expect(await storage.read(key: repository.key), '42');
    repository.dispose();
  });

  test('repository captures the configured client when created', () async {
    final firstTransport = _FakeHttpClient('1');
    BaseRepository.config(
      baseUrl: Uri.parse('https://example.com'),
      httpClient: firstTransport,
      storage: _InMemoryCacheStorage(),
    );
    final repository = Repository<int, NoRepositoryActions>(
      endpoint: const .relative('/value'),
      fromJson: int.parse,
      actions: () => (),
      resolveOnCreate: false,
    );

    final secondTransport = _FakeHttpClient('2');
    BaseRepository.config(
      baseUrl: Uri.parse('https://example.com'),
      httpClient: secondTransport,
      storage: _InMemoryCacheStorage(),
    );
    await repository.refresh();

    expect(repository.currentValue, 1);
    expect(firstTransport.requests, hasLength(1));
    expect(secondTransport.requests, isEmpty);
    repository.dispose();
  });

  test(
    'repository uses the transport and cache configured by its client',
    () async {
      final transport = _FakeHttpClient('42');
      final storage = _InMemoryCacheStorage();
      final client = RepositoryClient(
        httpClient: transport,
        storage: storage,
      );
      final repository = Repository<int, NoRepositoryActions>(
        client: client,
        actions: () => (),
        endpoint: const .absolute('https://example.com/value'),
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
    final first = Repository<int, NoRepositoryActions>(
      client: RepositoryClient(
        httpClient: _FakeHttpClient('1'),
        storage: firstStorage,
      ),
      actions: () => (),
      endpoint: const .absolute('https://example.com/value'),
      fromJson: int.parse,
      resolveOnCreate: false,
    );
    final second = Repository<int, NoRepositoryActions>(
      client: RepositoryClient(
        httpClient: _FakeHttpClient('2'),
        storage: secondStorage,
      ),
      actions: () => (),
      endpoint: const .absolute('https://example.com/value'),
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

  test('interceptor can transform a request and its response', () async {
    final transport = _FakeHttpClient('transport');
    final client = RepositoryClient(
      httpClient: transport,
      storage: _InMemoryCacheStorage(),
      interceptors: const [_TransformingInterceptor()],
    );

    final response = await client.call(
      request: const RepositoryHttpRequest(
        url: .absolute('https://example.com/value'),
      ),
    );

    expect(transport.requests.single.headers, {'X-Repository': 'configured'});
    expect(response.body, 'intercepted transport');
  });

  test('client resolves relative URLs before running interceptors', () async {
    final transport = _FakeHttpClient('transport');
    final interceptor = _RecordingInterceptor();
    final client = RepositoryClient(
      baseUrl: Uri.parse('https://api.example.com/v1/'),
      httpClient: transport,
      storage: _InMemoryCacheStorage(),
      interceptors: [interceptor],
    );

    await client.call(
      request: const RepositoryHttpRequest(
        url: .relative('transactions'),
      ),
    );

    final expected = Uri.parse('https://api.example.com/v1/transactions');
    expect(interceptor.requests.single.resolvedUrl, expected);
    expect(transport.requests.single.resolvedUrl, expected);
  });

  test('absolute URLs ignore the configured base URL', () async {
    final transport = _FakeHttpClient('transport');
    final client = RepositoryClient(
      baseUrl: Uri.parse('https://api.example.com/v1/'),
      httpClient: transport,
      storage: _InMemoryCacheStorage(),
    );

    await client.call(
      request: const RepositoryHttpRequest(
        url: .absolute('https://external.example.com/transactions/1'),
      ),
    );

    expect(
      transport.requests.single.resolvedUrl,
      Uri.parse('https://external.example.com/transactions/1'),
    );
  });

  test('interceptor can replay a request after handling a response', () async {
    final transport = _SequenceHttpClient([401, 200]);
    final client = RepositoryClient(
      httpClient: transport,
      storage: _InMemoryCacheStorage(),
      interceptors: const [_RetryUnauthorizedInterceptor()],
    );

    final response = await client.call(
      request: const RepositoryHttpRequest(
        url: .absolute('https://example.com/private'),
      ),
    );

    expect(response.statusCode, 200);
    expect(transport.requests, hasLength(2));
  });

  test('interceptors wrap the transport in declaration order', () async {
    final trace = <String>[];
    final client = RepositoryClient(
      httpClient: _TracingHttpClient(trace),
      storage: _InMemoryCacheStorage(),
      interceptors: [
        _TracingInterceptor('first', trace),
        _TracingInterceptor('second', trace),
      ],
    );

    await client.call(
      request: const RepositoryHttpRequest(
        url: .absolute('https://example.com/value'),
      ),
    );

    expect(trace, [
      'first:request',
      'second:request',
      'transport',
      'second:response',
      'first:response',
    ]);
  });
}

class _TracingInterceptor implements RepositoryInterceptor {
  _TracingInterceptor(this.name, this.trace);

  final String name;
  final List<String> trace;

  @override
  Future<RepositoryHttpResponse> intercept({
    required RepositoryHttpRequest request,
    required RepositoryRequestHandler next,
  }) async {
    trace.add('$name:request');
    final response = await next(request);
    trace.add('$name:response');
    return response;
  }
}

class _RetryUnauthorizedInterceptor implements RepositoryInterceptor {
  const _RetryUnauthorizedInterceptor();

  @override
  Future<RepositoryHttpResponse> intercept({
    required RepositoryHttpRequest request,
    required RepositoryRequestHandler next,
  }) async {
    final response = await next(request);
    if (response.statusCode == 401) {
      return next(request);
    }
    return response;
  }
}

class _TransformingInterceptor implements RepositoryInterceptor {
  const _TransformingInterceptor();

  @override
  Future<RepositoryHttpResponse> intercept({
    required RepositoryHttpRequest request,
    required RepositoryRequestHandler next,
  }) async {
    final response = await next(
      RepositoryHttpRequest(
        url: request.url,
        method: request.method,
        body: request.body,
        headers: {...request.headers, 'X-Repository': 'configured'},
      ),
    );

    return RepositoryHttpResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: 'intercepted ${response.body}',
    );
  }
}

class _RecordingInterceptor implements RepositoryInterceptor {
  final requests = <RepositoryHttpRequest>[];

  @override
  Future<RepositoryHttpResponse> intercept({
    required RepositoryHttpRequest request,
    required RepositoryRequestHandler next,
  }) {
    requests.add(request);
    return next(request);
  }
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

class _SequenceHttpClient extends RepositoryHttpClient {
  _SequenceHttpClient(this.statusCodes);

  final List<int> statusCodes;
  final requests = <RepositoryHttpRequest>[];

  @override
  Future<RepositoryHttpResponse> call({
    required RepositoryHttpRequest request,
  }) async {
    requests.add(request);
    return RepositoryHttpResponse(
      statusCode: statusCodes.removeAt(0),
      headers: const {},
      body: '',
    );
  }
}

class _TracingHttpClient extends RepositoryHttpClient {
  _TracingHttpClient(this.trace);

  final List<String> trace;

  @override
  Future<RepositoryHttpResponse> call({
    required RepositoryHttpRequest request,
  }) async {
    trace.add('transport');
    return const RepositoryHttpResponse(
      statusCode: 200,
      headers: {},
      body: '',
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
