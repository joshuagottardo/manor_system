import 'package:flutter/material.dart';

class RoomTransitionWrapper extends StatelessWidget {
  final Widget child;
  final Key? itemKey;

  const RoomTransitionWrapper({
    super.key,
    required this.child,
    this.itemKey,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      // TEMPISTICA:
      // 400ms è rapido ma percepibile. Abbastanza veloce da sembrare reattivo,
      // abbastanza lento da essere elegante.
      duration: const Duration(milliseconds: 400),
      
      // CURVA:
      // easeOutQuad è morbida in arrivo.
      switchInCurve: Curves.easeOutQuad,
      switchOutCurve: Curves.easeInQuad,

      // LAYOUT:
      // Mantiene i widget impilati durante la transizione
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },

      // LA NUOVA TRANSIZIONE
      transitionBuilder: (Widget child, Animation<double> animation) {
        // Distinguiamo se è la vista che entra o quella che esce
        // (Nota: in AnimatedSwitcher standard l'animazione va da 0 a 1 per chi entra
        // e da 1 a 0 per chi esce, quindi usiamo la stessa logica ma combinata).
        
        // 1. FADE (Dissolvenza): Base di tutto.
        final fadeAnimation = FadeTransition(
          opacity: animation,
          child: child,
        );

        // 2. SLIDE (Scivolamento):
        // Definiamo un movimento leggerissimo dal basso (Offset 0.05) verso il centro.
        // Solo il 5% di altezza, non un'intera pagina. È un tocco "premium".
        final slideAnimation = SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.05), // Parte leggermente più in basso
            end: Offset.zero,               // Arriva al centro
          ).animate(animation),
          child: fadeAnimation, // Avvolge il Fade
        );

        return slideAnimation;
      },
      
      child: Container(
        key: itemKey, // Fondamentale per far capire a Flutter che il widget è cambiato
        width: double.infinity,
        height: double.infinity,
        // Assicuriamo che lo sfondo sia trasparente/nero per evitare flash bianchi
        color: Colors.transparent, 
        child: child,
      ),
    );
  }
}