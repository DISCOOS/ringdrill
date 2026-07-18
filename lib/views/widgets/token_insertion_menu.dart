import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';

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

class CreateVariableMenuEntry extends TokenMenuEntry {
  const CreateVariableMenuEntry(this.name);
  final String name;
}

/// "Create location «x»" (ADR-0047, DESIGN-009 follow-up 4) — offered only
/// when [TokenInsertionMenu.onCreateLocation] is supplied, i.e. only in a
/// field with a `StationScope` (a station needs to own the new [Location]).
class CreateLocationMenuEntry extends TokenMenuEntry {
  const CreateLocationMenuEntry(this.label);
  final String label;
}

/// "Create person «x»", the [StationPersonToken] counterpart of
/// [CreateLocationMenuEntry].
class CreatePersonMenuEntry extends TokenMenuEntry {
  const CreatePersonMenuEntry(this.label);
  final String label;
}

/// Which entity kind a [StationFacetMenuEntry] completes — `station.loc.*`
/// or `station.person.*` (ADR-0047, DESIGN-009 follow-up 4d).
enum StationFacetKind { location, person }

/// A `{{station.loc/person.<slug>.<facetPath>}}` entry completing a known
/// entity's facet — additive to the bare [StationLocationMenuEntry]/
/// [StationPersonMenuEntry] default, never replacing it (DESIGN-009
/// follow-up 4d). [facetPath] is one or two segments (`['utm']` or, for a
/// person's location chained to its own facets, `['loc', 'utm']`), joined
/// with `.` to complete the token in [TokenInsertionMenuState._select].
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

  /// The facet's own display label, e.g. "Signalement".
  final String label;
}

class _Trigger {
  const _Trigger({required this.start, required this.filter});

  /// Index of the trigger's first character (the `/` or the first `{`).
  final int start;
  final String filter;
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
_Trigger? _detectTrigger(String text, int caret) {
  if (caret < 0 || caret > text.length) return null;
  final before = text.substring(0, caret);

  final brace = RegExp(r'\{\{([\w.]*)$').firstMatch(before);
  if (brace != null) {
    return _Trigger(start: brace.start, filter: brace.group(1)!);
  }

  final slash = RegExp(r'(?:^|\s)/(\w*)$').firstMatch(before);
  if (slash != null) {
    return _Trigger(start: before.lastIndexOf('/'), filter: slash.group(1)!);
  }

  return null;
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

/// The facets `brief_renderer.dart`'s `_resolveLocationFacet` switches on,
/// in picker display order (ADR-0047, DESIGN-009 follow-up 4d). There is no
/// facet enum in the renderer, so this constant — read directly by the
/// resolution-guard test that renders each one through `BriefRenderer` — is
/// what keeps the picker in sync with it. Public (not the usual leading
/// underscore) for that test's benefit only, same rationale as
/// [TokenInsertionMenuState.isMenuOpen]. The bare token (no facet) is a
/// separate, always-offered default; it is not itself in this list.
@visibleForTesting
const locationFacetNames = ['place', 'label', 'utm'];

/// The facets `_resolvePersonFacet` switches on. `loc` chains to the
/// person's location's own [locationFacetNames] one level deep (see
/// `_facetAwareEntries`) — `brief_renderer.dart` supports exactly one level
/// of chaining, so this picker does too.
@visibleForTesting
const personFacetNames = ['name', 'age', 'gender', 'signalement', 'loc'];

String _locationFacetLabel(AppLocalizations l10n, String facet) =>
    switch (facet) {
      'place' => l10n.locationsSectionPlaceLabel,
      'label' => l10n.locationsSectionLabelLabel,
      'utm' => l10n.utm,
      _ => facet,
    };

String _personFacetLabel(AppLocalizations l10n, String facet) =>
    switch (facet) {
      'name' => l10n.roleName,
      'age' => l10n.roleAge,
      'gender' => l10n.roleGender,
      'signalement' => l10n.roleSignalement,
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
  /// (Program/Exercise fields), same as [variables] being empty absent a
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
  static const _menuWidth = 280.0;
  static const _menuMaxHeight = 240.0;
  static const _gap = 4.0;

  OverlayEntry? _entry;
  _Trigger? _trigger;
  Rect? _caretRect;

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
  }

  @override
  void didUpdateWidget(TokenInsertionMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
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
    _entry?.remove();
    super.dispose();
  }

  void _onChanged() {
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
            if ((rest == null || f.toLowerCase().contains(rest.toLowerCase())) &&
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
    final trigger = _trigger;
    if (trigger == null) return;
    final caret = widget.controller.selection.baseOffset;
    final text = widget.controller.text;
    final token = switch (entry) {
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
    final newText = text.replaceRange(trigger.start, caret, token);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: trigger.start + token.length),
    );
    if (entry is CreateVariableMenuEntry) {
      widget.onCreateVariable?.call(entry.name);
    }
    _hideMenu();
  }

  Widget _buildOverlay(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = _filteredEntries(_trigger?.filter ?? '', l10n);
    final screenSize = MediaQuery.sizeOf(context);
    final caretRect = _caretRect ?? Rect.zero;
    final estimatedHeight = entries.isEmpty ? 48.0 : _menuMaxHeight;

    var left = caretRect.left;
    if (left + _menuWidth > screenSize.width) {
      left = screenSize.width - _menuWidth;
    }
    left = left.clamp(0.0, screenSize.width);

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
            onTap: _hideMenu,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: _menuWidth,
          child: _TokenMenuCard(
            entries: entries,
            emptyLabel: l10n.tokenMenuEmpty,
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
          _hideMenu();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}

class _TokenMenuCard extends StatelessWidget {
  const _TokenMenuCard({
    required this.entries,
    required this.emptyLabel,
    required this.onSelect,
  });

  final List<TokenMenuEntry> entries;
  final String emptyLabel;
  final ValueChanged<TokenMenuEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280, maxHeight: 240),
        child: entries.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  emptyLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final entry in entries) _tile(context, l10n, entry),
                ],
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
    Widget trailing(String text, {TextStyle? style}) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
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
        trailing: trailing(l10n.tokenMenuPlanFieldHint, style: mutedStyle),
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
