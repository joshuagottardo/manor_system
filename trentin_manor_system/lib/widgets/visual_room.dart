import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_models.dart';
import '../providers/app_providers.dart';
import 'device_control_modal.dart';
import '../utils/icon_helper.dart';
import 'camera_stream_modal.dart';
import 'tv_control_modal.dart';
import 'speaker_control_modal.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

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
                    ...room.devices.asMap().entries.map((entry) {
                      final index = entry.key;
                      final device = entry.value;

                      return Positioned(
                        left: device.x * mapWidth,
                        top: device.y * mapHeight,
                        child: AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 800),
                          child: FadeInAnimation(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOut,
                            child: ScaleAnimation(
                              curve: Curves.easeOutBack,
                              scale: 0.0,
                              child: FractionalTranslation(
                                translation: const Offset(-0.5, -0.5),
                                child: _buildDeviceMarker(
                                  context,
                                  ref,
                                  device,
                                  mapWidth,
                                  mapHeight,
                                ),
                              ),
                            ),
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
    double mapW,
    double mapH,
  ) {
    final state = currentStates[device.haEntityId];
    final bool isOn = IconHelper.isActive(state);
    final Color activeColor = IconHelper.getColor(device.type, state);
    final IconData icon = IconHelper.getIcon(device.type, state);
    final bool isComplex = [
      'climate',
      'media_player',
      'camera',
      'lock',
      'sensor',
    ].contains(device.type);

    VoidCallback? handleTap;
    VoidCallback? handleDetails;

    if (!isEditMode) {
      if (isComplex) {
        handleTap = () =>
            _handleDeviceTap(context, ref, device, state);
      } else {
        handleTap = () => ref
            .read(haServiceProvider)
            .toggleEntity(device.haEntityId);
      }

      handleDetails = () => _handleDeviceTap(context, ref, device, state);
    }
    // --- FINE LOGICA ---

    Widget marker = GestureDetector(
      // Gestione Gesture Unificata
      onTap: handleTap,
      onLongPress: isEditMode && onDeviceDelete != null
          ? () =>
                onDeviceDelete!(device.id) // Cancellazione in edit mode
          : handleDetails, // Modale in normal mode
      onSecondaryTap: handleDetails, // Click Destro -> Modale

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isOn
              ? activeColor.withOpacity(0.2)
              : const Color(0xFF1C1C1E).withOpacity(0.9),
          shape: BoxShape.circle,
          border: Border.all(
            color: isOn ? activeColor : Colors.white24,
            width: isOn ? 2.0 : 1.5,
          ),
          boxShadow: isOn
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Icon(icon, size: 20, color: isOn ? activeColor : Colors.white54),
      ),
    );

    if (isEditMode) {
      return Draggable<int>(
        data: device.id,
        onDragStarted: () => onDragStart?.call(device.id),
        onDragEnd: (details) {
          final RenderBox parentBox = context
              .findAncestorRenderObjectOfType<RenderBox>()!;
          final Offset localOffset = parentBox.globalToLocal(details.offset);
          double newX = localOffset.dx / mapW;
          double newY = localOffset.dy / mapH;
          newX = newX.clamp(0.0, 1.0);
          newY = newY.clamp(0.0, 1.0);
          onDragEnd?.call(device.id, newX, newY);
        },
        onDragUpdate: (details) {
          final RenderBox parentBox = context
              .findAncestorRenderObjectOfType<RenderBox>()!;
          final Offset localOffset = parentBox.globalToLocal(
            details.globalPosition,
          );
          double newX = localOffset.dx / mapW;
          double newY = localOffset.dy / mapH;
          onDeviceMoved?.call(device.id, newX, newY);
        },
        feedback: Transform.scale(
          scale: 1.2,
          child: Opacity(opacity: 0.9, child: marker),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: marker),
        child: marker,
      );
    }

    return marker;
  }

  void _handleDeviceTap(
    BuildContext context,
    WidgetRef ref,
    DeviceConfig device,
    Map<String, dynamic>? state,
  ) {
    if (state == null) return;

    if (device.type == 'camera') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CameraStreamModal(device: device)),
      );
    } else if (device.type == 'media_player') {
      final devClass = state['attributes']['device_class'];
      if (devClass == 'speaker') {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) =>
              SpeakerControlModal(device: device, currentState: state),
        );
      } else {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => TvControlModal(device: device, currentState: state),
        );
      }
    } else {
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
