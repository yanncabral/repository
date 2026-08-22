import 'package:http/http.dart' as http;
import 'package:repository/src/external/platform_http_client_io.dart'
    if (dart.library.js_interop) 'platform_http_client_web.dart'
    as impl;
import 'package:repository/src/infra/repository_http_client.dart';

/// Creates the default HTTP adapter for the current platform.
///
/// When [client] is provided, the standard package:http adapter is used on
/// every platform. The injected client remains caller-owned unless
/// [closeClient] is true.
RepositoryHttpClient createPlatformHttpClient({
  TokenBuilder? tokenBuilder,
  http.Client? client,
  bool closeClient = false,
}) => impl.createPlatformHttpClient(
  tokenBuilder: tokenBuilder,
  client: client,
  closeClient: closeClient,
);
