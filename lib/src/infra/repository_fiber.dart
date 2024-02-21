import 'dart:async';

/// {@template fiber}
/// A fiber is a class that ensures that only one async function is running at
/// a time.
/// {@endtemplate}
class RepositoryFiber<Data> {
  /// {@macro fiber}
  RepositoryFiber();

  Completer<Data>? _completer;

  /// Runs an async function and returns a [Future] that completes with the
  /// result of the function. If there is already a running async function,
  /// it will wait for it to complete. If there is no running async function,
  /// it will run the function and complete the [Future].
  Future<Data> run(Future<Data> Function() fn) async {
    if (_completer != null && _completer?.isCompleted == false) {
      // If there is a completer and completer is not completed, wait for it.

      return _completer!.future;
    } else {
      // If there is no completer or completer is completed, create a new one.
      _completer = Completer();
      try {
        final response = await fn();
        _completer!.complete(response);

        return response;
      } catch (e) {
        _completer!.completeError(e, StackTrace.current);
        rethrow;
      }
    }
  }
}
