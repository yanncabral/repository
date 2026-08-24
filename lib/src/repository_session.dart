import 'dart:async';
import 'dart:convert';

/// Controls whether a repository uses the configured session.
enum RepositoryAccess {
  /// Waits for a session and sends authenticated requests.
  authenticated,

  /// Sends requests without requiring a session.
  unauthenticated,
}

/// Base type for sessions managed by the repository runtime.
sealed class RepositorySession {
  /// Creates a repository session.
  const RepositorySession();

  /// Stable identity used to isolate cached repository data.
  String? get subject;
}

/// A session applied through the `Authorization: Bearer` header.
final class RepositorySessionBearer extends RepositorySession {
  /// Creates a bearer session.
  const RepositorySessionBearer({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this._subject,
  });

  /// Token sent to authenticated endpoints.
  final String accessToken;

  /// Token used to renew the session, when supported by the backend.
  final String? refreshToken;

  /// Explicit expiration for opaque tokens.
  ///
  /// When omitted, the manager attempts to read the JWT `exp` claim.
  final DateTime? expiresAt;

  final String? _subject;

  @override
  String? get subject => _subject ?? _jwtStringClaim(accessToken, 'sub');

  /// Expiration supplied explicitly or decoded from the JWT `exp` claim.
  DateTime? get resolvedExpiresAt {
    if (expiresAt case final expiration?) {
      return expiration;
    }
    final seconds = _jwtIntClaim(accessToken, 'exp');
    return seconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }
}

/// A session whose credentials are maintained by a cookie jar.
final class RepositorySessionCookies extends RepositorySession {
  /// Creates a cookie-backed session marker.
  const RepositorySessionCookies({this.identity});

  /// Stable identity associated with the cookie session, when known.
  final String? identity;

  @override
  String? get subject => identity;
}

/// Input passed to a password request body mapper.
final class CreateSessionWithPassword {
  /// Creates password credentials.
  const CreateSessionWithPassword({
    required this.username,
    required this.password,
  });

  /// Login identifier supplied by the caller.
  final String username;

  /// Password supplied by the caller.
  final String password;
}

/// Input passed to a refresh request body mapper.
final class RefreshSession<Session extends RepositorySession> {
  /// Creates a refresh input.
  const RefreshSession(this.session);

  /// Current session being renewed.
  final Session session;
}

/// Input passed to an optional remote logout body mapper.
final class SignOutSession<Session extends RepositorySession> {
  /// Creates a logout input.
  const SignOutSession(this.session);

  /// Session being closed.
  final Session session;
}

/// Input passed to the first step of a passwordless code flow.
final class RequestPasswordlessCode {
  /// Creates a passwordless request.
  const RequestPasswordlessCode({required this.username});

  /// Identifier that should receive the code.
  final String username;
}

/// Input passed to the verification step of a passwordless code flow.
final class VerifyPasswordlessCode<Challenge> {
  /// Creates a passwordless verification input.
  const VerifyPasswordlessCode({
    required this.challenge,
    required this.code,
  });

  /// Typed value returned by the request-code endpoint.
  final Challenge challenge;

  /// Code supplied by the caller.
  final String code;
}

/// A JSON object returned by an authentication endpoint.
typedef RepositoryAuthenticationJson = Map<String, Object?>;

/// Maps a typed operation input into a JSON request body.
typedef RepositoryAuthenticationBody<Input> =
    Map<String, dynamic> Function(Input input);

/// Maps an endpoint response into its typed result.
typedef RepositoryAuthenticationDecoder<Output> =
    FutureOr<Output> Function(RepositoryAuthenticationJson json);

/// Maps a refresh response and current session into a replacement session.
typedef RepositoryRefreshDecoder<Session extends RepositorySession> =
    FutureOr<Session> Function(
      RepositoryAuthenticationJson json,
      Session current,
    );

/// Persistence dedicated to authentication credentials.
///
/// Implementations should use secure platform storage in production.
abstract interface class RepositorySessionStorage {
  /// Reads the serialized session, or `null` when none exists.
  Future<String?> read();

  /// Atomically replaces the serialized session.
  Future<void> write(String value);

  /// Removes the serialized session.
  Future<void> delete();
}

/// Volatile session storage useful for tests and non-persistent sessions.
final class InMemoryRepositorySessionStorage
    implements RepositorySessionStorage {
  String? _value;

  @override
  Future<void> delete() async => _value = null;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async => _value = value;
}

/// Cookie persistence and request integration used by `.cookies()` sessions.
abstract interface class RepositoryCookieJar {
  /// Returns cookie headers for [uri].
  Future<Map<String, String>> requestHeaders(Uri uri);

  /// Stores cookies received from [uri].
  Future<void> storeResponseHeaders(Uri uri, Map<String, String> headers);

  /// Returns whether the jar currently contains an authenticated session.
  Future<bool> get hasSession;

  /// Removes all locally persisted cookies.
  Future<void> clear();
}

/// Public state exposed by a repository session manager.
sealed class RepositorySessionState {
  const RepositorySessionState();

  /// The persisted session is still being resolved.
  const factory RepositorySessionState.pending() =
      RepositorySessionStatePending;

  /// No authenticated session is available.
  const factory RepositorySessionState.unauthenticated() =
      RepositorySessionStateUnauthenticated;

  /// A usable authenticated session is available.
  const factory RepositorySessionState.authenticated(
    RepositorySession session,
  ) = RepositorySessionStateAuthenticated;

  /// Resolving the persisted session failed.
  const factory RepositorySessionState.error(Object error) =
      RepositorySessionStateError;
}

/// The persisted session is still being resolved.
final class RepositorySessionStatePending extends RepositorySessionState {
  /// Creates a pending state.
  const RepositorySessionStatePending();
}

/// No authenticated session is available.
final class RepositorySessionStateUnauthenticated
    extends RepositorySessionState {
  /// Creates an unauthenticated state.
  const RepositorySessionStateUnauthenticated();
}

/// A usable authenticated session is available.
final class RepositorySessionStateAuthenticated extends RepositorySessionState {
  /// Creates an authenticated state.
  const RepositorySessionStateAuthenticated(this.session);

  /// Current session.
  final RepositorySession session;
}

/// Resolving the persisted session failed.
final class RepositorySessionStateError extends RepositorySessionState {
  /// Creates a session resolution error state.
  const RepositorySessionStateError(this.error);

  /// Resolution failure.
  final Object error;
}

/// Describes a change that affects authenticated repository data.
enum RepositorySessionChange {
  /// A session became available.
  authenticated,

  /// The current session was renewed without changing identity.
  refreshed,

  /// The session was removed.
  signedOut,

  /// The authenticated identity changed.
  identityChanged,
}

/// Internal seam used by clients and repositories without depending on a
/// concrete session manager.
abstract interface class RepositorySessionRuntime {
  /// Current lifecycle generation.
  int get generation;

  /// Namespace used to isolate authenticated cache entries.
  String? get cacheNamespace;

  /// Session lifecycle events.
  Stream<RepositorySessionChange> get changes;

  /// Resolves persisted credentials and reports whether requests may proceed.
  Future<bool> canAccess();
}

Map<String, Object?>? _jwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    return null;
  }
  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final payload = jsonDecode(decoded);
    if (payload is Map<String, dynamic>) {
      return payload;
    }
  } on Object {
    return null;
  }
  return null;
}

String? _jwtStringClaim(String token, String name) {
  final value = _jwtPayload(token)?[name];
  return value is String ? value : null;
}

int? _jwtIntClaim(String token, String name) {
  final value = _jwtPayload(token)?[name];
  return switch (value) {
    int() => value,
    num() => value.toInt(),
    _ => null,
  };
}
