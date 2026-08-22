import 'package:equatable/equatable.dart';
import 'package:repository/src/domain/entities/data_source.dart';

/// {@template repository_state}
/// A generic class that holds a value of the current state of the repository.
/// {@endtemplate}
sealed class RepositoryState<Data> extends Equatable {
  /// {@macro repository_state}
  const RepositoryState();

  /// Creates a [RepositoryState] that indicates that content is not available
  /// yet.
  const factory RepositoryState.pending() = RepositoryStatePending<Data>;

  /// Creates a [RepositoryState] that indicates that the repository is ready.
  /// It contains the data loaded by the repository.
  /// It also contains the source of the data.
  const factory RepositoryState.ready({
    required Data data,
    required RepositoryDatasource source,
  }) = RepositoryStateReady<Data>;

  /// Returns the value of the current state of the repository.
  /// It can be either [RepositoryStatePending] or [RepositoryStateReady].
  /// It throws an [Exception] if the state is not handled.
  ///
  /// The [map] method is useful when you want to handle the state of the
  /// repository. For example you can map pending state to a loading
  /// indicator and ready state to a list of items.
  Result? map<Result>({
    required Result Function(RepositoryStateReady<Data> state) ready,
    Result? Function(RepositoryStatePending<Data> state)? pending,
  }) {
    final self = this;

    return switch (self) {
      RepositoryStatePending<Data> _ => pending?.call(self),
      RepositoryStateReady<Data> _ => ready.call(self),
    };
  }
}

/// {@template repository_state_pending}
/// A [RepositoryState] that indicates that content is not available yet.
/// {@endtemplate}
class RepositoryStatePending<Data> extends RepositoryState<Data> {
  /// {@macro repository_state_pending}
  const RepositoryStatePending();

  @override
  List<Object?> get props => [Data.runtimeType];
}

/// {@template repository_state_ready}
/// A [RepositoryState] that indicates that the repository has successfully
/// loaded data.
/// {@endtemplate}
class RepositoryStateReady<Data> extends RepositoryState<Data> {
  /// {@macro repository_state_ready}
  const RepositoryStateReady({required this.data, required this.source});

  /// The data loaded by the repository.
  final Data data;

  /// The source of the data.
  final RepositoryDatasource source;

  @override
  List<Object?> get props => [data, source, Data.runtimeType];
}
