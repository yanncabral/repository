import 'dart:async';

import 'package:repository/repository.dart';
import 'package:test/test.dart';

void main() {
  group('BaseRepository lifecycle', () {
    test('captures errors from initial hydration', () async {
      final uncaughtErrors = <Object>[];
      final logger = _RecordingLogger();

      await runZonedGuarded(() async {
        final repository = _TestRepository(
          client: _client(
            storage: _TestStorage(
              onRead: () async => throw Exception('cache unavailable'),
            ),
            logger: logger,
          ),
          resolveOnCreate: false,
        );

        await Future<void>.delayed(Duration.zero);
        repository.dispose();
        await Future<void>.delayed(Duration.zero);
      }, (error, _) => uncaughtErrors.add(error));

      expect(uncaughtErrors, isEmpty);
      expect(logger.messages, contains(contains('initial hydration failed')));
    });

    test('captures errors from automatic refresh and emits error', () async {
      final refreshAttempted = Completer<void>();
      final uncaughtErrors = <Object>[];
      late _TestRepository repository;

      await runZonedGuarded(() async {
        repository = _TestRepository(
          client: _client(),
          resolveOnCreate: false,
          autoRefreshInterval: const Duration(milliseconds: 1),
          resolver: () async {
            if (!refreshAttempted.isCompleted) {
              refreshAttempted.complete();
            }
            throw Exception('refresh unavailable');
          },
        );
        final subscription = repository.stream.listen((_) {});

        await refreshAttempted.future;
        await Future<void>.delayed(Duration.zero);
        repository.dispose();
        await subscription.cancel();
      }, (error, _) => uncaughtErrors.add(error));

      expect(uncaughtErrors, isEmpty);
      expect(repository.currentState, isA<RepositoryStateError<int>>());
    });

    test('captures errors from dependency-triggered refresh', () async {
      final refreshAttempted = Completer<void>();
      final uncaughtErrors = <Object>[];
      late _TestRepository source;
      late _TestRepository dependent;

      await runZonedGuarded(() async {
        source = _TestRepository(
          client: _client(),
          resolveOnCreate: false,
        );
        dependent = _TestRepository(
          client: _client(),
          resolveOnCreate: false,
          dependencies: [source],
          resolver: () async {
            refreshAttempted.complete();
            throw Exception('dependency refresh unavailable');
          },
        );

        await source.refresh();
        await refreshAttempted.future;
        await Future<void>.delayed(Duration.zero);
        source.dispose();
        dependent.dispose();
      }, (error, _) => uncaughtErrors.add(error));

      expect(uncaughtErrors, isEmpty);
      expect(dependent.currentState, isA<RepositoryStateError<int>>());
    });

    test(
      'does not emit or persist an in-flight refresh after dispose',
      () async {
        final response = Completer<String?>();
        final storage = _TestStorage();
        final repository = _TestRepository(
          client: _client(storage: storage),
          resolveOnCreate: false,
          resolver: () => response.future,
        );
        final states = <RepositoryState<int>>[];
        final subscription = repository.stream.listen(states.add);

        final refresh = repository.refresh();
        await Future<void>.delayed(Duration.zero);
        repository.dispose();
        response.complete('42');

        expect(await refresh, isNull);
        await subscription.cancel();
        expect(states, isEmpty);
        expect(storage.writes, isEmpty);
      },
    );

    test('does not persist when disposed after emitting remote data', () async {
      final storage = _TestStorage();
      final emitStarted = Completer<void>();
      final finishEmit = Completer<void>();
      final repository = _DelayedEmitRepository(
        client: _client(storage: storage),
        emitStarted: emitStarted,
        finishEmit: finishEmit,
      );

      final refresh = repository.refresh();
      await emitStarted.future;
      repository.dispose();
      finishEmit.complete();

      expect(await refresh, 42);
      expect(storage.writes, isEmpty);
    });

    test('does not evaluate optimistic updates after dispose', () async {
      final repository = _TestRepository(
        client: _client(),
        resolveOnCreate: false,
      );
      var resolverCalled = false;
      repository.dispose();

      await repository.update((_) {
        resolverCalled = true;
        return 42;
      });

      expect(resolverCalled, isFalse);
    });

    test('does not emit cached data after dispose', () async {
      final cachedValue = Completer<String?>();
      final readStarted = Completer<void>();
      final repository = _TestRepository(
        client: _client(
          storage: _TestStorage(
            onRead: () {
              readStarted.complete();
              return cachedValue.future;
            },
          ),
        ),
        resolveOnCreate: false,
      );
      final states = <RepositoryState<int>>[];
      final subscription = repository.stream.listen(states.add);

      await readStarted.future;
      repository.dispose();
      cachedValue.complete('42');
      await Future<void>.delayed(Duration.zero);

      await subscription.cancel();
      expect(states, isEmpty);
      expect(repository.currentState, isA<RepositoryStatePending<int>>());
    });

    test('emits error when refresh fails without previous content', () async {
      final failure = Exception('unavailable');
      final repository = _TestRepository(
        client: _client(),
        resolveOnCreate: false,
        resolver: () async => throw failure,
      );

      await expectLater(repository.refresh(), throwsA(same(failure)));

      expect(
        repository.currentState,
        isA<RepositoryStateError<int>>().having(
          (state) => state.error,
          'error',
          same(failure),
        ),
      );
      repository.dispose();
    });

    test('preserves ready content when background refresh fails', () async {
      var shouldFail = false;
      final repository = _TestRepository(
        client: _client(),
        resolveOnCreate: false,
        resolver: () async {
          if (shouldFail) {
            throw Exception('unavailable');
          }
          return '42';
        },
      );

      await repository.refresh();
      final readyState = repository.currentState;
      shouldFail = true;
      await expectLater(repository.refresh(), throwsException);

      expect(repository.currentState, same(readyState));
      expect(repository.currentValue, 42);
      repository.dispose();
    });
  });
}

RepositoryClient _client({
  _TestStorage? storage,
  RepositoryLogger? logger,
}) {
  return RepositoryClient(
    httpClient: const _UnusedHttpClient(),
    storage: storage ?? _TestStorage(),
    logger: logger ?? _RecordingLogger(),
  );
}

class _TestRepository extends BaseRepository<int, NoRepositoryActions> {
  _TestRepository({
    required super.client,
    required super.resolveOnCreate,
    super.autoRefreshInterval,
    super.dependencies,
    Future<String?> Function()? resolver,
  }) : _resolver = resolver ?? (() async => '42'),
       super(actions: (_) => ());

  final Future<String?> Function() _resolver;

  @override
  String get key => 'test-repository';

  @override
  String get name => 'test-repository';

  @override
  int fromJson(String json) => int.parse(json);

  @override
  Future<String?> resolve() => _resolver();

  @override
  bool shouldRetry(Exception exception) => false;
}

class _DelayedEmitRepository extends _TestRepository {
  _DelayedEmitRepository({
    required super.client,
    required this.emitStarted,
    required this.finishEmit,
  }) : super(resolveOnCreate: false);

  final Completer<void> emitStarted;
  final Completer<void> finishEmit;

  @override
  Future<void> emit({
    required int data,
    RepositoryDatasource datasource = RepositoryDatasource.local,
  }) async {
    await super.emit(data: data, datasource: datasource);
    emitStarted.complete();
    await finishEmit.future;
  }
}

class _TestStorage extends RepositoryCacheStorage {
  _TestStorage({this.onRead});

  final Future<String?> Function()? onRead;
  final Map<String, String> values = {};
  final List<(String, String)> writes = [];

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async {
    return onRead?.call() ?? values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    writes.add((key, value));
    values[key] = value;
  }
}

class _UnusedHttpClient extends RepositoryHttpClient {
  const _UnusedHttpClient();

  @override
  Future<RepositoryHttpResponse> call({
    required RepositoryHttpRequest request,
  }) {
    throw UnimplementedError();
  }
}

class _RecordingLogger extends RepositoryLogger {
  _RecordingLogger() : super(level: RepositoryLoggingLevel.debug);

  final messages = <String>[];

  @override
  void call(
    String message, {
    RepositoryLoggingLevel level = RepositoryLoggingLevel.info,
  }) {
    messages.add(message);
  }
}
