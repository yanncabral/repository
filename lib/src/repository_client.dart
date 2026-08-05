import 'package:repository/src/infra/repository_cache_storage.dart';
import 'package:repository/src/infra/repository_http_client.dart';
import 'package:repository/src/infra/repository_logger.dart';

/// Configures the shared infrastructure used by repositories.
class RepositoryClient {
  /// Creates a repository client.
  const RepositoryClient({
    required this.httpClient,
    required this.storage,
    this.logger = const RepositoryLogger.dev(),
  });

  /// The HTTP adapter used to execute requests.
  final RepositoryHttpClient httpClient;

  /// The cache adapter used to hydrate and persist repository data.
  final RepositoryCacheStorage storage;

  /// The logger used by repositories managed by this client.
  final RepositoryLogger logger;

  /// Executes an HTTP request using the configured adapter.
  Future<RepositoryHttpResponse> call({
    required RepositoryHttpRequest request,
  }) {
    return httpClient.call(request: request);
  }
}
