import 'package:repository/src/infra/repository_cache_storage.dart';
import 'package:repository/src/infra/repository_http_client.dart';
import 'package:repository/src/infra/repository_logger.dart';
import 'package:repository/src/repository_interceptor.dart';
import 'package:repository/src/repository_session.dart';

/// Configures the shared infrastructure used by repositories.
class RepositoryClient {
  /// Creates a repository client.
  const RepositoryClient({
    required this.httpClient,
    required this.storage,
    this.baseUrl,
    this.logger = const RepositoryLogger.dev(),
    this.interceptors = const [],
    this.sessionRuntime,
  });

  /// The base URL used to resolve relative repository URLs.
  final Uri? baseUrl;

  /// The HTTP adapter used to execute requests.
  final RepositoryHttpClient httpClient;

  /// The cache adapter used to hydrate and persist repository data.
  final RepositoryCacheStorage storage;

  /// The logger used by repositories managed by this client.
  final RepositoryLogger logger;

  /// Middleware applied to every HTTP request in declaration order.
  final List<RepositoryInterceptor> interceptors;

  /// Session lifecycle used by this authenticated client.
  final RepositorySessionRuntime? sessionRuntime;

  /// Whether an authenticated repository request may currently run.
  Future<bool> canAccess() => sessionRuntime?.canAccess() ?? Future.value(true);

  /// Current session generation, used to reject stale asynchronous work.
  int get sessionGeneration => sessionRuntime?.generation ?? 0;

  /// Returns the cache key scoped to the current authenticated identity.
  String cacheKey(String key) {
    final runtime = sessionRuntime;
    if (runtime == null) {
      return key;
    }
    final namespace =
        runtime.cacheNamespace ?? 'generation-${runtime.generation}';
    return 'session:$namespace:$key';
  }

  /// Executes an HTTP request using the configured adapter.
  Future<RepositoryHttpResponse> call({
    required RepositoryHttpRequest request,
  }) {
    final resolvedRequest = request.resolveUrl(baseUrl);
    var handler = (RepositoryHttpRequest currentRequest) {
      return httpClient.call(request: currentRequest);
    };

    for (final interceptor in interceptors.reversed) {
      final next = handler;
      handler = (currentRequest) {
        return interceptor.intercept(request: currentRequest, next: next);
      };
    }

    return handler(resolvedRequest);
  }

  /// Releases resources owned by the configured HTTP adapter.
  void close() => httpClient.close();
}
