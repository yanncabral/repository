import 'dart:async';

/// {@template fiber}
/// A fiber is a class that ensures that only
/// one async function is running at a time.
/// {@endtemplate}
class RepositoryFiber<Data> {
  /// {@macro fiber}
  RepositoryFiber();

  /// The completer that completes when the async function is done.
  Completer<Data>? _completer;

  /// Returns true if there is one or more async functions running.
  bool get isBusy {
    return _completer != null && _completer?.isCompleted == false;
  }

  /// Runs an async function and returns a `Future` that
  /// completes with the result of the function.
  /// If there is already a running async function, it will
  /// wait for it to complete.
  /// If there is no running async function, it will run the
  /// function and complete the `Future`.
  Future<Data> run(Future<Data> Function() fn) async {
    if (isBusy) {
      // If there is a completer and completer is not completed, wait for it.

      return _completer!.future;
    } else {
      // If there is no completer or completer is completed, create a new one.
      _completer = Completer();
      final response = await fn();
      _completer!.complete(response);

      return response;
    }
  }
}
