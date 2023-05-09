import 'package:equatable/equatable.dart';
import 'package:repository/src/domain/entities/data_source.dart';

/// {@template repository_state}
/// A generic class that holds a value of the current state of the repository.
/// {@endtemplate}
abstract class RepositoryState<Data> extends Equatable {
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

  /// Returns the value of the current state of the repository.
  /// It can be either [RepositoryStateEmpty] or [RepositoryStateReady].
  /// It throws an [Exception] if the state is not handled.
  ///
  /// The [map] method is useful when you want to handle the state of the
  /// repository. For example you can map empty state to a loading
  /// indicator and ready state to a list of items.
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

  @override
  List<Object?> get props => [isLoading, Data.runtimeType];
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

  @override
  List<Object?> get props => [data, source, Data.runtimeType];
}
