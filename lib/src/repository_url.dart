import 'package:meta/meta.dart';

/// A URL used by repository requests.
@immutable
sealed class RepositoryUrl {
  const RepositoryUrl(this.value);

  /// Creates a URL resolved against `RepositoryClient.baseUrl`.
  const factory RepositoryUrl.relative(String value) = RepositoryRelativeUrl;

  /// Creates an absolute URL that ignores `RepositoryClient.baseUrl`.
  const factory RepositoryUrl.absolute(String value) = RepositoryAbsoluteUrl;

  /// The URL text supplied by the caller.
  final String value;

  /// Resolves this value using [baseUrl] when it is relative.
  Uri resolve(Uri? baseUrl);

  @override
  bool operator ==(Object other) {
    return other.runtimeType == runtimeType &&
        other is RepositoryUrl &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => value;
}

/// A URL resolved against the configured base URL.
final class RepositoryRelativeUrl extends RepositoryUrl {
  /// Creates a relative repository URL.
  const RepositoryRelativeUrl(super.value);

  @override
  Uri resolve(Uri? baseUrl) {
    if (baseUrl == null) {
      throw StateError(
        'RepositoryClient.baseUrl is required for relative URLs.',
      );
    }
    if (!baseUrl.isAbsolute || !baseUrl.hasAuthority) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'Expected an absolute base URL.',
      );
    }
    final relative = Uri.parse(value);
    if (relative.isAbsolute) {
      throw ArgumentError.value(value, 'value', 'Expected a relative URL.');
    }
    return baseUrl.resolveUri(relative);
  }
}

/// A URL that is independent from the configured base URL.
final class RepositoryAbsoluteUrl extends RepositoryUrl {
  /// Creates an absolute repository URL.
  const RepositoryAbsoluteUrl(super.value);

  @override
  Uri resolve(Uri? baseUrl) {
    final absolute = Uri.parse(value);
    if (!absolute.isAbsolute || !absolute.hasAuthority) {
      throw ArgumentError.value(value, 'value', 'Expected an absolute URL.');
    }
    return absolute;
  }
}
