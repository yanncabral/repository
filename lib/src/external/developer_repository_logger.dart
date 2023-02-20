import 'dart:developer';

import 'package:repository/src/infra/repository_logger.dart';

/// {@template default_repository_logger}
/// A [RepositoryLogger] that uses `dart:developer` to log messages.
/// This is the default logger used by `Repository`.
/// It's not recommended to use this logger in production.
/// {@endtemplate}
class DefaultRepositoryLogger extends RepositoryLogger {
  /// {@macro default_repository_logger}
  const DefaultRepositoryLogger();

  @override
  void call(
    String message, {
    RepositoryLoggingLevel level = RepositoryLoggingLevel.info,
  }) {
    log(message);
  }
}
