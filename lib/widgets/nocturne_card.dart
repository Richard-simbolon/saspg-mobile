import 'package:flutter/material.dart';
import '../theme/nocturne_theme.dart';

class NocturneCard extends StatelessWidget {
  const NocturneCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderColor,
    this.padding = const EdgeInsets.all(NocturneSpace.s3 + 4),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? borderColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: NocturneColors.surface,
        borderRadius: BorderRadius.circular(NocturneRadius.md),
        border: Border.all(color: borderColor ?? NocturneColors.neutral800, width: 1),
      ),
      child: child,
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NocturneRadius.md),
      child: card,
    );
  }
}

class CardKicker extends StatelessWidget {
  const CardKicker(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        letterSpacing: 1.0,
        color: NocturneColors.accent,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class NocturneTag extends StatelessWidget {
  const NocturneTag(this.text, {super.key, this.variant = TagVariant.neutral, this.color});
  final String text;
  final TagVariant variant;

  /// Overrides the variant's colors with a tint of this color instead — used where a status
  /// needs a specific semantic color (e.g. red/yellow/green attendance status) that doesn't
  /// map to one of the three fixed variants.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Border? border;
    if (color != null) {
      bg = color!.withValues(alpha: 0.16);
      fg = color!;
    } else {
      switch (variant) {
        case TagVariant.accent:
          bg = NocturneColors.accent800;
          fg = NocturneColors.accent100;
          break;
        case TagVariant.outline:
          bg = Colors.transparent;
          fg = NocturneColors.accent;
          border = Border.all(color: NocturneColors.accent);
          break;
        case TagVariant.neutral:
          bg = NocturneColors.neutral800;
          fg = NocturneColors.neutral100;
          break;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), border: border),
      child: Text(text, style: TextStyle(fontSize: 11, color: fg, letterSpacing: 0.2)),
    );
  }
}

enum TagVariant { accent, outline, neutral }

class NocturneDivider extends StatelessWidget {
  const NocturneDivider({super.key});
  @override
  Widget build(BuildContext context) => Divider(color: NocturneColors.divider, height: 1);
}
