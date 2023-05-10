import 'package:collection/collection.dart';
import 'package:repository/src/repository.dart';

/// {@template custom_zip_repository}
/// A [Repository] that combines multiple [Repository]s into one.
/// It takes a list of data of each repository and returns a single zipped data.
/// It is useful when you want to combine multiple repositories into one.
/// {@endtemplate}
abstract class CustomZipRepository<Data> extends Repository<Data> {
  /// {@macro custom_zip_repository}
  CustomZipRepository({super.autoRefreshInterval, super.resolveOnCreate});

  static final _separator = String.fromCharCode(0x1d);

  @override
  String get key => repositories.map((r) => r.key).join('-');

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

  /// Takes a list of data of each repository and returns a single zipped data.
  Data zipper(List<dynamic> values);

  @override
  Data fromJson(covariant String json) {
    /// Split the json into a list of jsons
    final jsons = json.split(_separator);

    /// Make sure the number of values in the json matches the number of
    /// repositories
    assert(
      jsons.length == repositories.length,
      'The number of values in the json does not '
      'match the number of repositories',
    );

    /// Create a list of futures that decodes the jsons into data.
    final responses = IterableZip([repositories, jsons]).map((packed) {
      final repository = packed[0] as Repository<dynamic>;
      final json = packed[1] as String;

      return repository.fromJson(json);
    });

    /// Zip the responses into a single data
    return zipper(responses.toList());
  }
}
