import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_models.dart';
import '../providers/app_providers.dart';
import 'device_control_modal.dart';
import '../utils/icon_helper.dart';
import 'camera_stream_modal.dart';
import 'tv_control_modal.dart';
import 'speaker_control_modal.dart';

class VisualRoom extends ConsumerWidget {
  final RoomConfig room;
  final bool isEditMode;
  final Map<String, dynamic> currentStates;
  final Function(int deviceId, double newX, double newY)? onDeviceMoved;
  final Function(int deviceId, double x, double y)? onDragEnd;
  final Function(int deviceId)? onDeviceDelete;
  final Function(int deviceId)? onDragStart;

  static const double fixedAspectRatio = 2360 / 1640;

  const VisualRoom({
    super.key,
    required this.room,
    this.isEditMode = false,
    this.currentStates = const {},
    this.onDeviceMoved,
    this.onDragEnd,
    this.onDeviceDelete,
    this.onDragStart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (room.imageUrl == null) {
      return const Center(
        child: Text(
          "Nessuna planimetria",
          style: TextStyle(color: Colors.white30),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: AspectRatio(
          aspectRatio: fixedAspectRatio,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double mapWidth = constraints.maxWidth;
              final double mapHeight = constraints.maxHeight;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  children: [
                    // 1. IMMAGINE
                    Positioned.fill(
                      child: Image.asset(room.imageUrl!, fit: BoxFit.cover),
                    ),

                    // 2. GRIGLIA
                    if (isEditMode)
                      Positioned.fill(
                        child: CustomPaint(painter: GridPainter()),
                      ),

                    // 3. DISPOSITIVI
                    ...room.devices.map((device) {
                      return Positioned(
                        left: device.x * mapWidth,
                        top: device.y * mapHeight,
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, -0.5),
                          child: _buildDeviceMarker(
                            context,
                            ref, // Passiamo ref per i comandi
                            device,
                            mapWidth,
                            mapHeight,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceMarker(
    BuildContext context,
    WidgetRef ref,
    DeviceConfig device,
    double mapWidth,
    double mapHeight,
  ) {
    final entityState = currentStates[device.haEntityId];
    final bool isOn = IconHelper.isActive(entityState);
    final Color activeColor = IconHelper.getColor(device.type, entityState);
    final IconData iconData = IconHelper.getIcon(device.type, entityState);

    Widget markerContent;

    // --- COSTRUZIONE GRAFICA (Identica a prima) ---
    if (device.type == 'sensor') {
      String val = entityState?['state'] ?? '--';
      String unit = entityState?['attributes']?['unit_of_measurement'] ?? '';

      markerContent = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              "$val $unit",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      );
    } else {
      markerContent = AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOn
              ? activeColor.withOpacity(0.2)
              : Colors.black.withOpacity(0.7),
          border: Border.all(
            color: isEditMode
                ? Colors.redAccent
                : (isOn ? activeColor : Colors.white24),
            width: isEditMode ? 2.5 : 1.5,
          ),
          boxShadow: isOn
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.6),
                    blurRadius: 25,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: activeColor.withOpacity(0.8),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Colors.black54,
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Icon(
          iconData,
          color: isEditMode
              ? Colors.white
              : (isOn ? Colors.white : Colors.white54),
          size: 24,
          shadows: isOn
              ? [const Shadow(color: Colors.black, blurRadius: 4)]
              : null,
        ),
      );
    }

    if (isEditMode) {
      markerContent = Stack(
        clipBehavior: Clip.none,
        children: [
          markerContent,
          Positioned(
            right: -8,
            top: -8,
            child: GestureDetector(
              onTap: () => onDeviceDelete?.call(device.id),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 4),
                  ],
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    // --- INTERAZIONE UX RAFFINATA ---
    return GestureDetector(
      // 1. Quando metti il dito
      onPanStart: isEditMode ? (_) => onDragStart?.call(device.id) : null,

      // 2. Quando muovi il dito
      onPanUpdate: isEditMode
          ? (details) {
              double dx = details.delta.dx;
              double dy = details.delta.dy;
              double newX = (device.x + (dx / mapWidth)).clamp(0.0, 1.0);
              double newY = (device.y + (dy / mapHeight)).clamp(0.0, 1.0);
              onDeviceMoved?.call(device.id, newX, newY);
            }
          : null,
      // 3. Quando alzi il dito
      onPanEnd: isEditMode
          ? (details) => onDragEnd?.call(device.id, device.x, device.y)
          : null,

      // TAP SINGOLO: Toggle (Luci) oppure Dettagli (Sensori)
      onTap: !isEditMode
          ? () {
              if (device.type == 'sensor' ||
                  device.type == 'climate' ||
                  device.type == 'camera' ||
                  device.type == 'media_player') {
                _openDetails(context, device, entityState);
              } else {
                ref.read(haServiceProvider).toggleEntity(device.haEntityId);
              }
            }
          : null,

      // TAP PROLUNGATO: Sempre Dettagli
      onLongPress: !isEditMode
          ? () => _openDetails(context, device, entityState)
          : null,

      child: markerContent,
    );
  }

  void _openDetails(
    BuildContext context,
    DeviceConfig device,
    Map<String, dynamic>? state,
  ) {
    if (state != null) {
      // 1. CAMERA -> STREAM
      if (device.type == 'camera') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CameraStreamModal(device: device)),
        );
        return;
      }

      // 2. TV / MEDIA PLAYER -> TV MODAL
      if (device.type == 'media_player') {
         // Controlliamo la device_class dall'entità reale
         final deviceClass = state['attributes']?['device_class'];
         
         // Se è esplicitamente uno speaker o receiver, oppure NON è una TV
         // (Le Google TV hanno device_class: 'tv')
         if (deviceClass == 'speaker' || deviceClass == 'receiver' || deviceClass == null) {
            // Assumiamo Speaker come default se non è tv
            if (deviceClass == 'tv') {
               showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => TvControlModal(device: device, currentState: state),
               );
            } else {
               showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => SpeakerControlModal(device: device, currentState: state),
               );
            }
         } else {
            // Fallback TV (se deviceClass == 'tv')
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => TvControlModal(device: device, currentState: state),
            );
         }
         return;
      }

      // 3. ALTRO -> MODALE STANDARD
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DeviceControlModal(device: device, currentState: state),
      );
    }
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;
    for (double i = 0; i <= size.width; i += size.width / 10) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i <= size.height; i += size.height / 10) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
