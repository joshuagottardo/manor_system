import 'dart:ui';
import 'package:flutter/material.dart';

class ModernGlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double opacity;
  final double blur;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool hasBorder;

  const ModernGlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.opacity = 0.05,
    this.blur = 20.0,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap, // <--- LO INSERIAMO QUI
    this.padding,
    this.margin,
    this.borderRadius = 24.0,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              onSecondaryTap: onSecondaryTap, // <--- LO PASSIAMO ALL'INKWELL
              splashColor: Colors.white.withOpacity(0.1),
              highlightColor: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(borderRadius),
              child: Container(
                width: width,
                height: height,
                padding: padding ?? const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(opacity),
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: hasBorder
                      ? Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1,
                        )
                      : null,
                  gradient: hasBorder
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.05),
                          ],
                        )
                      : null,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
