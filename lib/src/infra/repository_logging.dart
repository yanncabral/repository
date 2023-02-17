/// {@template repository_logging}
/// Abstract class for logging in repositories.
/// You can use this class to create your own logger,
/// or just use the default one.
/// {@endtemplate}
abstract class RepositoryLogging {
  /// {@macro repository_logging}
  const RepositoryLogging({
    this.level = RepositoryLoggingLevel.error,
  });

  /// Defines the level of logging. Defaults to [RepositoryLoggingLevel.error].
  final RepositoryLoggingLevel level;
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
