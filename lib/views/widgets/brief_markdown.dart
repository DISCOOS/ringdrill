import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:ringdrill/views/widgets/brief_theme.dart';

// ---------------------------------------------------------------------------
// Private heading-config subclasses that suppress the built-in divider
// ---------------------------------------------------------------------------
//
// markdown_widget v2.x ships H1Config / H2Config / H3Config with a non-null
// `divider` getter that renders an underline below every heading, coloured
// from the default Material palette.  The `tag` getter is @nonVirtual on each
// concrete class, so subclasses still register under the correct tag.  We
// override only `divider → null` to remove the underlines without touching
// any other logic.

class _BriefH1Config extends H1Config {
  const _BriefH1Config({super.style});
  @override
  HeadingDivider? get divider => null;
}

class _BriefH2Config extends H2Config {
  const _BriefH2Config({super.style});
  @override
  HeadingDivider? get divider => null;
}

class _BriefH3Config extends H3Config {
  const _BriefH3Config({super.style});
  @override
  HeadingDivider? get divider => null;
}

// ---------------------------------------------------------------------------
// BriefMarkdown
// ---------------------------------------------------------------------------

/// A thin wrapper around [MarkdownWidget] that applies a [BriefTheme] to
/// every markdown node type via a fully populated [MarkdownConfig].
///
/// All style decisions for the Brief reading surface flow through
/// [BriefTheme]; no call site should reach into [MarkdownConfig] directly.
///
/// Usage:
/// ```dart
/// BriefMarkdown(
///   data: markdownString,
///   theme: BriefTheme.of(context),
///   tocController: _tocController,
/// )
/// ```
class BriefMarkdown extends StatelessWidget {
  const BriefMarkdown({
    super.key,
    required this.data,
    required this.theme,
    this.tocController,
  });

  final String data;
  final BriefTheme theme;
  final TocController? tocController;

  @override
  Widget build(BuildContext context) {
    return MarkdownWidget(
      data: data,
      tocController: tocController,
      config: _buildConfig(),
    );
  }

  MarkdownConfig _buildConfig() {
    final t = theme;

    return MarkdownConfig(
      configs: [
        // Headings — style from theme, no built-in dividers
        _BriefH1Config(style: t.typography.h1.copyWith(color: t.text.heading)),
        _BriefH2Config(style: t.typography.h2.copyWith(color: t.text.heading)),
        _BriefH3Config(style: t.typography.h3.copyWith(color: t.text.heading)),
        H4Config(style: t.typography.h4.copyWith(color: t.text.heading)),
        // Paragraphs
        PConfig(textStyle: t.typography.body.copyWith(color: t.text.body)),
        // Links — body color with thin underline; distinction is the
        // underline opacity, not a different hue.
        LinkConfig(
          style: TextStyle(
            color: t.link.color,
            decoration: TextDecoration.underline,
            decorationColor: t.link.color.withValues(
              alpha: t.link.underlineOpacity,
            ),
          ),
        ),
        // Inline code
        CodeConfig(
          style: t.typography.code.copyWith(
            color: t.code.foreground,
            backgroundColor: t.code.background,
          ),
        ),
        // Fenced code blocks
        PreConfig(
          textStyle: t.typography.code.copyWith(color: t.code.foreground),
          decoration: BoxDecoration(
            color: t.code.background,
            border: Border.all(color: t.code.border),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
        // Blockquotes
        BlockquoteConfig(sideColor: t.borders.subtle, textColor: t.text.muted),
        // Tables
        TableConfig(
          border: TableBorder.all(color: t.borders.subtle),
          headerStyle: TextStyle(
            color: t.text.heading,
            fontWeight: FontWeight.bold,
          ),
          bodyStyle: TextStyle(color: t.text.body),
        ),
        // Horizontal rules
        HrConfig(color: t.borders.subtle, height: 1),
      ],
    );
  }
}
