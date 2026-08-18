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

  test('HttpRepositoryHttpClient sends the default JSON Content-Type', () {
    return _withObservedRequest((url, observedRequest) async {
      await const HttpRepositoryHttpClient()(
        request: RepositoryHttpRequest(
          url: RepositoryUrl.absolute(url.toString()),
          method: RepositoryHttpMethod.post,
          body: const {'name': 'Ada'},
        ),
      );

      final received = await observedRequest;
      expect(
        received.headers.value(HttpHeaders.contentTypeHeader),
        ContentType.json.mimeType,
      );
    });
  });

  test(
    'HttpRepositoryHttpClient normalizes asynchronous network errors',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final unavailableUrl = Uri.parse(
        'http://${server.address.host}:${server.port}/resource',
      );
      await server.close(force: true);

      await expectLater(
        const HttpRepositoryHttpClient()(
          request: RepositoryHttpRequest(
            url: RepositoryUrl.absolute(unavailableUrl.toString()),
          ),
        ),
        throwsA(isA<NetworkUnavailableException>()),
      );
    },
  );
}

Future<void> _withObservedRequest(
  Future<void> Function(Uri url, Future<HttpRequest> observedRequest) body,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final observedRequest = server.first;
  final responseTask = observedRequest.then((request) async {
    await request.drain<void>();
    request.response
      ..statusCode = HttpStatus.ok
      ..write('{}');
    await request.response.close();
    return request;
  });

  try {
    await body(
      Uri.parse('http://${server.address.host}:${server.port}/resource'),
      responseTask,
    );
  } finally {
    await server.close(force: true);
  }
}
