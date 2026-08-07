import 'dart:async';
import 'dart:io' show SocketException;

import 'package:repository/src/base_repository.dart';
import 'package:repository/src/domain/exceptions/network_unavailable_exception.dart';
import 'package:repository/src/domain/exceptions/unexpected_status_code_exception.dart';
import 'package:repository/src/infra/repository_http_client.dart';
import 'package:repository/src/infra/repository_logger.dart';

/// {@template http_repository}
/// A `Repository` that fetches data from an HTTP endpoint.
/// Can be used both directly (instanciation) and by inheritance.
///
/// Usage examples:
///
/// Direct usage:
/// ```dart
/// final repo = Repository<MyData, NoRepositoryActions>(
///   client: client,
///   endpoint: Uri.parse('https://api.example.com/data'),
///   fromJson: (json) => MyData.fromJson(json),
///   actions: () => (),
/// );
/// ```
///
/// By inheritance:
/// ```dart
/// class MyRepository
///     extends Repository<MyData, NoRepositoryActions> {
///   MyRepository()
///       : super(
///           client: client,
///           endpoint: Uri.parse('https://api.example.com/data'),
///         );
///
///   @override
///   final NoRepositoryActions actions = ();
///
///   @override
///   MyData fromJson(String json) => MyData.fromJson(json);
/// }
/// ```
/// {@endtemplate}
class Repository<Data, Actions> extends BaseRepository<Data, Actions>
    with MutatorRepositoryMixin<Data, Actions> {
  /// Creates an [Repository] that fetches data from an endpoint.
  ///
  /// The [endpoint] is the only required parameter when used directly.
  /// The [fromJson] function is optional and defaults to returning the JSON
  /// unchanged.
  /// The [autoRefreshInterval] is optional and defaults to null.
  /// The [resolveOnCreate] is optional and defaults to true.
  /// If [autoRefreshInterval] is not null, the repository will automatically
  /// refresh at the specified interval.
  Repository({
    required this.endpoint,
    super.client,
    super.actions,
    this._fromJson,
    this._shouldRetryCondition,
    super.resolveOnCreate,
    super.autoRefreshInterval,
    this.tag,
    this._name,
    this._mutate,
    this.method = RepositoryHttpMethod.get,
    super.dependencies,
  }) : super();

  /// HTTP method used when resolving this repository.
  final RepositoryHttpMethod method;
  final String? _name;
  final Data Function(String json)? _fromJson;
  final FutureOr<bool> Function(Exception exception)? _shouldRetryCondition;
  final Future<void> Function(Data data)? _mutate;

  /// The endpoint to fetch data from.
  /// This is the only required parameter.
  final Uri endpoint;

  /// The tag of the repository.
  /// This is used to identify the repository in the cache.
  /// If the tag is not null, the repository will use the tag to
  /// create unique keys for the cache.
  /// A common use case for this is when you want to cache for different
  /// users. In this case, you can use the user id (e.g. e-mail) as the tag.
  @override
  final String? tag;

  @override
  String get name => _name ?? endpoint.path.split('/').last;

  /// This function is called on resolve to
  /// get the data from the endpoint or cache.
  @override
  Data fromJson(String json) {
    if (_fromJson != null) {
      return _fromJson(json);
    }

    // Default implementation for direct usage
    return json as Data;
  }

  @override
  Future<String?> resolve() async {
    try {
      await super.hydratationCompleter.future;
      final request = RepositoryHttpRequest(url: endpoint, method: method);
      final response = await client.call(request: request);

      /// If the endpoint returns a 200, add the data to the stream
      /// and cache it
      if (successfulCondition(response.statusCode, response.body)) {
        final result = response.body;
        return result;
      } else {
        client.logger(
          'Repository($name): Failed to resolve [$endpoint]. '
          'status code: ${response.statusCode}',
        );
        final shouldThrow = await onErrorStatusCode(response.statusCode);
        if (shouldThrow) {
          throw UnexpectedStatusCodeException(
            sent: request,
            received: response,
          );
        } else {
          return response.body;
        }
      }
    } catch (exception) {
      /// if the user is offline, the request will fail.
      /// if [onSocketException] is not null, we call it.
      /// if [onSocketException] is null, we rethrow the exception.
      client.logger(
        'Repository($name): throws [${exception.runtimeType}].',
        level: RepositoryLoggingLevel.warning,
      );

      // if (exception is Exception) {
      //   await onSocketException(exception);
      // }

      rethrow;
    }
  }

  /// If the request fails with [SocketException], this callback will be called
  /// with the repository itself as an argument.
  /// This callback is useful for retrying the request.
  FutureOr<void> onSocketException(Exception exception) {
    throw exception;
  }

  /// Condition to determine if the endpoint returns a successful status code.
  /// The default condition is `statusCode == 200 || statusCode == 201`.
  /// If you want to change the condition, override this method.
  bool successfulCondition(int statusCode, dynamic body) {
    return statusCode == 200 || statusCode == 201;
  }

  /// Called when the endpoint returns an unsuccessful status code.
  /// See also [successfulCondition].
  /// Return if the error should be thrown.
  Future<bool> onErrorStatusCode(int statusCode) async {
    return true;
  }

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
  FutureOr<bool> shouldRetry(Exception exception) {
    return _shouldRetryCondition?.call(exception) ??
        exception is NetworkUnavailableException;
  }

  @override
  Future<void> mutate(Data data) async {
    if (_mutate != null) {
      return _mutate(data);
    } else {
      throw UnimplementedError('Mutate method not implemented');
    }
  }
}
