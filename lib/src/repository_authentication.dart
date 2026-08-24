import 'dart:async';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:repository/src/infra/repository_http_client.dart';
import 'package:repository/src/repository_client.dart';
import 'package:repository/src/repository_interceptor.dart';
import 'package:repository/src/repository_session.dart';
import 'package:repository/src/repository_url.dart';

/// Empty authentication surface used by configurations without a manager.
typedef NoRepositoryAuthentication = ();

/// A typed authentication failure returned by session operations.
sealed class RepositoryAuthenticationFailure {
  const RepositoryAuthenticationFailure();
}

/// An authentication endpoint returned a non-successful status code.
final class RepositoryAuthenticationHttpFailure
    extends RepositoryAuthenticationFailure {
  /// Creates an HTTP authentication failure.
  const RepositoryAuthenticationHttpFailure(this.response);

  /// Received response.
  final RepositoryHttpResponse response;
}

/// Sending or decoding an authentication request failed.
final class RepositoryAuthenticationUnexpectedFailure
    extends RepositoryAuthenticationFailure {
  /// Creates an unexpected authentication failure.
  const RepositoryAuthenticationUnexpectedFailure(this.error, this.stackTrace);

  /// Original failure.
  final Object error;

  /// Original stack trace.
  final StackTrace stackTrace;
}

/// A request attempted to use authenticated access without a session.
final class RepositoryAuthenticationRequiredException implements Exception {
  /// Creates an authentication-required exception.
  const RepositoryAuthenticationRequiredException();

  @override
  String toString() => 'No repository session is available.';
}

/// HTTP operation whose response is decoded into [Output].
final class RepositoryAuthenticationRequest<Input, Output> {
  const RepositoryAuthenticationRequest._({
    required this.endpoint,
    required this.method,
    required this.body,
    required this.decode,
  });

  /// Creates a POST authentication operation.
  const RepositoryAuthenticationRequest.post({
    required this.endpoint,
    required this.body,
    required this.decode,
  }) : method = RepositoryHttpMethod.post;

  /// Creates a PUT authentication operation.
  const RepositoryAuthenticationRequest.put({
    required this.endpoint,
    required this.body,
    required this.decode,
  }) : method = RepositoryHttpMethod.put;

  /// Endpoint called by this operation.
  final RepositoryUrl endpoint;

  /// HTTP method called by this operation.
  final RepositoryHttpMethod method;

  /// Maps typed input into the endpoint JSON body.
  final RepositoryAuthenticationBody<Input> body;

  /// Maps the endpoint JSON response into its typed result.
  final RepositoryAuthenticationDecoder<Output> decode;
}

/// Configuration for a session refresh endpoint.
final class RepositorySessionRefresh<Session extends RepositorySession> {
  /// Creates a POST refresh operation.
  const RepositorySessionRefresh.post({
    required this.endpoint,
    required this.body,
    required this.decode,
  }) : method = RepositoryHttpMethod.post;

  /// Creates a PUT refresh operation.
  const RepositorySessionRefresh.put({
    required this.endpoint,
    required this.body,
    required this.decode,
  }) : method = RepositoryHttpMethod.put;

  /// Endpoint called to renew the session.
  final RepositoryUrl endpoint;

  /// HTTP method called to renew the session.
  final RepositoryHttpMethod method;

  /// Maps the current session into the refresh request body.
  final RepositoryAuthenticationBody<RefreshSession<Session>> body;

  /// Maps the response and previous value into one complete replacement.
  final RepositoryRefreshDecoder<Session> decode;
}

/// Optional remote logout request.
final class RepositorySessionLogout<Session extends RepositorySession> {
  /// Creates a POST logout operation.
  const RepositorySessionLogout.post({required this.endpoint, this.body})
    : method = RepositoryHttpMethod.post;

  /// Creates a DELETE logout operation.
  const RepositorySessionLogout.delete({required this.endpoint, this.body})
    : method = RepositoryHttpMethod.delete;

  /// Endpoint called before local credentials are removed.
  final RepositoryUrl endpoint;

  /// HTTP method called by this operation.
  final RepositoryHttpMethod method;

  /// Optional logout request body mapper.
  final RepositoryAuthenticationBody<SignOutSession<Session>>? body;
}

/// Input used to exchange an OAuth authorization code for a session.
final class ExchangeOAuthAuthorizationCode {
  /// Creates an authorization-code exchange input.
  const ExchangeOAuthAuthorizationCode({
    required this.code,
    required this.codeVerifier,
    required this.redirectUri,
    required this.clientId,
  });

  /// Authorization code returned by the provider.
  final String code;

  /// PKCE verifier associated with the authorization request.
  final String codeVerifier;

  /// Redirect URI used by the authorization request.
  final Uri redirectUri;

  /// OAuth client identifier.
  final String clientId;
}

/// Builds typed authentication methods for one concrete session family.
final class RepositoryAuthenticationBuilder<Session extends RepositorySession> {
  RepositoryAuthenticationBuilder._(this._manager);

  final _TypedRepositorySessionManager<Session, dynamic> _manager;

  /// Creates a password authentication method.
  RepositoryPasswordAuthentication<Session> password({
    required RepositoryUrl endpoint,
    required RepositoryAuthenticationBody<CreateSessionWithPassword> body,
    required RepositoryAuthenticationDecoder<Session> decode,
    RepositoryHttpMethod method = RepositoryHttpMethod.post,
  }) {
    return RepositoryPasswordAuthentication._(
      manager: _manager,
      request: RepositoryAuthenticationRequest._(
        endpoint: endpoint,
        method: method,
        body: body,
        decode: decode,
      ),
    );
  }

  /// Creates a two-step passwordless code authentication method.
  RepositoryPasswordlessAuthentication<Session, Challenge>
  passwordlessCode<Challenge>({
    required RepositoryAuthenticationRequest<RequestPasswordlessCode, Challenge>
    request,
    required RepositoryAuthenticationRequest<
      VerifyPasswordlessCode<Challenge>,
      Session
    >
    verify,
  }) {
    return RepositoryPasswordlessAuthentication._(
      manager: _manager,
      request: request,
      verify: verify,
    );
  }

  /// Creates an OAuth authorization-code exchange method.
  RepositoryOAuthAuthorizationCodeAuthentication<Session>
  oauthAuthorizationCode({
    required RepositoryAuthenticationRequest<
      ExchangeOAuthAuthorizationCode,
      Session
    >
    exchange,
  }) {
    return RepositoryOAuthAuthorizationCodeAuthentication._(
      manager: _manager,
      exchange: exchange,
    );
  }

  /// Creates an application-specific method that results in a session.
  RepositoryCustomAuthentication<Input, Session> custom<Input>({
    required RepositoryAuthenticationRequest<Input, Session> request,
  }) {
    return RepositoryCustomAuthentication._(
      manager: _manager,
      request: request,
    );
  }
}

/// Password authentication configured by [RepositoryAuthenticationBuilder].
final class RepositoryPasswordAuthentication<
  Session extends RepositorySession
> {
  RepositoryPasswordAuthentication._({
    required this._manager,
    required this._request,
  });

  final _TypedRepositorySessionManager<Session, dynamic> _manager;
  final RepositoryAuthenticationRequest<CreateSessionWithPassword, Session>
  _request;

  /// Creates and adopts a session using username and password.
  Future<Either<RepositoryAuthenticationFailure, Session>> signIn({
    required String username,
    required String password,
  }) {
    return _manager._createSession(
      _request,
      CreateSessionWithPassword(username: username, password: password),
    );
  }
}

/// Result of the first step in a passwordless flow.
final class RepositoryPasswordlessChallenge<
  Session extends RepositorySession,
  Challenge
> {
  RepositoryPasswordlessChallenge._({
    required this.value,
    required this._authentication,
  });

  /// Typed challenge decoded from the backend response.
  final Challenge value;

  final RepositoryPasswordlessAuthentication<Session, Challenge>
  _authentication;

  /// Verifies [code] and adopts the resulting session.
  Future<Either<RepositoryAuthenticationFailure, Session>> verify({
    required String code,
  }) {
    return _authentication._verify(value, code);
  }
}

/// Two-step passwordless code authentication.
final class RepositoryPasswordlessAuthentication<
  Session extends RepositorySession,
  Challenge
> {
  RepositoryPasswordlessAuthentication._({
    required this._manager,
    required this._request,
    required RepositoryAuthenticationRequest<
      VerifyPasswordlessCode<Challenge>,
      Session
    >
    verify,
  }) : _verifyRequest = verify;

  final _TypedRepositorySessionManager<Session, dynamic> _manager;
  final RepositoryAuthenticationRequest<RequestPasswordlessCode, Challenge>
  _request;
  final RepositoryAuthenticationRequest<
    VerifyPasswordlessCode<Challenge>,
    Session
  >
  _verifyRequest;

  /// Requests a passwordless code and returns its typed challenge.
  Future<
    Either<
      RepositoryAuthenticationFailure,
      RepositoryPasswordlessChallenge<Session, Challenge>
    >
  >
  requestCode({required String username}) async {
    final result = await _manager._perform(
      _request,
      RequestPasswordlessCode(username: username),
    );
    return result.map(
      (challenge) => RepositoryPasswordlessChallenge._(
        value: challenge,
        authentication: this,
      ),
    );
  }

  Future<Either<RepositoryAuthenticationFailure, Session>> _verify(
    Challenge challenge,
    String code,
  ) {
    return _manager._createSession(
      _verifyRequest,
      VerifyPasswordlessCode(challenge: challenge, code: code),
    );
  }
}

/// OAuth authorization-code exchange that adopts the decoded session.
final class RepositoryOAuthAuthorizationCodeAuthentication<
  Session extends RepositorySession
> {
  RepositoryOAuthAuthorizationCodeAuthentication._({
    required this._manager,
    required this._exchange,
  });

  final _TypedRepositorySessionManager<Session, dynamic> _manager;
  final RepositoryAuthenticationRequest<ExchangeOAuthAuthorizationCode, Session>
  _exchange;

  /// Exchanges a code obtained by the application and adopts the session.
  Future<Either<RepositoryAuthenticationFailure, Session>> exchange(
    ExchangeOAuthAuthorizationCode input,
  ) => _manager._createSession(_exchange, input);
}

/// Application-specific authentication method.
final class RepositoryCustomAuthentication<
  Input,
  Session extends RepositorySession
> {
  RepositoryCustomAuthentication._({
    required this._manager,
    required this._request,
  });

  final _TypedRepositorySessionManager<Session, dynamic> _manager;
  final RepositoryAuthenticationRequest<Input, Session> _request;

  /// Executes the custom operation and adopts its decoded session.
  Future<Either<RepositoryAuthenticationFailure, Session>> createSession(
    Input input,
  ) => _manager._createSession(_request, input);
}

/// Configures one built-in session strategy and its typed auth methods.
abstract class RepositorySessionManager<Authentication>
    implements RepositorySessionRuntime {
  RepositorySessionManager._();

  /// Creates a bearer session manager.
  factory RepositorySessionManager.bearer({
    required Authentication Function(
      RepositoryAuthenticationBuilder<RepositorySessionBearer> auth,
    )
    authentication,
    RepositorySessionStorage? storage,
    RepositorySessionRefresh<RepositorySessionBearer>? refresh,
    RepositorySessionLogout<RepositorySessionBearer>? logout,
  }) = RepositoryBearerSessionManager<Authentication>;

  /// Creates a cookie-backed session manager.
  factory RepositorySessionManager.cookies({
    required RepositoryCookieJar cookieJar,
    required Authentication Function(
      RepositoryAuthenticationBuilder<RepositorySessionCookies> auth,
    )
    authentication,
    RepositorySessionStorage? storage,
    RepositorySessionRefresh<RepositorySessionCookies>? refresh,
    RepositorySessionLogout<RepositorySessionCookies>? logout,
  }) = RepositoryCookiesSessionManager<Authentication>;

  /// Typed authentication methods returned by the config callback.
  Authentication get authentication;

  /// Current session, or `null` when signed out.
  RepositorySession? get current;

  /// Current session resolution state.
  RepositorySessionState get state;

  /// Session state changes.
  Stream<RepositorySessionState> get states;

  /// Removes the local session and optionally calls the remote endpoint.
  Future<Either<RepositoryAuthenticationFailure, Unit>> signOut();

  /// Attaches the public client used by authentication endpoints.
  void bindClient(
    RepositoryClient client, {
    Future<void> Function(RepositorySessionChange change)? onSessionChange,
  });

  /// Interceptor applied only to authenticated repository clients.
  RepositoryInterceptor get repositoryInterceptor;
}

/// Values returned when repository authentication is configured.
final class RepositoryEnvironment<Authentication> {
  /// Creates a configured repository environment.
  const RepositoryEnvironment({
    required this.client,
    required this.publicClient,
    this.sessionManager,
  });

  /// Default client captured by authenticated repositories.
  final RepositoryClient client;

  /// Client used by unauthenticated repositories and authentication endpoints.
  final RepositoryClient publicClient;

  /// Configured session manager, when authentication is enabled.
  final RepositorySessionManager<Authentication>? sessionManager;

  /// Typed methods returned by the authentication config callback.
  Authentication get auth {
    final manager = sessionManager;
    if (manager == null) {
      throw StateError('This repository environment has no session manager.');
    }
    return manager.authentication;
  }

  /// Configured session lifecycle.
  RepositorySessionManager<Authentication> get session {
    return sessionManager ??
        (throw StateError(
          'This repository environment has no session manager.',
        ));
  }
}

/// Bearer manager returned by [RepositorySessionManager.bearer].
final class RepositoryBearerSessionManager<Authentication>
    extends
        _TypedRepositorySessionManager<
          RepositorySessionBearer,
          Authentication
        > {
  /// Creates a bearer manager.
  RepositoryBearerSessionManager({
    required super.authentication,
    super.storage,
    super.refresh,
    super.logout,
  });

  @override
  String get _storageKind => 'bearer';

  @override
  RepositorySessionBearer _deserialize(Map<String, Object?> json) {
    return RepositorySessionBearer(
      accessToken: json['accessToken']! as String,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: _dateTimeOrNull(json['expiresAt']),
      subject: json['subject'] as String?,
    );
  }

  @override
  Map<String, Object?> _serialize(RepositorySessionBearer session) => {
    'accessToken': session.accessToken,
    'refreshToken': session.refreshToken,
    'expiresAt': session.expiresAt?.toIso8601String(),
    'subject': session.subject,
  };

  @override
  Future<RepositoryHttpRequest> _authorize(
    RepositoryHttpRequest request,
    RepositorySessionBearer session,
  ) async {
    return request.copyWith(
      headers: {
        ...request.headers,
        'Authorization': 'Bearer ${session.accessToken}',
      },
    );
  }

  @override
  Future<bool> _isLocallyAvailable(RepositorySessionBearer session) async {
    final expiration = session.resolvedExpiresAt;
    return expiration == null || expiration.isAfter(DateTime.now().toUtc());
  }
}

/// Cookie manager returned by [RepositorySessionManager.cookies].
final class RepositoryCookiesSessionManager<Authentication>
    extends
        _TypedRepositorySessionManager<
          RepositorySessionCookies,
          Authentication
        > {
  /// Creates a cookie-backed manager.
  RepositoryCookiesSessionManager({
    required this.cookieJar,
    required super.authentication,
    super.storage,
    super.refresh,
    super.logout,
  });

  /// Cookie jar shared by authentication and repository requests.
  final RepositoryCookieJar cookieJar;

  @override
  String get _storageKind => 'cookies';

  @override
  RepositorySessionCookies _deserialize(Map<String, Object?> json) =>
      RepositorySessionCookies(identity: json['identity'] as String?);

  @override
  Map<String, Object?> _serialize(RepositorySessionCookies session) => {
    'identity': session.identity,
  };

  @override
  Future<RepositoryHttpRequest> _authorize(
    RepositoryHttpRequest request,
    RepositorySessionCookies session,
  ) async {
    return request.copyWith(
      headers: {
        ...request.headers,
        ...await cookieJar.requestHeaders(request.resolvedUrl),
      },
    );
  }

  @override
  Future<void> _capture(
    RepositoryHttpRequest request,
    RepositoryHttpResponse response,
  ) {
    return cookieJar.storeResponseHeaders(
      request.resolvedUrl,
      response.headers,
    );
  }

  @override
  Future<bool> _isLocallyAvailable(RepositorySessionCookies session) =>
      cookieJar.hasSession;

  @override
  Future<void> _clearCredentials() => cookieJar.clear();
}

abstract class _TypedRepositorySessionManager<
  Session extends RepositorySession,
  Authentication
>
    extends RepositorySessionManager<Authentication> {
  _TypedRepositorySessionManager({
    required Authentication Function(
      RepositoryAuthenticationBuilder<Session> auth,
    )
    authentication,
    RepositorySessionStorage? storage,
    this.refresh,
    this.logout,
  }) : storage = storage ?? InMemoryRepositorySessionStorage(),
       _createAuthentication = authentication,
       super._();

  final RepositorySessionStorage storage;
  final RepositorySessionRefresh<Session>? refresh;
  final RepositorySessionLogout<Session>? logout;
  final Authentication Function(RepositoryAuthenticationBuilder<Session> auth)
  _createAuthentication;

  late final RepositoryClient _client;
  late final Authentication _authentication;
  bool _isBound = false;
  Session? _current;
  RepositorySessionState _state = const RepositorySessionState.pending();
  final StreamController<RepositorySessionState> _states =
      StreamController.broadcast(sync: true);
  final StreamController<RepositorySessionChange> _changes =
      StreamController.broadcast(sync: true);
  Future<void>? _initialization;
  Future<_RefreshResult>? _refreshing;
  Future<void> Function(RepositorySessionChange change)? _onSessionChange;
  int _generation = 0;

  String get _storageKind;
  Session _deserialize(Map<String, Object?> json);
  Map<String, Object?> _serialize(Session session);

  @override
  Authentication get authentication => _authentication;

  @override
  Session? get current => _current;

  @override
  RepositorySessionState get state => _state;

  @override
  Stream<RepositorySessionState> get states => _states.stream;

  @override
  Stream<RepositorySessionChange> get changes => _changes.stream;

  @override
  int get generation => _generation;

  @override
  String? get cacheNamespace => _current?.subject;

  @override
  void bindClient(
    RepositoryClient client, {
    Future<void> Function(RepositorySessionChange change)? onSessionChange,
  }) {
    if (_isBound) {
      throw StateError('A session manager can only be configured once.');
    }
    _isBound = true;
    _client = client;
    _onSessionChange = onSessionChange;
    _authentication = _createAuthentication(
      RepositoryAuthenticationBuilder._(this),
    );
  }

  @override
  RepositoryInterceptor get repositoryInterceptor =>
      _RepositoryAuthenticationInterceptor(this);

  @override
  Future<bool> canAccess() async {
    await _initialize();
    var session = _current;
    if (session == null) {
      return false;
    }
    if (_refreshing case final refresh?) {
      await refresh;
      session = _current;
      if (session == null) {
        return false;
      }
    }
    if (await _isLocallyAvailable(session)) {
      return true;
    }
    return await _refreshSession() == _RefreshResult.refreshed;
  }

  Future<void> _initialize() {
    return _initialization ??= () async {
      try {
        final serialized = await storage.read();
        if (serialized == null) {
          _setState(const RepositorySessionState.unauthenticated());
          return;
        }
        final value = jsonDecode(serialized);
        if (value is! Map<String, dynamic> || value['kind'] != _storageKind) {
          await storage.delete();
          _setState(const RepositorySessionState.unauthenticated());
          return;
        }
        _current = _deserialize(value);
        _setState(RepositorySessionState.authenticated(_current!));
      } on Object catch (error) {
        _setState(RepositorySessionState.error(error));
      }
    }();
  }

  void _setState(RepositorySessionState state) {
    _state = state;
    _states.add(state);
  }

  Future<Either<RepositoryAuthenticationFailure, Output>>
  _perform<Input, Output>(
    RepositoryAuthenticationRequest<Input, Output> operation,
    Input input,
  ) async {
    try {
      final request = RepositoryHttpRequest(
        url: operation.endpoint,
        method: operation.method,
        body: operation.body(input),
      );
      final response = await _callPublic(request);
      if (!_isSuccess(response.statusCode)) {
        return Left(RepositoryAuthenticationHttpFailure(response));
      }
      return Right(await operation.decode(_jsonObject(response.body)));
    } on Object catch (error, stackTrace) {
      return Left(RepositoryAuthenticationUnexpectedFailure(error, stackTrace));
    }
  }

  Future<Either<RepositoryAuthenticationFailure, Session>>
  _createSession<Input>(
    RepositoryAuthenticationRequest<Input, Session> operation,
    Input input,
  ) async {
    final result = await _perform(operation, input);
    return result.fold(Left.new, (session) async {
      await _adopt(session);
      return Right(session);
    });
  }

  Future<void> _adopt(Session session, {bool refreshed = false}) async {
    final previousSubject = _current?.subject;
    final changesIdentity =
        _current != null &&
        (previousSubject != session.subject ||
            (!refreshed && previousSubject == null));
    await storage.write(
      jsonEncode({'kind': _storageKind, ..._serialize(session)}),
    );
    _current = session;
    if (changesIdentity) {
      _generation++;
    }
    _setState(RepositorySessionState.authenticated(session));
    await _notify(
      changesIdentity
          ? RepositorySessionChange.identityChanged
          : refreshed
          ? RepositorySessionChange.refreshed
          : RepositorySessionChange.authenticated,
    );
  }

  Future<RepositoryHttpResponse> _callPublic(
    RepositoryHttpRequest request, {
    bool includeCredentials = false,
  }) async {
    final resolved = request.resolveUrl(_client.baseUrl);
    final session = _current;
    final sent = includeCredentials && session != null
        ? await _authorize(resolved, session)
        : resolved;
    final response = await _client.call(request: sent);
    await _capture(sent, response);
    return response;
  }

  Future<RepositoryHttpRequest> _authorize(
    RepositoryHttpRequest request,
    Session session,
  );

  Future<void> _capture(
    RepositoryHttpRequest request,
    RepositoryHttpResponse response,
  ) async {}

  Future<bool> _isLocallyAvailable(Session session) async => true;

  Future<_RefreshResult> _refreshSession() {
    return _refreshing ??= () async {
      final operation = refresh;
      final session = _current;
      if (operation == null || session == null) {
        await _clearLocal();
        return _RefreshResult.expired;
      }
      try {
        final request = RepositoryHttpRequest(
          url: operation.endpoint,
          method: operation.method,
          body: operation.body(RefreshSession(session)),
        );
        final response = await _callPublic(request, includeCredentials: true);
        if (response.statusCode == 401 || response.statusCode == 403) {
          await _clearLocal();
          return _RefreshResult.expired;
        }
        if (!_isSuccess(response.statusCode)) {
          return _RefreshResult.failed;
        }
        final refreshed = await operation.decode(
          _jsonObject(response.body),
          session,
        );
        await _adopt(refreshed, refreshed: true);
        return _RefreshResult.refreshed;
      } on Object {
        return _RefreshResult.failed;
      } finally {
        _refreshing = null;
      }
    }();
  }

  @override
  Future<Either<RepositoryAuthenticationFailure, Unit>> signOut() async {
    await _initialize();
    RepositoryAuthenticationFailure? failure;
    final session = _current;
    final operation = logout;
    try {
      if (session != null && operation != null) {
        final response = await _callPublic(
          RepositoryHttpRequest(
            url: operation.endpoint,
            method: operation.method,
            body: operation.body?.call(SignOutSession(session)),
          ),
          includeCredentials: true,
        );
        if (!_isSuccess(response.statusCode)) {
          failure = RepositoryAuthenticationHttpFailure(response);
        }
      }
    } on Object catch (error, stackTrace) {
      failure = RepositoryAuthenticationUnexpectedFailure(error, stackTrace);
    } finally {
      await _clearLocal();
    }
    return failure == null ? const Right(unit) : Left(failure);
  }

  Future<void> _clearLocal() async {
    final hadSession = _current != null;
    _current = null;
    if (hadSession) {
      _generation++;
    }
    await Future.wait([storage.delete(), _clearCredentials()]);
    _setState(const RepositorySessionState.unauthenticated());
    if (hadSession) {
      await _notify(RepositorySessionChange.signedOut);
    }
  }

  Future<void> _notify(RepositorySessionChange change) async {
    _changes.add(change);
    await _onSessionChange?.call(change);
  }

  Future<void> _clearCredentials() async {}
}

enum _RefreshResult { refreshed, expired, failed }

final class _RepositoryAuthenticationInterceptor
    implements RepositoryInterceptor {
  const _RepositoryAuthenticationInterceptor(this.manager);

  final _TypedRepositorySessionManager<dynamic, dynamic> manager;

  @override
  Future<RepositoryHttpResponse> intercept({
    required RepositoryHttpRequest request,
    required RepositoryRequestHandler next,
  }) async {
    if (!await manager.canAccess()) {
      throw const RepositoryAuthenticationRequiredException();
    }
    final generation = manager.generation;
    final session = manager.current;
    var authorized = await manager._authorize(request, session);
    var response = await next(authorized);
    await manager._capture(authorized, response);
    if (response.statusCode == 401 || response.statusCode == 403) {
      final refreshed = await manager._refreshSession();
      if (refreshed == _RefreshResult.refreshed) {
        authorized = await manager._authorize(request, manager.current);
        response = await next(authorized);
        await manager._capture(authorized, response);
      }
    }
    if (manager.generation != generation) {
      throw StateError('The repository session changed during the request.');
    }
    return response;
  }
}

bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

RepositoryAuthenticationJson _jsonObject(String body) {
  if (body.trim().isEmpty) {
    return const {};
  }
  final value = jsonDecode(body);
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw const FormatException('Authentication response must be a JSON object.');
}

DateTime? _dateTimeOrNull(Object? value) {
  return value is String ? DateTime.parse(value) : null;
}
