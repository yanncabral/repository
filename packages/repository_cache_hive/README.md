# repository_cache_hive

Hive cache storage for [`package:repository`](https://pub.dev/packages/repository).

```dart
import 'package:repository/repository.dart';
import 'package:repository_cache_hive/repository_cache_hive.dart';

BaseRepository.config<NoRepositoryAuthentication>(
  baseUrl: Uri.parse('https://api.example.com'),
  httpClient: createPlatformHttpClient(),
  storage: await HiveRepositoryCacheStorage.create(),
);
```

The adapter stores serialized repository values in a `Box<String>`. Pass an
existing box to control its location, encryption, and lifecycle:

```dart
final storage = HiveRepositoryCacheStorage(box: box);
```
