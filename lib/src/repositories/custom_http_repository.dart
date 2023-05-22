import 'dart:async';
import 'dart:io';

import 'package:repository/repository.dart';
import 'package:repository/src/domain/exceptions/unexpected_status_code_exception.dart';
import 'package:repository/src/infra/repository_logger.dart';

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
    this.accessTokenBuilder,
  });

  /// A callback that returns the access token.
  Future<String> Function()? accessTokenBuilder;

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
  FutureOr<void> onSocketException(Exception exception) {
    throw exception;
  }

  /// The endpoint to fetch data from.
  Uri get endpoint;

  // Dependencies

  /// The http client used to fetch data from the endpoint.
  /// This is a monostate, so it will be shared across all instances of
  /// [CustomHttpRepository] and `HttpRepository`.
  static const client = HttpRepositoryHttpClient();

  @override
  Future<String> resolve() async {
    try {
      final request = RepositoryHttpRequest(url: endpoint);
      final response = await client.get(request: request);

      /// If the endpoint returns a 200, add the data to the stream
      /// and cache it
      if (successfulCondition(response.statusCode, response.body)) {
        final result = response.body;

        return result;
      } else {
        Repository.logger(
          'Repository($name): Failed to resolve [$endpoint]. '
          'status code: ${response.statusCode}',
        );
        await onErrorStatusCode(response.statusCode);

        throw UnexpectedStatusCodeException(
          sent: request,
          received: response,
        );
      }
    } catch (exception) {
      /// if the user is offline, the request will fail.
      /// if [onSocketException] is not null, we call it.
      /// if [onSocketException] is null, we rethrow the exception.
      Repository.logger(
        'Repository($name): throws [${exception.runtimeType}].',
        level: RepositoryLoggingLevel.warning,
      );

      if (exception is Exception) {
        await onSocketException(exception);
      }

      rethrow;
    }
  }

  @override
  String get name => endpoint.path.split('/').last;

  /// Condition to determine if the endpoint returns a successful status code.
  /// The default condition is `statusCode >= 200 && statusCode < 300`.
  /// If you want to change the condition, override this method.
  bool successfulCondition(int statusCode, dynamic body) {
    return statusCode == 200 || statusCode == 201;
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
      return endpoint.toString();
    } else {
      return '$tag,$endpoint';
    }
  }

  @override
  FutureOr<bool> shouldRetry(Exception exception) =>
      exception is SocketException;
}
