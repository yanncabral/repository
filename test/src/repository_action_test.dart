import 'package:repository/repository.dart';
import 'package:test/test.dart';

void main() {
  test(
    'repository action can execute a request and update repository data',
    () async {
      final transport = _ActionHttpClient();
      final repository = Repository<List<String>, _TransactionActions>(
        client: RepositoryClient(
          httpClient: transport,
          storage: _InMemoryCacheStorage(),
        ),
        endpoint: Uri.parse('https://example.com/transactions'),
        fromJson: (json) => [json],
        actions: _TransactionActions.new,
        resolveOnCreate: false,
      );
      await repository.refresh();

      final created = await repository.actions.createNewTransaction('New');

      expect(created, 'New');
      expect(repository.currentValue, ['Existing', 'New']);
      expect(transport.requests.last.method, RepositoryHttpMethod.post);
      repository.dispose();
    },
  );

  test('repository action without input can update nullable data', () async {
    final transport = _ActionHttpClient();
    final repository = Repository<String?, _SessionActions>(
      client: RepositoryClient(
        httpClient: transport,
        storage: _InMemoryCacheStorage(),
      ),
      endpoint: Uri.parse('https://example.com/session'),
      fromJson: (json) => json,
      actions: _SessionActions.new,
      resolveOnCreate: false,
    );
    await repository.refresh();

    await repository.actions.logout();

    expect(repository.currentValue, isNull);
    expect(transport.requests.last.method, RepositoryHttpMethod.delete);
    repository.dispose();
  });

  test('repository action does not update data when execution fails', () async {
    final repository = Repository<List<String>, _FailingActions>(
      client: RepositoryClient(
        httpClient: _ActionHttpClient(),
        storage: _InMemoryCacheStorage(),
      ),
      endpoint: Uri.parse('https://example.com/transactions'),
      fromJson: (json) => [json],
      actions: _FailingActions.new,
      resolveOnCreate: false,
    );
    await repository.refresh();

    await expectLater(repository.actions.fail(), throwsStateError);

    expect(repository.currentValue, ['Existing']);
    repository.dispose();
  });

  test(
    'repository action does not update data after an HTTP failure',
    () async {
      final repository = Repository<List<String>, _TransactionActions>(
        client: RepositoryClient(
          httpClient: _FailingActionHttpClient(),
          storage: _InMemoryCacheStorage(),
        ),
        endpoint: Uri.parse('https://example.com/transactions'),
        fromJson: (json) => [json],
        actions: _TransactionActions.new,
        resolveOnCreate: false,
      );
      await repository.refresh();

      await expectLater(
        repository.actions.createNewTransaction('Rejected'),
        throwsA(isA<UnexpectedStatusCodeException>()),
      );

      expect(repository.currentValue, ['Existing']);
      repository.dispose();
    },
  );

  test(
    'repository action can accept an intentional non-2xx response',
    () async {
      final repository = Repository<List<String>, _ConflictActions>(
        client: RepositoryClient(
          httpClient: _ConflictHttpClient(),
          storage: _InMemoryCacheStorage(),
        ),
        endpoint: Uri.parse('https://example.com/items'),
        fromJson: (json) => [json],
        actions: _ConflictActions.new,
        resolveOnCreate: false,
      );
      await repository.refresh();

      final conflict = await repository.actions.acceptConflict();

      expect(conflict, 'Conflict');
      expect(repository.currentValue, ['Existing', 'Conflict']);
      repository.dispose();
    },
  );
}

class _ConflictActions extends RepositoryActions<List<String>> {
  _ConflictActions(super.context);

  late final RepositoryAction0<String> acceptConflict = action0<String>(
    run: (context) async {
      final response = await context.request(
        RepositoryHttpRequest(
          url: Uri.parse('https://example.com/items'),
          method: RepositoryHttpMethod.post,
        ),
        successfulCondition: (response) => response.statusCode == 409,
      );
      return response.body;
    },
    update: (current, conflict) => [...?current, conflict],
  );
}

class _FailingActions extends RepositoryActions<List<String>> {
  _FailingActions(super.context);

  late final RepositoryAction0<String> fail = action0<String>(
    run: (_) => throw StateError('failed'),
    update: (current, output) => [...?current, output],
  );
}

class _SessionActions extends RepositoryActions<String?> {
  _SessionActions(super.context);

  late final RepositoryAction0<void> logout = action0<void>(
    run: (context) async {
      await context.request(
        RepositoryHttpRequest(
          url: Uri.parse('https://example.com/session'),
          method: RepositoryHttpMethod.delete,
        ),
      );
    },
    update: (_, _) => null,
  );
}

class _TransactionActions extends RepositoryActions<List<String>> {
  _TransactionActions(super.context);

  late final RepositoryAction<String, String> createNewTransaction =
      action<String, String>(
        run: (context, title) async {
          final response = await context.request(
            RepositoryHttpRequest(
              url: Uri.parse('https://example.com/transactions'),
              method: RepositoryHttpMethod.post,
              body: {'title': title},
            ),
          );
          return response.body;
        },
        update: (current, created) => [...?current, created],
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
