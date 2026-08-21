import 'package:flutter/material.dart';

import '../core/theme/theme_tokens.dart';

class MukkingCard extends StatelessWidget {
  const MukkingCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.backgroundColor,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? tokens.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: tokens.secondary.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.textPrimary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: content,
    );
  }
}
