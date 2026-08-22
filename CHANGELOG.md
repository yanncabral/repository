## [4.0.0-dev.1] - Unreleased

* Add configurable, isolated `RepositoryClient` instances.
* Add `BaseRepository.config` for a default client captured by new repository
  instances while preserving optional per-repository overrides.
* Add base URL resolution with typed relative and absolute repository URLs.
* Add ordered `RepositoryInterceptor` middleware with replay support.
* Add external typed action factories whose runs receive `RepositoryClient`,
  return `Either`, and update repository state only on `Right`.
* Remove the legacy `mutate` interface; repository writes now use typed actions.
* Merge the Flutter integration into the main `repository` package.
* Pass the complete `RepositoryState<Data>` to `RepositoryBuilder` callbacks
  so consumers retain state metadata and handle states exhaustively.
* Model content availability as `RepositoryStatePending`,
  `RepositoryStateReady`, or `RepositoryStateError`, while preserving ready
  stale data when a background refresh fails.
* Add repository dependencies, nullable resolution, hydration coordination,
  and exception-safe fibers.
* Add multi-method HTTP requests, request bodies, mocks, token builders,
  platform-specific clients, and network-unavailable errors.
* Default requests with bodies to `Content-Type: application/json` while
  preserving explicitly provided content types.
* Make the package:http transport injectable with explicit ownership and a
  uniform client close lifecycle.
* Make `ZipRepository` react to changes from its child repositories.
* Replace the old `Repository` base class with `BaseRepository` and use
  `Repository` as the concrete HTTP implementation.

## [3.0.0] - 2023-05-22

* Major rewrite of all repository package to be more efficient and gracefully
  handle the different cache strategies, using hive as default and adding Zip repository.

## [2.0.0] - 2019-10-02

* Major rewrite of `CachedRepository` so that it returns `CacheItem<Item>`
  instead of `Item`s. This is a breaking change as it's no longer mutable.
  But it allows for cooler advanced functionality as it offers new information
  to users.

## [1.0.4] - 2019-10-01

* Add `OnlyCollectionFetcher`.

## [1.0.3] - 2019-09-13

* Major rewrite of `CachedRepository` to be more efficient and gracefully
  handle the different cache strategies as well as caches yielding multiple
  values.

## [1.0.2] - 2019-09-09

* `CachedRepository` allowing multiple cache strategies.

## [1.0.1] - 2019-09-09

* Minor fixes allowing `fetch` stream subscription to be closed after first
  event.

## [1.0.0] - 2019-09-06

* Removed unnecessary dependencies `flutter`, `hive`, `path_provider`,
  `provider` and `shared_preferences`.
* Fixed pubspec description and homepage.
* Added example.

## [0.0.1] - 2019-08-22

* Initial release with basic `Repository` and `Id` structure, as well as `InMemoryStorage`, `Transformer`, `ObjectToJsonTransformer`, `JsonToStringTransformer`, and `CachedRepository`.
