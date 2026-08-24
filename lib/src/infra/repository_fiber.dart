import 'dart:async';
import 'dart:developer';

/// {@template fiber}
/// A fiber is a class that ensures that only
/// one async function is running at a time.
/// {@endtemplate}
class RepositoryFiber<Data> {
  /// {@macro fiber}
  RepositoryFiber();

  /// The operation currently shared by all callers.
  Future<Data>? _operation;

  /// Returns true if there is one or more async functions running.
  bool get isBusy => _operation != null;

  /// Runs an async function and returns a `Future` that
  /// completes with the result of the function.
  /// If there is already a running async function, it will
  /// wait for it to complete.
  /// If there is no running async function, it will run the
  /// function and complete the `Future`.
  Future<Data> run(Future<Data> Function() fn, {String? name}) {
    log('[RepositoryFiber] Running fiber $name');
    final currentOperation = _operation;

    if (currentOperation != null) {
      return currentOperation;
    }

    log('[RepositoryFiber] Creating new operation for $name');
    late final Future<Data> operation;
    operation = Future<Data>.sync(fn).whenComplete(() {
      log('[RepositoryFiber] Completing fiber $name');
      if (identical(_operation, operation)) {
        _operation = null;
      }
    });
    _operation = operation;
    return operation;
  }
}
