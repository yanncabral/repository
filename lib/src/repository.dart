import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:repository/src/domain/entities/data_source.dart';
import 'package:repository/src/domain/entities/repository_state.dart';
import 'package:repository/src/infra/repository_cache_storage.dart';
import 'package:repository/src/infra/repository_fiber.dart';
import 'package:repository/src/infra/repository_logger.dart';
import 'package:retry/retry.dart';
import 'package:rxdart/rxdart.dart';

/// A [Repository] that can be backpropagated to a remote source.
/// It is useful when you want to save data to a remote source
/// though a repository.
/// For example, you can use this mixin to save data to a remote API
/// when a user updates a profile.
mixin PropagatingRepositoryMixin<Data> on Repository<Data> {
  /// Propagates data to a remote source and updates the stream.
  Future<void> propagate(Data data);
}

/// A [Repository] is a class that holds data and provides a stream.
/// It can be used to fetch data from a remote source, cache it, and provide a
/// stream of that data.
abstract class Repository<Data> {
  /// If [resolveOnCreate] is true, the repository will resolve itself on
  /// creation.
  /// If [autoRefreshInterval] is not null, the repository will refresh itself
  /// every [autoRefreshInterval].
  Repository({
    this.autoRefreshInterval,
    bool resolveOnCreate = true,
  }) {
    hydrate(refreshAfter: resolveOnCreate);

    if (autoRefreshInterval != null) {
      timer = Timer.periodic(
        autoRefreshInterval!,
        (_) => refresh(),
      );
    }
  }

  /// The interval at which the repository will refresh itself.
  /// If null, the repository will not refresh itself.
  /// If not null, the repository will refresh itself
  /// every [autoRefreshInterval].
  final Duration? autoRefreshInterval;

  /// Internal timer used to refresh the repository.
  @protected
  Timer? timer;

  /// Stream controller to propagate data to the stream.
  /// It's using a BehaviorSubject so we can get the last value.
  @protected
  final _controller = BehaviorSubject<RepositoryState<Data>>();

  /// Monostate cache service to save data locally. It should be initialized
  /// before using any repository.
  static late RepositoryCacheStorage storage;

  /// Monostate logger service to log messages.
  static RepositoryLogger logger = const RepositoryLogger.dev();

  /// Getter for the last value of the stream.
  /// Returns null if the stream is empty.
  Data? get currentValue {
    return currentState.map(
      empty: (_) => null,
      ready: (state) => state.data,
    );
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
  final fiber = RepositoryFiber<Data>();

  /// Disposes the repository. You should call this method when you're done
  /// using the repository.
  /// This method will cancel the timer and close the stream.
  /// You should not use the repository after calling this method.
  void dispose() {
    timer?.cancel();
    _controller.close();
  }

  // Default methods

  /// Clears the cache.
  Future<void> clearCache() => storage.delete(key: key);

  /// Gets the data from the cache, if it exists, and emits it to the stream.
  Future<void> hydrate({bool refreshAfter = true}) async {
    try {
      final cachedDataString = await storage.read(key: key);

      if (cachedDataString != null) {
        final data = fromJson(json.decode(cachedDataString));

        await emit(data: data);
      }
    } on FormatException catch (e) {
      Repository.logger(
        'Error while hydrating repository $key: $e.'
        ' The cache will be cleared.',
      );

      await clearCache();
    } finally {
      if (refreshAfter) {
        await refresh();
      }
    }
  }

  /// Refreshes the repository from remote datasource.
  Future<Data> refresh() {
    // Run the refresh in a fiber to avoid multiple refreshes at the same time
    return retry(
      () => fiber.run(_refresh),
      retryIf: shouldRetry,
    );
  }

  /// Used to decide if the repository should retry after an error.
  @protected
  FutureOr<bool> shouldRetry(Exception exception) => true;

  Future<Data> _refresh() async {
    // Save the current time to calculate the time it took to refresh the
    final before = DateTime.now();
    // Log the refresh
    Repository.logger('Refreshing repository $key');
    // Resolve the data from the remote source
    final rawData = await resolve();
    // Decodes the raw data to the data that will be used in the stream
    final data = fromJson(json.decode(rawData));
    // Emit the data to the stream
    await emit(
      data: data,
      datasource: RepositoryDatasource.remote,
    );
    // Save the raw data in the cache
    await storage.write(key: key, value: rawData);
    // Log the time it took to refresh
    final after = DateTime.now();
    final timeSpent = after.difference(before);
    Repository.logger(
      'Repository $key refreshed in'
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
    await emit(
      data: newData,
      datasource: RepositoryDatasource.optimistic,
    );
    // It's just 'cause `this` is a getter, so the 'if' below will not work
    // if we don't use it as a local variable.
    final self = this;

    if (self is PropagatingRepositoryMixin<Data>) {
      await self.propagate(newData);
    }

    // Refresh the repository.
    await refresh();
  }

  /// Emits a new data to the repository.
  @protected
  Future<void> emit({
    required Data data,
    RepositoryDatasource datasource = RepositoryDatasource.local,
  }) async {
    _controller.add(
      RepositoryState.ready(
        data: data,
        source: datasource,
      ),
    );
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
  Future<String> resolve();

  /// Transforms the raw data from the remote source to the data that will be
  /// used in the stream.
  @protected
  Data fromJson(dynamic json);

  /// The key used to save the data in the cache.
  /// This key must be unique.
  /// If you have multiple repositories with the same key, the cache will be
  /// overwritten.
  @protected
  String get key => '$runtimeType(${tag ?? ''})';

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
}
