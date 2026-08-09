// ignore_for_file: public_member_api_docs
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

/// The `/api/auth/*` and `/api/accounts/*` contracts (ADR-0024, DESIGN-015).
///
/// Deliberately Flutter-free and in `lib/data/`, like [DrillClient]: the CLI's
/// device-authorization grant (DESIGN-015 §3.6) is the same protocol, so
/// putting this in `lib/services/` would mean writing it twice the day that
/// lands. Nothing here touches storage — [AuthService] owns that, because
/// storing a token is a platform concern and this is not.

/// Thin error type that preserves HTTP context, mirroring [DrillApiException].
class AuthApiException implements Exception {
  final String message;
  final int? status;

  /// The server's machine-readable reason (`wrong_identity`, `expired`,
  /// `last_owner`, …). The UI branches on this rather than on the message,
  /// which is for logs.
  final String? reason;

  /// Extra detail the server attached to the refusal, already joined for
  /// display — today the organisations that would be stranded by deleting an
  /// account. Carried because naming them is what makes the refusal
  /// actionable; without it the user is told no and not what to fix.
  final String? detail;

  AuthApiException(this.message, {this.status, this.reason, this.detail});

  @override
  String toString() =>
      'AuthApiException($status${reason == null ? '' : ', $reason'}): $message';
}

/// A signed-in user, as the server describes them.
@immutable
class AuthUser {
  final String id;
  final String displayName;
  final String? email;

  const AuthUser({required this.id, required this.displayName, this.email});

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id: j['id'] as String,
    displayName: (j['displayName'] as String?) ?? '',
    email: j['email'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'email': ?email,
  };
}

/// One membership: an account, and this user's role in it.
///
/// The role here is [MemberRole] — the account/administration axis — and never
/// a staff role. Conflating the two is the mistake DESIGN-015 §7 exists to
/// prevent, so they do not share a type.
@immutable
class AccountMembership {
  final String accountId;
  final String displayName;
  final String? handle;

  /// `personal` or `organization`.
  final String type;

  /// `owner`, `member` or `guest`.
  final String role;

  const AccountMembership({
    required this.accountId,
    required this.displayName,
    required this.type,
    required this.role,
    this.handle,
  });

  bool get isOwner => role == 'owner';
  bool get isOrganisation => type == 'organization';

  factory AccountMembership.fromJson(Map<String, dynamic> j) =>
      AccountMembership(
        accountId: (j['accountId'] ?? j['id']) as String,
        displayName: (j['displayName'] as String?) ?? '',
        handle: j['handle'] as String?,
        type: (j['type'] as String?) ?? 'personal',
        role: (j['role'] as String?) ?? 'member',
      );

  Map<String, dynamic> toJson() => {
    'accountId': accountId,
    'displayName': displayName,
    'handle': ?handle,
    'type': type,
    'role': role,
  };
}

/// The result of a successful sign-in or refresh.
///
/// [expiresAt] is stored rather than the server's `expiresIn`, because a
/// duration is only meaningful at the instant it was received — persisting it
/// across a restart would make a token look fresh for an hour after every
/// launch.
@immutable
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final String sessionId;
  final DateTime expiresAt;
  final AuthUser user;
  final List<AccountMembership> accounts;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.sessionId,
    required this.expiresAt,
    required this.user,
    required this.accounts,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> j, {DateTime? now}) {
    final seconds = (j['expiresIn'] as num?)?.toInt() ?? 3600;
    return AuthTokens(
      accessToken: j['accessToken'] as String,
      refreshToken: j['refreshToken'] as String,
      sessionId: j['sessionId'] as String,
      expiresAt: (now ?? DateTime.now().toUtc()).add(
        Duration(seconds: seconds),
      ),
      user: AuthUser.fromJson(j['user'] as Map<String, dynamic>),
      accounts: _accountsOf(j),
    );
  }

  /// Persisted shape. The access token is included so a warm start does not
  /// have to spend a round trip refreshing a token that is still valid.
  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'sessionId': sessionId,
    'expiresAt': expiresAt.toIso8601String(),
    'user': user.toJson(),
    'accounts': accounts.map((a) => a.toJson()).toList(),
  };

  static AuthTokens fromStored(Map<String, dynamic> j) => AuthTokens(
    accessToken: j['accessToken'] as String,
    refreshToken: j['refreshToken'] as String,
    sessionId: j['sessionId'] as String,
    expiresAt: DateTime.parse(j['expiresAt'] as String),
    user: AuthUser.fromJson(j['user'] as Map<String, dynamic>),
    accounts: ((j['accounts'] as List?) ?? const [])
        .map((e) => AccountMembership.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  AuthTokens copyWith({String? accessToken, DateTime? expiresAt}) => AuthTokens(
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken,
    sessionId: sessionId,
    expiresAt: expiresAt ?? this.expiresAt,
    user: user,
    accounts: accounts,
  );

  /// The server sends `accounts` (ids) and `roles` (id → role) separately,
  /// because the token claims are shaped that way. The client wants one list.
  static List<AccountMembership> _accountsOf(Map<String, dynamic> j) {
    final raw = j['accounts'];
    if (raw is! List) return const [];
    // Already-joined objects (what /me returns) pass straight through.
    if (raw.isNotEmpty && raw.first is Map) {
      return raw
          .map((e) => AccountMembership.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final roles = (j['roles'] as Map?)?.cast<String, dynamic>() ?? const {};
    return raw
        .cast<String>()
        .map(
          (id) => AccountMembership(
            accountId: id,
            displayName: '',
            type: 'personal',
            role: (roles[id] as String?) ?? 'member',
          ),
        )
        .toList();
  }
}

/// A third-party sign-in button, as the server describes it.
///
/// [authorizeUrl] is built server-side and already carries the client id, the
/// PKCE challenge, the nonce and a single-use `state`. The app holds none of
/// those — it opens the URL and waits.
@immutable
class AuthProvider {
  final String id;
  final String label;
  final String authorizeUrl;

  const AuthProvider({
    required this.id,
    required this.label,
    required this.authorizeUrl,
  });

  factory AuthProvider.fromJson(Map<String, dynamic> j) => AuthProvider(
    id: j['id'] as String,
    label: j['label'] as String,
    authorizeUrl: j['authorizeUrl'] as String,
  );
}

/// What a challenge started — the code path and the link path are the same
/// challenge, redeemable either way (DESIGN-015 §3.3).
@immutable
class EmailChallenge {
  final String challengeId;
  final Duration expiresIn;

  /// Only ever set under `AUTH_MODE=mock`, where the mail channel is
  /// short-circuited so the flow can run end to end with no provider
  /// (ADR-0073). In live mode this is null, because the response would
  /// otherwise *be* the credential.
  final String? devCode;

  const EmailChallenge({
    required this.challengeId,
    required this.expiresIn,
    this.devCode,
  });
}

/// What `/api/auth/me` knows: the user, their accounts *with names*, and the
/// sessions they can end from the account page (DESIGN-015 §4.3).
@immutable
class AuthIdentity {
  final AuthUser user;
  final List<AccountMembership> accounts;
  final String? activeAccountId;
  final List<AuthDevice> devices;

  const AuthIdentity({
    required this.user,
    required this.accounts,
    this.activeAccountId,
    this.devices = const [],
  });
}

/// A signed-in device, for the sessions list.
///
/// This is where refresh-token rotation becomes visible. A session ended by
/// replay detection is kept server-side as a tombstone rather than deleted, so
/// it arrives here with [endedReason] set — the user is *told* their refresh
/// token was replayed instead of watching a device quietly disappear.
@immutable
class AuthDevice {
  final String sessionId;
  final String? label;
  final DateTime? lastUsedAt;

  /// When the session was ended, or null while it is live.
  final DateTime? endedAt;

  /// Why it ended — today only `replayed`. Null while live.
  final String? endedReason;

  const AuthDevice({
    required this.sessionId,
    this.label,
    this.lastUsedAt,
    this.endedAt,
    this.endedReason,
  });

  bool get isEnded => endedAt != null;

  /// Whether this is the session the app is currently running on. Compared by
  /// id rather than by label, because two phones of the same model report the
  /// same label.
  bool isCurrent(String? currentSessionId) =>
      currentSessionId != null && sessionId == currentSessionId;

  static DateTime? _time(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  factory AuthDevice.fromJson(Map<String, dynamic> j) => AuthDevice(
    sessionId: (j['sessionId'] ?? j['id']) as String,
    label: j['deviceLabel'] as String? ?? j['label'] as String?,
    lastUsedAt: _time(j['lastUsedAt']),
    endedAt: _time(j['endedAt']),
    endedReason: j['endedReason'] as String?,
  );
}

/// An invitation as the landing page needs to render it (DESIGN-015 §6.4).
@immutable
class InvitationInfo {
  /// `pending`, `accepted`, `withdrawn`, `expired`, `organisation_deleted`.
  final String state;
  final String email;
  final String role;
  final String? organisation;
  final String? inviterName;

  const InvitationInfo({
    required this.state,
    required this.email,
    required this.role,
    this.organisation,
    this.inviterName,
  });

  bool get isPending => state == 'pending';

  factory InvitationInfo.fromJson(Map<String, dynamic> j) => InvitationInfo(
    state: (j['state'] as String?) ?? 'pending',
    email: (j['email'] as String?) ?? '',
    role: (j['role'] as String?) ?? 'member',
    organisation: j['organisation'] as String?,
    inviterName: j['inviterName'] as String?,
  );
}

/// One row of an account's roster.
@immutable
class AccountMember {
  final String? userId;
  final String? email;
  final String? displayName;
  final String role;

  /// `accepted`, `invited` or `failed` — a state on the row, never a role.
  final String state;

  const AccountMember({
    required this.role,
    required this.state,
    this.userId,
    this.email,
    this.displayName,
  });

  bool get isPending => state != 'accepted';

  /// The path segment that addresses this row. A pending invitation has no
  /// user to key on, so it is addressed by the address it was sent to.
  String get pathId => userId ?? 'pending:${email ?? ''}';

  factory AccountMember.fromJson(Map<String, dynamic> j) => AccountMember(
    userId: j['userId'] as String?,
    email: j['email'] as String?,
    displayName: j['displayName'] as String?,
    role: (j['role'] as String?) ?? 'member',
    state: (j['state'] as String?) ?? 'accepted',
  );
}

/// The roster, plus the one advisory that belongs with it.
@immutable
class AccountRoster {
  final List<AccountMember> members;

  /// DESIGN-015 §4.4: an organisation with one owner is one unavailable
  /// person away from being unrecoverable. The advisory is prevention, and it
  /// lives on this screen rather than in a recovery flow.
  final bool singleOwner;

  const AccountRoster({required this.members, required this.singleOwner});
}

class AuthClient {
  /// Base origin, or empty for same-origin web builds — same contract as
  /// [DrillClient.baseUrl].
  final String baseUrl;
  final String functionsBasePath;
  final http.Client _http;

  /// The clock used to turn the server's `expiresIn` into an absolute
  /// [AuthTokens.expiresAt]. Injectable so a test can age a session without
  /// waiting an hour — and because deriving expiry from a *different* clock
  /// than the one that later checks it is how a token looks fresh forever.
  final DateTime Function() _now;

  AuthClient({
    required this.baseUrl,
    this.functionsBasePath = '/api',
    http.Client? httpClient,
    DateTime Function()? now,
  }) : _http = httpClient ?? http.Client(),
       _now = now ?? (() => DateTime.now().toUtc());

  // ---------------- sign-in ----------------

  /// Begin email sign-in. Sends a link *and* a code for the same challenge.
  Future<EmailChallenge> startEmail(
    String email, {
    String locale = 'en',
  }) async {
    final j = await _post('auth/start-email', {
      'email': email,
      'locale': locale,
    });
    return EmailChallenge(
      challengeId: j['challengeId'] as String,
      expiresIn: Duration(
        milliseconds: (j['expiresInMs'] as num?)?.toInt() ?? 0,
      ),
      devCode: j['code'] as String?,
    );
  }

  /// Which providers this deployment offers, and the URL to open for each.
  ///
  /// Asked at runtime rather than compiled in, which is the whole point: a
  /// client id belongs to a deployment, not to a build, so adding or rotating
  /// a provider never needs an app release. An empty list is the normal answer
  /// for a deployment with none configured — not an error.
  ///
  /// Each call mints fresh single-use `state` values server-side, so the
  /// result must not be cached across sign-in attempts.
  Future<List<AuthProvider>> providers() async {
    final j = await _get('auth/providers');
    return ((j['providers'] as List?) ?? const [])
        .map((e) => AuthProvider.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Exchange the handoff code the browser returned for a session.
  ///
  /// The tokens never travelled in a URL — this is the round trip that fetches
  /// them, over TLS. Single-use and valid for a minute.
  Future<AuthTokens> redeemHandoff(
    String handoff, {
    String? deviceLabel,
  }) async {
    final j = await _post('auth/callback', {
      'handoff': handoff,
      'deviceLabel': ?deviceLabel,
    });
    return AuthTokens.fromJson(j, now: _now());
  }

  /// The signed-in user with their accounts *named*.
  ///
  /// `callback` and `refresh` return account **ids** and a role map, because
  /// that is the shape of the token claims. Nothing there can render a list of
  /// organisations, so a sign-in is followed by one call to this.
  Future<AuthIdentity> me({required String token}) async {
    final j = await _get('auth/me', token: token);
    return AuthIdentity(
      user: AuthUser.fromJson(j['user'] as Map<String, dynamic>),
      accounts: ((j['accounts'] as List?) ?? const [])
          .map((e) => AccountMembership.fromJson(e as Map<String, dynamic>))
          .toList(),
      activeAccountId: j['activeAccount'] as String?,
      devices: ((j['devices'] as List?) ?? const [])
          .map((e) => AuthDevice.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Redeem a challenge (email code or link) or a provider result.
  Future<AuthTokens> callback({
    String? challengeId,
    String? code,
    String? provider,
    String? idToken,
    String? deviceLabel,
  }) async {
    final j = await _post('auth/callback', {
      'challengeId': ?challengeId,
      'code': ?code,
      'provider': ?provider,
      'idToken': ?idToken,
      'deviceLabel': ?deviceLabel,
    });
    return AuthTokens.fromJson(j, now: _now());
  }

  Future<AuthTokens> refresh({
    required String sessionId,
    required String refreshToken,
  }) async {
    final j = await _post('auth/refresh', {
      'sessionId': sessionId,
      'refreshToken': refreshToken,
    });
    return AuthTokens.fromJson(j, now: _now());
  }

  /// Sign out, ending this session server-side.
  ///
  /// [refreshToken] is sent alongside the access token because by the time
  /// somebody signs out the access token may well have expired — and the
  /// server needs *some* proof of ownership, or a leaked session id would be a
  /// forced-logout capability for anyone holding it. Without it a stale client
  /// cannot revoke its own session, which then lives for the full 60-day
  /// refresh window.
  Future<void> logout({
    required String sessionId,
    String? refreshToken,
    String? accessToken,
  }) async {
    await _post('auth/logout', {
      'sessionId': sessionId,
      'refreshToken': ?refreshToken,
    }, token: accessToken);
  }

  /// End *another* of this user's sessions — the sessions list's "log out this
  /// device" (DESIGN-015 §4.3). Always needs a live access token: revoking a
  /// device you are not holding is administration, not a sign-out.
  Future<void> revokeSession({
    required String sessionId,
    required String token,
  }) => _post('auth/sessions/revoke', {'sessionId': sessionId}, token: token);

  // ---------------- accounts ----------------

  Future<AccountRoster> members(
    String accountId, {
    required String token,
  }) async {
    final j = await _get('accounts/$accountId/members', token: token);
    return AccountRoster(
      members: ((j['members'] as List?) ?? const [])
          .map((e) => AccountMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      singleOwner: j['singleOwner'] == true,
    );
  }

  Future<void> invite(
    String accountId, {
    required String email,
    required String role,
    required String token,
    String locale = 'en',
  }) => _post('accounts/$accountId/members', {
    'email': email,
    'role': role,
    'locale': locale,
  }, token: token);

  Future<void> changeRole(
    String accountId,
    String memberId, {
    required String role,
    required String token,
  }) => _send(
    'PATCH',
    'accounts/$accountId/members/${Uri.encodeComponent(memberId)}',
    body: {'role': role},
    token: token,
  );

  /// Removes a member, withdraws a pending invitation, or leaves — the server
  /// decides which from the row, and refuses the last owner in every case.
  Future<void> removeMember(
    String accountId,
    String memberId, {
    required String token,
  }) => _send(
    'DELETE',
    'accounts/$accountId/members/${Uri.encodeComponent(memberId)}',
    token: token,
  );

  Future<AccountMembership> createOrganisation({
    required String displayName,
    String? handle,
    String? upgradeAccountId,
    required String token,
  }) async {
    final j = await _post('accounts', {
      'displayName': displayName,
      if (handle != null && handle.isNotEmpty) 'handle': handle,
      'upgradeAccountId': ?upgradeAccountId,
    }, token: token);
    return AccountMembership.fromJson({
      ...(j['account'] as Map<String, dynamic>),
      'role': 'owner',
    });
  }

  /// Resolve an account handle to the id a shared plan stores.
  ///
  /// Handles change and ids do not (ADR-0074), so the id is what gets written
  /// — but a handle is the name already in that account's plan URLs, which is
  /// something a person can be told over the phone. Returns null when no such
  /// handle exists.
  Future<AccountMembership?> lookupHandle(
    String handle, {
    required String token,
  }) async {
    try {
      final j = await _get(
        'accounts/lookup?handle=${Uri.encodeQueryComponent(handle)}',
        token: token,
      );
      return AccountMembership.fromJson({
        ...j,
        'role': 'guest',
        'type': 'organization',
      });
    } on AuthApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Delete an account (DESIGN-015 §5.1).
  ///
  /// Throws with `reason: 'sole_owner_of_organisation'` when the caller is the
  /// only owner of an organisation — deleting then would strand it, and the
  /// error carries the names so the UI can say which.
  /// [publishUnpublished] leaves plans nobody else relies on in the public
  /// catalog instead of deleting them — an explicit "leave my work to the
  /// community". Published plans are not affected either way: they stay,
  /// because other people have installed them.
  Future<void> deleteAccount(
    String accountId, {
    required String token,
    bool publishUnpublished = false,
  }) => _send(
    'DELETE',
    'accounts/$accountId',
    body: {'unpublishedPlans': publishUnpublished ? 'publish' : 'delete'},
    token: token,
  );

  // ---------------- invitations ----------------

  /// Anonymous on purpose: the landing page has to say who to sign in as
  /// before anyone has signed in.
  Future<InvitationInfo> invitation(String inviteToken) async {
    final j = await _get('invitations/${Uri.encodeComponent(inviteToken)}');
    return InvitationInfo.fromJson(j);
  }

  /// Accept an invitation. Throws with `reason: 'wrong_identity'` when the
  /// signed-in user does not hold the invited address — the case the UI has
  /// to explain rather than retry.
  Future<String> acceptInvitation(
    String inviteToken, {
    required String token,
  }) async {
    final j = await _post(
      'invitations/${Uri.encodeComponent(inviteToken)}/accept',
      const {},
      token: token,
    );
    return j['accountId'] as String;
  }

  // ---------------- plumbing ----------------

  Uri _uri(String path) {
    final prefix = functionsBasePath.isEmpty ? '' : functionsBasePath;
    return Uri.parse('$baseUrl$prefix/$path');
  }

  Future<Map<String, dynamic>> _get(String path, {String? token}) =>
      _send('GET', path, token: token);

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) => _send('POST', path, body: body, token: token);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final req = http.Request(method, _uri(path));
    req.headers['accept'] = 'application/json';
    if (token != null) req.headers['authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode(body);
    }

    final res = await http.Response.fromStream(await _http.send(req));
    if (res.statusCode == 204 || res.body.isEmpty) return const {};

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(res.body) as Map<String, dynamic>;
    } on FormatException {
      // A non-JSON body from an auth endpoint means something upstream
      // answered instead — a proxy error page, most often. Reporting the
      // status is more use than the HTML.
      throw AuthApiException('Unexpected response', status: res.statusCode);
    }

    if (res.statusCode >= 400) {
      final organisations = parsed['organisations'];
      throw AuthApiException(
        (parsed['error'] as String?) ?? 'request_failed',
        status: res.statusCode,
        // `state` carries the invitation's outcome; `error` carries
        // everything else. Both are the machine-readable branch.
        reason: (parsed['state'] as String?) ?? (parsed['error'] as String?),
        detail: organisations is List
            ? organisations.map((e) => e.toString()).join(', ')
            : null,
      );
    }
    return parsed;
  }
}
