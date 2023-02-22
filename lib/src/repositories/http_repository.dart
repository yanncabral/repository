import 'dart:async';

import 'package:repository/src/repositories/custom_http_repository.dart';
import 'package:repository/src/repository.dart';

/// {@template http_repository}
/// A `Repository` that fetches data from an endpoint. It is a wrapper around
/// [CustomHttpRepository] that uses the default `RepositoryHttpClient`.
/// It is recommended to use [CustomHttpRepository] instead of this class if you
/// need to customize the request.
/// {@endtemplate}
class HttpRepository<Data> extends CustomHttpRepository<Data> {
  /// Creates a [HttpRepository] that fetches data from an endpoint.
  /// The [endpoint] is the only required parameter.
  /// The [fromJson] function is optional
  ///  and defaults to returning the json as is.
  /// The [autoRefreshInterval] is optional and defaults to null.
  /// The `resolveOnCreate` is optional and defaults to true.
  /// If [autoRefreshInterval] is not null, the repository will automatically
  HttpRepository({
    required this.endpoint,
    Data Function(dynamic json)? fromJson,
    FutureOr<void> Function(Repository<Data> repository)? onSocketException,
    super.resolveOnCreate,
    super.autoRefreshInterval,
    super.tag,
  })  : _fromJson = fromJson ?? ((json) => json as Data),
        _onSocketException = onSocketException;

  /// The endpoint to fetch the data from.
  /// This is the only required parameter.
  @override
  final Uri endpoint;

  /// Private field that holds the [fromJson] callback.
  final Data Function(dynamic json) _fromJson;

  /// Private field that holds the [onSocketException] callback.
  final FutureOr<void> Function(Repository<Data> repository)?
      _onSocketException;

  /// This function is called on resolve to
  /// get the data from the endpoint or cache.
  @override
  Data fromJson(dynamic json) {
    return _fromJson(json);
  }

  @override
  FutureOr<void> onSocketException(Repository<Data> repository) {
    return _onSocketException?.call(repository);
  }
}
