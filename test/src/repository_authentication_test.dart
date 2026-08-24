import 'dart:async';
import 'dart:convert';

import 'package:repository/repository.dart';
import 'package:test/test.dart';

void main() {
  test('password maps its own body and decodes a bearer session', () async {
    final sessionStorage = InMemoryRepositorySessionStorage();
    final transport = _RoutingHttpClient((request) async {
      if (request.resolvedUrl.path == '/login') {
        return _jsonResponse({
          'session': {'token': 'access', 'renewal': 'refresh'},
        });
      }
      return const RepositoryHttpResponse(
        statusCode: 200,
        headers: {},
        body: 'private',
      );
    });
    final environment = BaseRepository.config(
      baseUrl: Uri.parse('https://api.example.com'),
      httpClient: transport,
      storage: _CacheStorage(),
      sessionManager: .bearer(
        storage: sessionStorage,
        authentication: (auth) => (
          password: auth.password(
            endpoint: const .relative('/login'),
            body: (input) => {
              'email': input.username,
              'secret': input.password,
            },
            decode: (json) {
              final session = json['session']! as Map<String, dynamic>;
              return .new(
                accessToken: session['token']! as String,
                refreshToken: session['renewal'] as String?,
              );
            },
          ),
        ),
      ),
    );

    final result = await environment.auth.password.signIn(
      username: 'user@example.com',
      password: 'secret',
    );
    final response = await environment.client.call(
      request: const RepositoryHttpRequest(url: .relative('/private')),
    );

    expect(result.isRight(), isTrue);
    expect(transport.requests.first.body, {
      'email': 'user@example.com',
      'secret': 'secret',
    });
    expect(transport.requests.last.headers['Authorization'], 'Bearer access');
    expect(response.body, 'private');
    expect(await sessionStorage.read(), contains('access'));
  });

  test('refresh decoder rotates tokens and refresh is single-flight', () async {
    final refreshStarted = Completer<void>();
    final releaseRefresh = Completer<void>();
    var privateCalls = 0;
    var refreshCalls = 0;
    final transport = _RoutingHttpClient((request) async {
      switch (request.resolvedUrl.path) {
        case '/login':
          return _jsonResponse({
            'access_token': 'old-access',
            'refresh_token': 'old-refresh',
          });
        case '/refresh':
          refreshCalls++;
          if (!refreshStarted.isCompleted) {
            refreshStarted.complete();
          }
          await releaseRefresh.future;
          return _jsonResponse({'access_token': 'new-access'});
        default:
          privateCalls++;
          return RepositoryHttpResponse(
            statusCode: request.headers['Authorization'] == 'Bearer new-access'
                ? 200
                : 401,
            headers: const {},
            body: '',
          );
      }
    });
    final environment = BaseRepository.config(
      baseUrl: Uri.parse('https://api.example.com'),
      httpClient: transport,
      storage: _CacheStorage(),
      sessionManager: .bearer(
        refresh: .post(
          endpoint: const .relative('/refresh'),
          body: (input) => {
            'refresh_token': input.session.refreshToken,
          },
          decode: (json, current) => .new(
            accessToken: json['access_token']! as String,
            refreshToken: current.refreshToken,
          ),
        ),
        authentication: (auth) => (
          password: auth.password(
            endpoint: const .relative('/login'),
            body: (input) => {
              'username': input.username,
              'password': input.password,
            },
            decode: (json) => .new(
              accessToken: json['access_token']! as String,
              refreshToken: json['refresh_token'] as String?,
            ),
          ),
        ),
      ),
    );
    await environment.auth.password.signIn(username: 'user', password: 'pass');

    final first = environment.client.call(
      request: const RepositoryHttpRequest(url: .relative('/first')),
    );
    final second = environment.client.call(
      request: const RepositoryHttpRequest(url: .relative('/second')),
    );
    await refreshStarted.future;
    releaseRefresh.complete();
    final responses = await Future.wait([first, second]);

    expect(responses.map((response) => response.statusCode), everyElement(200));
    expect(refreshCalls, 1);
    expect(privateCalls, 4);
    expect(
      (environment.session.current! as RepositorySessionBearer).refreshToken,
      'old-refresh',
    );
  });

  test('signOut always deletes the local bearer session', () async {
    final sessionStorage = InMemoryRepositorySessionStorage();
    final environment = BaseRepository.config(
      baseUrl: Uri.parse('https://api.example.com'),
      httpClient: _RoutingHttpClient(
        (_) async => _jsonResponse({
          'access_token': 'access',
        }),
      ),
      storage: _CacheStorage(),
      sessionManager: .bearer(
        storage: sessionStorage,
        authentication: (auth) => (
          password: auth.password(
            endpoint: const .relative('/login'),
            body: (input) => {
              'username': input.username,
              'password': input.password,
            },
            decode: (json) => .new(
              accessToken: json['access_token']! as String,
            ),
          ),
        ),
      ),
    );
    await environment.auth.password.signIn(username: 'user', password: 'pass');

    final result = await environment.session.signOut();

    expect(result.isRight(), isTrue);
    expect(environment.session.current, isNull);
    expect(await sessionStorage.read(), isNull);
  });

  test('cookies use their own session type and cookie jar', () async {
    final jar = _CookieJar();
    final transport = _RoutingHttpClient((request) async {
      if (request.resolvedUrl.path == '/login') {
        return _jsonResponse(
          {'user_id': '42'},
          headers: const {'set-cookie': 'session=cookie-value'},
        );
      }
      return const RepositoryHttpResponse(
        statusCode: 200,
        headers: {},
        body: '',
      );
    });
    final environment = BaseRepository.config(
      baseUrl: Uri.parse('https://api.example.com'),
      httpClient: transport,
      storage: _CacheStorage(),
      sessionManager: .cookies(
        cookieJar: jar,
        authentication: (auth) => (
          password: auth.password(
            endpoint: const .relative('/login'),
            body: (input) => {
              'username': input.username,
              'password': input.password,
            },
            decode: (json) => .new(identity: json['user_id']! as String),
          ),
        ),
      ),
    );
    await environment.auth.password.signIn(username: 'user', password: 'pass');

    await environment.client.call(
      request: const RepositoryHttpRequest(url: .relative('/private')),
    );

    expect(environment.session.current, isA<RepositorySessionCookies>());
    expect(transport.requests.last.headers['Cookie'], 'session=cookie-value');
    await environment.session.signOut();
    expect(jar.hasCookies, isFalse);
  });

  test(
    'authenticated repositories wait for login and clear on logout',
    () async {
      final cache = _CacheStorage();
      final transport = _RoutingHttpClient((request) async {
        switch (request.resolvedUrl.path) {
          case '/login':
            return _jsonResponse({'access_token': 'access'});
          case '/private':
            return const RepositoryHttpResponse(
              statusCode: 200,
              headers: {},
              body: '42',
            );
          default:
            return const RepositoryHttpResponse(
              statusCode: 200,
              headers: {},
              body: '7',
            );
        }
      });
      final environment = BaseRepository.config(
        baseUrl: Uri.parse('https://api.example.com'),
        httpClient: transport,
        storage: cache,
        sessionManager: .bearer(
          authentication: (auth) => (
            password: auth.password(
              endpoint: const .relative('/login'),
              body: (input) => {
                'username': input.username,
                'password': input.password,
              },
              decode: (json) => .new(
                accessToken: json['access_token']! as String,
              ),
            ),
          ),
        ),
      );
      final privateRepository = Repository<int, NoRepositoryActions>(
        endpoint: const .relative('/private'),
        fromJson: int.parse,
        actions: (_) => (),
        resolveOnCreate: false,
      );
      final publicRepository = Repository<int, NoRepositoryActions>(
        endpoint: const .relative('/public'),
        access: .unauthenticated,
        fromJson: int.parse,
        actions: (_) => (),
        resolveOnCreate: false,
      );

      expect(await privateRepository.refresh(), isNull);
      expect(
        privateRepository.currentState,
        isA<RepositoryStatePending<int>>(),
      );
      expect(await publicRepository.refresh(), 7);

      final privateReady = privateRepository.stream.firstWhere(
        (state) => state is RepositoryStateReady<int>,
      );
      await environment.auth.password.signIn(
        username: 'user',
        password: 'pass',
      );
      await privateReady;

      expect(privateRepository.currentValue, 42);
      expect(cache.values, isNotEmpty);

      await environment.session.signOut();

      expect(
        privateRepository.currentState,
        isA<RepositoryStatePending<int>>(),
      );
      expect(cache.values.values, isNot(contains('42')));
      expect(publicRepository.currentValue, 7);
      privateRepository.dispose();
      publicRepository.dispose();
    },
  );

  test('remote logout failure still clears the local session', () async {
    final sessionStorage = InMemoryRepositorySessionStorage();
    final transport = _RoutingHttpClient((request) async {
      if (request.resolvedUrl.path == '/login') {
        return _jsonResponse({'access_token': 'access'});
      }
      return const RepositoryHttpResponse(
        statusCode: 503,
        headers: {},
        body: '',
      );
    });
    final environment = BaseRepository.config(
      baseUrl: Uri.parse('https://api.example.com'),
      httpClient: transport,
      storage: _CacheStorage(),
      sessionManager: .bearer(
        storage: sessionStorage,
        logout: const .delete(endpoint: .relative('/logout')),
        authentication: (auth) => (
          password: auth.password(
            endpoint: const .relative('/login'),
            body: (input) => {
              'username': input.username,
              'password': input.password,
            },
            decode: (json) => .new(
              accessToken: json['access_token']! as String,
            ),
          ),
        ),
      ),
    );
    await environment.auth.password.signIn(username: 'user', password: 'pass');

    final result = await environment.session.signOut();

    expect(result.isLeft(), isTrue);
    expect(environment.session.current, isNull);
    expect(await sessionStorage.read(), isNull);
  });
}

RepositoryHttpResponse _jsonResponse(
  Map<String, Object?> json, {
  Map<String, String> headers = const {},
}) {
  return RepositoryHttpResponse(
    statusCode: 200,
    headers: headers,
    body: jsonEncode(json),
  );
}

final class _RoutingHttpClient extends RepositoryHttpClient {
  _RoutingHttpClient(this.handler);

  final Future<RepositoryHttpResponse> Function(RepositoryHttpRequest request)
  handler;
  final requests = <RepositoryHttpRequest>[];

  @override
  Future<RepositoryHttpResponse> call({
    required RepositoryHttpRequest request,
  }) {
    requests.add(request);
    return handler(request);
  }
}

final class _CacheStorage extends RepositoryCacheStorage {
  final values = <String, String>{};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

final class _CookieJar implements RepositoryCookieJar {
  String? cookie;

  bool get hasCookies => cookie != null;

  @override
  Future<void> clear() async => cookie = null;

  @override
  Future<bool> get hasSession async => hasCookies;

  @override
  Future<Map<String, String>> requestHeaders(Uri uri) async {
    return cookie == null ? const {} : {'Cookie': cookie!};
  }

  @override
  Future<void> storeResponseHeaders(
    Uri uri,
    Map<String, String> headers,
  ) async {
    cookie = headers['set-cookie'] ?? cookie;
  }
}
