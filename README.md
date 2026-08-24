# Repository

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![Powered by Mason](https://img.shields.io/endpoint?url=https%3A%2F%2Ftinyurl.com%2Fmason-badge)](https://github.com/felangel/mason)
[![License: MIT][license_badge]][license_link]

A reactive repository toolkit for Flutter with HTTP, caching, dependency tracking, auto refresh, and UI integration.

## Warning ⚠️

This package is currently under heavy development and is **not yet ready for production use**. It is being actively worked on by our development team, and we are constantly adding new features and making improvements.

While we are working hard to make this package as stable and reliable as possible, there may be bugs or issues that arise as new code is added or existing code is modified. We encourage you to report any issues you encounter during this development process, and we will do our best to address them as quickly as possible.

As we continue to develop this package, we may make breaking changes to the API or other aspects of the package. We will do our best to document any such changes and provide guidance on how to update your code accordingly.

We appreciate your patience and understanding as we work to bring this package to maturity. We are committed to delivering a high-quality, reliable package that meets the needs of our users, and we believe that with your feedback and support, we can achieve that goal.

## Installation 💻

**❗ Repository now includes its Flutter integration, so a Flutter SDK is required.**

Add `repository` to your `pubspec.yaml`:

```yaml
dependencies:
  repository: ^4.0.0-dev.1
```

Hive persistence is provided by the optional adapter package:

```yaml
dependencies:
  repository: ^4.0.0-dev.1
  repository_cache_hive: ^4.0.0-dev.1
```

Install it:

```sh
flutter pub get
```

## Configure repositories

When using Hive, import its adapter separately:

```dart
import 'package:repository/repository.dart';
import 'package:repository_cache_hive/repository_cache_hive.dart';
```

Configure the default client and the session lifecycle once before creating
repositories:

```dart
final repositories = BaseRepository.config(
  baseUrl: Uri.parse('https://api.example.com/v1/'),
  httpClient: createPlatformHttpClient(),
  storage: await HiveRepositoryCacheStorage.create(),

  sessionManager: .bearer(
    storage: secureSessionStorage,

    refresh: .post(
      endpoint: .relative('/auth/refresh'),
      body: (input) => {
        'refresh_token': input.session.refreshToken,
      },
      decode: (json, current) => .new(
        accessToken: json['access_token']! as String,
        refreshToken:
            json['refresh_token'] as String? ?? current.refreshToken,
      ),
    ),

    authentication: (auth) => (
      password: auth.password(
        endpoint: .relative('/auth/login'),
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
  ),
);

await repositories.auth.password.signIn(
  username: email,
  password: password,
);
```

The callback returned by `authentication` remains fully typed. In a bearer
manager every terminal decoder must return `RepositorySessionBearer`; in a
cookies manager it must return `RepositorySessionCookies`. Authentication
endpoints do not share a default decoder because each backend response may
have a different shape.

`RepositorySessionStorage` is intentionally separate from repository cache
storage. Use a secure platform-backed implementation for persisted access and
refresh tokens. `InMemoryRepositorySessionStorage` is available for tests and
sessions that should not survive an application restart.

Each repository captures the configured client when it is created. A later
configuration does not change existing repositories. `client:` remains an
optional per-repository override for tests or different infrastructure.

`createPlatformHttpClient()` owns its internally created transport. To inject
a package:http client, pass `client:`; it remains caller-owned by default, or
set `closeClient: true` to transfer ownership to the adapter. Call `close()` on
the adapter, or on a directly held `RepositoryClient`, during application
shutdown.

A read-only repository needs only an endpoint, decoder, and empty actions
factory:

```dart
final repository = Repository<int, NoRepositoryActions>(
  endpoint: .relative('count'),
  fromJson: int.parse,
  actions: (_) => (),
);
```

`NoRepositoryActions` is the empty record used by read-only repositories.

## Request URLs

Relative URLs are resolved against `RepositoryClient.baseUrl` before any
interceptor runs:

```dart
RepositoryHttpRequest(
  url: .relative('transactions/42'),
);
```

An absolute URL ignores the configured base URL:

```dart
RepositoryHttpRequest(
  url: .absolute('https://external.example.com/transactions/42'),
);
```

Resolution follows `Uri.resolve`: a leading slash starts at the host root,
while a path without one is relative to the base URL path.

## Interceptors

`RepositoryInterceptor` is middleware around the configured HTTP adapter.
Interceptors run in declaration order and may transform requests, transform
responses, handle failures, short-circuit the transport, or invoke `next`
again. The latter enables session refresh followed by a single replay.

```dart
class HeaderInterceptor implements RepositoryInterceptor {
  const HeaderInterceptor();

  @override
  Future<RepositoryHttpResponse> intercept({
    required RepositoryHttpRequest request,
    required RepositoryRequestHandler next,
  }) {
    return next(
      RepositoryHttpRequest(
        url: request.url,
        method: request.method,
        body: request.body,
        headers: {...request.headers, 'X-App': 'example'},
      ),
    );
  }
}
```

When a session manager is configured, its interceptor is installed
automatically after the declared application interceptors. Token resolution
and refresh are single-flight, and an unauthorized request is replayed at most
once.

## Repository access

Repositories use authenticated access by default. Without a session they stay
pending and do not call their endpoint. Login activates existing authenticated
repositories; logout clears their in-memory data and scoped cache.

```dart
final profile = Repository<Profile, NoRepositoryActions>(
  endpoint: .relative('/profile'),
  fromJson: Profile.fromJson,
  actions: (_) => (),
);

final appVersion = Repository<AppVersion, NoRepositoryActions>(
  endpoint: .relative('/version'),
  access: .unauthenticated,
  fromJson: AppVersion.fromJson,
  actions: (_) => (),
);
```

Remote logout is optional. `signOut()` always removes local credentials and
authenticated repository data, even if a configured logout endpoint fails:

```dart
await repositories.session.signOut();
```

Cookie sessions use the same typed authentication methods and a user-supplied
`RepositoryCookieJar`:

```dart
sessionManager: .cookies(
  cookieJar: cookieJar,
  authentication: (auth) => (
    password: auth.password(
      endpoint: .relative('/auth/login'),
      body: (input) => {
        'email': input.username,
        'password': input.password,
      },
      decode: (json) => .new(identity: json['user_id'] as String?),
    ),
  ),
),
```

## Actions

Actions are typed Dart functions grouped in a named record. Their factory is
defined outside the repository and receives a `RepositoryActionExecutor`.
Each `run` receives the repository's captured `RepositoryClient` and returns
`Either<Failure, Output>` from `dartz`.

```dart
typedef TransactionActions = ({
  Future<Either<CreateFailure, Transaction>> Function(
    CreateTransaction input,
  ) create,
});

TransactionActions transactionActions(
  RepositoryActionExecutor<List<Transaction>> execute,
) {
  return (
    create: (input) => execute(
      run: (client) async {
        final response = await client.call(
          request: RepositoryHttpRequest(
            url: .relative('transactions'),
            method: RepositoryHttpMethod.post,
            body: input.toJson(),
          ),
        );

        if (response.statusCode != 201) {
          return Left(CreateFailure.fromResponse(response));
        }

        return Right(Transaction.fromJson(response.body));
      },
      update: (current, created) => [...?current, created],
    ),
  );
}

final transactions = Repository<List<Transaction>, TransactionActions>(
  endpoint: .relative('transactions'),
  fromJson: Transaction.listFromJson,
  actions: transactionActions,
);
```

`Left` is returned without changing repository data. On `Right`, the optional
`update` callback receives the current data and successful output, emits the
new optimistic state, and the same `Right` is returned to the caller.
Unexpected exceptions propagate and also skip `update`.

## Flutter

`RepositoryBuilder` infers both the data and actions types from the repository:

```dart
RepositoryBuilder(
  repository: transactions,
  builder: (context, state, actions) {
    return switch (state) {
      RepositoryStatePending() => const CircularProgressIndicator(),
      RepositoryStateReady(data: final transactions, source: final source) =>
        ElevatedButton(
          onPressed: () async {
            final result = await actions.create(input);
            result.fold(showCreateError, showCreatedTransaction);
          },
          child: Text('Create transaction (${transactions.length}, $source)'),
        ),
      RepositoryStateError(error: final error) => Text('Error: $error'),
    };
  },
);
```

The builder receives the complete `RepositoryState<Data>`, so the UI chooses
how to render pending content or ready data and retains metadata such as the
data `source`. Request activity is independent from content availability. The
actions record remains inferred from the repository type.

## Migration from the monostate API

- Call `BaseRepository.config(...)` once before creating repositories.
- Remove repeated `client:` arguments; retain them only for explicit overrides.
- Replace `Uri` request values with `.relative(...)` or `.absolute(...)`.
- Move action records into external factories that receive
  `RepositoryActionExecutor<Data>`.
- Return `Either<Failure, Output>` from every action `run`.
- Use `Repository<Data, NoRepositoryActions>` with `actions: (_) => ()` for
  repositories without custom actions.
- The second `RepositoryBuilder` callback argument is the complete
  `RepositoryState<Data>` instead of nullable data. The third argument is the
  typed actions container instead of the repository.
- Remove session mixins and repeated session dependencies. Configure a
  `RepositorySessionManager` once and mark only public repositories with
  `access: .unauthenticated`.

---

## Continuous Integration 🤖

Repository comes with a built-in [GitHub Actions workflow][github_actions_link] powered by [Very Good Workflows][very_good_workflows_link] but you can also add your preferred CI/CD solution.

Out of the box, on each pull request and push, the CI `formats`, `lints`, and `tests` the code. This ensures the code remains consistent and behaves correctly as you add functionality or make changes. The project uses [Very Good Analysis][very_good_analysis_link] for a strict set of analysis options used by our team. Code coverage is enforced using the [Very Good Workflows][very_good_coverage_link].

---

## Running Tests 🧪

To run all unit tests:

```sh
flutter test --coverage
```

To view the generated coverage report you can use [lcov](https://github.com/linux-test-project/lcov).

```sh
# Generate Coverage Report
genhtml coverage/lcov.info -o coverage/

# Open Coverage Report
open coverage/index.html
```

[github_actions_link]: https://docs.github.com/en/actions/learn-github-actions
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[logo_black]: https://raw.githubusercontent.com/VGVentures/very_good_brand/main/styles/README/vgv_logo_black.png#gh-light-mode-only
[logo_white]: https://raw.githubusercontent.com/VGVentures/very_good_brand/main/styles/README/vgv_logo_white.png#gh-dark-mode-only
[mason_link]: https://github.com/felangel/mason
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
[very_good_coverage_link]: https://github.com/marketplace/actions/very-good-coverage
[very_good_ventures_link]: https://verygood.ventures
[very_good_ventures_link_light]: https://verygood.ventures#gh-light-mode-only
[very_good_ventures_link_dark]: https://verygood.ventures#gh-dark-mode-only
[very_good_workflows_link]: https://github.com/VeryGoodOpenSource/very_good_workflows
