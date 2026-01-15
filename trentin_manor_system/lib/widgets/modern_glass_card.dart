import 'dart:ui';
import 'package:flutter/material.dart';
// Importa per usare i colori del tema se serve

class ModernGlassCard extends StatelessWidget {
  final Widget child;
  final double opacity;
  final double blur;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const ModernGlassCard({
    super.key,
    required this.child,
    // CAMBIO DEFAULT: Opacità bassissima di bianco (0.05) su fondo nero 
    // crea un grigio scuro elegante
    this.opacity = 0.05, 
    this.blur = 20.0,    // Aumentiamo il blur per eleganza
    this.onTap,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: Colors.white.withOpacity(0.05),
              highlightColor: Colors.white.withOpacity(0.02),
              child: Container(
                padding: padding ?? const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  // Qui sta il trucco: un tocco di bianco su sfondo nero = grigio fumo
                  color: Colors.white.withOpacity(opacity),
                  
                  // Bordo: Sottilissimo, quasi impercettibile, sfumato se possibile
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08), 
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(24),
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