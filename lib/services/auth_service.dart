import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:ringdrill/data/auth_client.dart';

/// Where the session is kept between launches.
///
/// An interface rather than a direct [FlutterSecureStorage] call for one
/// reason that matters and one that follows from it: tests must not need a
/// platform channel, and the CLI's device grant (DESIGN-015 §3.6) will want a
/// file-backed store instead of a keychain.
abstract class AuthTokenStore {
  Future<String?> read();

  Future<void> write(String value);

  Future<void> clear();
}

/// The default: the platform keychain/keystore, and WebCrypto-backed storage
/// on web.
///
/// A refresh token lives 60 days and survives a restart, so
/// `shared_preferences` — plaintext everywhere — is the wrong home for it.
/// Rotation with replay detection (ADR-0025) is the other half of the defence
/// and the more important half, but rotation cannot help a token that was read
/// straight off disk.
class SecureAuthTokenStore implements AuthTokenStore {
  static const _key = 'ringdrill.auth.session';

  final FlutterSecureStorage _storage;

  /// The defaults are the right ones here and are not merely accepted: since
  /// v11 the Android backend encrypts unconditionally (AES-GCM behind a
  /// Keystore-held key), so the `encryptedSharedPreferences` opt-in that older
  /// guidance calls for no longer exists. iOS and macOS use the Keychain, web
  /// uses WebCrypto.
  const SecureAuthTokenStore([this._storage = const FlutterSecureStorage()]);

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// In memory only — for tests, and for `AUTH_MODE=off` builds where there is
/// nothing to persist.
class InMemoryAuthTokenStore implements AuthTokenStore {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async => _value = value;

  @override
  Future<void> clear() async => _value = null;
}

/// Opens [url] in a system browser and returns the callback URL it lands on.
///
/// A typedef rather than a direct call so a test can drive the whole sign-in
/// without a platform channel — and so the one place that reaches a native API
/// is a single injectable line.
typedef WebAuthLauncher =
    Future<String> Function({
      required String url,
      required String callbackUrlScheme,
    });

/// The scheme the server bounces back to. Already registered on iOS
/// (`ios/Runner/Info.plist`), so provider sign-in needs no new one.
const kAuthCallbackScheme = 'ringdrill';

/// Raised when the person closed the browser without finishing.
///
/// Distinct from a failure because it is not one: cancelling a sign-in is an
/// ordinary thing to do, and the screen should go quiet rather than show an
/// error.
class SignInCancelled implements Exception {
  const SignInCancelled();
}

/// The default launcher: `ASWebAuthenticationSession` on iOS, Custom Tabs on
/// Android, `window.open` on web.
Future<String> _launchWebAuth({
  required String url,
  required String callbackUrlScheme,
}) => FlutterWebAuth2.authenticate(
  url: url,
  callbackUrlScheme: callbackUrlScheme,
);

/// Signed in, or not. There is no third state the UI needs to distinguish, and
/// inventing one ("signing in", "expired") would put a spinner in front of
/// people who are not signing in — most of them, most of the time
/// (DESIGN-015 §5.1: no account is the normal state, not a step on the way to
/// one).
@immutable
class AuthState {
  final AuthUser? user;
  final List<AccountMembership> accounts;
  final String? activeAccountId;

  const AuthState({this.user, this.accounts = const [], this.activeAccountId});

  static const signedOut = AuthState();

  bool get isSignedIn => user != null;

  /// The account a publish lands in. Personal unless the user picked
  /// otherwise, because the personal account is the one they did not have to
  /// think about.
  AccountMembership? get activeAccount {
    if (accounts.isEmpty) return null;
    for (final a in accounts) {
      if (a.accountId == activeAccountId) return a;
    }
    for (final a in accounts) {
      if (!a.isOrganisation) return a;
    }
    return accounts.first;
  }

  List<AccountMembership> get organisations =>
      accounts.where((a) => a.isOrganisation).toList();
}

/// The app's session.
///
/// One instance, created in `main()` and reachable from the widget tree. It
/// owns three things and no more: the stored session, refreshing it before it
/// expires, and telling the UI which of the two states it is in.
///
/// **Every failure path signs out rather than retrying.** A refresh that is
/// refused is either an expired session or a detected replay, and both mean
/// the same thing to the user: sign in again. Retrying a refused refresh is
/// how a client turns a revoked session into a hot loop against the server.
class AuthService extends ChangeNotifier {
  /// Refresh this long before expiry, so a request never leaves with a token
  /// that expires in flight.
  static const _refreshMargin = Duration(minutes: 5);

  final AuthClient _client;
  final AuthTokenStore _store;
  final DateTime Function() _now;

  AuthTokens? _tokens;
  AuthState _state = AuthState.signedOut;

  /// In-flight refresh, shared by every caller that arrives while it runs.
  /// Without this, a screen that fires five requests on open performs five
  /// refreshes, four of which are replays of a rotated token — and replay
  /// detection ends the session. The single-flight is a correctness
  /// requirement, not an optimisation.
  Future<String?>? _refreshing;

  final WebAuthLauncher _launch;

  AuthService({
    required AuthClient client,
    AuthTokenStore? store,
    DateTime Function()? now,
    WebAuthLauncher? launcher,
  }) : _client = client,
       _store = store ?? const SecureAuthTokenStore(),
       _now = now ?? (() => DateTime.now().toUtc()),
       _launch = launcher ?? _launchWebAuth;

  static AuthService? _instance;

  /// The app's session, once [install] has run.
  ///
  /// Reachable statically rather than through the widget tree because
  /// `buildCatalogClient()` — which is not a widget and has no context — needs
  /// a token provider. A field rather than a lazy getter so a test never gets
  /// a real keychain-backed service by accident: reading this before [install]
  /// is a mistake worth failing on.
  static AuthService get instance {
    final it = _instance;
    assert(it != null, 'AuthService.install() must run before use');
    return it!;
  }

  /// Whether a session is available at all. False before [install], which is
  /// the state every `flutter test` that does not opt in stays in.
  static bool get isInstalled => _instance != null;

  static void install(AuthService service) => _instance = service;

  @visibleForTesting
  static void resetForTest() => _instance = null;

  AuthState get state => _state;

  bool get isSignedIn => _state.isSignedIn;

  /// Restore a stored session, if there is one.
  ///
  /// Never throws and never blocks startup on the network: a person who is not
  /// signing in must not wait for an auth round trip, and one who is signed in
  /// should see their account appear rather than a gate.
  Future<void> restore() async {
    try {
      final raw = await _store.read();
      if (raw == null) return;
      _tokens = AuthTokens.fromStored(jsonDecode(raw) as Map<String, dynamic>);
      _publish(
        AuthState(
          user: _tokens!.user,
          accounts: _tokens!.accounts,
          activeAccountId: _state.activeAccountId,
        ),
      );
      // Hydrate names and sessions in the background. A stale display name is
      // not worth delaying the first frame for.
      unawaited(_hydrate());
    } catch (e, s) {
      // A session that cannot be decoded is a session that cannot be used.
      // Clearing it is the only way out of a permanent failure loop.
      debugPrint('auth: discarding unreadable session ($e)');
      assert(() {
        debugPrintStack(stackTrace: s);
        return true;
      }());
      await signOut();
    }
  }

  /// Begin email sign-in. Returns the challenge; the code and the link redeem
  /// the same one.
  Future<EmailChallenge> startEmailSignIn(
    String email, {
    String locale = 'en',
  }) => _client.startEmail(email, locale: locale);

  /// Which third-party providers this deployment offers.
  ///
  /// Never cached: each call mints fresh single-use `state` values server-side,
  /// so a reused response would send two attempts at the same one.
  Future<List<AuthProvider>> providers() => _client.providers();

  /// Sign in through a provider.
  ///
  /// Opens the server-built authorize URL in a system browser — the person
  /// signs in on the provider's own page, on the provider's own domain — and
  /// exchanges the single-use handoff code the browser comes back with. The
  /// tokens themselves never travel in a URL.
  ///
  /// Throws [SignInCancelled] when the browser was dismissed, which is not an
  /// error and should not be shown as one.
  Future<void> signInWithProvider(AuthProvider provider) async {
    final String callback;
    try {
      callback = await _launch(
        url: provider.authorizeUrl,
        callbackUrlScheme: kAuthCallbackScheme,
      );
    } on PlatformException {
      // What flutter_web_auth_2 raises when the sheet is dismissed. Retrying
      // or reporting a failure here would both be wrong.
      throw const SignInCancelled();
    }

    final params = Uri.parse(callback).queryParameters;
    // The server bounces back with `error` for everything from a cancelled
    // consent to a failed exchange, so the reason survives to the UI instead
    // of becoming a generic failure.
    final error = params['error'];
    if (error != null) {
      if (error == 'access_denied') throw const SignInCancelled();
      throw AuthApiException(error, reason: error);
    }

    final handoff = params['handoff'];
    if (handoff == null) throw AuthApiException('no_handoff');

    await _adopt(await _client.redeemHandoff(handoff));
    await _hydrate();
  }

  /// Redeem an email code, an emailed link, or a provider result.
  Future<void> completeSignIn({
    String? challengeId,
    String? code,
    String? provider,
    String? idToken,
    String? deviceLabel,
  }) async {
    final tokens = await _client.callback(
      challengeId: challengeId,
      code: code,
      provider: provider,
      idToken: idToken,
      deviceLabel: deviceLabel,
    );
    await _adopt(tokens);
    await _hydrate();
  }

  /// The session this app is running on, or null when signed out.
  ///
  /// The sessions list needs it to mark one row as "this device" — comparing
  /// by label instead would mark both of somebody's two identical phones.
  String? get currentSessionId => _tokens?.sessionId;

  /// This user's devices, live and recently-ended (DESIGN-015 §4.3).
  ///
  /// Fetched rather than cached: the list's whole purpose is answering "what
  /// is signed in *right now*", and a stale answer to that is worse than a
  /// slow one.
  Future<List<AuthDevice>> devices() async {
    final token = await accessToken();
    if (token == null) return const [];
    return (await _client.me(token: token)).devices;
  }

  /// End one of this user's other sessions.
  ///
  /// Revoking the *current* session is sign-out with extra steps, so it is
  /// routed there — otherwise the app would keep running on a session the
  /// server has just destroyed, and every later request would 401 with no
  /// explanation.
  Future<void> revokeSession(String sessionId) async {
    if (sessionId == currentSessionId) return signOut();
    final token = await accessToken();
    if (token == null) return;
    await _client.revokeSession(sessionId: sessionId, token: token);
  }

  /// Re-read the user's accounts from the server.
  ///
  /// Needed after anything that changes membership from this device — deleting
  /// an organisation, accepting an invitation — because the account list came
  /// from the token's claims and those are only refreshed on rotation.
  Future<void> refreshAccounts() => _hydrate();

  /// Which account a publish lands in. Persisted with the session, because a
  /// person who works in one organisation should not re-pick it every launch.
  Future<void> setActiveAccount(String? accountId) async {
    _publish(
      AuthState(
        user: _state.user,
        accounts: _state.accounts,
        activeAccountId: accountId,
      ),
    );
  }

  /// Tokens cleared, local plans untouched, account still exists
  /// (DESIGN-015 §5.1). Signing out must never look like losing work.
  Future<void> signOut() async {
    final tokens = _tokens;
    _tokens = null;
    _refreshing = null;
    await _store.clear();
    _publish(AuthState.signedOut);

    if (tokens != null) {
      // Best effort, and deliberately after the local state is already gone:
      // if the network is down, the user is still signed out on this device,
      // which is what they asked for.
      try {
        await _client.logout(
          sessionId: tokens.sessionId,
          // Both, because the access token may already have expired — and
          // without proof of ownership the server now (correctly) refuses to
          // end the session, which would leave it alive for 60 days.
          refreshToken: tokens.refreshToken,
          accessToken: tokens.accessToken,
        );
      } catch (_) {
        // Nothing to tell the user. The session expires on its own.
      }
    }
  }

  /// A valid access token, or null when signed out.
  ///
  /// This is the single entry point every authenticated request goes through,
  /// which is what makes the single-flight refresh above sufficient.
  Future<String?> accessToken() async {
    final tokens = _tokens;
    if (tokens == null) return null;
    if (_now().add(_refreshMargin).isBefore(tokens.expiresAt)) {
      return tokens.accessToken;
    }
    return _refreshing ??= _refreshOnce().whenComplete(() {
      _refreshing = null;
    });
  }

  Future<String?> _refreshOnce() async {
    final tokens = _tokens;
    if (tokens == null) return null;
    try {
      final fresh = await _client.refresh(
        sessionId: tokens.sessionId,
        refreshToken: tokens.refreshToken,
      );
      await _adopt(fresh);
      return fresh.accessToken;
    } on AuthApiException catch (e) {
      // 401 is expiry or a detected replay; both end the session. Anything
      // else is transport, and signing out over a flaky network would be a
      // worse answer than failing this one request.
      if (e.status == 401) await signOut();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _adopt(AuthTokens tokens) async {
    _tokens = tokens;
    await _store.write(jsonEncode(tokens.toJson()));
    _publish(
      AuthState(
        user: tokens.user,
        accounts: tokens.accounts.isEmpty ? _state.accounts : tokens.accounts,
        activeAccountId: _state.activeAccountId,
      ),
    );
  }

  /// Replace the id-only membership list from the token with the named one.
  Future<void> _hydrate() async {
    final token = await accessToken();
    if (token == null) return;
    try {
      final identity = await _client.me(token: token);
      _publish(
        AuthState(
          user: identity.user,
          accounts: identity.accounts,
          activeAccountId: _state.activeAccountId ?? identity.activeAccountId,
        ),
      );
    } catch (_) {
      // The session still works; only the display names are stale.
    }
  }

  /// Put the service into a given state without a round trip.
  ///
  /// Widget tests need a signed-in service to render against, and driving the
  /// real sign-in through a scripted transport in every such test would test
  /// the transport rather than the widget.
  @visibleForTesting
  void debugSetStateForTest(AuthState state) => _publish(state);

  void _publish(AuthState next) {
    _state = next;
    notifyListeners();
  }
}
