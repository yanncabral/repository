import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:repository/src/infra/repository_http_client.dart';

const _contentTypeHeader = 'content-type';

/// Encodes and sends [request] through an `http` package [client].
///
/// This is shared by the standard and Cupertino repository HTTP adapters.
Future<RepositoryHttpResponse> sendRepositoryHttpRequest({
  required http.Client client,
  required RepositoryHttpRequest request,
  String? bearerToken,
}) async {
  final headers = Map<String, String>.from(request.headers);

  final sendsBody =
      request.method != RepositoryHttpMethod.get && request.body != null;

  if (sendsBody &&
      !headers.keys.any(
        (header) => header.toLowerCase() == _contentTypeHeader,
      )) {
    headers['Content-Type'] = 'application/json';
  }

  if (bearerToken != null && bearerToken.isNotEmpty) {
    headers['Authorization'] = 'Bearer $bearerToken';
  }

  final encodedBody = sendsBody ? jsonEncode(request.body) : null;
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
}
