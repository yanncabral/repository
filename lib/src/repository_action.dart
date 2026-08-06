import 'dart:async';

import 'package:repository/src/infra/repository_http_client.dart';

/// The actions type used by repositories without custom operations.
typedef NoRepositoryActions = ();

/// Creates the typed actions exposed by a directly instantiated repository.
typedef RepositoryActionsFactory<Actions> = Actions Function();

/// Decides whether an action request response is successful.
typedef RepositoryResponseCondition =
    FutureOr<bool> Function(RepositoryHttpResponse response);
