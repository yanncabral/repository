import 'package:repository/src/infra/repository_http_client.dart';

/// Executes the next step in a repository HTTP request pipeline.
typedef RepositoryRequestHandler =
    Future<RepositoryHttpResponse> Function(
      RepositoryHttpRequest request,
    );

/// Intercepts repository HTTP requests and responses.
// This is an extension seam with production and test adapters.
// ignore: one_member_abstracts
abstract interface class RepositoryInterceptor {
  /// Handles [request] and delegates to [next] when appropriate.
  Future<RepositoryHttpResponse> intercept({
    required RepositoryHttpRequest request,
    required RepositoryRequestHandler next,
  });
}
