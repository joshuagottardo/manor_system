import 'dart:math';
import 'package:flutter/material.dart';

class NeonColorPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<Color> onColorEnd;

  const NeonColorPicker({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
    required this.onColorEnd,
  });

  @override
  State<NeonColorPicker> createState() => _NeonColorPickerState();
}

class _NeonColorPickerState extends State<NeonColorPicker> {
  double _hue = 0.0;

  @override
  void initState() {
    super.initState();
    // Convertiamo il colore iniziale in HSV per estrarre la tonalità (Hue)
    _hue = HSVColor.fromColor(widget.initialColor).hue;
  }

  void _handleGesture(Offset position, Size size, {bool isFinal = false}) {
    // Calcoliamo il centro del widget
    Offset center = Offset(size.width / 2, size.height / 2);
    
    // Calcoliamo l'angolo del tocco rispetto al centro
    double angle = atan2(position.dy - center.dy, position.dx - center.dx);
    
    // Convertiamo l'angolo in gradi (0-360) per ottenere la Hue
    double degrees = angle * 180 / pi;
    if (degrees < 0) degrees += 360;

    setState(() {
      _hue = degrees;
    });

    // Creiamo il colore pieno (Saturazione e Valore al massimo per effetto Neon)
    Color color = HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor();

    widget.onColorChanged(color);
    if (isFinal) widget.onColorEnd(color);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double size = min(constraints.maxWidth, constraints.maxHeight);
        
        return GestureDetector(
          onPanUpdate: (details) => _handleGesture(details.localPosition, Size(size, size)),
          onPanEnd: (details) {
             // Ricostruiamo il colore finale per l'evento onEnd
             Color color = HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor();
             widget.onColorEnd(color);
          },
          onTapDown: (details) => _handleGesture(details.localPosition, Size(size, size), isFinal: true),
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _WheelPainter(hue: _hue),
            ),
          ),
        );
      },
    );
  }
}

class _WheelPainter extends CustomPainter {
  final double hue;

  _WheelPainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    Offset center = Offset(size.width / 2, size.height / 2);
    double radius = size.width / 2;
    double strokeWidth = 25.0; // Spessore dell'anello

    // 1. DISEGNA L'ANELLO ARCOBALENO (SweepGradient)
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    final gradient = SweepGradient(
      colors: [
        const HSVColor.fromAHSV(1.0, 0.0, 1.0, 1.0).toColor(),
        const HSVColor.fromAHSV(1.0, 60.0, 1.0, 1.0).toColor(),
        const HSVColor.fromAHSV(1.0, 120.0, 1.0, 1.0).toColor(),
        const HSVColor.fromAHSV(1.0, 180.0, 1.0, 1.0).toColor(),
        const HSVColor.fromAHSV(1.0, 240.0, 1.0, 1.0).toColor(),
        const HSVColor.fromAHSV(1.0, 300.0, 1.0, 1.0).toColor(),
        const HSVColor.fromAHSV(1.0, 360.0, 1.0, 1.0).toColor(),
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, paint);

    // 2. DISEGNA IL CURSORE (Il "Manettino" bianco)
    // Calcoliamo la posizione X,Y sulla circonferenza basandoci sull'angolo Hue
    double angleRad = hue * pi / 180;
    double indicatorRadius = radius - strokeWidth / 2;
    Offset indicatorPos = Offset(
      center.dx + indicatorRadius * cos(angleRad),
      center.dy + indicatorRadius * sin(angleRad),
    );

    // Ombra del cursore (Glow)
    canvas.drawCircle(
      indicatorPos,
      12,
      Paint()
        ..color = Colors.black.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Bordo cursore
    canvas.drawCircle(
      indicatorPos,
      10, 
      Paint()..color = Colors.white
    );
    
    // Centro cursore (il colore selezionato)
    canvas.drawCircle(
      indicatorPos,
      6,
      Paint()..color = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor()
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => oldDelegate.hue != hue;
}