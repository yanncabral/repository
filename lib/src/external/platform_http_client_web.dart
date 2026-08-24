import 'package:http/http.dart' as http;
import 'package:repository/src/external/http_repository_http_client.dart';
import 'package:repository/src/infra/repository_http_client.dart';

/// Creates the standard HTTP adapter for web builds.
RepositoryHttpClient createPlatformHttpClient({
  TokenBuilder? tokenBuilder,
  http.Client? client,
  bool closeClient = false,
}) => HttpRepositoryHttpClient(
  client: client,
  closeClient: closeClient,
  tokenBuilder: tokenBuilder,
);
