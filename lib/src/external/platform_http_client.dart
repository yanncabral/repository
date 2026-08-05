import 'package:repository/src/external/platform_http_client_io.dart'
    if (dart.library.js_interop) 'platform_http_client_web.dart'
    as impl;
import 'package:repository/src/infra/repository_http_client.dart';

RepositoryHttpClient createPlatformHttpClient({TokenBuilder? tokenBuilder}) =>
    impl.createPlatformHttpClient(tokenBuilder: tokenBuilder);
