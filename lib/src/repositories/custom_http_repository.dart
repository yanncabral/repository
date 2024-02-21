import 'dart:async';
import 'dart:io';

import 'package:http/http.dart';
import 'package:repository/src/domain/exceptions/unexpected_status_code_exception.dart';
import 'package:repository/src/external/http_repository_http_client.dart';
import 'package:repository/src/infra/repository_http_client.dart';
import 'package:repository/src/infra/repository_logger.dart';
import 'package:repository/src/repository.dart';

/// A type alias for bearer token String.
/// Notice that this is just the token, without the `Bearer` prefix.
typedef RepositorySession = ({String userId, String bearerToken});

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
    this.accessTokenBuilder,
    this.headers,
    this.queryParameters,
    RepositoryHttpClient? client,
  }) : client = client ?? HttpRepositoryHttpClient();

  @override
  String get key => endpoint.toString();

  /// A function that returns the access token to be used in the request.
  Future<String> Function()? accessTokenBuilder;

  /// If the request fails with [SocketException], this callback will be called
  /// with the repository itself as an argument.
  /// This callback is useful for retrying the request.
  FutureOr<void> onSocketException(Exception exception) {
    throw exception;
  }

  /// The endpoint to fetch data from.
  Uri get endpoint;

  /// The headers to be used in the request.
  final Map<String, String>? headers;

  /// The query parameters to be used in the request.
  Map<String, dynamic>? queryParameters;

  /// Sets the query parameters to be used in the request.
  void setQueryParameters(Map<String, dynamic> params) {
    queryParameters = params;
    refresh();
  }

  /// The http client used to fetch data from the endpoint.
  final RepositoryHttpClient client;

  @override
  Future<({String body, String? tag})> resolve() async {
    try {
      final session = await CustomHttpRepository.sessionBuilder?.call();

      final url = queryParameters != null
          ? endpoint.replace(queryParameters: queryParameters)
          : endpoint;

      final request = RepositoryHttpRequest(
        url: url,
        headers: {
          if (session case RepositorySession(:final String bearerToken))
            'Authorization': bearerToken,
          ...?headers,
        },
      );

      final response = await client.get(request: request);

      /// If the endpoint returns a 200, add the data to the stream
      /// and cache it
      if (successfulCondition(response.statusCode, response.body)) {
        return (body: response.body, tag: session?.userId);
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

      if (exception is SocketException) {
        await onSocketException(exception);
      }

      rethrow;
    }
  }

  @override
  String? get name => endpoint.path.split('/').last;

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
  FutureOr<bool> shouldRetry(Exception exception) =>
      exception is SocketException || exception is ClientException;

  /// Sets the [sessionBuilder] to be used by all [CustomHttpRepository].
  static SessionBuilder? sessionBuilder;
}

/// A type alias for a function that returns a [RepositorySession].
typedef SessionBuilder = Future<RepositorySession?> Function();
