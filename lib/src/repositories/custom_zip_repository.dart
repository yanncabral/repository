import 'dart:async';

import 'package:repository/src/domain/entities/repository_state.dart';
import 'package:repository/src/repository.dart';
import 'package:rxdart/rxdart.dart';

/// {@template custom_zip_repository}
/// A [Repository] that combines multiple [Repository]s into one.
/// It takes a list of data of each repository and returns a single zipped data.
/// It is useful when you want to combine multiple repositories into one.
/// {@endtemplate}
abstract class CustomZipRepository<Data> extends Repository<Data> {
  /// {@macro custom_zip_repository}
  CustomZipRepository({
    super.autoRefreshInterval,
    super.resolveOnCreate,
  }) {
    ZipStream(repositories.map((e) => e.stream), _zipper).listen((data) {
      // Whenever any of the repositories emit new data, zip the data from
      // all repositories and emit it
      // to the stream of this repository.

      emit(data: data);
    });
  }

  Data _zipper(List<RepositoryState<dynamic>> states) {
    final values =
        states.map((e) => e.map(ready: (state) => state.data)).toList();

    return zipper(values);
  }

  /// Zips the data of each repository into a single data.
  Data zipper(List<dynamic> values);

  // It's just a misused character that is unlikely to be used in the data.
  // It's used to separate the data of each repository.
  // See more: https://stackoverflow.com/a/29811033
  static final _separator = String.fromCharCode(0x1d);

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
      repositories.map(
        (repository) => repository.resolve(),
      ),
    );

    return responses.join(_separator);
  }

  /// A list of repositories that will be zipped.
  List<Repository<dynamic>> get repositories;

  @override
  Data fromJson(String json) {
    throw UnimplementedError();
  }

  /// Gets the data from the cache, if it exists, and emits it to the stream.
  @override
  Future<Data?> hydrate({bool refreshAfter = true}) async {
    final stopwatch = Stopwatch()..start();

    await Future.wait(
      repositories.map(
        (repository) => repository.hydrate(refreshAfter: refreshAfter),
      ),
    );

    stopwatch.stop();
    Repository.logger.call(
      'Repository($name): '
      'hydrated in ${stopwatch.elapsedMilliseconds}ms',
    );
    return null;
  }

  @override
  String get name => repositories.map((e) => e.name).join('-');

  /// Refreshes the repository from remote datasource.
  @override
  Future<Data> refresh() async {
    final values = await Future.wait(
      repositories.map(
        (repository) => repository.refresh(),
      ),
    );

    final data = zipper(values);

    return data;
  }
}
