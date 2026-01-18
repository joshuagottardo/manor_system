import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_models.dart';
import '../providers/app_providers.dart';
import '../services/backend_service.dart';
import '../utils/icon_helper.dart';
import 'modern_glass_card.dart';
import '../config/app_theme.dart';
import 'device_control_modal.dart';
import 'camera_stream_modal.dart';
import 'tv_control_modal.dart';
import 'speaker_control_modal.dart';

class ControlCenterPanel extends ConsumerStatefulWidget {
  final List<DeviceConfig> devices;
  final bool isEditMode;
  final Map<String, dynamic> entityStates;

  final VoidCallback onEditModeToggle;
  final VoidCallback onAddDevice;
  final VoidCallback? onDeleteRoom;

  const ControlCenterPanel({
    super.key,
    required this.devices,
    required this.isEditMode,
    required this.entityStates,
    required this.onEditModeToggle,
    required this.onAddDevice,
    this.onDeleteRoom,
  });

  @override
  ConsumerState<ControlCenterPanel> createState() => _ControlCenterPanelState();
}

class _ControlCenterPanelState extends ConsumerState<ControlCenterPanel> {
  final int columns = 4;
  final double spacing = 12.0;

  int? _dragTargetX;
  int? _dragTargetY;
  bool _isDragCollision = false;

  void _openDeviceDetails(DeviceConfig device) {
    final state = widget.entityStates[device.haEntityId];
    if (state == null) return;

    if (device.type == 'camera') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CameraStreamModal(device: device)),
      );
    } else if (device.type == 'media_player') {
      final devClass = state['attributes']['device_class'];
      // Se è uno speaker o non è definito bene, apriamo controllo speaker
      if (devClass == 'speaker') {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) =>
              SpeakerControlModal(device: device, currentState: state),
        );
      } else {
        // Altrimenti assumiamo sia una TV
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => TvControlModal(device: device, currentState: state),
        );
      }
    } else {
      // Luci, Clima, Switch, etc.
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DeviceControlModal(device: device, currentState: state),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double panelWidth = constraints.maxWidth;
        final double cellW = (panelWidth - (spacing * (columns - 1))) / columns;
        final double cellH = cellW;

        int maxRow = 0;
        for (var d in widget.devices) {
          int bottom = d.gridY + d.gridH;
          if (bottom > maxRow) maxRow = bottom;
        }
        if (widget.isEditMode) maxRow += 4;

        final double contentHeight = (maxRow * (cellH + spacing)) + 50;

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  height: contentHeight,
                  width: panelWidth,
                  child: Stack(
                    children: [
                      if (widget.isEditMode)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _GridGuidePainter(
                              cols: columns,
                              cellW: cellW,
                              cellH: cellH,
                              gap: spacing,
                            ),
                          ),
                        ),

                      ...widget.devices.map((device) {
                        final double w =
                            (device.gridW * cellW) +
                            ((device.gridW - 1) * spacing);
                        final double h =
                            (device.gridH * cellH) +
                            ((device.gridH - 1) * spacing);

                        return Positioned(
                          left: device.gridX * (cellW + spacing),
                          top: device.gridY * (cellH + spacing),
                          width: w,
                          height: h,
                          child: _buildDeviceTile(
                            context,
                            device,
                            cellW,
                            cellH,
                            spacing,
                          ),
                        );
                      }),

                      if (widget.isEditMode)
                        Positioned.fill(
                          child: DragTarget<DeviceConfig>(
                            onWillAccept: (_) => true,
                            onMove: (details) {
                              final RenderBox box =
                                  context.findRenderObject() as RenderBox;
                              final localPos = box.globalToLocal(
                                details.offset,
                              );

                              int tx = (localPos.dx / (cellW + spacing))
                                  .floor();
                              int ty = (localPos.dy / (cellH + spacing))
                                  .floor();

                              if (tx < 0) tx = 0;
                              if (tx > columns - (details.data.gridW))
                                tx = columns - details.data.gridW;
                              if (ty < 0) ty = 0;

                              bool collision = _checkCollision(
                                tx,
                                ty,
                                details.data,
                              );

                              if (_dragTargetX != tx ||
                                  _dragTargetY != ty ||
                                  _isDragCollision != collision) {
                                setState(() {
                                  _dragTargetX = tx;
                                  _dragTargetY = ty;
                                  _isDragCollision = collision;
                                });
                              }
                            },
                            onLeave: (_) => setState(() {
                              _dragTargetX = null;
                              _dragTargetY = null;
                            }),
                            onAccept: (device) {
                              if (_dragTargetX != null &&
                                  _dragTargetY != null &&
                                  !_isDragCollision) {
                                _updatePosition(
                                  device,
                                  _dragTargetX!,
                                  _dragTargetY!,
                                );
                              }
                              setState(() {
                                _dragTargetX = null;
                                _dragTargetY = null;
                              });
                            },
                            builder: (context, candidates, rejects) {
                              if (_dragTargetX != null &&
                                  _dragTargetY != null &&
                                  candidates.isNotEmpty) {
                                final device = candidates.first!;
                                return Positioned(
                                  left: _dragTargetX! * (cellW + spacing),
                                  top: _dragTargetY! * (cellH + spacing),
                                  width:
                                      (device.gridW * cellW) +
                                      ((device.gridW - 1) * spacing),
                                  height:
                                      (device.gridH * cellH) +
                                      ((device.gridH - 1) * spacing),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _isDragCollision
                                          ? Colors.red.withOpacity(0.3)
                                          : Colors.greenAccent.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: _isDragCollision
                                            ? Colors.red
                                            : Colors.greenAccent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildBottomActions(),
          ],
        );
      },
    );
  }

  bool _checkCollision(int targetX, int targetY, DeviceConfig draggingDevice) {
    final Rect targetRect = Rect.fromLTWH(
      targetX.toDouble(),
      targetY.toDouble(),
      draggingDevice.gridW.toDouble(),
      draggingDevice.gridH.toDouble(),
    );
    for (var other in widget.devices) {
      if (other.id == draggingDevice.id) continue;
      final Rect otherRect = Rect.fromLTWH(
        other.gridX.toDouble(),
        other.gridY.toDouble(),
        other.gridW.toDouble(),
        other.gridH.toDouble(),
      );
      if (targetRect.overlaps(otherRect)) return true;
    }
    return false;
  }

  void _updatePosition(DeviceConfig device, int x, int y) {
    BackendService().updateDeviceGridPosition(device.id, x, y);
  }

  Widget _buildBottomActions() {
    return SizedBox(
      height: 70,
      child: Row(
        children: [
          Expanded(
            child: ModernGlassCard(
              onTap: widget.onEditModeToggle,
              opacity: widget.isEditMode ? 0.15 : 0.05,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isEditMode ? Icons.check : Icons.edit,
                      color: widget.isEditMode
                          ? AppTheme.accent
                          : Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isEditMode ? "FATTO" : "MODIFICA",
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ModernGlassCard(
            onTap: widget.onAddDevice,
            opacity: 0.1,
            child: const Center(child: Icon(Icons.add, color: Colors.white)),
          ),
          if (widget.isEditMode && widget.onDeleteRoom != null) ...[
            const SizedBox(width: 12),
            ModernGlassCard(
              onTap: widget.onDeleteRoom,
              opacity: 0.1,
              child: const Center(
                child: Icon(Icons.delete_forever, color: Colors.redAccent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceTile(
    BuildContext context,
    DeviceConfig device,
    double cellW,
    double cellH,
    double gap,
  ) {
    final stateData = widget.entityStates[device.haEntityId];
    final bool isOn = IconHelper.isActive(stateData);
    final Color color = IconHelper.getColor(device.type, stateData);
    final IconData icon = IconHelper.getIcon(device.type, stateData);

    final Color iconColor = isOn ? color : const Color(0xFFE0E0E0);

    Widget innerContent;

    if (device.gridW == 1 && device.gridH == 1) {
      innerContent = Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Icon(icon, color: iconColor, size: 28),
        ),
      );
    } else if (device.gridW == 1 && device.gridH > 1) {
      innerContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          if (device.type == 'light' && isOn)
            Container(
              width: 4,
              height: 30,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Icon(icon, color: iconColor, size: 28),
          const Spacer(),
        ],
      );
    } else {
      innerContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor, size: 26),
              if (isOn)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color, blurRadius: 6)],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              device.friendlyName.toUpperCase(),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    Widget content = ModernGlassCard(
      padding: EdgeInsets.zero,
      opacity: isOn ? 0.12 : 0.08,

      // AZIONE 1: TAP SINGOLO (Toggle)
      onTap: widget.isEditMode
          ? null
          : () => ref.read(haServiceProvider).toggleEntity(device.haEntityId),

      // AZIONE 2: LONG PRESS (Apre Modale)
      onLongPress: widget.isEditMode
          ? null
          : () => _openDeviceDetails(device), // <--- ECCOLO!

      child: Container(
        padding: const EdgeInsets.all(10),
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: isOn ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isOn ? color.withOpacity(0.5) : Colors.transparent,
            width: 1,
          ),
        ),
        child: innerContent,
      ),
    );

    if (widget.isEditMode) {
      final double feedbackW =
          (device.gridW * cellW) + ((device.gridW - 1) * gap);
      final double feedbackH =
          (device.gridH * cellH) + ((device.gridH - 1) * gap);

      return Stack(
        children: [
          LongPressDraggable<DeviceConfig>(
            data: device,
            delay: const Duration(milliseconds: 150),
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: feedbackW,
                height: feedbackH,
                child: Opacity(opacity: 0.8, child: content),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: content),
            child: content,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => _showResizeDialog(context, device),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: const Icon(
                  Icons.aspect_ratio,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return content;
  }

  void _showResizeDialog(BuildContext context, DeviceConfig device) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: ModernGlassCard(
              opacity: 0.1,
              blur: 20,
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    IconHelper.getIcon(device.type, null),
                    color: Colors.white54,
                    size: 40,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "DIMENSIONI WIDGET",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Wrap(
                    spacing: 15,
                    runSpacing: 15,
                    alignment: WrapAlignment.center,
                    children: [
                      _ResizeOption(
                        w: 1,
                        h: 1,
                        label: "1x1",
                        icon: Icons.crop_square,
                        device: device,
                        ctx: ctx,
                      ),
                      _ResizeOption(
                        w: 2,
                        h: 2,
                        label: "2x2",
                        icon: Icons.grid_view,
                        device: device,
                        ctx: ctx,
                      ),
                      _ResizeOption(
                        w: 1,
                        h: 2,
                        label: "1x2",
                        icon: Icons.crop_portrait,
                        device: device,
                        ctx: ctx,
                      ),
                      _ResizeOption(
                        w: 2,
                        h: 4,
                        label: "2x4 (Tower)",
                        icon: Icons.view_week,
                        device: device,
                        ctx: ctx,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "ANNULLA",
                      style: TextStyle(color: Colors.white30),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ResizeOption extends StatelessWidget {
  final int w;
  final int h;
  final String label;
  final IconData icon;
  final DeviceConfig device;
  final BuildContext ctx;

  const _ResizeOption({
    required this.w,
    required this.h,
    required this.label,
    required this.icon,
    required this.device,
    required this.ctx,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = device.gridW == w && device.gridH == h;

    return GestureDetector(
      onTap: () {
        BackendService().updateDeviceGridSize(device.id, w, h);
        Navigator.pop(ctx);
      },
      child: Container(
        width: 85,
        height: 85,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E676).withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00E676)
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white54,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridGuidePainter extends CustomPainter {
  final int cols;
  final double cellW;
  final double cellH;
  final double gap;
  _GridGuidePainter({
    required this.cols,
    required this.cellW,
    required this.cellH,
    required this.gap,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 0; i < cols; i++) {
      for (int j = 0; j < 30; j++) {
        final double left = i * (cellW + gap);
        final double top = j * (cellH + gap);
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, cellW, cellH),
          const Radius.circular(24),
        );
        canvas.drawRRect(rrect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
