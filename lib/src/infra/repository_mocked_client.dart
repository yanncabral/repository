import 'dart:convert';

import 'package:repository/src/infra/repository_http_client.dart';

/// {@template repository_mocked_client}
/// A mocked implementation of a [RepositoryHttpClient]. It's used for testing
/// & developing purposes only.
/// {@endtemplate}
class RepositoryMockedClient extends RepositoryHttpClient {
  /// {@macro repository_mocked_client}
  RepositoryMockedClient({required this.responses});

  /// The responses that the client will return. It's a map where the key is the
  /// path of the request and the value is the response.
  final Map<String, dynamic> responses;

  @override
  Future<RepositoryHttpResponse> get({
    required RepositoryHttpRequest request,
  }) async {
    try {
      final response = responses[request.url.path];

      if (response != null) {
        return RepositoryHttpResponse(
          statusCode: 200,
          body: jsonEncode(response),
        );
      }

      return const RepositoryHttpResponse(
        statusCode: 404,
        body: '',
      );
    } catch (_) {
      return const RepositoryHttpResponse(
        statusCode: 404,
        body: '',
      );
    }
  }
}
