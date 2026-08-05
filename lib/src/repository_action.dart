import 'dart:async';

import 'package:meta/meta.dart';
import 'package:repository/src/domain/entities/data_source.dart';
import 'package:repository/src/infra/repository_http_client.dart';
import 'package:repository/src/repository_client.dart';

/// Creates the typed actions exposed by a repository.
typedef RepositoryActionsFactory<
  Data,
  Actions extends RepositoryActions<Data>
> = Actions Function(RepositoryActionContext<Data> context);

/// Runs a repository action with an input value.
typedef RepositoryActionRunner<Data, Input, Output> =
    FutureOr<Output> Function(
      RepositoryActionContext<Data> context,
      Input input,
    );

/// Runs a repository action without an input value.
typedef RepositoryActionRunner0<Data, Output> =
    FutureOr<Output> Function(RepositoryActionContext<Data> context);

/// Updates repository data after an action succeeds.
typedef RepositoryActionUpdate<Data, Output> =
    FutureOr<Data> Function(Data? current, Output output);

/// Capabilities available while a repository action is running.
class RepositoryActionContext<Data> {
  /// Creates an action context.
  @internal
  const RepositoryActionContext(
    this.client,
    this._read,
    this._emit,
    this._refresh,
  );

  /// Infrastructure configured for the owning repository.
  final RepositoryClient client;

  final Data? Function() _read;
  final Future<void> Function(Data, RepositoryDatasource) _emit;
  final Future<Data?> Function() _refresh;

  /// The latest repository data.
  Data? get currentValue => _read();

  /// Executes a request through the owning [RepositoryClient].
  Future<RepositoryHttpResponse> request(RepositoryHttpRequest request) {
    return client.call(request: request);
  }

  /// Emits data produced by an action.
  Future<void> setData(
    Data data, {
    RepositoryDatasource datasource = RepositoryDatasource.optimistic,
  }) {
    return _emit(data, datasource);
  }

  /// Refreshes the owning repository.
  Future<Data?> refresh() => _refresh();
}

/// Base class for a typed collection of repository actions.
class RepositoryActions<Data> {
  /// Creates repository actions bound to [context].
  const RepositoryActions(this.context);

  /// The owning repository context.
  @protected
  final RepositoryActionContext<Data> context;

  /// Defines an action that accepts an input value.
  @protected
  RepositoryAction<Input, Output> action<Input, Output>({
    required RepositoryActionRunner<Data, Input, Output> run,
    RepositoryActionUpdate<Data, Output>? update,
  }) {
    return RepositoryAction<Input, Output>._((input) async {
      final output = await run(context, input);
      if (update != null) {
        await context.setData(await update(context.currentValue, output));
      }
      return output;
    });
  }

  /// Defines an action that does not require input.
  @protected
  RepositoryAction0<Output> action0<Output>({
    required RepositoryActionRunner0<Data, Output> run,
    RepositoryActionUpdate<Data, Output>? update,
  }) {
    return RepositoryAction0<Output>._(() async {
      final output = await run(context);
      if (update != null) {
        await context.setData(await update(context.currentValue, output));
      }
      return output;
    });
  }
}

/// A callable repository action that accepts [Input].
class RepositoryAction<Input, Output> {
  const RepositoryAction._(this._run);

  final Future<Output> Function(Input input) _run;

  /// Executes the action.
  Future<Output> call(Input input) => _run(input);
}

/// A callable repository action without input.
class RepositoryAction0<Output> {
  const RepositoryAction0._(this._run);

  final Future<Output> Function() _run;

  /// Executes the action.
  Future<Output> call() => _run();
}
