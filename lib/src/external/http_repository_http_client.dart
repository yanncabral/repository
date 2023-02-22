import 'package:http/http.dart' as http;
import 'package:repository/repository.dart';

import 'package:repository/src/infra/repository_http_client.dart';
import 'package:repository/src/infra/repository_logger.dart';

final _client = http.Client();

/// {@template http_repository_http_client}
/// A [RepositoryHttpClient] that uses `http` package.
/// {@endtemplate}
class HttpRepositoryHttpClient implements RepositoryHttpClient {
  @override
  Future<RepositoryHttpResponse> get({
    required RepositoryHttpRequest request,
  }) async {
    try {
      final response = await _client.get(
        request.url,
        headers: request.headers,
      );

      return RepositoryHttpResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } on http.ClientException {
      Repository.logger(
        'ClientException: ${request.url}',
        level: RepositoryLoggingLevel.error,
      );

      rethrow;
    }
  }
}
