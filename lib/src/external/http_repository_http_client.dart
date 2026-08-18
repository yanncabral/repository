import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:repository/src/domain/exceptions/network_unavailable_exception.dart';
import 'package:repository/src/external/repository_http_request_sender.dart';
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

      final mockedResponse = super.findMock(request);

      if (mockedResponse != null) {
        return mockedResponse;
      }

      return await sendRepositoryHttpRequest(
        client: _client,
        request: request,
        bearerToken: tokenWithBearerPrefix,
      );
    } on SocketException catch (e) {
      throw NetworkUnavailableException(e);
    } on http.ClientException catch (e) {
      throw NetworkUnavailableException(e);
    }
  }
}
