import 'dart:async';

import 'package:meta/meta.dart';
import 'package:repository/src/infra/repository_cache_storage.dart';
import 'package:rxdart/rxdart.dart';

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
  /// We're using a BehaviorSubject so we can get the last value.
  @protected
  final _controller = BehaviorSubject<Data>();

  // TODO(@dizyann): Set a default implementation for the cache storage.
  /// Monostate cache service to save data locally.
  static late RepositoryCacheStorage cache;

  /// Getter for the last value of the stream.
  /// Returns null if the stream is empty.
  Data? get value {
    try {
      return _controller.value;
    } on ValueStreamError {
      return null;
    }
  }

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

  /// Refreshes the repository ignoring cache.
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
  Future<void> update(Data Function(Data data) resolver) async {
    final lastData = _controller.value;
    final newData = resolver(lastData);
    _controller.add(newData);
    await refresh();
  }

  /// Adds data to the repository and refreshes it.
  /// If [refresh] is false, the repository will not be refreshed.
  /// This method is useful if you want to use Optimistic UI.
  /// You can add the new data to the repository and refresh in a row.
  Future<void> add({required Data data, bool refresh = true}) async {
    _controller.add(data);
    if (refresh) {
      await this.refresh();
    }
  }

  // Abstract methods and properties

  /// The key used to save the data in the cache.
  /// This key must be unique.
  /// If you have multiple repositories with the same key, the cache will be
  /// overwritten.
  @protected
  String get key;

  /// The stream of the repository.
  /// This stream will emit the data every time it changes.
  /// The data will be cached locally.
  /// The data will be refreshed every [autoRefreshInterval].
  /// The data will be refreshed when [refresh] is called.
  Stream<Data> get stream => _controller.stream;
}
