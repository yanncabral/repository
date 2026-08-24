import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:repository/src/repository_client.dart';

/// The actions type used by repositories without custom operations.
typedef NoRepositoryActions = ();

/// Runs an action using the repository's configured client.
typedef RepositoryActionRun<Failure, Output> =
    FutureOr<Either<Failure, Output>> Function(RepositoryClient client);

/// Executes an action and applies its successful output to repository data.
typedef RepositoryActionExecutor<Data> =
    Future<Either<Failure, Output>> Function<Failure, Output>({
      required RepositoryActionRun<Failure, Output> run,
      FutureOr<Data> Function(Data? current, Output output)? update,
    });

/// Creates the typed actions exposed by a repository.
typedef RepositoryActionsFactory<Data, Actions> =
    Actions Function(RepositoryActionExecutor<Data> execute);
