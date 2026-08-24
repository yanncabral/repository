import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:repository/repository.dart';
import 'package:repository/src/external/repository_http_request_sender.dart';

void main() {
  group('repository HTTP request sender', () {
    test('defaults Content-Type to JSON when the request has a body', () async {
      late http.Request sentRequest;
      final transport = MockClient((request) async {
        sentRequest = request;
        return http.Response('{}', HttpStatus.ok);
      });
      final originalHeaders = <String, String>{'X-Request': 'value'};
      final request = RepositoryHttpRequest(
        url: const RepositoryUrl.absolute('https://example.com/resource'),
        method: RepositoryHttpMethod.post,
        body: const {'name': 'Ada'},
        headers: originalHeaders,
      );

      await sendRepositoryHttpRequest(client: transport, request: request);

      expect(sentRequest.headers['Content-Type'], ContentType.json.mimeType);
      expect(originalHeaders, {'X-Request': 'value'});
      expect(request.headers, {'X-Request': 'value'});
    });

    test('does not add Content-Type when the request body is null', () async {
      late http.Request sentRequest;
      final transport = MockClient((request) async {
        sentRequest = request;
        return http.Response('{}', HttpStatus.ok);
      });

      await sendRepositoryHttpRequest(
        client: transport,
        request: const RepositoryHttpRequest(
          url: RepositoryUrl.absolute('https://example.com/resource'),
          body: null,
        ),
      );

      expect(
        sentRequest.headers.keys.map((header) => header.toLowerCase()),
        isNot(contains(HttpHeaders.contentTypeHeader)),
      );
    });

    test('does not add Content-Type to GET with its default body', () async {
      late http.Request sentRequest;
      final transport = MockClient((request) async {
        sentRequest = request;
        return http.Response('{}', HttpStatus.ok);
      });

      await sendRepositoryHttpRequest(
        client: transport,
        request: const RepositoryHttpRequest(
          url: RepositoryUrl.absolute('https://example.com/resource'),
        ),
      );

      expect(
        sentRequest.headers.keys.map((header) => header.toLowerCase()),
        isNot(contains(HttpHeaders.contentTypeHeader)),
      );
    });

    test('preserves a case-insensitive explicit Content-Type', () async {
      late http.Request sentRequest;
      final transport = MockClient((request) async {
        sentRequest = request;
        return http.Response('{}', HttpStatus.ok);
      });

      await sendRepositoryHttpRequest(
        client: transport,
        request: const RepositoryHttpRequest(
          url: RepositoryUrl.absolute('https://example.com/resource'),
          method: RepositoryHttpMethod.post,
          body: {'name': 'Ada'},
          headers: {'content-type': 'application/merge-patch+json'},
        ),
      );

      expect(
        sentRequest.headers['content-type'],
        'application/merge-patch+json',
      );
      expect(
        sentRequest.headers.keys.where(
          (header) => header.toLowerCase() == HttpHeaders.contentTypeHeader,
        ),
        hasLength(1),
      );
    });
  });

  test(
    'HttpRepositoryHttpClient sends the default JSON Content-Type',
    () async {
      late http.Request sentRequest;
      final transport = MockClient((request) async {
        sentRequest = request;
        return http.Response('{}', HttpStatus.ok);
      });
      final client = HttpRepositoryHttpClient(client: transport);

      await client(
        request: const RepositoryHttpRequest(
          url: RepositoryUrl.absolute('https://example.com/resource'),
          method: RepositoryHttpMethod.post,
          body: {'name': 'Ada'},
        ),
      );

      expect(sentRequest.headers['Content-Type'], ContentType.json.mimeType);
    },
  );

  test(
    'HttpRepositoryHttpClient normalizes asynchronous network errors',
    () async {
      final transport = MockClient((_) async {
        throw http.ClientException('connection failed');
      });
      final client = HttpRepositoryHttpClient(client: transport);

      await expectLater(
        client(
          request: const RepositoryHttpRequest(
            url: RepositoryUrl.absolute('https://example.com/resource'),
          ),
        ),
        throwsA(isA<NetworkUnavailableException>()),
      );
    },
  );

  test('HttpRepositoryHttpClient normalizes socket errors', () async {
    final transport = MockClient((_) async {
      throw const SocketException('connection failed');
    });
    final client = HttpRepositoryHttpClient(client: transport);

    await expectLater(
      client(
        request: const RepositoryHttpRequest(
          url: RepositoryUrl.absolute('https://example.com/resource'),
        ),
      ),
      throwsA(isA<NetworkUnavailableException>()),
    );
  });

  test('keeps an injected client caller-owned by default', () {
    final transport = _CloseTrackingClient();
    HttpRepositoryHttpClient(client: transport).close();

    expect(transport.isClosed, isFalse);
  });

  test('closes an injected client when ownership is transferred', () {
    final transport = _CloseTrackingClient();
    HttpRepositoryHttpClient(
      client: transport,
      closeClient: true,
    ).close();

    expect(transport.isClosed, isTrue);
  });
}

class _CloseTrackingClient extends http.BaseClient {
  bool isClosed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(const Stream.empty(), HttpStatus.ok);
  }

  @override
  void close() {
    isClosed = true;
  }
}
