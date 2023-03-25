import 'dart:async';

import 'package:meta/meta.dart';
import 'package:repository/src/infra/repository_cache_storage.dart';
import 'package:repository/src/infra/repository_logger.dart';
import 'package:rxdart/rxdart.dart';

/// A [Repository] that can be backpropagated to a remote source.
/// It is useful when you want to save data to a remote source
/// though a repository.
/// For example, you can use this mixin to save data to a remote API
/// when a user updates a profile.
mixin PropagatingRepositoryMixin<Data> on Repository<Data> {
  /// Converts data to a JSON compatible format.
  dynamic toJson(Data data);

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
    if (resolveOnCreate) {
      resolve();
    }

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
  final _controller = BehaviorSubject<Data>();

  /// Monostate cache service to save data locally.
  static RepositoryCacheStorage cache =
      const RepositoryCacheStorage.sharedPreferences();

  /// Monostate logger service to log messages.
  static RepositoryLogger logger = const RepositoryLogger.dev();

  /// Getter for the last value of the stream.
  /// Returns null if the stream is empty.
  Data? currentValue;

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
  Future<void> clearCache() => cache.delete(key: key);

  /// Refreshes the repository from remote datasource, ignoring cache.
  Future<void> refresh() => resolve(useCache: false);

  /// Resolves the repository.
  /// If [useCache] is true, the repository will try to fetch data
  /// from the cache.
  /// If the cache is not empty, the repository will add the data from the cache
  /// to the stream.
  Future<void> resolve({bool useCache = true, bool useRemote = true});

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
    await emit(data: newData);

    // It's just `this` is a getter and the if below will not work
    // if we don't use it as a local variable.
    final self = this;

    if (self is PropagatingRepositoryMixin<Data>) {
      await self.propagate(newData);
    }

    // Refresh the repository.
    await refresh();
  }

  /// Emits a new data to the repository.
  Future<void> emit({required Data data}) async {
    _controller.add(data);
    currentValue = data;
  }

  // Abstract methods and properties

  /// The key used to save the data in the cache.
  /// This key must be unique.
  /// If you have multiple repositories with the same key, the cache will be
  /// overwritten.
  @protected
  String get key;

  /// The tag used to differ cache from same key repositories. It's commonly
  /// used to build the `key` property.
  @protected
  String? get tag;

  /// The stream of the repository.
  /// This stream will emit the data every time it changes.
  /// The data will be cached locally.
  /// The data will be refreshed every [autoRefreshInterval].
  /// The data will be refreshed when [refresh] is called.
  late final Stream<Data> stream = _controller.stream;
}
