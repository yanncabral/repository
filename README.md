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

Install it:

```sh
flutter pub get
```

## Configure a client

`RepositoryClient` owns the infrastructure shared by a group of repositories.
Create separate clients when repositories must not share transport, cache,
logging, or interceptors.

```dart
final client = RepositoryClient(
  httpClient: createPlatformHttpClient(),
  storage: await HiveRepositoryCacheStorage.create(),
  interceptors: [
    authenticationInterceptor,
  ],
);
```

Every repository receives its client explicitly:

```dart
final repository = Repository<int, RepositoryActions<int>>(
  client: client,
  endpoint: Uri.parse('https://example.com/count'),
  fromJson: int.parse,
  actions: RepositoryActions.new,
);
```

`RepositoryActions<Data>` is the empty actions container for read-only
repositories.

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

Authentication remains application-specific. A session interceptor can read
the current token, refresh the session on `401`, and replay once. This keeps
authentication consistent for repository refreshes and custom actions.

## Actions

Actions are named, typed operations bound to a repository. An action may make
zero, one, or several requests, and can update the repository only after it
succeeds. It is therefore an orchestration abstraction, not a subtype of
`RepositoryHttpRequest`.

```dart
class TransactionActions extends RepositoryActions<List<Transaction>> {
  TransactionActions(super.context);

  late final RepositoryAction<CreateTransaction, Transaction>
  createNewTransaction = action(
    run: (context, input) async {
      final response = await context.request(
        RepositoryHttpRequest(
          url: Uri.parse('https://example.com/transactions'),
          method: RepositoryHttpMethod.post,
          body: input.toJson(),
        ),
      );
      return Transaction.fromJson(response.body);
    },
    update: (current, created) => [...?current, created],
  );
}

final transactions = Repository<List<Transaction>, TransactionActions>(
  client: client,
  endpoint: Uri.parse('https://example.com/transactions'),
  fromJson: Transaction.listFromJson,
  actions: TransactionActions.new,
);
```

Actions without input use `RepositoryAction0<Output>`, which is useful for
operations such as logout or refresh commands.

## Flutter

`RepositoryBuilder` infers both the data and actions types from the repository:

```dart
RepositoryBuilder(
  repository: transactions,
  builder: (context, data, actions) {
    if (data == null) {
      return const CircularProgressIndicator();
    }

    return ElevatedButton(
      onPressed: () => actions.createNewTransaction(input),
      child: const Text('Create transaction'),
    );
  },
);
```

## Migration from the monostate API

- Replace `BaseRepository.storage` and `BaseRepository.logger` configuration
  with a `RepositoryClient` instance.
- Pass `client:` and `actions:` when declaring a repository.
- Use `Repository<Data, RepositoryActions<Data>>` for repositories without
  custom actions.
- The third `RepositoryBuilder` callback argument is now the typed actions
  container instead of the repository.
- Move request-wide authentication and retry behavior from repository mixins
  into a `RepositoryInterceptor`. A thin session mixin may still gate refresh
  and declare reactive session dependencies.

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
