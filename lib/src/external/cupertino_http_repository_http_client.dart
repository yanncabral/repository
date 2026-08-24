import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart' as cupertino;
import 'package:http/http.dart' as http;
import 'package:repository/src/domain/exceptions/network_unavailable_exception.dart';
import 'package:repository/src/external/repository_http_request_sender.dart';
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

      final mockedResponse = super.findMock(request);

      if (mockedResponse != null) {
        return mockedResponse;
      }

      return await sendRepositoryHttpRequest(
        client: client,
        request: request,
        bearerToken: tokenWithBearerPrefix,
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
