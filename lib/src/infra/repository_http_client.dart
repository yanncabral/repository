import 'dart:io';

/// A type alias for bearer token String.
/// Notice that this is just the token, without the `Bearer` prefix.
typedef BearerToken = String;

/// {@template repository_http_client}
/// Abstract class for HTTP client to be used in http `Repositories`.
/// You can use this class to create your own HTTP client,
/// or just use the default one.
/// {@endtemplate}
abstract class RepositoryHttpClient {
  /// {@macro repository_http_client}
  const RepositoryHttpClient();

  /// Makes a HTTP `get` request using [HttpClientRequest].
  Future<RepositoryHttpResponse> get({
    required RepositoryHttpRequest request,
  });
}

/// {@template repository_http_response}
/// A class that represents the response from a HTTP request.
/// {@endtemplate}
class RepositoryHttpResponse {
  /// {@macro repository_http_response}
  const RepositoryHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  /// The status code of the response.
  final int statusCode;

  /// The headers of the response.
  final Map<String, String> headers;

  /// The body of the response.
  final String body;

  @override
  String toString() {
    return 'RepositoryHttpResponse{'
        'statusCode: $statusCode, '
        'headers: $headers, body: $body'
        '}';
  }
}

/// {@template repository_http_request}
/// This is used by [RepositoryHttpClient] to make HTTP requests.
/// You can use this class to create your own HTTP client,
/// or just use the default one.
/// But notice that Repositories will only use `GET` method.
/// {@endtemplate}
class RepositoryHttpRequest {
  /// {@macro repository_http_request}
  const RepositoryHttpRequest({
    required this.url,
    this.headers = const {},
    this.bearerTokenBuilder,
  });

  /// The url of the request.
  final Uri url;

  /// The headers of the request.
  final Map<String, String> headers;

  /// Builds the bearer token if it's needed.
  final BearerToken Function()? bearerTokenBuilder;

  @override
  String toString() {
    return 'RepositoryHttpRequest{url: $url, headers: $headers}';
  }
}
