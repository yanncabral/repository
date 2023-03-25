import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:repository/src/external/http_repository_http_client.dart';
import 'package:repository/src/infra/repository_http_client.dart';
import 'package:repository/src/infra/repository_logger.dart';
import 'package:repository/src/repository.dart';

/// {@template custom_http_repository}
/// A [CustomHttpRepository] is a [Repository] that fetches data from an Http
/// endpoint. It differs from `HttpRepository` in that it allows you to
/// customize the request.
/// {@endtemplate}
abstract class CustomHttpRepository<Data> extends Repository<Data> {
  /// {@macro custom_http_repository}
  CustomHttpRepository({
    super.autoRefreshInterval,
    super.resolveOnCreate,
    this.tag,
  });

  /// The tag of the repository.
  /// This is used to identify the repository in the cache.
  /// If the tag is not null, the repository will use the tag to
  /// create unique keys for the cache.
  /// A commom use case for this is when you want to cache for different
  /// users. In this case, you can use the user id (e.g. e-mail) as the tag.
  @override
  final String? tag;

  /// If the request fails with [SocketException], this callback will be called
  /// with the repository itself as an argument.
  /// This callback is useful for retrying the request.
  FutureOr<void> onSocketException(Repository<Data> repository);

  /// The endpoint to fetch data from.
  Uri get endpoint;

  /// Decode json to Data
  Data fromJson(dynamic json);

  // Dependencies

  /// The http client used to fetch data from the endpoint.
  /// This is a monostate, so it will be shared across all instances of
  /// [CustomHttpRepository] and `HttpRepository`.
  static RepositoryHttpClient client = HttpRepositoryHttpClient();

  /// Resolves the repository by fetching data from the endpoint.
  /// If [useCache] is true, the repository
  /// will try to fetch data from the cache.
  /// If the cache is not empty, the repository will add the data from the cache
  /// to the stream.
  ///
  /// If [useCache] is false, the repository will fetch data from the endpoint
  /// and add the data to the stream.
  ///
  /// If the endpoint returns a 400 or 500, the repository will not add anything
  /// to the stream.
  /// If the endpoint returns a 200, but the data is invalid, the repository
  /// will not add anything to the stream.
  /// If the endpoint returns a 200, but the data is valid, the repository will
  /// add the data to the stream and cache it.
  @override
  Future<void> resolve({bool useCache = true, bool useRemote = true}) async {
    Repository.logger('Resolving [$key].');

    /// Try to fetch data from the cache.
    if (useCache) {
      final cached = await Repository.cache.read(key: key);
      if (cached != null) {
        try {
          /// Add the data from the cache to the stream.
          /// We also use [unawaited] to prevent the future from being awaited.
          /// See [Repository.add].
          /// See also [Repository.refresh].
          unawaited(emit(data: fromJson(jsonDecode(cached))));
        } on FormatException catch (_) {
          /// If the data is invalid, clear the cache.
          /// In this case, we don't need to use [unawaited] because
          /// we want to ensure that the cache is cleared before we
          /// fetch data from the endpoint.
          Repository.logger(
            'Failed to decode cached data from key [$key].'
            ' Clearing cache.',
            level: RepositoryLoggingLevel.warning,
          );
          await Repository.cache.delete(key: key);
        }
      }
    }

    /// Fetch data from the endpoint
    if (useRemote) {
      try {
        final response = await client.get(
          request: RepositoryHttpRequest(
            url: endpoint,
          ),
        );

        /// If the endpoint returns a 200, add the data to the stream
        /// and cache it
        if (successfulCondition(response.statusCode, response.body)) {
          final result = response.body;

          Repository.logger('Adding [$result]. to [$key]');

          /// Add the data to the stream and
          /// cache the data. We can do this in parallel.
          await Future.wait([
            emit(data: fromJson(result)),
            Repository.cache.write(
              key: key,
              value: jsonEncode(result),
            ),
          ]);
        } else {
          Repository.logger(
            'Failed to resolve [$endpoint]. '
            'status code: ${response.statusCode}',
          );
          await onErrorStatusCode(response.statusCode);
        }
      } on FormatException catch (e) {
        Repository.logger(
          'Failed to decode remote data from [${e.source}].',
          level: RepositoryLoggingLevel.error,
        );
        rethrow;
      } on SocketException {
        /// if the user is offline, the request will fail.
        /// if [onSocketException] is not null, we call it.
        /// if [onSocketException] is null, we rethrow the exception.
        Repository.logger(
          '$runtimeType throws [SocketException].'
          ' Calling [onSocketException].',
          level: RepositoryLoggingLevel.warning,
        );

        await onSocketException(this);
        rethrow;
      }
    }
  }

  /// Condition to determine if the endpoint returns a successful status code.
  /// The default condition is `statusCode >= 200 && statusCode < 300`.
  /// If you want to change the condition, override this method.
  bool successfulCondition(int statusCode, dynamic body) {
    return statusCode >= 200 && statusCode < 300;
  }

  /// Called when the endpoint returns a unsuccessful status code.
  /// See also [successfulCondition].
  Future<void> onErrorStatusCode(int statusCode) async {}

  @override
  String get key {
    /// We combine the `tag` and the `endpoint` to create a unique key
    /// and we use the md5 hash to create a unique but "shorter" key.
    /// When the `tag` is null, we use only the `endpoint` as the key.

    if (tag == null) {
      return md5.convert(endpoint.toString().codeUnits).toString();
    } else {
      return md5.convert('$tag,$endpoint'.codeUnits).toString();
    }
  }
}
