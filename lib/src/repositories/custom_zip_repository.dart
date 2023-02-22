import 'package:rxdart/streams.dart';

import '../repository.dart';

abstract class CustomZipRepository<Data> extends Repository<Data> {
  @override
  String get key => repositories.map((e) => e.key).join('-');

  @override
  Future<void> resolve({bool useCache = true, bool useRemote = true}) {
    return Future.wait(
      repositories.map(
        (repository) => repository.resolve(
          useCache: useCache,
          useRemote: useRemote,
        ),
      ),
    );
  }

  @override
  Stream<Data> get stream =>
      ZipStream(repositories.map((e) => e.stream), zipper);

  /// A list of repositories that will be zipped.
  List<Repository> get repositories;

  /// Takes a list of data of each repository and returns a single zipped data.
  Data zipper(List<dynamic> values);

  /// Creates a [CustomZipRepository] that combines multiple [Repository]s into one.
  CustomZipRepository({super.autoRefreshInterval, super.resolveOnCreate});
}
