import 'package:dartz/dartz.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repository/repository.dart';

void main() {
  testWidgets('builder exposes the complete pending repository state', (
    tester,
  ) async {
    final repository = Repository<List<String>, _ItemActions>(
      client: RepositoryClient(
        httpClient: const _ItemHttpClient(),
        storage: _InMemoryCacheStorage(),
      ),
      endpoint: const .absolute('https://example.com/items'),
      fromJson: (json) => [json],
      actions: _itemActions,
      resolveOnCreate: false,
    );
    RepositoryState<List<String>>? receivedState;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepositoryBuilder(
          repository: repository,
          builder: (context, state, actions) {
            receivedState = state;
            return const Text('Pending');
          },
        ),
      ),
    );

    expect(receivedState, const RepositoryState<List<String>>.pending());
    expect(receivedState, isA<RepositoryStatePending<List<String>>>());
    repository.dispose();
  });

  testWidgets('builder exposes typed actions and rebuilds after an action', (
    tester,
  ) async {
    final receivedStates = <RepositoryState<List<String>>>[];
    final repository = Repository<List<String>, _ItemActions>(
      client: RepositoryClient(
        httpClient: const _ItemHttpClient(),
        storage: _InMemoryCacheStorage(),
      ),
      endpoint: const .absolute('https://example.com/items'),
      fromJson: (json) => [json],
      actions: _itemActions,
      resolveOnCreate: false,
    );
    await repository.refresh();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepositoryBuilder(
          repository: repository,
          builder: (context, state, actions) {
            receivedStates.add(state);
            return GestureDetector(
              key: const Key('create'),
              onTap: actions.create.call,
              child: Text(
                switch (state) {
                  RepositoryStateReady(data: final data) => data.join(', '),
                  RepositoryStatePending() => 'Loading',
                  RepositoryStateError(error: final error) => 'Error: $error',
                },
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Existing'), findsOneWidget);
    expect(
      receivedStates.last,
      isA<RepositoryStateReady<List<String>>>()
          .having((state) => state.data, 'data', ['Existing'])
          .having(
            (state) => state.source,
            'source',
            RepositoryDatasource.remote,
          ),
    );

    await tester.tap(find.byKey(const Key('create')));
    await tester.pump();

    expect(find.text('Existing, Created'), findsOneWidget);
    expect(
      receivedStates.last,
      isA<RepositoryStateReady<List<String>>>()
          .having((state) => state.data, 'data', ['Existing', 'Created'])
          .having(
            (state) => state.source,
            'source',
            RepositoryDatasource.optimistic,
          ),
    );
    repository.dispose();
  });
}

typedef _ItemActions = ({
  Future<Either<Never, String>> Function() create,
});

_ItemActions _itemActions(RepositoryActionExecutor<List<String>> execute) {
  return (
    create: () => execute(
      run: (_) => const Right('Created'),
      update: (current, created) => [...?current, created],
    ),
  );
}

class _ItemHttpClient extends RepositoryHttpClient {
  const _ItemHttpClient();

  @override
  Future<RepositoryHttpResponse> call({
    required RepositoryHttpRequest request,
  }) async {
    return const RepositoryHttpResponse(
      statusCode: 200,
      headers: {},
      body: 'Existing',
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
