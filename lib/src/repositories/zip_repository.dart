import 'dart:async';

import 'package:repository/src/base_repository.dart';
import 'package:repository/src/domain/entities/repository_state.dart';
import 'package:repository/src/repository_action.dart';
import 'package:rxdart/rxdart.dart';

/// {@template zip_repository}
/// A [BaseRepository] that combines multiple [BaseRepository]s into one.
/// Can be used both directly (instantiation) and by inheritance.
///
/// Usage examples:
///
/// Direct usage:
/// ```dart
/// final repo = ZipRepository<CombinedData>(
///   client: client,
///   repositories: [repo1, repo2, repo3],
///   zipper: (values) => CombinedData.fromValues(values),
/// );
/// ```
///
/// By inheritance:
/// ```dart
/// class MyCombinedRepository extends ZipRepository<CombinedData> {
///   MyCombinedRepository()
///       : super(client: client, repositories: [repo1, repo2]);
///
///   @override
///   CombinedData zipper(List<dynamic> values) {
///     return CombinedData.fromValues(values);
///   }
/// }
/// ```
/// {@endtemplate}
class ZipRepository<Data> extends BaseRepository<Data, NoRepositoryActions> {
  /// Creates a repository that combines multiple [BaseRepository] instances.
  ///
  /// The [repositories] is the only required parameter when used directly.
  /// The [zipper] function can be overridden when using inheritance. It takes
  /// data from each repository and returns one combined value.
  ZipRepository({
    required this.repositories,
    super.client,
    this._zipper,
    super.autoRefreshInterval,
    this._name,
    super.resolveOnCreate,
  }) : super() {
    _combinedSubscription =
        CombineLatestStream(
          repositories.map((e) => e.stream.startWith(e.currentState)),
          _zipperInternal,
        ).listen((data) {
          unawaited(emit(data: data));
        });
  }

  final String? _name;
  final Data Function(List<dynamic> values)? _zipper;
  late final StreamSubscription<Data> _combinedSubscription;

  @override
  final NoRepositoryActions actions = ();

  /// The list of [BaseRepository]s to combine.
  /// The [zipper] function runs whenever a child repository emits a value.
  final List<BaseRepository<dynamic, dynamic>> repositories;

  Data _zipperInternal(List<RepositoryState<dynamic>> states) {
    final values = states
        .map((e) => e.map(ready: (state) => state.data, empty: (_) => null))
        .toList();

    return zipper(values);
  }

  /// Zips the data of each repository into a single data.
  /// This method can be overridden when using inheritance.
  Data zipper(List<dynamic> values) {
    if (_zipper != null) {
      return _zipper(values);
    }

    // Default implementation - should be overridden
    throw UnimplementedError(
      'Provide a zipper function or override the zipper method.',
    );
  }

  // It's just a misused character that is unlikely to be used in the data.
  // It's used to separate the data of each repository.
  // See more: https://stackoverflow.com/a/29811033
  static final _separator = String.fromCharCode(0x1d);

  @override
  String get name => _name ?? repositories.map((e) => e.name).join('-');

  @override
  String get key {
    return [
      ...repositories.map((r) => r.key),
      if (tag != null) tag,
    ].join('-').hashCode.toString();
  }

  @override
  Future<String> resolve() async {
    final responses = await Future.wait(
      repositories.map((repository) => repository.resolve()),
    );

    return responses.join(_separator);
  }

  @override
  Data fromJson(String json) {
    throw UnimplementedError();
  }

  /// Gets the data from the cache, if it exists, and emits it to the stream.
  @override
  Future<Data?> hydratate({bool refreshAfter = true}) async {
    final stopwatch = Stopwatch()..start();

    await Future.wait(
      repositories.map(
        (repository) => repository.hydratate(refreshAfter: refreshAfter),
      ),
    );

    stopwatch.stop();
    client.logger.call(
      'Repository($name): '
      'hydrated in ${stopwatch.elapsedMilliseconds}ms',
    );
    return null;
  }

  /// Refreshes the repository from remote datasource.
  @override
  Future<Data> refresh() async {
    final values = await Future.wait(
      repositories.map((repository) => repository.refresh()),
    );

    final data = zipper(values);

    return data;
  }

  @override
  void dispose() {
    unawaited(_combinedSubscription.cancel());
    super.dispose();
  }
}
