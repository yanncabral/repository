import 'dart:io';

import 'package:repository/src/external/cupertino_http_repository_http_client.dart';
import 'package:repository/src/external/http_repository_http_client.dart';
import 'package:repository/src/infra/repository_http_client.dart';

/// Creates the Cupertino adapter on iOS and the standard adapter elsewhere.
RepositoryHttpClient createPlatformHttpClient({TokenBuilder? tokenBuilder}) =>
    Platform.isIOS
    ? CupertinoHttpRepositoryHttpClient(tokenBuilder: tokenBuilder)
    : HttpRepositoryHttpClient(tokenBuilder: tokenBuilder);
