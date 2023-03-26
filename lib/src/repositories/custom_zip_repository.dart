import 'package:repository/src/domain/entities/data_source.dart';
import 'package:repository/src/domain/entities/states.dart';
import 'package:repository/src/repository.dart';
import 'package:rxdart/streams.dart';

/// {@template custom_zip_repository}
/// A [Repository] that combines multiple [Repository]s into one.
/// It takes a list of data of each repository and returns a single zipped data.
/// It is useful when you want to combine multiple repositories into one.
/// {@endtemplate}
abstract class CustomZipRepository<Data> extends Repository<Data> {
  /// {@macro custom_zip_repository}
  CustomZipRepository({super.autoRefreshInterval, super.resolveOnCreate});

  @override
  String get key => repositories.map((r) => r.key).join('-');

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
  Stream<RepositoryState<Data>> get stream => _stream;

  late final Stream<RepositoryState<Data>> _stream = ZipStream(
    repositories.map((e) => e.stream),
    (values) {
      return RepositoryState.ready(
        data: zipper(values),
        source: RepositoryDatasource.remote,
      );
    },
  ).asBroadcastStream();

  /// A list of repositories that will be zipped.
  List<Repository<dynamic>> get repositories;

  /// Takes a list of data of each repository and returns a single zipped data.
  Data zipper(List<dynamic> values);
}
