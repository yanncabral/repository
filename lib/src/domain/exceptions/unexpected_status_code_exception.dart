import 'package:repository/src/infra/repository_http_client.dart';

/// {@template http_repository}
/// Exception thrown when the endpoint returns a unsuccessful status code.
/// {@endtemplate}
class UnexpectedStatusCodeException implements Exception {
  /// {@macro http_repository}
  const UnexpectedStatusCodeException({
    required this.sent,
    required this.received,
  });

  /// The request that was sent to the endpoint.
  final RepositoryHttpRequest sent;

  /// The response that was received from the endpoint.
  final RepositoryHttpResponse received;

  @override
  String toString() {
    return 'UnexpectedStatusCodeException{'
        'request: $sent, '
        'response: $received'
        '}';
  }
}
