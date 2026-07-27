import 'package:flutter/widgets.dart';

/// The outcome of loading what a widget was asked to show: [Loaded] with the
/// value, or [NotFound].
///
/// Anything opened with an id rather than an object — every route and context
/// sheet target in this app carries uuids — can find that its target no longer
/// exists: a stale deep link, or a delete from elsewhere while it is open. That
/// is a distinct case, not an object with empty fields.
///
/// A sealed type keeps both cases honest without spreading `?`/`!` through the
/// consumer: a `switch` over it is exhaustive, so the compiler will not let a
/// case be forgotten, and [Loaded.value] hands the rest of the code a plain
/// non-null object nothing has to re-check.
///
/// Deliberately *not* a sentinel value (an `Empty`/`Zero` instance of the type
/// itself). The analyzer cannot force anyone to compare against a sentinel, so
/// that trades a compiler-checked obligation for a convention. It also means
/// fabricating a domain object — and a fabricated one carries degenerate data
/// into whatever consumes it, instead of stopping at the edge.
///
/// There is no `Loading` case: every load behind this today is synchronous
/// (the repository reads `SharedPreferences` in-process), so a spinner state
/// would be unreachable. If a screen ever loads asynchronously, add `Loading`
/// here and a `buildLoading` to [Loader] — being sealed, the compiler will
/// then flag every `switch` that has not handled it.
sealed class LoadState<T> {
  const LoadState();
}

class Loaded<T> extends LoadState<T> {
  const Loaded(this.value);

  final T value;
}

class NotFound<T> extends LoadState<T> {
  const NotFound();
}

/// Loads what a [State] was asked to show, and copes with it disappearing
/// while mounted.
///
/// Owns only the load lifecycle: load before the first build, reload on
/// demand, rebuild, and dispatch `build` over the cases — so a host implements
/// [onLoad] and [buildLoaded] and gets the rest. It takes no position on what a
/// missing target *means*: [buildNotFound] renders nothing by default. A host
/// on a dismissable surface overrides it to close (see `ClosableSurface`); one
/// embedded where something must always be shown renders a placeholder.
///
/// The host implements the `on…` pair — [onLoad] to produce the value and
/// [onLoaded] to refresh anything derived from it. Callers drive it with [load]
/// (no rebuild, for `initState`) and [reload] (rebuilds).
///
/// [onLoad] must be free of navigation and inherited-widget access: it runs
/// from [load], before the first build, where neither is allowed.
///
/// [R] is what triggered a reload (an event, a notification), passed through to
/// [onLoad] so an object already carried on it can be preferred over a fresh
/// lookup. Use `void` when there is nothing to pass.
mixin Loader<W extends StatefulWidget, T, R> on State<W> {
  LoadState<T> _loadState = NotFound<T>();

  /// The current load state. Never null and never `late`: assigned at
  /// declaration, re-assigned by [load] and [reload].
  LoadState<T> get loadState => _loadState;

  /// Produces the target, or null when it (or anything it needs) no longer
  /// exists. Must not navigate or read inherited widgets.
  T? onLoad(R? reason);

  /// Hook for state derived from the target. Runs after every load, inside the
  /// same `setState` when called via [reload].
  void onLoaded() {}

  /// Loads without rebuilding — for `initState`.
  void load([R? reason]) {
    final value = onLoad(reason);
    _loadState = value == null ? NotFound<T>() : Loaded<T>(value);
    onLoaded();
  }

  /// Loads again and rebuilds. Safe from anywhere *after* `initState`.
  void reload([R? reason]) {
    if (!mounted) return;
    setState(() => load(reason));
  }

  /// Replaces the loaded value directly and rebuilds, without going through
  /// [onLoad].
  ///
  /// For an optimistic local update — a host that has just saved an edit and
  /// already holds the new object, so re-reading it from the repository would
  /// be redundant. Only meaningful once something is loaded; a no-op otherwise,
  /// since there is nothing to update and inventing a [Loaded] here would
  /// resurrect a target that was reported gone.
  void updateLoaded(T value) {
    if (!mounted || _loadState is! Loaded<T>) return;
    setState(() {
      _loadState = Loaded<T>(value);
      onLoaded();
    });
  }

  /// Dispatches over [loadState]. Provided so a host cannot forget to route
  /// through it — implement [buildLoaded] (and optionally [buildNotFound])
  /// instead of `build`.
  @override
  Widget build(BuildContext context) => switch (_loadState) {
    Loaded<T>(:final value) => buildLoaded(context, value),
    NotFound<T>() => buildNotFound(context),
  };

  /// The normal body, with a guaranteed-present target.
  Widget buildLoaded(BuildContext context, T value);

  /// What to show when the target is gone. Renders nothing by default —
  /// override to dismiss the surface or to show a placeholder.
  Widget buildNotFound(BuildContext context) => const SizedBox.shrink();
}
