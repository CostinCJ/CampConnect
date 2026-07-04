import 'package:flutter/material.dart';

/// Shared building blocks of the "Trail Adventure" design system.
/// Keep screens consistent: use these instead of ad-hoc containers.

/// Left-aligned extra-bold section title with an optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  const SectionHeader(
    this.title, {
    super.key,
    this.action,
    this.padding = const EdgeInsets.only(top: 8, bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Friendly empty state: icon in a tonal circle, one-line invitation,
/// optional call to action. Never show a bare "nothing here" text.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact rounded pill for a small stat or badge (points, rank, count).
class StatPill extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color? background;
  final Color? foreground;

  const StatPill({
    super.key,
    this.icon,
    required this.label,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = background ?? theme.colorScheme.surfaceContainerHigh;
    final fg = foreground ?? theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Solid-color hero card (the team card on the kid home screen).
/// The one place a large color block is allowed outside emergency UI.
class HeroCard extends StatelessWidget {
  final Color color;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const HeroCard({
    super.key,
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  /// Readable foreground for text placed on [color].
  static Color onColor(Color color) =>
      color.computeLuminance() > 0.45 ? const Color(0xFF26302A) : Colors.white;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

/// Circular tonal icon bubble used as a leading element in list cards.
class IconBubble extends StatelessWidget {
  final IconData icon;
  final Color? background;
  final Color? foreground;
  final double size;

  const IconBubble({
    super.key,
    required this.icon,
    this.background,
    this.foreground,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: foreground ?? scheme.onPrimaryContainer,
      ),
    );
  }
}
