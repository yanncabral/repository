import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:repository/src/external/cupertino_http_repository_http_client.dart';
import 'package:repository/src/external/http_repository_http_client.dart';
import 'package:repository/src/infra/repository_http_client.dart';

/// Creates the Cupertino adapter on iOS and the standard adapter elsewhere.
///
/// An injected [client] always selects the standard adapter.
RepositoryHttpClient createPlatformHttpClient({
  TokenBuilder? tokenBuilder,
  http.Client? client,
  bool closeClient = false,
}) {
  if (client != null) {
    return HttpRepositoryHttpClient(
      client: client,
      closeClient: closeClient,
      tokenBuilder: tokenBuilder,
    );
  }

  return Platform.isIOS
      ? CupertinoHttpRepositoryHttpClient(tokenBuilder: tokenBuilder)
      : HttpRepositoryHttpClient(tokenBuilder: tokenBuilder);
}
