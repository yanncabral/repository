import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:repository/src/infra/repository_http_client.dart';
import 'package:repository/src/infra/repository_logger.dart';
import 'package:repository/src/repository.dart';

/// {@template http_repository_http_client}
/// A [RepositoryHttpClient] that uses `http` package.
/// {@endtemplate}
class HttpRepositoryHttpClient implements RepositoryHttpClient {
  /// {@macro http_repository_http_client}
  HttpRepositoryHttpClient({http.Client? client})
      : client = client ?? http.Client();

  /// The HTTP client used to make requests.
  final http.Client client;

  @override
  Future<RepositoryHttpResponse> get({
    required RepositoryHttpRequest request,
  }) async {
    try {
      final response = await client.get(
        request.url,
        headers: request.headers,
      );

      final repositoryResponse = RepositoryHttpResponse(
        statusCode: response.statusCode,
        body: utf8.decode(response.bodyBytes),
        headers: response.headers,
      );

      return repositoryResponse;
    } on http.ClientException {
      Repository.logger(
        'ClientException: ${request.url}',
        level: RepositoryLoggingLevel.error,
      );

      rethrow;
    }
  }
}
