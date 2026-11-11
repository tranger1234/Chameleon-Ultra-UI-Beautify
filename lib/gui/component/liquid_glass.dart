import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:liquid_glass_native/liquid_glass_native.dart';

// Re-exported so pages only need this one import for glass widgets.
export 'package:liquid_glass_native/liquid_glass_native.dart';

/// Shared helpers that centralise the HIG rules for the Liquid Glass refactor.
///
/// * iOS 26+ -> the native `liquid_glass_native` widgets (real SwiftUI glass).
/// * Below iOS 26 / non-Apple platforms -> standard Material or an opaque
///   elevated surface. Nothing in this file uses `BackdropFilter`.
bool get isLiquidGlassActive => defaultTargetPlatform == TargetPlatform.iOS;

/// Regular glass variant tint for the current theme.
///
/// `regular` is the default variant and is used for every control. `clear` is
/// never used here: it is reserved for controls floating on photos/video.
Color liquidGlassTint(BuildContext context) =>
    Theme.of(context).colorScheme.primary;

/// Opaque elevated surface used when glass is not available (HIG rule 7).
Color elevatedSurface(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHigh;

/// A capsule-shaped glass container: the preferred shape for controls.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.child,
    this.tint,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  final Widget child;
  final Color? tint;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (!isLiquidGlassActive) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(100),
        ),
        child: child,
      );
    }

    return LiquidGlassContainer(
      tint: tint ?? liquidGlassTint(context),
      borderRadius: 100,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Glass content container with concentric corners matching the existing
/// 16px cards. Falls back to an opaque elevated surface.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.tint,
    this.padding,
  });

  final Widget child;
  final double borderRadius;
  final Color? tint;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final Widget content =
        padding == null ? child : Padding(padding: padding!, child: child);

    if (!isLiquidGlassActive) {
      return Container(
        decoration: BoxDecoration(
          color: elevatedSurface(context),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: content,
      );
    }

    return LiquidGlassContainer(
      tint: tint ?? liquidGlassTint(context),
      borderRadius: borderRadius,
      child: content,
    );
  }
}

/// A lightweight action widget: glass button on iOS, filled button elsewhere.
///
/// Replaces the page-level `TextButton`/`ElevatedButton` calls so the call
/// sites stay readable and every action keeps the same 44pt touch height.
class GlassAction extends StatelessWidget {
  const GlassAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingSymbol,
    this.tint,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? leadingSymbol;
  final Color? tint;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    Widget button;
    if (isLiquidGlassActive) {
      button = LiquidGlassButton(
        label: label,
        onPressed: onPressed,
        leadingSymbol: leadingSymbol,
        tint: tint ?? liquidGlassTint(context),
        borderRadius: 100,
      );
    } else {
      button = FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingSymbol != null) ...[
              _Glyph(symbol: leadingSymbol!),
              const SizedBox(width: 6),
            ],
            Text(label),
          ],
        ),
      );
    }

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A one-choice dropdown.
///
/// iOS 26 -> `LiquidGlassMenu` (regular variant, native blur + tint on the
/// system side, covers the whole panel including padding and scroll area).
/// Everything else -> `PopupMenuButton` styled by the global
/// `PopupMenuTheme` registered in `main.dart`: opaque elevated surface,
/// no translucency, no fake blur (HIG rule 7 fallback).
class GlassSelect<T> extends StatelessWidget {
  const GlassSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
    this.sfSymbol,
    this.width,
  });

  /// Text shown on the closed control / fallback button.
  final String label;

  /// Current selection. Nullable because several pages use a null value to
  /// mean "not chosen yet" (e.g. the magic-card write helper).
  final T? value;
  final List<GlassSelectOption<T>> options;
  final ValueChanged<T> onSelected;
  final String? sfSymbol;
  final double? width;

  @override
  Widget build(BuildContext context) {
    Widget control;

    if (isLiquidGlassActive) {
      control = LiquidGlassMenu(
        label: label,
        sfSymbol: sfSymbol,
        tint: liquidGlassTint(context),
        items: [
          for (int i = 0; i < options.length; i++)
            MenuItem(id: options[i].key ?? '$i', title: options[i].label),
        ],
        onSelected: (String id) {
          for (final GlassSelectOption<T> option in options) {
            if ((option.key ?? '${options.indexOf(option)}') == id) {
              onSelected(option.value);
              return;
            }
          }
        },
      );
    } else {
      control = PopupMenuButton<T>(
        initialValue: value,
        onSelected: onSelected,
        position: PopupMenuPosition.under,
        itemBuilder: (BuildContext context) => [
          for (final GlassSelectOption<T> option in options)
            PopupMenuItem<T>(value: option.value, child: Text(option.label)),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sfSymbol != null && !isLiquidGlassActive) ...[
                _Glyph(symbol: sfSymbol!),
                const SizedBox(width: 6),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      );
    }

    return width == null ? control : SizedBox(width: width, child: control);
  }
}

/// A menu trigger that opens a popup menu.
///
/// iOS 26 -> `LiquidGlassMenu`: the popup is a real native system menu, i.e.
/// the `regular` glass variant with background blur and the system tint, which
/// covers the entire panel (padding, scroll area, gaps between rows).
/// Non-iOS -> `PopupMenuButton` on the global opaque elevated surface
/// (`PopupMenuTheme` in main.dart). Menu rows are never given their own glass.
class GlassMenuButton extends StatelessWidget {
  const GlassMenuButton({
    super.key,
    required this.label,
    required this.sfSymbol,
    required this.fallbackIcon,
    required this.items,
    required this.onSelected,
    this.elevated = false,
  });

  /// Text on the button. Also used as the tooltip of the icon-only trigger.
  final String label;

  /// SF Symbol for the native trigger / rows.
  final String sfSymbol;

  /// Material icon for the icon-only trigger on non-Apple platforms.
  final IconData fallbackIcon;

  final List<GlassSelectOption<String>> items;
  final ValueChanged<String> onSelected;

  /// `true` renders a filled capsule trigger (used on the compact layouts
  /// where the button floats above the list), `false` an inline icon trigger.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    if (isLiquidGlassActive) {
      return LiquidGlassMenu(
        label: label,
        sfSymbol: sfSymbol,
        tint: liquidGlassTint(context),
        items: [
          for (final GlassSelectOption<String> item in items)
            MenuItem(id: item.value, title: item.label),
        ],
        onSelected: onSelected,
      );
    }

    final Widget trigger = elevated
        ? Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Icon(fallbackIcon, size: 22),
          )
        : Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(fallbackIcon, size: 22),
          );

    return Tooltip(
      message: label,
      child: PopupMenuButton<String>(
        tooltip: '',
        position: PopupMenuPosition.under,
        onSelected: onSelected,
        itemBuilder: (BuildContext context) => [
          for (final GlassSelectOption<String> item in items)
            PopupMenuItem<String>(value: item.value, child: Text(item.label)),
        ],
        child: trigger,
      ),
    );
  }
}

/// One row of a [GlassSelect].
class GlassSelectOption<T> {
  const GlassSelectOption({required this.label, required this.value, this.key});

  final String label;
  final T value;

  /// Stable string id required by the native menu; defaults to the index.
  final String? key;
}

/// Minimal SF Symbol stand-in for the non-iOS fallback rendering.
class _Glyph extends StatelessWidget {
  const _Glyph({required this.symbol});

  final String symbol;

  static const Map<String, IconData> _map = {
    'square.and.arrow.up': Icons.upload,
    'square.and.arrow.down': Icons.download,
    'info.circle': Icons.info_outline,
    'doc.plaintext': Icons.description_outlined,
    'clock.arrow.circlepath': Icons.history,
    'globe': Icons.language,
    'cpu': Icons.memory,
    'ant.fill': Icons.bolt,
  };

  @override
  Widget build(BuildContext context) =>
      Icon(_map[symbol] ?? Icons.circle, size: 18);
}
