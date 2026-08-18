import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:meta/meta.dart';
import 'package:repository/src/domain/entities/data_source.dart';
import 'package:repository/src/domain/entities/repository_state.dart';
import 'package:repository/src/infra/repository_cache_storage.dart';
import 'package:repository/src/infra/repository_fiber.dart';
import 'package:repository/src/infra/repository_http_client.dart';
import 'package:repository/src/infra/repository_logger.dart';
import 'package:repository/src/repositories/http_repository.dart';
import 'package:repository/src/repository_action.dart';
import 'package:repository/src/repository_client.dart';
import 'package:repository/src/repository_interceptor.dart';
import 'package:repository/src/repository_url.dart';
import 'package:retry/retry.dart';
import 'package:rxdart/rxdart.dart';

/// A [BaseRepository] is a class that holds data and provides a stream.
/// It can be used to fetch data from a remote source, cache it, and provide a
/// stream of that data.
abstract class BaseRepository<Data, Actions> {
  /// If [resolveOnCreate] is true, the repository will resolve itself on
  /// creation.
  /// If [autoRefreshInterval] is not null, the repository will refresh itself
  /// every [autoRefreshInterval].
  BaseRepository({
    RepositoryClient? client,
    RepositoryActionsFactory<Data, Actions>? actions,
    this.autoRefreshInterval,
    bool resolveOnCreate = true,
    List<BaseRepository<dynamic, dynamic>>? dependencies,
  }) : client = client ?? _configuredClient(),
       _createActions = actions,
       dependencies = dependencies ?? <BaseRepository<dynamic, dynamic>>[] {
    track();

    unawaited(hydratate(refreshAfter: resolveOnCreate));

    if (autoRefreshInterval != null) {
      timer = Timer.periodic(autoRefreshInterval!, (_) {
        if (_controller.hasListener) {
          unawaited(refresh());
        }
      });
    }

    _listenToDependencies();
  }

  /// {@macro http_repository}
  factory BaseRepository.http({
    required RepositoryUrl endpoint,
    required RepositoryActionsFactory<Data, Actions> actions,
    RepositoryClient? client,
    Data Function(String json)? fromJson,
    FutureOr<bool> Function(Exception exception)? shouldRetryCondition,
    Duration? autoRefreshInterval,
    String? tag,
    bool resolveOnCreate = true,
    String? name,
  }) {
    return Repository<Data, Actions>(
      client: client,
      actions: actions,
      name: name,
      endpoint: endpoint,
      fromJson: fromJson,
      shouldRetryCondition: shouldRetryCondition,
      tag: tag,
      autoRefreshInterval: autoRefreshInterval,
      resolveOnCreate: resolveOnCreate,
    );
  }

  static RepositoryClient? _client;

  /// Configures the client used by repositories created without an override.
  static void config({
    required Uri baseUrl,
    required RepositoryHttpClient httpClient,
    required RepositoryCacheStorage storage,
    RepositoryLogger logger = const RepositoryLogger.dev(),
    List<RepositoryInterceptor> interceptors = const [],
  }) {
    _client = RepositoryClient(
      baseUrl: baseUrl,
      httpClient: httpClient,
      storage: storage,
      logger: logger,
      interceptors: interceptors,
    );
  }

  static RepositoryClient _configuredClient() {
    return _client ??
        (throw StateError(
          'BaseRepository.config must be called before creating a repository.',
        ));
  }

  /// Adds a repository that triggers a refresh when it emits ready data.
  void addDependency(BaseRepository<dynamic, dynamic> dependency) {
    _unlistenToDependencies();
    dependencies.add(dependency);
    _listenToDependencies();
  }

  final _subscriptions = <StreamSubscription<RepositoryState<dynamic>>>[];

  void _listenToDependencies() {
    _subscriptions.addAll(
      dependencies.map(
        (dependency) => dependency.stream.listen((state) {
          if (state is RepositoryStateReady) {
            unawaited(refresh());
          }
        }),
      ),
    );
  }

  void _unlistenToDependencies() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  /// List of all repositories in memory. It's useful for debugging.
  static final List<WeakReference<BaseRepository<dynamic, dynamic>>>
  repositories = [];

  /// Add the repository to the list of all repositories in memory if it's not
  /// already in the list.
  @protected
  void track() {
    final alreadyTracked = BaseRepository.repositories.any(
      (ref) => ref.target?.key == key,
    );

    if (!alreadyTracked) {
      BaseRepository.repositories.add(WeakReference(this));
    }
  }

  @override
  String toString() {
    return 'Repository($name, key: $key, type: $Data)';
  }

  /// Repository name used to log messages.
  String get name;

  /// The interval at which the repository will refresh itself.
  /// If null, the repository will not refresh itself.
  /// If not null, the repository will refresh itself
  /// every [autoRefreshInterval].
  final Duration? autoRefreshInterval;

  /// Get the current data of the repository
  /// if it's already resolved, otherwise resolve it.
  /// This method will not refresh the repository if it's already resolved.
  Future<Data?> currentValueOrResolve() async {
    return currentValue ?? await refresh();
  }

  /// Internal timer used to refresh the repository.
  @protected
  Timer? timer;

  /// Stream controller to propagate data to the stream.
  /// It's using a BehaviorSubject so we can get the last value.
  @protected
  final _controller = BehaviorSubject<RepositoryState<Data>>();

  /// Infrastructure shared by this repository.
  final RepositoryClient client;

  final RepositoryActionsFactory<Data, Actions>? _createActions;

  /// Typed operations exposed by this repository.
  late final Actions _actions =
      _createActions?.call(_executeAction) ??
      (throw StateError('This repository does not define actions.'));

  /// Typed operations exposed by this repository.
  Actions get actions => _actions;

  Future<Either<Failure, Output>> _executeAction<Failure, Output>({
    required RepositoryActionRun<Failure, Output> run,
    FutureOr<Data> Function(Data? current, Output output)? update,
  }) async {
    final result = await run(client);
    await result.fold<Future<void>>(
      (_) async {},
      (output) async {
        if (update != null) {
          await emit(
            data: await update(currentValue, output),
            datasource: RepositoryDatasource.optimistic,
          );
        }
      },
    );
    return result;
  }

  /// Getter for the last value of the stream.
  /// Returns null if the stream is empty.
  Data? get currentValue {
    return currentState.map(empty: (_) => null, ready: (state) => state.data);
  }

  /// Returns the current state of the repository.
  ///
  /// If the repository does not have any data, this method returns
  /// [RepositoryState.empty]. Otherwise, it returns a [RepositoryState]
  /// instance containing the current data.
  RepositoryState<Data> get currentState {
    final state = _controller.valueOrNull;

    if (state == null) {
      return RepositoryState<Data>.empty();
    } else {
      return state;
    }
  }

  /// The `Fiber` is used to avoid multiple refreshes at the same time.
  @protected
  final refreshFiber = RepositoryFiber<Data?>();

  /// The `Fiber` is used to avoid multiple hydratations at the same time.
  @protected
  final _hydratationFiber = RepositoryFiber<Data?>();

  /// Completes after the first cache hydration attempt.
  @protected
  final Completer<Data?> hydratationCompleter = Completer<Data?>();

  /// Disposes the repository. You should call this method when you're done
  /// using the repository.
  /// This method will cancel the timer and close the stream.
  /// You should not use the repository after calling this method.
  void dispose() {
    timer?.cancel();
    _unlistenToDependencies();
    unawaited(_controller.close());
  }

  // Default methods

  /// Clears the cache.
  Future<void> clearCache() => client.storage.delete(key: key);

  /// Gets the data from the cache, if it exists, and emits it to the stream.
  @visibleForTesting
  @protected
  Future<Data?> hydratate({bool refreshAfter = true}) async {
    return _hydratationFiber.run(name: name, () async {
      final stopwatch = Stopwatch()..start();
      try {
        final cachedDataString = await client.storage.read(key: key);

        if (cachedDataString != null) {
          final data = await _emitRawData(cachedDataString);
          if (!hydratationCompleter.isCompleted) {
            hydratationCompleter.complete(data);
          }
          return data;
        }
      } on FormatException catch (e) {
        client.logger.call(
          'Repository($name): Error while hydrating repository $key: $e.'
          ' The cache will be cleared.',
        );

        await clearCache();
      } finally {
        stopwatch.stop();
        client.logger.call(
          'Repository($name): '
          'hydrated in ${stopwatch.elapsedMilliseconds}ms',
        );

        if (!hydratationCompleter.isCompleted) {
          hydratationCompleter.complete(null);
        }

        if (refreshAfter) {
          await refresh();
        }
      }
      return null;
    });
  }

  Future<Data> _emitRawData(
    String rawData, {
    RepositoryDatasource datasource = RepositoryDatasource.local,
  }) async {
    final data = fromJson(rawData);
    await emit(data: data, datasource: datasource);

    // We do not need to persist if it comes from the cache or
    // if the data is optimistic.
    if (datasource == RepositoryDatasource.remote) {
      await client.storage.write(key: key, value: rawData);
    }

    return data;
  }

  /// Refreshes the repository from remote datasource.
  Future<Data?> refresh() async {
    return retry(
      // Run the refresh in a fiber to avoid multiple refreshes at the same time
      () => refreshFiber.run(name: name, _refresh),
      retryIf: shouldRetry,
      onRetry: (exception) {
        client.logger('Repository($name): Retrying refresh...');
      },
    );
  }

  /// Used to decide if the repository should retry after an error.
  @protected
  FutureOr<bool> shouldRetry(Exception exception) => true;

  Future<Data?> _refresh() async {
    // Save the current time to calculate the time it took to refresh the
    final before = DateTime.now();
    // Resolve the data from the remote source
    final rawData = await resolve();
    // Decodes the raw data to the data that will be used in the stream
    // Emit the data to the stream and persist
    Data? data;
    if (rawData != null) {
      data = await _emitRawData(
        rawData,
        datasource: RepositoryDatasource.remote,
      );
    }
    // Log the time it took to refresh
    final after = DateTime.now();
    final timeSpent = after.difference(before);
    client.logger(
      'Repository($name): refreshed in'
      ' ${timeSpent.inMilliseconds}ms',
    );

    // Return the new data
    return data;
  }

  /// Updates the current data and refresh the repository.
  /// The [resolver] function takes the current data and returns the new data.
  /// The new data will be added to the stream and the repository will be
  /// refreshed.
  /// This method is useful if you want to use Optimistic UI.
  /// You can update the data to the repository and refresh in a row.
  Future<void> update(Data Function(Data? data) resolver) async {
    // Call the resolver function to get the new data.
    final newData = resolver.call(currentValue);
    // Add the new data to the repository without refreshing yet.
    await emit(data: newData, datasource: RepositoryDatasource.optimistic);

    // Refresh the repository.
    await refresh();
  }

  /// Emits a new data to the repository.
  @protected
  Future<void> emit({
    required Data data,
    RepositoryDatasource datasource = RepositoryDatasource.local,
  }) async {
    client.logger('Emitting data to repository $name: $data');
    _controller.add(RepositoryState.ready(data: data, source: datasource));
  }

  /// Clears the cache and emits an empty state to the repository stream.
  Future<void> clear() async {
    _controller.add(const RepositoryState.empty());
    await clearCache();
  }

  // Abstract methods and properties

  /// Gets the data from the remote source and returns the raw data.
  /// The returned string will be saved in the cache and decoded using
  /// [fromJson].
  @protected
  Future<String?> resolve();

  /// Transforms the raw data from the remote source to the data that will be
  /// used in the stream.
  @protected
  Data fromJson(String json);

  /// The key used to save the data in the cache.
  /// This key must be unique.
  /// If you have multiple repositories with the same key, the cache will be
  /// overwritten.
  @protected
  String get key {
    return (runtimeType.toString().hashCode + (tag?.hashCode ?? 0)).toString();
  }

  /// The tag used to differ cache from same key repositories. It's commonly
  /// used to build the `key` property.
  @protected
  String? get tag => null;

  /// The stream of the repository.
  /// This stream will emit the data every time it changes.
  /// The data will be cached locally.
  /// The data will be refreshed every [autoRefreshInterval].
  /// The data will be refreshed when [refresh] is called.
  late final Stream<RepositoryState<Data>> stream = _controller.stream;

  /// Emits only repository data, or `null` while the repository is empty.
  late final Stream<Data?> dataStream = stream.map(
    (state) => state.map(ready: (state) => state.data, empty: (_) => null),
  );

  /// Repositories whose ready emissions invalidate this repository.
  final List<BaseRepository<dynamic, dynamic>> dependencies;
}
