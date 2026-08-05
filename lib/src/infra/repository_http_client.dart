import 'dart:io' show HttpClientRequest;

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

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
  const RepositoryHttpClient({this.mocks});

  final Map<RepositoryHttpMockedRequest, RepositoryHttpResponse>? mocks;

  /// Makes a HTTP `get` request using [HttpClientRequest].
  Future<RepositoryHttpResponse> call({required RepositoryHttpRequest request});

  /// Handle mocked requests if needed.
  @protected
  RepositoryHttpResponse? findMock(RepositoryHttpRequest request) {
    final mock = RepositoryHttpMockedRequest(
      url: request.url,
      method: request.method,
    );

    return mocks?[mock];
  }
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

/// A type alias for the HTTP method.
enum RepositoryHttpMethod { get, post, put, delete, patch }

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
    this.method = RepositoryHttpMethod.get,
    this.body = const {},
    this.headers = const {},
  });

  /// The url of the request.
  final Uri url;

  /// The method of the request.
  final RepositoryHttpMethod method;

  /// The headers of the request.
  final Map<String, String> headers;

  /// The body of the request.
  final Map<String, dynamic>? body;

  @override
  String toString() {
    return 'RepositoryHttpRequest{url: $url, headers: $headers}';
  }
}

class RepositoryHttpMockedRequest extends Equatable {
  const RepositoryHttpMockedRequest({required this.url, required this.method});

  /// The url of the request.
  final Uri url;

  /// The method of the request.
  final RepositoryHttpMethod method;

  @override
  List<Object?> get props => [url, method];
}
