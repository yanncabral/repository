import 'dart:convert';
import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart' as cupertino;
import 'package:http/http.dart' as http;
import 'package:repository/src/domain/exceptions/network_unavailable_exception.dart';
import 'package:repository/src/infra/repository_http_client.dart';

/// A repository HTTP adapter backed by `cupertino_http` on Apple platforms.
class CupertinoHttpRepositoryHttpClient extends RepositoryHttpClient {
  /// Creates a Cupertino HTTP adapter.
  const CupertinoHttpRepositoryHttpClient({this.tokenBuilder, super.mocks});

  /// Builds the bearer token attached to each request when available.
  final TokenBuilder? tokenBuilder;

  @override
  Future<RepositoryHttpResponse> call({
    required RepositoryHttpRequest request,
  }) async {
    final client = cupertino.CupertinoClient.fromSessionConfiguration(
      cupertino.URLSessionConfiguration.defaultSessionConfiguration(),
    );

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
        .get => await client.get(request.resolvedUrl, headers: headers),
        .post => await client.post(
          request.resolvedUrl,
          headers: headers,
          body: encodedBody,
        ),
        .patch => await client.patch(
          request.resolvedUrl,
          headers: headers,
          body: encodedBody,
        ),
        .put => await client.put(
          request.resolvedUrl,
          headers: headers,
          body: encodedBody,
        ),
        .delete => await client.delete(
          request.resolvedUrl,
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
    } finally {
      client.close();
    }
  }
}
