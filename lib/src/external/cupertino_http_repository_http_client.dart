import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:repository/src/base_repository.dart';
import 'package:repository/src/domain/exceptions/network_unavailable_exception.dart';
import 'package:repository/src/infra/repository_http_client.dart';
import 'package:repository/src/infra/repository_logger.dart';
import 'package:cupertino_http/cupertino_http.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

typedef BearerToken = String;
typedef TokenBuilder = FutureOr<BearerToken?> Function();

class CupertinoHttpRepositoryHttpClient extends RepositoryHttpClient {
  const CupertinoHttpRepositoryHttpClient({this.tokenBuilder, super.mocks});

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

      final metadata = <String, String>{
        'method': request.method.name.toUpperCase(),
        'url': request.url.toString(),
        'headers': _hideJwt(headers.toString()),
        'body': encodedBody ?? '',
      };

      BaseRepository.logger('[REQUEST] $metadata');

      final mockedResponse = super.findMock(request);

      if (mockedResponse != null) {
        return mockedResponse;
      }

      final response = switch (request.method) {
        .get => await client.get(request.url, headers: headers),
        .post => await client.post(
          request.url,
          headers: headers,
          body: encodedBody,
        ),
        .patch => await client.patch(
          request.url,
          headers: headers,
          body: encodedBody,
        ),
        .put => await client.put(
          request.url,
          headers: headers,
          body: encodedBody,
        ),
        .delete => await client.delete(
          request.url,
          headers: headers,
          body: encodedBody,
        ),
      };

      BaseRepository.logger(
        '[RESPONSE] ${response.statusCode} ${_hideJwt(response.body)}]',
      );

      return RepositoryHttpResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } on SocketException catch (e) {
      BaseRepository.logger(
        'SocketException (Cupertino): ${request.url}',
        level: RepositoryLoggingLevel.error,
      );
      throw NetworkUnavailableException(e);
    } on http.ClientException catch (e) {
      BaseRepository.logger(
        'ClientException (Cupertino): ${request.url}',
        level: RepositoryLoggingLevel.error,
      );
      throw NetworkUnavailableException(e);
    } finally {
      client.close();
    }
  }

  static final RegExp _jwtRegex = RegExp(r'((?:[\\w-]*\.){2}[\w-]*)');
  String _hideJwt(String raw) {
    var result = raw;
    if (kDebugMode) {
      return raw;
    }
    for (final match in _jwtRegex.allMatches(raw)) {
      result = result.replaceRange(match.start, match.end, 'hidden');
    }
    return result;
  }
}
