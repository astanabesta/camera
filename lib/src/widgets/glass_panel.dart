import 'dart:ui';

import 'package:flutter/material.dart';

import '../design/tokens.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(8),
    this.borderRadius = ZirconRadius.md,
    this.color = ZirconColors.panel,
    this.blur = 12,
    this.borderColor = ZirconColors.strokeSoft,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color color;
  final double blur;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class PrototypeBadge extends StatelessWidget {
  const PrototypeBadge({
    super.key,
    this.compact = false,
    this.label = 'FUNCTIONAL BETA',
    this.compactLabel = 'BETA',
  });

  final bool compact;
  final String label;
  final String compactLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ZirconColors.warning.withValues(alpha: .13),
        border: Border.all(color: ZirconColors.warning.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(ZirconRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          compact ? compactLabel : label,
          maxLines: 1,
          style: const TextStyle(
            color: ZirconColors.warning,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
      ),
    );
  }
}
