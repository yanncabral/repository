import 'package:flutter/widgets.dart';
import 'package:repository/src/base_repository.dart';
import 'package:repository/src/domain/entities/repository_state.dart';
import 'package:repository/src/repository_action.dart';

/// {@template repository_builder}
/// A package aimed at providing seamless integration between the
/// repository library and Flutter, creating a communication
/// widget between them.
/// {@endtemplate}
typedef RepositoryBuilderBuilder<
  Data,
  Actions extends RepositoryActions<Data>
> =
    Widget Function(
      BuildContext context,
      Data? snapshot,
      Actions actions,
    );

/// A widget that builds itself based on the latest state of a repository.
///
/// This widget rebuilds itself whenever the repository changes, and it
/// rebuilds its child whenever the data in the repository changes.
///
/// This widget is useful for fetching data from a repository and building a
/// widget tree based on the data.
///
/// To use this widget, you must provide a repository and a builder function.
/// The builder function is called whenever the repository changes. It is
/// passed the latest data from the repository, and it must return a widget.
///
/// If the repository is not ready, the builder function is called with a null
/// data value. This can happen when the repository has not yet fetched any
/// data, or when the repository is in an error state.
///
/// The following example shows how you might use this widget to build a list
/// of items:
///
/// ```dart
/// RepositoryBuilder(
///   repository: itemRepository,
///   builder: (context, items, actions) {
///     if (items == null) {
///      return const Center(child: CircularProgressIndicator());
///    } else {
///     return ListView(
///       children: [
///         for (var item in items)
///           ListTile(
///             title: Text(item.name),
///             subtitle: Text(item.description),
///           ),
///       ],
///     );
///   },
/// );
/// ```
class RepositoryBuilder<
  Data,
  RepositoryActionsType extends RepositoryActions<Data>
>
    extends StatelessWidget {
  /// {@macro repository_builder}
  const RepositoryBuilder({
    required this.repository,
    required this.builder,
    super.key,
  });

  /// The repository to which this widget is connected.
  /// The builder is called whenever this repository changes.
  final BaseRepository<Data, RepositoryActionsType> repository;

  /// The builder is called whenever this repository changes.
  /// It is passed the latest data from the repository, and it
  /// must return a widget.
  final RepositoryBuilderBuilder<Data, RepositoryActionsType> builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RepositoryState<Data>>(
      stream: repository.stream,
      initialData: repository.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data;

        return switch (state) {
          RepositoryStateReady(data: final data) => builder(
            context,
            data,
            repository.actions,
          ),
          _ => builder(context, null, repository.actions),
        };
      },
    );
  }
}
