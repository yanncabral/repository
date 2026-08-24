import 'dart:async';
import 'dart:io' show HttpClientRequest;

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:repository/src/repository_url.dart';

/// A type alias for bearer token String.
/// Notice that this is just the token, without the `Bearer` prefix.
typedef BearerToken = String;

/// Builds the bearer token used to authenticate an HTTP request.
typedef TokenBuilder = FutureOr<BearerToken?> Function();

/// {@template repository_http_client}
/// Abstract class for HTTP client to be used in http `Repositories`.
/// You can use this class to create your own HTTP client,
/// or just use the default one.
/// {@endtemplate}
abstract class RepositoryHttpClient {
  /// {@macro repository_http_client}
  const RepositoryHttpClient({this.mocks});

  /// Responses returned without reaching the transport.
  final Map<RepositoryHttpMockedRequest, RepositoryHttpResponse>? mocks;

  /// Makes a HTTP `get` request using [HttpClientRequest].
  Future<RepositoryHttpResponse> call({required RepositoryHttpRequest request});

  /// Releases resources owned by this client.
  ///
  /// Implementations that do not own resources may keep the default no-op.
  void close() {}

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

/// HTTP methods supported by repository requests.
enum RepositoryHttpMethod {
  /// An HTTP GET request.
  get,

  /// An HTTP POST request.
  post,

  /// An HTTP PUT request.
  put,

  /// An HTTP DELETE request.
  delete,

  /// An HTTP PATCH request.
  patch,
}

/// {@template repository_http_request}
/// This is used by [RepositoryHttpClient] to make HTTP requests.
/// You can use this class to create your own HTTP client,
/// or just use the default one.
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
  final RepositoryUrl url;

  /// The absolute URL resolved by `RepositoryClient` before transport.
  Uri get resolvedUrl => url.resolve(null);

  /// Returns a copy whose URL has been resolved against [baseUrl].
  RepositoryHttpRequest resolveUrl(Uri? baseUrl) {
    return RepositoryHttpRequest(
      url: RepositoryUrl.absolute(url.resolve(baseUrl).toString()),
      method: method,
      body: body,
      headers: headers,
    );
  }

  /// Returns a copy with selected fields replaced.
  RepositoryHttpRequest copyWith({
    RepositoryUrl? url,
    RepositoryHttpMethod? method,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) {
    return RepositoryHttpRequest(
      url: url ?? this.url,
      method: method ?? this.method,
      body: body ?? this.body,
      headers: headers ?? this.headers,
    );
  }

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

/// Identifies a mocked request by URL and method.
class RepositoryHttpMockedRequest extends Equatable {
  /// Creates a mocked request identifier.
  const RepositoryHttpMockedRequest({required this.url, required this.method});

  /// The url of the request.
  final RepositoryUrl url;

  /// The method of the request.
  final RepositoryHttpMethod method;

  @override
  List<Object?> get props => [url, method];
}
