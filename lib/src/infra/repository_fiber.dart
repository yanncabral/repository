import 'dart:async';
import 'dart:developer';

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
    return _completer?.isCompleted == false;
  }

  /// Runs an async function and returns a `Future` that
  /// completes with the result of the function.
  /// If there is already a running async function, it will
  /// wait for it to complete.
  /// If there is no running async function, it will run the
  /// function and complete the `Future`.
  Future<Data> run(Future<Data> Function() fn, {String? name}) async {
    log('[RepositoryFiber] Running fiber $name');
    final currentCompleter = _completer;

    if (currentCompleter != null && !currentCompleter.isCompleted) {
      return currentCompleter.future;
    }

    log('[RepositoryFiber] Creating new completer for $name');
    final newCompleter = Completer<Data>();
    _completer = newCompleter;

    try {
      log('[RepositoryFiber] Executing function $name');
      final response = await fn();
      log('[RepositoryFiber] Completing completer for $name');
      newCompleter.complete(response);
      return response;
    } catch (e, stackTrace) {
      log('[RepositoryFiber] Completing completer with error for $name');
      newCompleter.completeError(e, stackTrace);
      rethrow;
    } finally {
      log('[RepositoryFiber] Completing fiber $name');
      _completer = null;
    }
  }
}
