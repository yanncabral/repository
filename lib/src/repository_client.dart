import 'package:repository/src/infra/repository_cache_storage.dart';
import 'package:repository/src/infra/repository_http_client.dart';
import 'package:repository/src/infra/repository_logger.dart';
import 'package:repository/src/repository_interceptor.dart';

/// Configures the shared infrastructure used by repositories.
class RepositoryClient {
  /// Creates a repository client.
  const RepositoryClient({
    required this.httpClient,
    required this.storage,
    this.logger = const RepositoryLogger.dev(),
    this.interceptors = const [],
  });

  /// The HTTP adapter used to execute requests.
  final RepositoryHttpClient httpClient;

  /// The cache adapter used to hydrate and persist repository data.
  final RepositoryCacheStorage storage;

  /// The logger used by repositories managed by this client.
  final RepositoryLogger logger;

  /// Middleware applied to every HTTP request in declaration order.
  final List<RepositoryInterceptor> interceptors;

  /// Executes an HTTP request using the configured adapter.
  Future<RepositoryHttpResponse> call({
    required RepositoryHttpRequest request,
  }) {
    var handler = (RepositoryHttpRequest currentRequest) {
      return httpClient.call(request: currentRequest);
    };

    for (final interceptor in interceptors.reversed) {
      final next = handler;
      handler = (currentRequest) {
        return interceptor.intercept(request: currentRequest, next: next);
      };
    }

    return handler(request);
  }
}
