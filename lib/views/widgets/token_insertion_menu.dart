import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/station_scenario_tokens.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';
import 'package:ringdrill/views/widgets/token_browser.dart';
import 'package:ringdrill/views/widgets/token_browser_registry.dart';

/// One entry in the flat DESIGN-008 insertion-menu list. A single list, no
/// group headers: variable entries show their effective value, plan-field
/// entries show a muted "planfelt" hint instead, and — when
/// [TokenInsertionMenu.onCreateVariable] is supplied and nothing else
/// matches — a trailing "Opprett variabel «x»" entry.
sealed class TokenMenuEntry {
  const TokenMenuEntry();
}

class VariableMenuEntry extends TokenMenuEntry {
  const VariableMenuEntry(this.token);
  final VariableToken token;
}

class PlanFieldMenuEntry extends TokenMenuEntry {
  const PlanFieldMenuEntry(this.token);
  final PlanFieldToken token;
}

/// A `{{station.loc.<slug>}}` entry (ADR-0047, DESIGN-009 follow-up 4).
class StationLocationMenuEntry extends TokenMenuEntry {
  const StationLocationMenuEntry(this.token);
  final StationLocationToken token;
}

/// A `{{station.person.<slug>}}` entry.
class StationPersonMenuEntry extends TokenMenuEntry {
  const StationPersonMenuEntry(this.token);
  final StationPersonToken token;
}

/// Marks the three "Create …" entries, so "did anything actually match?" can be
/// asked without naming each of them (and without a fourth being forgotten).
mixin _CreateEntry {}

/// "Vis alle …" — the card's pinned footer (ADR-0067).
///
/// Always present: it is the way out when the filter matched nothing *and* when it
/// matched plenty, so it cannot depend on what the results look like. When nothing
/// matched, the alternative is "no matches", which tells the author their guess
/// failed and nothing about what would have worked.
///
/// Not a list row. It scrolled away with the results when it was one, and it is not
/// a result — it is what to do when the results are not what you wanted, so it sits
/// below the scroll view, behind a divider and on its own surface.
class BrowseTokensMenuEntry extends TokenMenuEntry {
  const BrowseTokensMenuEntry();
}

class CreateVariableMenuEntry extends TokenMenuEntry with _CreateEntry {
  const CreateVariableMenuEntry(this.name);
  final String name;
}

/// "Create location «x»" (ADR-0047, DESIGN-009 follow-up 4) — offered only
/// when [TokenInsertionMenu.onCreateLocation] is supplied, i.e. only in a
/// field with a `StationScope` (a station needs to own the new [Location]).
class CreateLocationMenuEntry extends TokenMenuEntry with _CreateEntry {
  const CreateLocationMenuEntry(this.label);
  final String label;
}

/// "Create person «x»", the [StationPersonToken] counterpart of
/// [CreateLocationMenuEntry].
class CreatePersonMenuEntry extends TokenMenuEntry with _CreateEntry {
  const CreatePersonMenuEntry(this.label);
  final String label;
}

/// Which entity kind a [StationFacetMenuEntry] completes — `station.loc.*`
/// or `station.person.*` (ADR-0047, DESIGN-009 follow-up 4d).
enum StationFacetKind { location, person }

/// A `{{station.loc/person.<slug>.<facetPath>}}` entry completing a known
/// entity's facet — additive to the bare [StationLocationMenuEntry]/
/// [StationPersonMenuEntry] default, never replacing it (DESIGN-009
/// follow-up 4d). [facetPath] is one or two segments (`['position']` or, for
/// a person's location chained to its own facets, `['loc', 'position']`),
/// joined with `.` to complete the token in
/// [TokenInsertionMenuState._select].
class StationFacetMenuEntry extends TokenMenuEntry {
  const StationFacetMenuEntry({
    required this.kind,
    required this.slug,
    required this.facetPath,
    required this.label,
  });

  final StationFacetKind kind;
  final String slug;
  final List<String> facetPath;

  /// The facet's own display label, e.g. "Description".
  final String label;
}

class _Trigger {
  const _Trigger({
    required this.start,
    required this.filter,
    required this.isBrace,
  });

  /// Index of the trigger's first character (the `/` or the first `{`).
  final int start;
  final String filter;

  /// Whether this is a `{{` trigger rather than a `/` one.
  ///
  /// Only a `{{` trigger may have the *rest of a token* ahead of the caret, so
  /// only it consumes what follows (see [_replacementEnd]). After a `/`, a `}}`
  /// further along the line is ordinary text and stays put.
  final bool isBrace;
}

/// Where an insertion stops replacing, starting from [_Trigger.start].
///
/// The caret is the obvious end and the wrong one when the caret sits *inside* an
/// existing token. Put it right after the braces of `{{var.year}}` and the menu
/// opens, correctly — but replacing only up to the caret left the `var.year}}`
/// tail behind, so picking an entry produced `{{var.year}}var.year}}` rather than
/// replacing the token the author was plainly editing.
///
/// Token characters followed by `}}` are the rest of that token, so they go with
/// it. The `}}` is required: without it there is no token ahead, just prose, and
/// prose after the caret is not the author's to lose. Matching stops at the first
/// `}}`, so a second token further along the line is never swallowed.
int _replacementEnd(String text, int caret, _Trigger trigger) {
  if (!trigger.isBrace) return caret;
  final tail = RegExp(r'^[\w.]*\}\}').firstMatch(text.substring(caret));
  return tail == null ? caret : caret + tail.end;
}

/// `/` opens the command menu; an unclosed `{{` opens the same picker
/// directly. Both are detected by looking backward from the caret, so
/// typing continues to work as ordinary text until one of these patterns
/// appears right before the caret.
///
/// The `{{` filter allows a `.` (in addition to word characters) so that
/// manually typing the actual token syntax — `{{var.` or `{{exercise.` —
/// keeps the menu open and filtering instead of closing the instant the
/// dot is typed; it only closes once the token itself closes (typing `}`
/// is not a filter character, so a completed `{{var.frekvens}}` no longer
/// matches). The `/` trigger deliberately does not allow `.`: variable
/// names are plain slugs (ADR-0046) with no dotted path to type out.
///
/// The `/` trigger used to require a space (or the start of the field) in front of
/// it, which made `Kanal/` type as ordinary text and open nothing — the author has
/// to know to put a space in first, and there is nothing on screen to tell them
/// that. It now fires wherever the `/` is.
///
/// The two exclusions left are the ones where a `/` is provably part of something
/// else: right after another `/` or after a `:`, which between them cover
/// `https://`, `//` and the like. Without them, typing a URL into a markdown field
/// pops the menu open mid-word. A `/` after a letter or a digit does open it —
/// "rull/retur" will — and that is the accepted cost: the menu changes no text, and
/// the next non-word character closes it again.
_Trigger? _detectTrigger(String text, int caret) {
  if (caret < 0 || caret > text.length) return null;
  final before = text.substring(0, caret);
  if (_insideQuotes(before)) return null;

  final brace = RegExp(r'\{\{([\w.]*)$').firstMatch(before);
  if (brace != null) {
    return _Trigger(start: brace.start, filter: brace.group(1)!, isBrace: true);
  }

  final slash = RegExp(r'(?<![/:])/(\w*)$').firstMatch(before);
  if (slash != null) {
    // The match starts at the `/` itself now that nothing precedes it in the
    // pattern, so there is no need to go looking for it again.
    return _Trigger(
      start: slash.start,
      filter: slash.group(1)!,
      isBrace: false,
    );
  }

  return null;
}

/// Whether the caret sits inside an open quotation.
///
/// Quoted text is being reported rather than written — a talegruppe, a phrase from
/// the source booklet, "km/t" — so a `/` or a `{{` in there is content, and popping
/// the menu open over it is noise the author has to dismiss every time.
///
/// Judged per line, not per field: prose closes its quotes on the same line it opens
/// them, and one stray `"` earlier in a long markdown field would otherwise flip
/// every trigger after it for good.
///
/// `"` is counted for parity, since the same character opens and closes. `«` and `“`
/// are matched against their closers instead, which is what a Norwegian author
/// actually types. `'` is left out on purpose: it is an apostrophe far more often
/// than a quote, and counting it would break the trigger after every "don't".
bool _insideQuotes(String before) {
  final lineStart = before.lastIndexOf('\n') + 1;
  final line = before.substring(lineStart);
  if (line.split('"').length.isEven) return true;
  for (final pair in const [('«', '»'), ('\u201C', '\u201D')]) {
    final open = line.lastIndexOf(pair.$1);
    if (open >= 0 && !line.substring(open).contains(pair.$2)) return true;
  }
  return false;
}

/// A `{{var.` prefix on the filter names the registry namespace explicitly
/// (ADR-0046) rather than being part of any entry's own name — matching it
/// literally against variable names would never succeed. Stripped so
/// `{{var.frek` filters variables by `frek`, the same as typing `/frek`
/// would, instead of showing "no matches" for as long as the prefix is
/// present.
final _varPrefixPattern = RegExp(r'^var\.(.*)$', caseSensitive: false);

/// `{{station.loc.`/`{{station.person.` prefixes name the station-scoped
/// namespaces explicitly (ADR-0047, DESIGN-009 follow-up 4), the
/// `station.*` counterpart of [_varPrefixPattern].
final _stationLocPrefixPattern = RegExp(
  r'^station\.loc\.(.*)$',
  caseSensitive: false,
);
final _stationPersonPrefixPattern = RegExp(
  r'^station\.person\.(.*)$',
  caseSensitive: false,
);

String _locationFacetLabel(AppLocalizations l10n, String facet) =>
    switch (facet) {
      'place' => l10n.locationsSectionPlaceLabel,
      'label' => l10n.locationsSectionLabelLabel,
      'position' => l10n.positionUtm,
      _ => facet,
    };

String _personFacetLabel(AppLocalizations l10n, String facet) =>
    switch (facet) {
      'name' => l10n.roleName,
      'age' => l10n.roleAge,
      'gender' => l10n.roleGender,
      'description' => l10n.roleDescription,
      'loc' => l10n.personsSectionLocationLabel,
      _ => facet,
    };

/// Wraps a token-aware field with the DESIGN-008 `/`/`{{` insertion menu: an
/// [OverlayEntry] anchored at the caret (via [RenderEditable] found through
/// [FocusNode.context], not a `position: fixed` hack), shown while the
/// caret sits right after an unclosed `{{` or a `/` command, and dismissed
/// on Escape, on a tap outside, or once the caret moves away from the
/// trigger.
///
/// A markdown section body fills the whole screen ([RingDrillTextArea]'s
/// `expands: true`), so anchoring at the *field's* bounding box (an earlier
/// version of this widget did, via [CompositedTransformFollower]) puts the
/// menu at the bottom of the screen for a caret near the top of a long
/// field — anchoring at the caret itself is not optional here.
class TokenInsertionMenu extends StatefulWidget {
  const TokenInsertionMenu({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.child,
    this.variables = const [],
    this.planFields = const [],
    this.stationLocations = const [],
    this.stationPersons = const [],
    this.onCreateVariable,
    this.onCreateLocation,
    this.onCreatePerson,
    this.selfLocation,
    this.selfPerson,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Widget child;
  final List<VariableToken> variables;
  final List<PlanFieldToken> planFields;

  /// `station.loc.*`/`station.person.*` entries (ADR-0047, DESIGN-009
  /// follow-up 4) — empty when the field has no `StationScope` ancestor
  /// (Plan/Exercise fields), same as [variables] being empty absent a
  /// `PlanScope`.
  final List<StationLocationToken> stationLocations;
  final List<StationPersonToken> stationPersons;

  /// Self-reference withholding (DESIGN-009 follow-up 4e) — see
  /// [SelfTokenExclusion]. Null (the default) excludes nothing.
  final SelfTokenExclusion? selfLocation;
  final SelfTokenExclusion? selfPerson;

  /// Wired by the caller once a scope owns a variable registry to mutate
  /// (DESIGN-008 Stage 5). Null keeps the "Opprett variabel" entry hidden.
  final ValueChanged<String>? onCreateVariable;

  /// Wired by the caller once a `StationScope` owns a station to create a
  /// new [Location]/[Person] on, from the typed label — synchronous, like
  /// [onCreateVariable]: the callback creates the entity in its own working
  /// list right away and returns its generated slug, which is what gets
  /// embedded in the inserted `{{station.loc/person.<slug>}}` token (ADR-0047
  /// DESIGN-009 follow-up 4). Null keeps the "Create location/person «x»"
  /// entry hidden — a field with no `StationScope` has no station to own
  /// the new entity.
  final String Function(String label)? onCreateLocation;
  final String Function(String label)? onCreatePerson;

  @override
  State<TokenInsertionMenu> createState() => TokenInsertionMenuState();
}

/// Public (not the usual `_State` convention) so a widget test can inspect
/// [isMenuOpen] via `tester.state<TokenInsertionMenuState>(...)`.
class TokenInsertionMenuState extends State<TokenInsertionMenu> {
  /// Card width, and the width it settles for on a narrow viewport.
  ///
  /// 280 was too tight once entries carried both a name and a value: a talegruppe
  /// like `RK-VFOLD-ØV4 / DMO-ANDRE-1` beside `talegruppe_ovelse` left both
  /// ellipsised. The card takes [_menuMaxWidth] where there is room and shrinks to
  /// fit where there is not, so a phone still gets a card inside its margins
  /// rather than one clipped by the screen edge.
  static const _menuMaxWidth = 360.0;
  static const _menuMaxHeight = 240.0;
  static const _gap = 4.0;

  /// Breathing room between the card and the screen edge.
  static const _edgeMargin = 8.0;

  OverlayEntry? _entry;
  _Trigger? _trigger;
  Rect? _caretRect;

  /// Where the trigger was when the author dismissed the menu on purpose.
  ///
  /// Dismissing has to *stay* dismissed. Without this, Escape closed the menu and
  /// then any caret move back to the same spot reopened it — the controller notifies
  /// on a selection change too, so simply clicking where you had just escaped from
  /// put it straight back. The author had no way to say "not here".
  ///
  /// Held as an offset and checked against the character still sitting there, so the
  /// suppression lasts exactly as long as that trigger does: keep typing after the
  /// `/` and it stays shut, delete the `/` and retype it and it opens again. Which is
  /// how a completion popup behaves everywhere else.
  int? _dismissedAt;

  @visibleForTesting
  bool get isMenuOpen => _entry != null;

  /// Whether the bare `{{station.loc.<slug>}}` entry is this field's own
  /// self-reference (DESIGN-009 follow-up 4e, [SelfTokenExclusion]).
  bool _excludeLocationBare(String slug) =>
      widget.selfLocation != null &&
      widget.selfLocation!.slug == slug &&
      widget.selfLocation!.excludeBare;

  bool _excludePersonBare(String slug) =>
      widget.selfPerson != null &&
      widget.selfPerson!.slug == slug &&
      widget.selfPerson!.excludeBare;

  /// Whether `.facet` on `<slug>` is this field's own withheld self-facet.
  bool _excludeLocationFacet(String slug, String facet) =>
      widget.selfLocation != null &&
      widget.selfLocation!.slug == slug &&
      widget.selfLocation!.excludedFacet == facet;

  bool _excludePersonFacet(String slug, String facet) =>
      widget.selfPerson != null &&
      widget.selfPerson!.slug == slug &&
      widget.selfPerson!.excludedFacet == facet;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    // The section editor's ⋮ opens the browser for whichever token-aware field has
    // focus (ADR-0067), and only this widget knows how. Registration follows focus
    // rather than mounting: several of these are alive in one section form, and the
    // ⋮ has to mean the field the caret is in.
    widget.focusNode.addListener(_onFocusChanged);
    if (widget.focusNode.hasFocus) TokenBrowserRegistry().register(_browse);
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus) {
      TokenBrowserRegistry().register(_browse);
    } else {
      TokenBrowserRegistry().unregister(_browse);
    }
  }

  @override
  void didUpdateWidget(TokenInsertionMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
      _onFocusChanged();
    }
    // Refreshes the open menu's content (e.g. a variable's effective value)
    // against this widget's latest data. Deferred to a post-frame callback,
    // the same way _onChanged defers _refreshMenuPosition: this can run
    // while a caller's own onChanged is mid-rebuild of an ancestor (e.g.
    // RolePlayFormScreen's name field calls setState() on every keystroke to
    // keep its identity preview live), and OverlayEntry.markNeedsBuild is a
    // setState on a State elsewhere in the tree (attached to the root
    // Overlay, not a descendant of what's currently building) — calling it
    // synchronously here would hit "setState() or markNeedsBuild() called
    // during build". _entry is re-read at call time (not captured), so a
    // menu hidden/disposed before the callback fires is a safe no-op.
    if (_entry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _entry?.markNeedsBuild();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    TokenBrowserRegistry().unregister(_browse);
    _entry?.remove();
    super.dispose();
  }

  void _onChanged() {
    _expireDismissal();
    final selection = widget.controller.selection;
    if (!widget.focusNode.hasFocus ||
        !selection.isValid ||
        !selection.isCollapsed) {
      _hideMenu();
      return;
    }
    final trigger = _detectTrigger(
      widget.controller.text,
      selection.baseOffset,
    );
    if (trigger == null) {
      _hideMenu();
      return;
    }
    if (trigger.start == _dismissedAt) return;
    _trigger = trigger;
    // The controller notifies listeners synchronously as soon as its value
    // changes, before EditableText's own listener (registered later, since
    // this widget wraps it) has relaid-out RenderEditable for that change —
    // reading the caret rect right now would be one keystroke stale. Defer
    // to a post-frame callback, once layout has caught up.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshMenuPosition());
  }

  void _refreshMenuPosition() {
    if (!mounted || _trigger == null) return;
    final rect = _caretGlobalRect();
    if (rect == null) {
      _hideMenu();
      return;
    }
    _caretRect = rect;
    if (_entry == null) {
      _showMenu();
    } else {
      _entry!.markNeedsBuild();
    }
  }

  /// Finds the wrapped field's [RenderEditable] through its own
  /// [FocusNode]: [FocusNode.context] is the `Focus` widget `EditableText`
  /// builds around itself, which is a descendant of [EditableTextState] —
  /// reachable by an ancestor search from there, even though
  /// [TokenInsertionMenu]'s own `context` is on the *other* side (an
  /// ancestor of the field, not a descendant of it).
  Rect? _caretGlobalRect() {
    final focusContext = widget.focusNode.context;
    final editableState = focusContext
        ?.findAncestorStateOfType<EditableTextState>();
    final renderEditable = editableState?.renderEditable;
    if (renderEditable == null || !renderEditable.attached) return null;
    final selection = widget.controller.selection;
    if (!selection.isValid) return null;

    final local = renderEditable.getLocalRectForCaret(
      TextPosition(offset: selection.baseOffset),
    );
    return Rect.fromPoints(
      renderEditable.localToGlobal(local.topLeft),
      renderEditable.localToGlobal(local.bottomLeft),
    );
  }

  void _showMenu() {
    final entry = OverlayEntry(builder: _buildOverlay);
    _entry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  /// Drops the dismissal once the trigger it referred to is gone.
  ///
  /// Keyed on the *text*, never on where the caret is: moving away from a dismissed
  /// trigger and back again must not revive the menu, which is the whole point, so
  /// "no trigger detected right now" cannot be what expires it. Only the character
  /// at the remembered offset can — deleted, or shifted out from under the offset by
  /// an edit.
  void _expireDismissal() {
    final at = _dismissedAt;
    if (at == null) return;
    final text = widget.controller.text;
    if (at >= text.length || (text[at] != '/' && text[at] != '{')) {
      _dismissedAt = null;
    }
  }

  /// Closes the menu *and* remembers it, for Escape and for a tap outside — the two
  /// ways the author says "not this time". Distinct from [_hideMenu], which also runs
  /// when the trigger simply stops existing and must not suppress anything.
  void _dismiss() {
    _dismissedAt = _trigger?.start;
    _hideMenu();
  }

  void _hideMenu() {
    if (_entry == null) return;
    _entry!.remove();
    _entry = null;
    _trigger = null;
    _caretRect = null;
  }

  List<TokenMenuEntry> _filteredEntries(
    String rawFilter,
    AppLocalizations l10n,
  ) {
    // A `var.`/`station.loc.`/`station.person.` prefix names one registry
    // namespace explicitly (ADR-0046/ADR-0047) rather than being part of
    // any entry's own name — once typed, narrow to just that namespace and
    // match the remainder against its entries' names, the same as the bare
    // `/` picker would for an unprefixed filter.
    final varMatch = _varPrefixPattern.firstMatch(rawFilter);
    final locMatch = _stationLocPrefixPattern.firstMatch(rawFilter);
    final personMatch = _stationPersonPrefixPattern.firstMatch(rawFilter);
    final namespaced = varMatch ?? locMatch ?? personMatch;
    final filter = namespaced?.group(1) ?? rawFilter;
    final lower = filter.toLowerCase();

    final entries = <TokenMenuEntry>[];
    // Set once a station.loc./station.person. filter's slug segment exactly
    // matches an existing entity (DESIGN-009 follow-up 4d) — an existing
    // slug with no matching facet still means "found the entity", not
    // "create it", so this suppresses that namespace's "Create …" fallback
    // below even when its own facet-completion entries come back empty.
    var matchedEntity = false;

    if (namespaced == null || varMatch != null) {
      for (final v in widget.variables) {
        if (filter.isEmpty || v.name.toLowerCase().contains(lower)) {
          entries.add(VariableMenuEntry(v));
        }
      }
    }
    if (namespaced == null) {
      for (final f in widget.planFields) {
        if (filter.isEmpty ||
            f.name.toLowerCase().contains(lower) ||
            f.label.toLowerCase().contains(lower)) {
          entries.add(PlanFieldMenuEntry(f));
        }
      }
    }
    if (locMatch != null) {
      final result = _facetAwareEntries(
        l10n: l10n,
        isLocation: true,
        filter: filter,
      );
      entries.addAll(result.entries);
      matchedEntity = matchedEntity || result.matchedEntity;
    } else if (namespaced == null) {
      for (final l in widget.stationLocations) {
        if (_excludeLocationBare(l.slug)) continue;
        if (filter.isEmpty ||
            l.slug.toLowerCase().contains(lower) ||
            l.label.toLowerCase().contains(lower)) {
          entries.add(StationLocationMenuEntry(l));
        }
      }
    }
    if (personMatch != null) {
      final result = _facetAwareEntries(
        l10n: l10n,
        isLocation: false,
        filter: filter,
      );
      entries.addAll(result.entries);
      matchedEntity = matchedEntity || result.matchedEntity;
    } else if (namespaced == null) {
      for (final p in widget.stationPersons) {
        if (_excludePersonBare(p.slug)) continue;
        if (filter.isEmpty ||
            p.slug.toLowerCase().contains(lower) ||
            p.label.toLowerCase().contains(lower)) {
          entries.add(StationPersonMenuEntry(p));
        }
      }
    }
    // Inline creation (ADR-0047, DESIGN-009 follow-up 4): when the filter
    // matches nothing, offer a "Create …" entry per namespace that both (a)
    // has a callback wired (only a field with the right scope offers it at
    // all) and (b) is in scope for the current prefix — an explicit
    // "var."/"station.loc."/"station.person." prefix narrows to just that
    // one kind, matching how it already narrows the real entries above; a
    // bare filter (no prefix) offers every kind that is available here, all
    // at once, since the author has not said which they mean yet.
    final trimmed = filter.trim();
    if (trimmed.isNotEmpty && entries.isEmpty && !matchedEntity) {
      if ((namespaced == null || varMatch != null) &&
          widget.onCreateVariable != null) {
        entries.add(CreateVariableMenuEntry(trimmed));
      }
      if ((namespaced == null || locMatch != null) &&
          widget.onCreateLocation != null) {
        entries.add(CreateLocationMenuEntry(trimmed));
      }
      if ((namespaced == null || personMatch != null) &&
          widget.onCreatePerson != null) {
        entries.add(CreatePersonMenuEntry(trimmed));
      }
    }
    return entries;
  }

  /// `station.loc.`/`station.person.` facet completion (ADR-0047,
  /// DESIGN-009 follow-up 4d): [filter] is the text after that prefix, read
  /// as `<slug>[.<facetPath>]`. While `<slug>` doesn't exactly match an
  /// existing entity, this behaves exactly like the pre-4d entity list
  /// (filtering by `contains`). Once it does, the picker switches from
  /// "search for an entity" to "complete this entity's facets":
  ///
  /// * No dot yet (`filter == slug`) — discovery: the bare entry plus every
  ///   facet, unfiltered, so the facets are discoverable without knowing to
  ///   type `.` first.
  /// * One dot (`slug.partial`) — completion: that kind's facets filtered
  ///   by `partial`, dropping the bare entry (the author has committed to
  ///   picking a facet).
  /// * For a person, `slug.loc.partial` — chaining: the *location* facets
  ///   filtered by `partial`, completing to `loc.<facet>`. One level of
  ///   chaining, matching `_resolvePersonFacet`'s `loc` case in
  ///   `brief_renderer.dart`.
  ({List<TokenMenuEntry> entries, bool matchedEntity}) _facetAwareEntries({
    required AppLocalizations l10n,
    required bool isLocation,
    required String filter,
  }) {
    final dot = filter.indexOf('.');
    final slugPart = dot < 0 ? filter : filter.substring(0, dot);
    final rest = dot < 0 ? null : filter.substring(dot + 1);
    final lower = filter.toLowerCase();

    if (isLocation) {
      final location = _byExactSlug(
        widget.stationLocations,
        (l) => l.slug,
        slugPart,
      );
      if (location == null) {
        return (
          entries: [
            for (final l in widget.stationLocations)
              if (!_excludeLocationBare(l.slug) &&
                  (filter.isEmpty ||
                      l.slug.toLowerCase().contains(lower) ||
                      l.label.toLowerCase().contains(lower)))
                StationLocationMenuEntry(l),
          ],
          matchedEntity: false,
        );
      }
      return (
        entries: [
          if (rest == null && !_excludeLocationBare(location.slug))
            StationLocationMenuEntry(location),
          for (final f in locationFacetNames)
            if ((rest == null ||
                    f.toLowerCase().contains(rest.toLowerCase())) &&
                !_excludeLocationFacet(location.slug, f))
              StationFacetMenuEntry(
                kind: StationFacetKind.location,
                slug: slugPart,
                facetPath: [f],
                label: _locationFacetLabel(l10n, f),
              ),
        ],
        matchedEntity: true,
      );
    }

    final person = _byExactSlug(widget.stationPersons, (p) => p.slug, slugPart);
    if (person == null) {
      return (
        entries: [
          for (final p in widget.stationPersons)
            if (!_excludePersonBare(p.slug) &&
                (filter.isEmpty ||
                    p.slug.toLowerCase().contains(lower) ||
                    p.label.toLowerCase().contains(lower)))
              StationPersonMenuEntry(p),
        ],
        matchedEntity: false,
      );
    }

    // Location chaining (DESIGN-009 follow-up 4d): a person path
    // <slug>.loc.<partial> switches from completing the person's own
    // facets to completing their *location's* facets — mirroring
    // _resolvePersonFacet's 'loc' case, which resolves Person.locSlug to
    // a Location and applies the remaining facet path to it. One level
    // only, matching the renderer.
    if (rest != null) {
      final locDot = rest.indexOf('.');
      if (locDot >= 0 && rest.substring(0, locDot).toLowerCase() == 'loc') {
        final locPartial = rest.substring(locDot + 1).toLowerCase();
        return (
          entries: [
            for (final f in locationFacetNames)
              if (locPartial.isEmpty || f.toLowerCase().contains(locPartial))
                StationFacetMenuEntry(
                  kind: StationFacetKind.person,
                  slug: slugPart,
                  facetPath: ['loc', f],
                  label: _locationFacetLabel(l10n, f),
                ),
          ],
          matchedEntity: true,
        );
      }
    }
    return (
      entries: [
        if (rest == null && !_excludePersonBare(person.slug))
          StationPersonMenuEntry(person),
        for (final f in personFacetNames)
          if ((rest == null || f.toLowerCase().contains(rest.toLowerCase())) &&
              !_excludePersonFacet(person.slug, f))
            StationFacetMenuEntry(
              kind: StationFacetKind.person,
              slug: slugPart,
              facetPath: [f],
              label: _personFacetLabel(l10n, f),
            ),
      ],
      matchedEntity: true,
    );
  }

  T? _byExactSlug<T>(
    List<T> items,
    String Function(T item) slugOf,
    String slug,
  ) {
    final lower = slug.toLowerCase();
    for (final item in items) {
      if (slugOf(item).toLowerCase() == lower) return item;
    }
    return null;
  }

  void _select(TokenMenuEntry entry) {
    // Not an insertion of its own — it opens the browser, which produces one
    // (ADR-0067).
    if (entry is BrowseTokensMenuEntry) {
      _browse();
      return;
    }
    final trigger = _trigger;
    if (trigger == null) return;
    final token = switch (entry) {
      // Unreachable: returned above. The arm exists because [TokenMenuEntry] is
      // sealed, so the switch has to name every subclass.
      BrowseTokensMenuEntry() => '',
      VariableMenuEntry(token: final v) => '{{var.${v.name}}}',
      PlanFieldMenuEntry(token: final f) => '{{${f.name}}}',
      StationLocationMenuEntry(token: final l) => '{{station.loc.${l.slug}}}',
      StationPersonMenuEntry(token: final p) => '{{station.person.${p.slug}}}',
      StationFacetMenuEntry(
        kind: final kind,
        slug: final slug,
        facetPath: final path,
      ) =>
        '{{station.${kind == StationFacetKind.location ? 'loc' : 'person'}.'
            '$slug.${path.join('.')}}}',
      CreateVariableMenuEntry(name: final name) => '{{var.$name}}',
      // The slug is only known once the callback creates the entity (it
      // generates it, ADR-0047), unlike CreateVariableMenuEntry where the
      // typed name already *is* the var.* key.
      CreateLocationMenuEntry(label: final label) =>
        '{{station.loc.${widget.onCreateLocation!(label)}}}',
      CreatePersonMenuEntry(label: final label) =>
        '{{station.person.${widget.onCreatePerson!(label)}}}',
    };
    _insert(token, trigger: trigger);
    if (entry is CreateVariableMenuEntry) {
      widget.onCreateVariable?.call(entry.name);
    }
    _hideMenu();
  }

  /// Puts [token] in the field, and leaves the caret after it.
  ///
  /// The one implementation of "what text does an entry produce", shared by the
  /// caret menu and the browser (ADR-0067) so the two cannot drift on the part
  /// that is easy to get subtly wrong — which range gets replaced.
  ///
  /// With no [trigger] there is nothing to replace and the token is inserted at
  /// the caret: that is the browser opened from the section editor's own menu,
  /// where the author never typed a trigger character.
  void _insert(String token, {_Trigger? trigger}) {
    final text = widget.controller.text;
    final caret = widget.controller.selection.baseOffset;
    final start = trigger?.start ?? (caret < 0 ? text.length : caret);
    final end = trigger == null ? start : _replacementEnd(text, caret, trigger);
    widget.controller.value = TextEditingValue(
      text: text.replaceRange(start, end, token),
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  /// Opens the token browser and inserts whatever it returns.
  ///
  /// The entries are built here, not in the picker's builder: the picker mounts on
  /// a modal route, a sibling of this subtree rather than a descendant, so
  /// `PlanScope` and the other scopes are out of reach from inside it (DESIGN-008
  /// follow-up 11). This context has them, so the live values are resolved before
  /// the sheet opens.
  ///
  /// The trigger is captured before the menu closes, because closing clears it and
  /// the author's `/` or `{{` still has to be replaced rather than left in the
  /// text beside the token.
  Future<void> _browse() async {
    final trigger = _trigger;
    final entries = buildTokenBrowserEntries(
      context,
      planFields: widget.planFields,
      variables: widget.variables,
      stationLocations: widget.stationLocations,
      stationPersons: widget.stationPersons,
    );
    _hideMenu();
    final token = await showTokenBrowser(context: context, entries: entries);
    if (token == null || !mounted) return;
    _insert(token, trigger: trigger);
    widget.focusNode.requestFocus();
  }

  Widget _buildOverlay(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = _filteredEntries(_trigger?.filter ?? '', l10n);
    final screenSize = MediaQuery.sizeOf(context);
    final caretRect = _caretRect ?? Rect.zero;
    final estimatedHeight = entries.isEmpty ? 48.0 : _menuMaxHeight;
    final width = math.min(
      _menuMaxWidth,
      math.max(0.0, screenSize.width - _edgeMargin * 2),
    );

    var left = caretRect.left;
    if (left + width > screenSize.width - _edgeMargin) {
      left = screenSize.width - _edgeMargin - width;
    }
    left = left.clamp(_edgeMargin, math.max(_edgeMargin, screenSize.width));

    // Prefer just below the caret line; flip above it if there is not
    // enough room below (e.g. typing on the last visible line of a
    // full-screen markdown section).
    var top = caretRect.bottom + _gap;
    if (top + estimatedHeight > screenSize.height) {
      top = caretRect.top - estimatedHeight - _gap;
    }
    top = top.clamp(0.0, screenSize.height);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            // Tapping in the text closes the menu and moves the caret: the barrier
            // is translucent, so the tap reaches the field too.
            onTap: _dismiss,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: width,
          child: _TokenMenuCard(
            entries: entries,
            width: width,
            // "No matches" used to be the whole card when nothing matched. The
            // pinned footer is always there now, so it is a muted line above the
            // things the author can still do — which is what it always meant.
            emptyLabel: entries.every((e) => e is _CreateEntry)
                ? l10n.tokenMenuEmpty
                : null,
            onSelect: _select,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (_entry != null &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _dismiss();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}

/// Share of the card's width a value may take, leaving the rest to the name.
///
/// A fraction rather than a fixed cap so it holds at whatever width the card
/// settled on. It also has to keep `ListTile`'s trailing from consuming the tile:
/// the leading icon, the title gap and the content padding come to about 66, so
/// any fraction well under 1 leaves the title real space at every width a screen
/// can produce.
const _menuValueWidthFraction = 0.42;

class _TokenMenuCard extends StatelessWidget {
  const _TokenMenuCard({
    required this.entries,
    required this.width,
    required this.emptyLabel,
    required this.onSelect,
  });

  final List<TokenMenuEntry> entries;

  /// The width the overlay settled on, so the value cap tracks it.
  final double width;

  /// Shown as a muted first row when nothing the author typed matched. Null when
  /// something did.
  final String? emptyLabel;
  final ValueChanged<TokenMenuEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: 240),
        // The footer is outside the scroll view and always built, so it is there
        // for a long list, a short one, and none at all.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  if (emptyLabel != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        emptyLabel!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final entry in entries) _tile(context, l10n, entry),
                ],
              ),
            ),
            const Divider(height: 1),
            _browseFooter(context, l10n),
          ],
        ),
      ),
    );
  }

  /// Fixed below the scroll view, on its own surface and behind a divider, so it
  /// reads as an action on the card rather than one more thing that matched. Accent
  /// coloured for the same reason the picker's own `footerActions` are.
  Widget _browseFooter(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => onSelect(const BrowseTokensMenuEntry()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Icon(
                Icons.manage_search,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.tokenBrowserBrowseAll,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    AppLocalizations l10n,
    TokenMenuEntry entry,
  ) {
    final mutedStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic);
    // Every tile's title/trailing is capped to one line: a menu card with a
    // fixed max height (_menuMaxHeight) renders as many tiles as fit its
    // viewport, so an entry whose text wraps to extra lines both looks
    // wrong and, worse, silently pushes tiles below it out of that
    // viewport — the exact failure mode ADR-0047/DESIGN-009 follow-up 4d's
    // facet-discovery list hit with a long location/person label paired
    // with a long preview (Flutter's ListTile has no built-in single-line
    // guarantee for either slot).
    Widget title(String text) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
    // ListTile lays its trailing out at the width the text wants and gives the
    // title whatever is left, so a long value — a location's "LSOR kurslokale,
    // 32V 0580465E 6551894N", a talegruppe like "RK-VFOLD-ØV4 / DMO-ANDRE-1" —
    // took the whole row and ellipsised the token's *name* down to nothing. The
    // name is what the author is looking for, so it gets the larger share and the
    // value is capped: an ellipsised value is still recognisable, an ellipsised
    // name is not.
    Widget trailing(String text, {TextStyle? style}) => ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width * _menuValueWidthFraction),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
    return switch (entry) {
      VariableMenuEntry(token: final v) => ListTile(
        dense: true,
        leading: const Icon(Icons.data_object, size: 18),
        title: title(v.name),
        trailing: trailing(
          v.effectiveValue,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onTap: () => onSelect(entry),
      ),
      PlanFieldMenuEntry(token: final f) => ListTile(
        dense: true,
        leading: const Icon(Icons.article_outlined, size: 18),
        title: title(f.label),
        // Which scope the token reads from — "plan", "øvelse", "post",
        // "rollespill". The fallback is what every entry used to show
        // unconditionally, which is why an {{exercise.*}} token read "planfelt".
        trailing: trailing(
          f.hint ?? l10n.tokenMenuPlanFieldHint,
          style: mutedStyle,
        ),
        onTap: () => onSelect(entry),
      ),
      StationLocationMenuEntry(token: final l) => ListTile(
        dense: true,
        leading: const Icon(Icons.location_on_outlined, size: 18),
        title: title(l.label),
        trailing: trailing(
          l.preview,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onTap: () => onSelect(entry),
      ),
      StationPersonMenuEntry(token: final p) => ListTile(
        dense: true,
        leading: const Icon(Icons.person_outline, size: 18),
        title: title(p.label),
        trailing: trailing(
          p.preview,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onTap: () => onSelect(entry),
      ),
      StationFacetMenuEntry(kind: final kind, label: final label) => ListTile(
        dense: true,
        leading: Icon(
          kind == StationFacetKind.location
              ? Icons.location_on_outlined
              : Icons.person_outline,
          size: 18,
        ),
        title: title(label),
        onTap: () => onSelect(entry),
      ),
      // The card's pinned footer, not a row — see [_browseFooter]. The arm exists
      // because [TokenMenuEntry] is sealed.
      BrowseTokensMenuEntry() => const SizedBox.shrink(),
      CreateVariableMenuEntry(name: final name) => ListTile(
        dense: true,
        leading: const Icon(Icons.add, size: 18),
        title: title(l10n.tokenMenuCreateVariable(name)),
        onTap: () => onSelect(entry),
      ),
      CreateLocationMenuEntry(label: final label) => ListTile(
        dense: true,
        leading: const Icon(Icons.add, size: 18),
        title: title(l10n.tokenMenuCreateLocation(label)),
        onTap: () => onSelect(entry),
      ),
      CreatePersonMenuEntry(label: final label) => ListTile(
        dense: true,
        leading: const Icon(Icons.add, size: 18),
        title: title(l10n.tokenMenuCreatePerson(label)),
        onTap: () => onSelect(entry),
      ),
    };
  }
}
