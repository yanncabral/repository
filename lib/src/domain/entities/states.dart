import 'package:repository/src/domain/entities/data_source.dart';

/// {@template repository_state}
/// A generic class that holds a value of the current state of the repository.
/// {@endtemplate}
abstract class RepositoryState<Data> {
  /// {@macro repository_state}
  const RepositoryState();

  /// Creates a [RepositoryState] that indicates that the repository is empty.
  const factory RepositoryState.empty({
    bool isLoading,
  }) = RepositoryStateEmpty<Data>;

  /// Creates a [RepositoryState] that indicates that the repository is ready.
  /// It contains the data loaded by the repository.
  /// It also contains the source of the data.
  const factory RepositoryState.ready({
    required Data data,
    required RepositoryDatasource source,
  }) = RepositoryStateReady<Data>;

  /// Maps the current state to a new state.
  Result map<Result>({
    required Result Function(RepositoryStateEmpty<Data> state) empty,
    required Result Function(RepositoryStateReady<Data> state) ready,
  }) {
    final self = this;

    if (self is RepositoryStateEmpty<Data>) {
      return empty(self);
    } else if (self is RepositoryStateReady<Data>) {
      return ready(self);
    } else {
      throw Exception('Unhandled Repository state $runtimeType');
    }
  }
}

/// {@template repository_state_empty}
/// A [RepositoryState] that indicates that the repository is loading data.
/// {@endtemplate}
class RepositoryStateEmpty<Data> extends RepositoryState<Data> {
  /// {@macro repository_state_empty}
  const RepositoryStateEmpty({
    this.isLoading = false,
  });

  /// Whether the repository is loading data.
  final bool isLoading;
}

/// {@template repository_state_ready}
/// A [RepositoryState] that indicates that the repository has successfully
/// loaded data.
/// {@endtemplate}
class RepositoryStateReady<Data> extends RepositoryState<Data> {
  /// {@macro repository_state_ready}
  const RepositoryStateReady({
    required this.data,
    required this.source,
  });

  /// The data loaded by the repository.
  final Data data;

  /// The source of the data.
  final RepositoryDatasource source;
}
