import 'package:dartz/dartz.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repository/repository.dart';

void main() {
  testWidgets('builder exposes typed actions and rebuilds after an action', (
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
    await repository.refresh();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepositoryBuilder(
          repository: repository,
          builder: (context, data, actions) {
            return GestureDetector(
              key: const Key('create'),
              onTap: actions.create.call,
              child: Text(data?.join(', ') ?? 'Loading'),
            );
          },
        ),
      ),
    );

    expect(find.text('Existing'), findsOneWidget);

    await tester.tap(find.byKey(const Key('create')));
    await tester.pump();

    expect(find.text('Existing, Created'), findsOneWidget);
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
