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
    this.blur = 22,
    this.borderColor = ZirconColors.glassBorder,
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
            // A very low-opacity neutral tint lets the image below determine
            // whether the glass reads light or dark.
            color: color,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: .20),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Specular upper rim and gentle internal falloff are what keep
              // this from looking like a flat translucent dark rectangle.
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Colors.white.withValues(alpha: .16),
                        Colors.white.withValues(alpha: .045),
                        Colors.white.withValues(alpha: .015),
                      ],
                      stops: const <double>[0, .12, 1],
                    ),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
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
