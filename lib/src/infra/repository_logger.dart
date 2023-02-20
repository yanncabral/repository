/// {@template repository_logging}
/// Abstract class for logging in repositories.
/// You can use this class to create your own logger,
/// or just use the default one.
/// {@endtemplate}
abstract class RepositoryLogger {
  /// {@macro repository_logging}
  const RepositoryLogger({
    this.level = RepositoryLoggingLevel.error,
  });

  /// Defines the level of logging. Defaults to [RepositoryLoggingLevel.error].
  final RepositoryLoggingLevel level;

  /// Logs a message.
  /// The level of logging is defined by [level].
  /// If [level] is [RepositoryLoggingLevel.none], nothing will be logged.
  ///
  /// If [level] is [RepositoryLoggingLevel.error], only errors will be logged.
  ///
  /// If [level] is [RepositoryLoggingLevel.warning],
  /// errors and warnings will be logged.
  ///
  /// If [level] is [RepositoryLoggingLevel.info],
  /// errors, warnings and info will be logged.
  ///
  /// If [level] is [RepositoryLoggingLevel.debug], it's always logged.
  void call(
    String message, {
    RepositoryLoggingLevel level = RepositoryLoggingLevel.info,
  });
}

/// {@template repository_logging_level}
/// The level of logging.
/// {@endtemplate}
enum RepositoryLoggingLevel {
  /// Log nothing
  none,

  /// Log only errors
  error,

  /// Log errors and warnings
  warning,

  /// Log errors, warnings and info
  info,

  /// Log errors, warnings, info and debug
  debug,
}
