import 'package:dartz/dartz.dart';
import 'package:repository/repository.dart';
import 'package:test/test.dart';

void main() {
  test('successful action updates repository data', () async {
    final transport = _ActionHttpClient();
    final repository = _transactionsRepository(
      RepositoryClient(
        httpClient: transport,
        storage: _InMemoryCacheStorage(),
      ),
    );
    await repository.refresh();

    final result = await repository.actions.create('New');

    expect(result, const Right<String, String>('New'));
    expect(repository.currentValue, ['Existing', 'New']);
    expect(transport.requests.last.method, RepositoryHttpMethod.post);
    repository.dispose();
  });

  test('action without input can update nullable data', () async {
    final transport = _ActionHttpClient();
    final repository = _sessionRepository(
      RepositoryClient(
        httpClient: transport,
        storage: _InMemoryCacheStorage(),
      ),
    );
    await repository.refresh();

    final result = await repository.actions.logout();

    expect(result.isRight(), isTrue);
    expect(repository.currentValue, isNull);
    expect(transport.requests.last.method, RepositoryHttpMethod.delete);
    repository.dispose();
  });

  test('Left action result does not update repository data', () async {
    final repository = Repository<List<String>, _FailingActions>(
      client: RepositoryClient(
        httpClient: _ActionHttpClient(),
        storage: _InMemoryCacheStorage(),
      ),
      endpoint: const .absolute('https://example.com/transactions'),
      fromJson: (json) => [json],
      actions: _failingActions,
      resolveOnCreate: false,
    );
    await repository.refresh();

    final result = await repository.actions.fail();

    expect(result, const Left<String, String>('failed'));
    expect(repository.currentValue, ['Existing']);
    repository.dispose();
  });

  test('HTTP failure returned as Left does not update data', () async {
    final repository = _transactionsRepository(
      RepositoryClient(
        httpClient: _FailingActionHttpClient(),
        storage: _InMemoryCacheStorage(),
      ),
    );
    await repository.refresh();

    final result = await repository.actions.create('Rejected');

    expect(result, const Left<String, String>('HTTP 500'));
    expect(repository.currentValue, ['Existing']);
    repository.dispose();
  });

  test('action can return Right for an intentional non-2xx response', () async {
    final repository = Repository<List<String>, _ConflictActions>(
      client: RepositoryClient(
        httpClient: _ConflictHttpClient(),
        storage: _InMemoryCacheStorage(),
      ),
      endpoint: const .absolute('https://example.com/items'),
      fromJson: (json) => [json],
      actions: _conflictActions,
      resolveOnCreate: false,
    );
    await repository.refresh();

    final result = await repository.actions.acceptConflict();

    expect(result, const Right<String, String>('Conflict'));
    expect(repository.currentValue, ['Existing', 'Conflict']);
    repository.dispose();
  });
}

typedef _TransactionsActions = ({
  Future<Either<String, String>> Function(String title) create,
});

Repository<List<String>, _TransactionsActions> _transactionsRepository(
  RepositoryClient client,
) {
  return Repository(
    client: client,
    endpoint: const .absolute('https://example.com/transactions'),
    fromJson: (json) => [json],
    actions: _transactionsActions,
    resolveOnCreate: false,
  );
}

_TransactionsActions _transactionsActions(
  RepositoryActionExecutor<List<String>> execute,
) {
  return (
    create: (title) => execute(
      run: (client) async {
        final response = await client.call(
          request: RepositoryHttpRequest(
            url: const .absolute('https://example.com/transactions'),
            method: RepositoryHttpMethod.post,
            body: {'title': title},
          ),
        );
        if (response.statusCode != 200) {
          return Left('HTTP ${response.statusCode}');
        }
        return Right(response.body);
      },
      update: (current, created) => [...?current, created],
    ),
  );
}

typedef _SessionActions = ({
  Future<Either<String, Unit>> Function() logout,
});

Repository<String?, _SessionActions> _sessionRepository(
  RepositoryClient client,
) {
  return Repository(
    client: client,
    endpoint: const .absolute('https://example.com/session'),
    fromJson: (json) => json,
    actions: _sessionActions,
    resolveOnCreate: false,
  );
}

_SessionActions _sessionActions(
  RepositoryActionExecutor<String?> execute,
) {
  return (
    logout: () => execute(
      run: (client) async {
        final response = await client.call(
          request: const RepositoryHttpRequest(
            url: .absolute('https://example.com/session'),
            method: RepositoryHttpMethod.delete,
          ),
        );
        if (response.statusCode != 200) {
          return Left('HTTP ${response.statusCode}');
        }
        return const Right(unit);
      },
      update: (_, _) => null,
    ),
  );
}

typedef _FailingActions = ({
  Future<Either<String, String>> Function() fail,
});

_FailingActions _failingActions(
  RepositoryActionExecutor<List<String>> execute,
) {
  return (
    fail: () => execute(
      run: (_) => const Left('failed'),
      update: (current, output) => [...?current, output],
    ),
  );
}

typedef _ConflictActions = ({
  Future<Either<String, String>> Function() acceptConflict,
});

_ConflictActions _conflictActions(
  RepositoryActionExecutor<List<String>> execute,
) {
  return (
    acceptConflict: () => execute(
      run: (client) async {
        final response = await client.call(
          request: const RepositoryHttpRequest(
            url: .absolute('https://example.com/items'),
            method: RepositoryHttpMethod.post,
          ),
        );
        if (response.statusCode != 409) {
          return Left('HTTP ${response.statusCode}');
        }
        return Right(response.body);
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
