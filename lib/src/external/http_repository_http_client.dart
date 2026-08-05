import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:repository/src/domain/exceptions/network_unavailable_exception.dart';
import 'package:repository/src/infra/repository_http_client.dart';

final _client = http.Client();

/// {@template http_repository_http_client}
/// A [RepositoryHttpClient] that uses `http` package.
/// {@endtemplate}
class HttpRepositoryHttpClient extends RepositoryHttpClient {
  /// {@macro http_repository_http_client}
  const HttpRepositoryHttpClient({this.tokenBuilder, super.mocks});

  /// The token builder for this specific request.
  /// If provided, this will be used instead of the static tokenBuilder.
  final TokenBuilder? tokenBuilder;

  @override
  Future<RepositoryHttpResponse> call({
    required RepositoryHttpRequest request,
  }) async {
    try {
      final tokenWithBearerPrefix = await tokenBuilder?.call();

      final headers = Map<String, String>.from(request.headers);

      if (tokenWithBearerPrefix != null && tokenWithBearerPrefix.isNotEmpty) {
        headers['Authorization'] = 'Bearer $tokenWithBearerPrefix';
      }

      final encodedBody = request.body == null
          ? null
          : jsonEncode(request.body);

      final mockedResponse = super.findMock(request);

      if (mockedResponse != null) {
        return mockedResponse;
      }

      final response = switch (request.method) {
        .get => await _client.get(request.url, headers: headers),
        .post => await _client.post(
          request.url,
          headers: headers,
          body: encodedBody,
        ),
        .patch => await _client.patch(
          request.url,
          headers: headers,
          body: encodedBody,
        ),
        .put => await _client.put(
          request.url,
          headers: headers,
          body: encodedBody,
        ),
        .delete => await _client.delete(
          request.url,
          headers: headers,
          body: encodedBody,
        ),
      };

      return RepositoryHttpResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } on SocketException catch (e) {
      throw NetworkUnavailableException(e);
    } on http.ClientException catch (e) {
      throw NetworkUnavailableException(e);
    }
  }
}
