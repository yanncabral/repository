import 'package:repository/src/external/http_repository_http_client.dart';
import 'package:repository/src/infra/repository_http_client.dart';

RepositoryHttpClient createPlatformHttpClient({TokenBuilder? tokenBuilder}) =>
    HttpRepositoryHttpClient(tokenBuilder: tokenBuilder);
