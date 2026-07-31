/// Lets the section editor's ⋮ menu open the token browser for whichever
/// token-aware field currently has focus (ADR-0067).
///
/// The direction is the awkward part. `TokenInsertionMenu` owns the browse action
/// — it holds the controller, the caret and the trigger — and it sits *below* the
/// section chrome that has to offer the action. An `InheritedWidget` only reaches
/// downwards, so the field registers instead, the same way `MainScreen` registers
/// its refresh indicator for the drawer to trigger
/// (`CatalogRefreshIndicatorRegistry`). Same shape, same reason.
///
/// Registration follows *focus*, not mounting: a section form has several
/// token-aware fields alive at once, and the ⋮ has to mean the one the caret is in.
/// A field with no focus is not the answer to "insert a token here".
library;

/// The focused token-aware field's browse action, or null when no such field has
/// focus.
class TokenBrowserRegistry {
  TokenBrowserRegistry._internal();

  static final TokenBrowserRegistry _instance =
      TokenBrowserRegistry._internal();

  factory TokenBrowserRegistry() => _instance;

  Future<void> Function()? _action;

  /// Whether the ⋮ should offer the token browser at all.
  bool get hasAction => _action != null;

  void register(Future<void> Function() action) => _action = action;

  /// No-ops unless [action] is the registered one, so a field losing focus after
  /// another has already claimed the slot cannot clear the newcomer's
  /// registration — which is the order focus changes actually arrive in.
  void unregister(Future<void> Function() action) {
    if (_action == action) _action = null;
  }

  /// Opens the browser for the focused field. No-ops when nothing is registered.
  Future<void> open() async => _action?.call();
}
