import 'package:repository/repository.dart';
import 'package:test/test.dart';

void main() {
  test(
    'repository action can execute a request and update repository data',
    () async {
      final transport = _ActionHttpClient();
      final repository = _TransactionsRepository(
        RepositoryClient(
          httpClient: transport,
          storage: _InMemoryCacheStorage(),
        ),
      );
      await repository.refresh();

      final created = await repository.actions.create('New');

      expect(created, 'New');
      expect(repository.currentValue, ['Existing', 'New']);
      expect(transport.requests.last.method, RepositoryHttpMethod.post);
      repository.dispose();
    },
  );

  test('repository action without input can update nullable data', () async {
    final transport = _ActionHttpClient();
    final repository = _SessionRepository(
      RepositoryClient(
        httpClient: transport,
        storage: _InMemoryCacheStorage(),
      ),
    );
    await repository.refresh();

    await repository.actions.logout();

    expect(repository.currentValue, isNull);
    expect(transport.requests.last.method, RepositoryHttpMethod.delete);
    repository.dispose();
  });

  test('repository action does not update data when execution fails', () async {
    final repository = _FailingRepository(
      RepositoryClient(
        httpClient: _ActionHttpClient(),
        storage: _InMemoryCacheStorage(),
      ),
    );
    await repository.refresh();

    await expectLater(repository.actions.fail(), throwsStateError);

    expect(repository.currentValue, ['Existing']);
    repository.dispose();
  });

  test(
    'repository action does not update data after an HTTP failure',
    () async {
      final repository = _TransactionsRepository(
        RepositoryClient(
          httpClient: _FailingActionHttpClient(),
          storage: _InMemoryCacheStorage(),
        ),
      );
      await repository.refresh();

      await expectLater(
        repository.actions.create('Rejected'),
        throwsA(isA<UnexpectedStatusCodeException>()),
      );

      expect(repository.currentValue, ['Existing']);
      repository.dispose();
    },
  );

  test(
    'repository action can accept an intentional non-2xx response',
    () async {
      final repository = _ConflictRepository(
        RepositoryClient(
          httpClient: _ConflictHttpClient(),
          storage: _InMemoryCacheStorage(),
        ),
      );
      await repository.refresh();

      final conflict = await repository.actions.acceptConflict();

      expect(conflict, 'Conflict');
      expect(repository.currentValue, ['Existing', 'Conflict']);
      repository.dispose();
    },
  );
}

typedef _TransactionsActions = ({
  Future<String> Function(String title) create,
});

class _TransactionsRepository
    extends Repository<List<String>, _TransactionsActions> {
  _TransactionsRepository(RepositoryClient client)
    : super(
        client: client,
        endpoint: Uri.parse('https://example.com/transactions'),
        fromJson: (json) => [json],
        resolveOnCreate: false,
      );

  @override
  late final _TransactionsActions actions = (
    create: (title) => executeAction(
      run: () async {
        final response = await request(
          RepositoryHttpRequest(
            url: Uri.parse('https://example.com/transactions'),
            method: RepositoryHttpMethod.post,
            body: {'title': title},
          ),
        );
        return response.body;
      },
      update: (current, created) => [...?current, created],
    ),
  );
}

typedef _SessionActions = ({Future<void> Function() logout});

class _SessionRepository extends Repository<String?, _SessionActions> {
  _SessionRepository(RepositoryClient client)
    : super(
        client: client,
        endpoint: Uri.parse('https://example.com/session'),
        fromJson: (json) => json,
        resolveOnCreate: false,
      );

  @override
  late final _SessionActions actions = (
    logout: () => executeAction<void>(
      run: () async {
        await request(
          RepositoryHttpRequest(
            url: Uri.parse('https://example.com/session'),
            method: RepositoryHttpMethod.delete,
          ),
        );
      },
      update: (_, _) => null,
    ),
  );
}

typedef _FailingActions = ({Future<String> Function() fail});

class _FailingRepository extends Repository<List<String>, _FailingActions> {
  _FailingRepository(RepositoryClient client)
    : super(
        client: client,
        endpoint: Uri.parse('https://example.com/transactions'),
        fromJson: (json) => [json],
        resolveOnCreate: false,
      );

  @override
  late final _FailingActions actions = (
    fail: () => executeAction(
      run: () => throw StateError('failed'),
      update: (current, output) => [...?current, output],
    ),
  );
}

typedef _ConflictActions = ({Future<String> Function() acceptConflict});

class _ConflictRepository extends Repository<List<String>, _ConflictActions> {
  _ConflictRepository(RepositoryClient client)
    : super(
        client: client,
        endpoint: Uri.parse('https://example.com/items'),
        fromJson: (json) => [json],
        resolveOnCreate: false,
      );

  @override
  late final _ConflictActions actions = (
    acceptConflict: () => executeAction(
      run: () async {
        final response = await request(
          RepositoryHttpRequest(
            url: Uri.parse('https://example.com/items'),
            method: RepositoryHttpMethod.post,
          ),
          successfulCondition: (response) => response.statusCode == 409,
        );
        return response.body;
      },
      update: (current, conflict) => [...?current, conflict],
    ),
  );
}

class _ActionHttpClient extends RepositoryHttpClient {
  final requests = <RepositoryHttpRequest>[];

  @override
  Future<RepositoryHttpResponse> call({
    required RepositoryHttpRequest request,
  }) async {
    requests.add(request);
    return RepositoryHttpResponse(
      statusCode: 200,
      headers: const {},
      body: switch (request.method) {
        RepositoryHttpMethod.get => 'Existing',
        RepositoryHttpMethod.post => request.body!['title']! as String,
        _ => '',
      },
    );
  }
}

class _FailingActionHttpClient extends RepositoryHttpClient {
  @override
  Future<RepositoryHttpResponse> call({
    required RepositoryHttpRequest request,
  }) async {
    if (request.method == RepositoryHttpMethod.get) {
      return const RepositoryHttpResponse(
        statusCode: 200,
        headers: {},
        body: 'Existing',
      );
    }
    return const RepositoryHttpResponse(
      statusCode: 500,
      headers: {},
      body: 'Rejected',
    );
  }
}

class _ConflictHttpClient extends RepositoryHttpClient {
  @override
  Future<RepositoryHttpResponse> call({
    required RepositoryHttpRequest request,
  }) async {
    return RepositoryHttpResponse(
      statusCode: request.method == RepositoryHttpMethod.get ? 200 : 409,
      headers: const {},
      body: request.method == RepositoryHttpMethod.get
          ? 'Existing'
          : 'Conflict',
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
