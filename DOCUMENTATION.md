# Repository

Comprehensive guide to the `repository` package and its optional adapters.

> **Status:** The 4.0 API is under active development. Expect breaking changes
> before a stable release.

## Table of contents

1. [Overview](#1-overview)
2. [Installation](#2-installation)
3. [Initial configuration](#3-initial-configuration)
4. [Creating repositories](#4-creating-repositories)
5. [Repository state](#5-repository-state)
6. [Flutter integration](#6-flutter-integration)
7. [Actions](#7-actions)
8. [HTTP client](#8-http-client)
9. [URLs](#9-urls)
10. [Interceptors](#10-interceptors)
11. [Cache and stale-while-revalidate](#11-cache-and-stale-while-revalidate)
12. [Authentication](#12-authentication)
13. [Repository dependencies](#13-repository-dependencies)
14. [Combining repositories](#14-combining-repositories)
15. [Retry and error handling](#15-retry-and-error-handling)
16. [Observability](#16-observability)
17. [Lifecycle](#17-lifecycle)
18. [Complete example](#18-complete-example)
19. [Testing](#19-testing)
20. [Monorepo development](#20-monorepo-development)
21. [Migration guide](#21-migration-guide)
22. [Public API reference](#22-public-api-reference)

## 1. Overview

`repository` is a reactive data-access toolkit for Flutter. A repository:

- resolves data from an HTTP endpoint;
- hydrates previously serialized data from a cache;
- exposes a typed stream of content states;
- refreshes stale content without hiding it;
- supports typed mutations through actions;
- reacts to other repositories and session changes;
- integrates with Flutter through `RepositoryBuilder`.

The main data flow is:

```text
cache hydration ──► ready(local)
        │
        └─────────► HTTP refresh ──► ready(remote) ──► cache write
                              └────► error, only when no content exists
```

The package currently uses a process-wide default configuration. Each
repository captures a `RepositoryClient` when it is created. Passing an
explicit `client` remains supported for tests and isolated infrastructure.

## 2. Installation

The package includes Flutter integration, so consumers need a Flutter SDK.

```yaml
dependencies:
  repository: ^4.0.0-dev.1
```

Install dependencies:

```sh
flutter pub get
```

Import the public API:

```dart
import 'package:repository/repository.dart';
```

### Optional Hive cache adapter

Hive support is intentionally kept outside the core package:

```yaml
dependencies:
  repository: ^4.0.0-dev.1
  repository_cache_hive: ^4.0.0-dev.1
```

```dart
import 'package:repository_cache_hive/repository_cache_hive.dart';
```

## 3. Initial configuration

Call `BaseRepository.config()` before creating repositories that do not receive
an explicit client:

```dart
final environment = BaseRepository.config(
  baseUrl: Uri.parse('https://api.example.com/v1/'),
  httpClient: createPlatformHttpClient(),
  storage: await HiveRepositoryCacheStorage.create(),
  logger: const RepositoryLogger.dev(),
  interceptors: const [],
);
```

The arguments configure:

| Argument | Responsibility |
| --- | --- |
| `baseUrl` | Resolves every `RepositoryUrl.relative` value. |
| `httpClient` | Sends resolved HTTP requests. |
| `storage` | Persists serialized repository responses. |
| `logger` | Receives lifecycle and error messages. |
| `interceptors` | Wraps every HTTP call in declaration order. |
| `sessionManager` | Adds bearer or cookie authentication. |

`config()` returns a typed `RepositoryEnvironment<Authentication>` containing:

- `client`: the default authenticated client;
- `publicClient`: the client used by public and authentication requests;
- `sessionManager`: the optional configured session manager;
- `auth`: the typed authentication methods;
- `session`: the session lifecycle API.

Without a session manager, `client` and `publicClient` are the same object.

### Current global configuration semantics

The default authenticated and public clients are stored statically by
`BaseRepository`. A repository captures the selected client in its constructor.
Calling `config()` again affects repositories created afterwards, not existing
instances.

For two simultaneous environments, create separate `RepositoryClient` objects
and pass the appropriate client explicitly to each repository. A scoped,
multi-environment API is not part of the current release.

### Direct client construction

Infrastructure can also be assembled without the global configuration:

```dart
final client = RepositoryClient(
  baseUrl: Uri.parse('https://tenant.example.com/v1/'),
  httpClient: createPlatformHttpClient(),
  storage: cacheStorage,
  interceptors: [const AppHeaderInterceptor()],
);

final repository = Repository<int, NoRepositoryActions>(
  client: client,
  endpoint: const .relative('count'),
  fromJson: int.parse,
  actions: (_) => (),
);
```

## 4. Creating repositories

`Repository<Data, Actions>` is the concrete HTTP repository and can be used
without inheritance:

```dart
final products = Repository<List<Product>, NoRepositoryActions>(
  name: 'products',
  endpoint: const .relative('products'),
  fromJson: Product.listFromJson,
  actions: (_) => (),
);
```

The equivalent factory on the base type is:

```dart
final products = BaseRepository<List<Product>, NoRepositoryActions>.http(
  endpoint: const .relative('products'),
  fromJson: Product.listFromJson,
  actions: (_) => (),
);
```

Relevant options include:

| Option | Default | Effect |
| --- | --- | --- |
| `access` | `authenticated` | Chooses the authenticated or public client. |
| `method` | `GET` | HTTP method used by `resolve()`. |
| `resolveOnCreate` | `true` | Refreshes after initial hydration. |
| `autoRefreshInterval` | `null` | Refreshes periodically while the stream has a listener. |
| `dependencies` | empty | Refreshes when a dependency emits ready content. |
| `tag` | `null` | Adds a discriminator to the cache key. |
| `name` | endpoint suffix | Identifies logs and diagnostics. |
| `shouldRetryCondition` | network errors | Selects errors eligible for retry. |

When `fromJson` is omitted, the raw response string is cast to `Data`. This is
mainly useful for `Repository<String, ...>`; structured data should always
provide a decoder.

### Inheritance

Inheritance remains available for specialized behavior:

```dart
final class ProductRepository
    extends Repository<List<Product>, NoRepositoryActions> {
  ProductRepository()
      : super(
          endpoint: const .relative('products'),
          actions: (_) => (),
        );

  @override
  List<Product> fromJson(String json) => Product.listFromJson(json);

  @override
  bool successfulCondition(int statusCode, dynamic body) {
    return statusCode >= 200 && statusCode < 300;
  }
}
```

By default, only status codes `200` and `201` are considered successful.

## 5. Repository state

The UI-facing state is deliberately about content availability, not request
activity:

```dart
sealed class RepositoryState<Data> {
  const factory RepositoryState.pending();
  const factory RepositoryState.ready({
    required Data data,
    required RepositoryDatasource source,
  });
  const factory RepositoryState.error({
    required Object error,
    required StackTrace stackTrace,
  });
}
```

### Pending

`RepositoryStatePending` means no content is available yet. It can represent a
new repository, a cleared repository, or an authenticated repository waiting
for a session.

### Ready

`RepositoryStateReady<Data>` contains `data` and its source:

- `RepositoryDatasource.local`: hydrated cache content;
- `RepositoryDatasource.remote`: a successful remote refresh;
- `RepositoryDatasource.optimistic`: content emitted by an action or update.

A repository stays ready while it refreshes in the background. If that refresh
fails, existing content remains visible.

### Error

`RepositoryStateError` is emitted only when a refresh fails and there is no
ready content to preserve. It contains the original error and stack trace.

### Reading and observing state

```dart
final state = products.currentState;
final value = products.currentValue; // null unless ready
final resolved = await products.currentValueOrResolve();

products.stream.listen((RepositoryState<List<Product>> state) {});
products.dataStream.listen((List<Product>? data) {});
```

`currentValueOrResolve()` returns ready content immediately; otherwise it
starts or joins a refresh.

States can be handled with Dart patterns or `map()`:

```dart
final count = products.currentState.map(
  pending: (_) => 0,
  ready: (state) => state.data.length,
  error: (_) => 0,
);
```

## 6. Flutter integration

`RepositoryBuilder` listens to a repository and exposes both its complete state
and typed actions:

```dart
RepositoryBuilder(
  repository: products,
  builder: (context, state, actions) {
    return switch (state) {
      RepositoryStatePending() =>
        const Center(child: CircularProgressIndicator()),
      RepositoryStateReady(data: final products) =>
        ProductList(products: products),
      RepositoryStateError(error: final error) =>
        ErrorView(error: error),
    };
  },
);
```

The builder uses `currentState` as its initial value and rebuilds for every
subsequent stream emission. It does not own the repository; dispose repositories
at the lifecycle boundary that created them.

## 7. Actions

Actions are external typed factories. The repository supplies a
`RepositoryActionExecutor<Data>` that runs the operation with its captured
client and optionally applies successful output to current data.

```dart
typedef TransactionActions = ({
  Future<Either<CreateTransactionFailure, Transaction>> Function(
    CreateTransaction input,
  ) create,
  Future<Either<DeleteTransactionFailure, Unit>> Function(String id) delete,
});
```

```dart
TransactionActions createTransactionActions(
  RepositoryActionExecutor<List<Transaction>> execute,
) {
  return (
    create: (input) => execute(
      run: (client) async {
        final response = await client.call(
          request: RepositoryHttpRequest(
            url: const .relative('transactions'),
            method: RepositoryHttpMethod.post,
            body: input.toJson(),
          ),
        );

        if (response.statusCode != 201) {
          return Left(CreateTransactionFailure(response));
        }

        return Right(Transaction.fromJson(response.body));
      },
      update: (current, created) => [...?current, created],
    ),
    delete: (id) => execute(
      run: (client) async {
        final response = await client.call(
          request: RepositoryHttpRequest(
            url: .relative('transactions/$id'),
            method: RepositoryHttpMethod.delete,
            body: null,
          ),
        );
        return response.statusCode == 204
            ? const Right(unit)
            : Left(DeleteTransactionFailure(response));
      },
      update: (current, _) => [
        for (final transaction in current ?? const <Transaction>[])
          if (transaction.id != id) transaction,
      ],
    ),
  );
}
```

Attach the factory to a repository:

```dart
final transactions = Repository<List<Transaction>, TransactionActions>(
  endpoint: const .relative('transactions'),
  fromJson: Transaction.listFromJson,
  actions: createTransactionActions,
);
```

Action behavior:

- `Left` is returned without updating repository data;
- `Right` invokes `update`, if supplied, and emits optimistic content;
- exceptions propagate and skip `update`;
- session generation is checked before applying output, preventing a result
  from one identity from updating another identity's data.

Repositories without actions use the empty record:

```dart
Repository<Data, NoRepositoryActions>(
  endpoint: endpoint,
  actions: (_) => (),
);
```

`BaseRepository.update()` is a lower-level optimistic helper that emits a value
and immediately refreshes. Typed actions are preferred for application writes.

## 8. HTTP client

### RepositoryClient

`RepositoryClient` combines the base URL, transport, cache, logger,
interceptors, and optional session runtime. `call()` resolves the URL, builds
the interceptor chain, and delegates to `RepositoryHttpClient`.

```dart
final response = await environment.client.call(
  request: const RepositoryHttpRequest(
    url: .relative('health'),
  ),
);
```

Call `close()` when the client owns resources that should be released.

### Requests and responses

```dart
const request = RepositoryHttpRequest(
  url: .relative('products'),
  method: RepositoryHttpMethod.post,
  headers: {'X-Request-ID': '123'},
  body: {'name': 'Keyboard'},
);
```

Supported methods are `get`, `post`, `put`, `delete`, and `patch`.
`RepositoryHttpResponse` exposes `statusCode`, `headers`, and the raw string
`body`.

The standard HTTP adapter serializes request bodies as JSON and supplies
`Content-Type: application/json` when a body is present, unless an explicit
content type was supplied. Empty/default GET requests do not receive that
header.

### Platform adapter

```dart
final transport = createPlatformHttpClient();
```

An internally created transport is owned by the adapter. An injected
`package:http` client remains caller-owned unless ownership is transferred:

```dart
final transport = createPlatformHttpClient(
  client: httpClient,
  closeClient: true,
);
```

`HttpRepositoryHttpClient` also accepts a legacy asynchronous `tokenBuilder`.
The built-in session managers are preferred for new authentication flows.

### Custom transport

```dart
final class ApiTransport extends RepositoryHttpClient {
  const ApiTransport();

  @override
  Future<RepositoryHttpResponse> call({
    required RepositoryHttpRequest request,
  }) async {
    // request.resolvedUrl is absolute here.
    return const RepositoryHttpResponse(
      statusCode: 200,
      headers: {},
      body: '{}',
    );
  }
}
```

## 9. URLs

Relative URLs are resolved against `RepositoryClient.baseUrl` before
interceptors run:

```dart
const RepositoryUrl.relative('transactions/42');
const RepositoryUrl.relative('/transactions/42');
```

Resolution follows `Uri.resolve`: a leading slash starts at the host root;
without a leading slash, the value is relative to the base URL path.

Absolute URLs ignore the base URL:

```dart
const RepositoryUrl.absolute(
  'https://external.example.com/transactions/42',
);
```

Resolving a relative URL without a valid absolute base URL throws. Supplying an
absolute string to `.relative()` or a relative string to `.absolute()` also
throws.

## 10. Interceptors

An interceptor wraps the next request handler:

```dart
final class AppHeaderInterceptor implements RepositoryInterceptor {
  const AppHeaderInterceptor();

  @override
  Future<RepositoryHttpResponse> intercept({
    required RepositoryHttpRequest request,
    required RepositoryRequestHandler next,
  }) {
    return next(
      request.copyWith(
        headers: {...request.headers, 'X-App': 'storefront'},
      ),
    );
  }
}
```

Interceptors run in declaration order. They may transform requests or
responses, short-circuit transport, handle errors, or invoke `next` again to
replay a request. Relative URLs have already been resolved when an interceptor
receives them.

When authentication is configured, the session interceptor is appended after
application interceptors.

## 11. Cache and stale-while-revalidate

Repository initialization performs these operations in order:

1. start one cache hydration;
2. decode and emit cached content as `ready(local)` when available;
3. if `resolveOnCreate` is true, refresh from the remote endpoint;
4. emit `ready(remote)` and persist the raw response.

Concurrent hydration and refresh calls are single-flight. Cached content stays
ready during a refresh. A background failure does not replace it with an error.

Cache keys include the repository key and, for authenticated clients, a session
namespace. Bearer sessions derive identity from the JWT `sub` claim when
available; otherwise the session generation prevents reuse after identity
changes.

### Clearing data

```dart
await products.clearCache(); // persistent cache only
await products.clear();      // pending state plus persistent cache
```

`clearCache()` removes both the current cache key and a previous identity-scoped
key remembered by the repository.

### Custom cache storage

```dart
final class MemoryCacheStorage extends RepositoryCacheStorage {
  final _values = <String, String>{};

  @override
  Future<String?> read({required String key}) async => _values[hashKey(key)];

  @override
  Future<void> write({required String key, required String value}) async {
    _values[hashKey(key)] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _values.remove(hashKey(key));
  }

  @override
  Future<void> clear() async => _values.clear();
}
```

### Hive adapter

```dart
final storage = await HiveRepositoryCacheStorage.create();
```

To control Hive initialization, encryption, and box lifecycle:

```dart
final storage = HiveRepositoryCacheStorage(box: stringBox);
```

## 12. Authentication

Authentication is configured once in `BaseRepository.config()`. The package
provides bearer and cookie session strategies plus typed password,
passwordless, OAuth authorization-code, and custom authentication operations.

Authentication request body and response formats are always supplied by the
application. There is no default decoder because backend contracts differ.

### Bearer sessions

```dart
final environment = BaseRepository.config(
  baseUrl: Uri.parse('https://api.example.com/v1/'),
  httpClient: createPlatformHttpClient(),
  storage: cacheStorage,
  sessionManager: .bearer(
    storage: secureSessionStorage,
    authentication: (auth) => (
      password: auth.password(
        endpoint: const .relative('auth/login'),
        body: (input) => {
          'email': input.username,
          'password': input.password,
        },
        decode: (json) => .new(
          accessToken: json['access_token']! as String,
          refreshToken: json['refresh_token'] as String?,
        ),
      ),
    ),
    refresh: .post(
      endpoint: const .relative('auth/refresh'),
      body: (input) => {
        'refresh_token': input.session.refreshToken,
      },
      decode: (json, current) => .new(
        accessToken: json['access_token']! as String,
        refreshToken:
            json['refresh_token'] as String? ?? current.refreshToken,
      ),
    ),
    logout: .delete(
      endpoint: const .relative('auth/session'),
    ),
  ),
);
```

Inside `.bearer()`, every session-producing decoder must return
`RepositorySessionBearer`. The contextual `.new()` constructor cannot select a
cookie session accidentally.

Sign in through the inferred authentication record:

```dart
final result = await environment.auth.password.signIn(
  username: email,
  password: password,
);

result.fold(showAuthenticationFailure, openApplication);
```

Bearer authorization sends:

```text
Authorization: Bearer <access token>
```

For JWTs, expiration is derived from the `exp` claim when `expiresAt` is not
supplied. The `sub` claim is used as the cache identity when available.

### Refresh behavior

- expired bearer sessions refresh before an authenticated request;
- a response with status `401` starts or joins one single-flight refresh;
- after a successful refresh, the original request is replayed once;
- a `401` from the refresh endpoint removes the local session;
- other refresh failures preserve the existing session and response;
- `403` never triggers refresh and never clears the session.

### Session storage

Repository cache storage and credential storage are separate interfaces.
Implement `RepositorySessionStorage` with a secure platform-backed solution for
production tokens:

```dart
abstract interface class RepositorySessionStorage {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}
```

`InMemoryRepositorySessionStorage` is the default and is suitable for tests or
sessions that should not survive an application restart.

### Session state and logout

```dart
final current = environment.session.current;
final state = environment.session.state;

environment.session.states.listen((state) {
  switch (state) {
    case RepositorySessionStatePending():
      break;
    case RepositorySessionStateUnauthenticated():
      break;
    case RepositorySessionStateAuthenticated(session: final session):
      print(session);
    case RepositorySessionStateError(error: final error):
      print(error);
  }
});

await environment.session.signOut();
```

Remote logout is optional. `signOut()` always removes local credentials and
clears authenticated repository content, even if the remote request fails.

Login refreshes existing authenticated repositories. A detected identity
change clears their content and cache before refreshing. A token rotation for
the same identity does not clear ready data.

### Public repositories

Authenticated access is the default. Public endpoints opt out explicitly:

```dart
final appVersion = Repository<AppVersion, NoRepositoryActions>(
  endpoint: const .relative('version'),
  access: .unauthenticated,
  fromJson: AppVersion.fromJson,
  actions: (_) => (),
);
```

An authenticated repository with no available session remains pending and does
not call its endpoint.

### Passwordless code flow

```dart
authentication: (auth) => (
  passwordless: auth.passwordlessCode<PasswordlessChallenge>(
    request: RepositoryAuthenticationRequest.post(
      endpoint: const .relative('auth/code'),
      body: (input) => {'email': input.username},
      decode: (json) => PasswordlessChallenge(
        id: json['challenge_id']! as String,
      ),
    ),
    verify: RepositoryAuthenticationRequest.post(
      endpoint: const .relative('auth/code/verify'),
      body: (input) => {
        'challenge_id': input.challenge.id,
        'code': input.code,
      },
      decode: (json) => RepositorySessionBearer(
        accessToken: json['access_token']! as String,
      ),
    ),
  ),
),
```

```dart
final result = await environment.auth.passwordless.requestCode(
  username: email,
);

final verified = await result.fold(
  (failure) async => Left(failure),
  (challenge) => challenge.verify(code: code),
);
```

### OAuth authorization code

The application performs browser authorization and PKCE generation. The
repository authentication API handles the typed code exchange:

```dart
oauth: auth.oauthAuthorizationCode(
  exchange: RepositoryAuthenticationRequest.post(
    endpoint: const .relative('auth/oauth/token'),
    body: (input) => {
      'code': input.code,
      'code_verifier': input.codeVerifier,
      'redirect_uri': input.redirectUri.toString(),
      'client_id': input.clientId,
    },
    decode: (json) => RepositorySessionBearer(
      accessToken: json['access_token']! as String,
      refreshToken: json['refresh_token'] as String?,
    ),
  ),
),
```

Call `environment.auth.oauth.exchange()` with an
`ExchangeOAuthAuthorizationCode`.

### Custom flow

```dart
magicLink: auth.custom<MagicLinkInput>(
  request: RepositoryAuthenticationRequest.post(
    endpoint: const .relative('auth/magic-link'),
    body: (input) => {'token': input.token},
    decode: (json) => RepositorySessionBearer(
      accessToken: json['access_token']! as String,
    ),
  ),
),
```

Call it with `environment.auth.magicLink.createSession(input)`.

### Cookie sessions

Cookie authentication requires an application-provided cookie jar:

```dart
sessionManager: .cookies(
  cookieJar: cookieJar,
  storage: sessionStorage,
  authentication: (auth) => (
    password: auth.password(
      endpoint: const .relative('auth/login'),
      body: (input) => {
        'email': input.username,
        'password': input.password,
      },
      decode: (json) => .new(
        identity: json['user_id'] as String?,
      ),
    ),
  ),
),
```

`RepositoryCookieJar` must provide request headers, capture response headers,
report whether a session exists, and clear stored cookies. Cookie decoders can
only create `RepositorySessionCookies`.

### Authentication failures

Authentication operations return:

```dart
Either<RepositoryAuthenticationFailure, Session>
```

Failures are either:

- `RepositoryAuthenticationHttpFailure`, containing the non-success response;
- `RepositoryAuthenticationUnexpectedFailure`, containing the error and stack;
- `RepositoryAuthenticationRequiredException`, thrown when an authenticated
  request reaches the interceptor without a usable session.

## 13. Repository dependencies

A dependency invalidates the repository that declares it:

```dart
final orders = Repository<List<Order>, NoRepositoryActions>(
  endpoint: const .relative('orders'),
  dependencies: [currentUser],
  fromJson: Order.listFromJson,
  actions: (_) => (),
);
```

Whenever `currentUser` emits a ready state, `orders.refresh()` runs. The
direction is dependency to dependent; updating `orders` does not refresh
`currentUser`.

Dependencies can also be added later:

```dart
orders.addDependency(currentUser);
```

The current implementation does not detect dependency cycles. Keep the graph
acyclic; `A -> B -> A` can cause repeated refreshes.

## 14. Combining repositories

`ZipRepository<Data>` combines the latest states of multiple repositories:

```dart
final dashboard = ZipRepository<DashboardData>(
  repositories: [profile, orders],
  zipper: (values) => DashboardData(
    profile: values[0] as Profile?,
    orders: values[1] as List<Order>?,
  ),
);
```

Pending and error child states are passed to `zipper` as `null`. The combined
repository listens to every child, hydrates all children, and refreshes all
children concurrently. It exposes `NoRepositoryActions`.

Dispose the zip repository to cancel its combined subscription. Child
repositories remain caller-owned.

## 15. Retry and error handling

`Repository.refresh()` is single-flight and uses the `retry` package. For the
concrete HTTP repository, only `NetworkUnavailableException` is retried by
default:

```dart
final repository = Repository<Data, NoRepositoryActions>(
  endpoint: endpoint,
  fromJson: decode,
  actions: (_) => (),
  shouldRetryCondition: (exception) {
    return exception is NetworkUnavailableException;
  },
);
```

The standard transport normalizes `SocketException` and
`http.ClientException` into `NetworkUnavailableException`.

An unsuccessful status code throws `UnexpectedStatusCodeException`, containing
both the sent request and received response, unless `onErrorStatusCode()` is
overridden to return `false`.

If a refresh fails:

- without ready content, the repository emits `RepositoryStateError` and
  rethrows;
- with ready content, it preserves that content and rethrows;
- detached initialization, dependency, and timer refreshes log the failure
  instead of producing an unhandled asynchronous error.

## 16. Observability

Provide a custom `RepositoryLogger` to integrate with application telemetry:

```dart
final class AppRepositoryLogger extends RepositoryLogger {
  const AppRepositoryLogger() : super(level: RepositoryLoggingLevel.info);

  @override
  void call(
    String message, {
    RepositoryLoggingLevel level = RepositoryLoggingLevel.info,
  }) {
    telemetry.record(message, level: level.name);
  }
}
```

Logging levels are `none`, `error`, `warning`, `info`, and `debug`.
`RepositoryLogger.dev()` uses `dart:developer` and is not intended as a
production logging backend.

Tracked repositories are available as weak references for diagnostics:

```dart
for (final reference in BaseRepository.repositories) {
  print(reference.target);
}
```

Repositories log hydration and refresh duration, retries, emitted values, and
detached lifecycle failures.

## 17. Lifecycle

Construction immediately starts hydration. After hydration, remote resolution
runs when `resolveOnCreate` is true. Periodic refreshes run only while the
repository stream has a listener.

```dart
final repository = Repository<Data, NoRepositoryActions>(
  endpoint: endpoint,
  autoRefreshInterval: const Duration(minutes: 5),
  actions: (_) => (),
);
```

Dispose repositories created for a finite feature or screen:

```dart
repository.dispose();
```

Disposal:

- cancels the auto-refresh timer;
- cancels dependency subscriptions;
- closes the state stream;
- ignores late refresh, hydration, and optimistic results.

Disposal does not close the shared `RepositoryClient`. Close a directly owned
client once all of its repositories are finished.

## 18. Complete example

```dart
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:repository/repository.dart';
import 'package:repository_cache_hive/repository_cache_hive.dart';

typedef TodoActions = ({
  Future<Either<String, Todo>> Function(String title) create,
});

TodoActions todoActions(RepositoryActionExecutor<List<Todo>> execute) => (
  create: (title) => execute(
    run: (client) async {
      final response = await client.call(
        request: RepositoryHttpRequest(
          url: const .relative('todos'),
          method: RepositoryHttpMethod.post,
          body: {'title': title},
        ),
      );
      return response.statusCode == 201
          ? Right(Todo.fromJson(response.body))
          : Left('Could not create todo (${response.statusCode})');
    },
    update: (current, todo) => [...?current, todo],
  ),
);

late final Repository<List<Todo>, TodoActions> todos;

Future<void> configureDataLayer() async {
  BaseRepository.config(
    baseUrl: Uri.parse('https://api.example.com/v1/'),
    httpClient: createPlatformHttpClient(),
    storage: await HiveRepositoryCacheStorage.create(),
  );

  todos = Repository(
    endpoint: const .relative('todos'),
    fromJson: (source) => [
      for (final value in jsonDecode(source) as List<dynamic>)
        Todo.fromMap(value as Map<String, dynamic>),
    ],
    actions: todoActions,
  );
}

class TodoPage extends StatelessWidget {
  const TodoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryBuilder(
      repository: todos,
      builder: (context, state, actions) => switch (state) {
        RepositoryStatePending() =>
          const Center(child: CircularProgressIndicator()),
        RepositoryStateReady(data: final todos) => ListView(
          children: [
            for (final todo in todos) ListTile(title: Text(todo.title)),
            FilledButton(
              onPressed: () => actions.create('Read documentation'),
              child: const Text('Add todo'),
            ),
          ],
        ),
        RepositoryStateError(error: final error) =>
          Center(child: Text('$error')),
      },
    );
  }
}
```

The example assumes application-specific `Todo`, secure session storage, and
error UI implementations where applicable.

## 19. Testing

Inject infrastructure instead of changing global production configuration:

```dart
final client = RepositoryClient(
  baseUrl: Uri.parse('https://test.example/'),
  httpClient: FakeRepositoryHttpClient(),
  storage: MemoryCacheStorage(),
);

final repository = Repository<int, NoRepositoryActions>(
  client: client,
  endpoint: const .relative('count'),
  fromJson: int.parse,
  actions: (_) => (),
  resolveOnCreate: false,
);
```

`RepositoryHttpClient` also supports a `mocks` map keyed by
`RepositoryHttpMockedRequest(url, method)`. A purpose-built fake is preferable
when tests need to inspect headers, request bodies, ordering, or refresh replay.

Useful assertions include:

- initial state is pending;
- cache hydration emits `ready(local)`;
- refresh emits `ready(remote)`;
- action `Left` preserves data;
- action `Right` emits `ready(optimistic)`;
- a background failure preserves stale ready content;
- `401` performs one refresh and one replay;
- `403` leaves the session unchanged;
- delete and clear remove both persistent and in-memory adapter values.

For widget tests, pump a `RepositoryBuilder` with `resolveOnCreate: false`,
drive the repository explicitly, and assert each pattern-rendered state.

## 20. Monorepo development

The repository is a Dart Pub Workspace orchestrated by Melos. It currently
contains:

```text
repository/
├── lib/                              # repository package
├── test/
└── packages/
    └── repository_cache_hive/        # optional Hive adapter
```

Install workspace dependencies:

```sh
flutter pub get
```

Run all quality checks:

```sh
dart run melos run quality
```

Or run each stage:

```sh
dart run melos run format
dart run melos run analyze
dart run melos run test
```

Melos uses `useRootAsPackage: true` so both the root package and nested adapter
participate in workspace commands. Analysis and tests run serially to avoid
Flutter SDK startup-lock contention.

Before publishing either package:

```sh
flutter pub publish --dry-run
```

Run it from the directory of the package being validated.

## 21. Migration guide

### Configure infrastructure once

Replace repeated default client arguments with:

```dart
BaseRepository.config(
  baseUrl: baseUrl,
  httpClient: httpClient,
  storage: storage,
);
```

Keep `client:` only for explicit isolation or test injection.

### Replace raw URI values

```dart
url: const .relative('transactions')
url: const .absolute('https://example.com/transactions')
```

### Replace mutate with actions

Move mutations into an external `RepositoryActionsFactory`, return
`Either<Failure, Output>`, and use `update` for successful optimistic state.

### Handle the complete state

`RepositoryBuilder` now passes `RepositoryState<Data>`, not `Data?`. Switch over
pending, ready, and error explicitly.

### Remove session mixins

Configure a session manager once. Repositories are authenticated by default;
mark only public endpoints with `access: .unauthenticated`.

### Move Hive out of the core package

Add `repository_cache_hive` and import its library separately. The core package
does not depend on Hive.

## 22. Public API reference

### Core repositories

| API | Purpose |
| --- | --- |
| `BaseRepository<Data, Actions>` | Stateful reactive repository foundation. |
| `Repository<Data, Actions>` | Concrete HTTP-backed repository. |
| `ZipRepository<Data>` | Combines the latest content of child repositories. |
| `RepositoryClient` | Bundles transport, cache, logging, interceptors, and session runtime. |

### State and Flutter

| API | Purpose |
| --- | --- |
| `RepositoryState<Data>` | Sealed pending/ready/error content state. |
| `RepositoryStatePending<Data>` | No content is available. |
| `RepositoryStateReady<Data>` | Content and datasource are available. |
| `RepositoryStateError<Data>` | Initial/no-content load failed. |
| `RepositoryDatasource` | `remote`, `local`, or `optimistic`. |
| `RepositoryBuilder<Data, Actions>` | Rebuilds Flutter UI from state and actions. |
| `RepositoryBuilderBuilder<Data, Actions>` | Typed Flutter builder callback. |

### Actions

| API | Purpose |
| --- | --- |
| `NoRepositoryActions` | Empty action record `()`. |
| `RepositoryActionRun<Failure, Output>` | Operation receiving a client. |
| `RepositoryActionExecutor<Data>` | Executes an operation and applies successful output. |
| `RepositoryActionsFactory<Data, Actions>` | Builds a repository's typed actions. |

### HTTP and URLs

| API | Purpose |
| --- | --- |
| `RepositoryHttpClient` | Abstract transport. |
| `HttpRepositoryHttpClient` | `package:http` transport implementation. |
| `createPlatformHttpClient()` | Creates the default platform transport. |
| `RepositoryHttpRequest` | URL, method, headers, and JSON body. |
| `RepositoryHttpResponse` | Status, headers, and raw body. |
| `RepositoryHttpMethod` | GET, POST, PUT, DELETE, and PATCH. |
| `RepositoryHttpMockedRequest` | URL/method key for transport mocks. |
| `BearerToken` | Alias for a bearer token string without its prefix. |
| `TokenBuilder` | Asynchronous legacy bearer-token provider. |
| `RepositoryUrl` | Sealed relative or absolute request URL. |
| `RepositoryRelativeUrl` | URL resolved against `baseUrl`. |
| `RepositoryAbsoluteUrl` | URL independent from `baseUrl`. |
| `RepositoryInterceptor` | HTTP middleware contract. |
| `RepositoryRequestHandler` | Next function in an interceptor chain. |

### Cache, logging, and errors

| API | Purpose |
| --- | --- |
| `RepositoryCacheStorage` | Abstract serialized repository cache. |
| `RepositoryLogger` | Logging abstraction and dev factory. |
| `DeveloperRepositoryLogger` | `dart:developer` logger. |
| `RepositoryLoggingLevel` | Logging severity configuration. |
| `NetworkUnavailableException` | Normalized transport connectivity error. |
| `UnexpectedStatusCodeException` | Contains an unsuccessful request and response. |

### Authentication and sessions

| API | Purpose |
| --- | --- |
| `RepositoryEnvironment<Authentication>` | Returned clients and typed session access. |
| `NoRepositoryAuthentication` | Empty authentication surface when no manager exists. |
| `RepositorySessionManager<Authentication>` | Bearer/cookie manager factory and lifecycle. |
| `RepositoryBearerSessionManager<Authentication>` | Bearer strategy implementation. |
| `RepositoryCookiesSessionManager<Authentication>` | Cookie strategy implementation. |
| `RepositoryAuthenticationBuilder<Session>` | Builds typed authentication methods. |
| `RepositoryAuthenticationRequest<Input, Output>` | Typed POST/PUT authentication operation. |
| `RepositoryAuthenticationJson` | JSON object received from an authentication endpoint. |
| `RepositoryAuthenticationBody<Input>` | Maps typed input to a request body. |
| `RepositoryAuthenticationDecoder<Output>` | Maps response JSON to typed output. |
| `RepositoryRefreshDecoder<Session>` | Maps response JSON and the old session to a replacement. |
| `RepositorySessionRefresh<Session>` | Typed POST/PUT refresh operation. |
| `RepositorySessionLogout<Session>` | Optional POST/DELETE remote logout. |
| `RepositoryPasswordAuthentication<Session>` | Username/password sign-in. |
| `RepositoryPasswordlessAuthentication<Session, Challenge>` | Request-and-verify code flow. |
| `RepositoryPasswordlessChallenge<Session, Challenge>` | Typed challenge with `verify()`. |
| `RepositoryOAuthAuthorizationCodeAuthentication<Session>` | OAuth code exchange. |
| `RepositoryCustomAuthentication<Input, Session>` | Application-specific session creation. |
| `CreateSessionWithPassword` | Password body-mapper input. |
| `RequestPasswordlessCode` | Passwordless request body-mapper input. |
| `VerifyPasswordlessCode<Challenge>` | Passwordless verification body-mapper input. |
| `ExchangeOAuthAuthorizationCode` | OAuth code, PKCE verifier, redirect URI, and client ID. |
| `RefreshSession<Session>` | Refresh body-mapper input. |
| `SignOutSession<Session>` | Logout body-mapper input. |
| `RepositorySessionBearer` | Access token, optional refresh token, and expiration. |
| `RepositorySessionCookies` | Marker for cookie-backed identity. |
| `RepositorySessionStorage` | Credential persistence interface. |
| `InMemoryRepositorySessionStorage` | Non-persistent credential storage. |
| `RepositoryCookieJar` | Cookie capture, sending, status, and clearing. |
| `RepositorySessionState` | Pending/unauthenticated/authenticated/error state. |
| `RepositorySessionStatePending` | Stored session has not been resolved yet. |
| `RepositorySessionStateUnauthenticated` | No local session is available. |
| `RepositorySessionStateAuthenticated` | A session is available. |
| `RepositorySessionStateError` | Stored session resolution failed. |
| `RepositorySessionChange` | Authentication, identity, refresh, or sign-out lifecycle event. |
| `RepositorySessionRuntime` | Non-generic session contract consumed by clients. |
| `RepositoryAccess` | Authenticated or unauthenticated repository access. |
| `RepositoryAuthenticationFailure` | Sealed authentication failure base. |
| `RepositoryAuthenticationHttpFailure` | Non-success authentication response. |
| `RepositoryAuthenticationUnexpectedFailure` | Unexpected error and stack trace. |
| `RepositoryAuthenticationRequiredException` | Authenticated request has no usable session. |

### Optional adapter package

| API | Purpose |
| --- | --- |
| `HiveRepositoryCacheStorage` | Hive-backed `RepositoryCacheStorage`. |
