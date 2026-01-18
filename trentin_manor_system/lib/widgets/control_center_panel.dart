import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart'; // <--- NUOVA LIBRERIA
import 'package:google_fonts/google_fonts.dart';
import '../models/app_models.dart';
import '../providers/app_providers.dart';
import '../services/backend_service.dart';
import '../utils/icon_helper.dart';
import 'modern_glass_card.dart';
import '../config/app_theme.dart';

// Import Modali
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
  // Stato per evidenziare il target del drop
  int? _targetDeviceId;

  // --- LOGICA SWAP (Scambio Posizione) ---
  Future<void> _handleSwap(DeviceConfig source, DeviceConfig target) async {
    if (source.id == target.id) return;

    // 1. Scambiamo le coordinate nel DB
    // Assegniamo a Source le coordinate di Target e viceversa.
    // In un layout "packed" questo cambierà il loro ordine di visualizzazione.

    final sX = source.gridX;
    final sY = source.gridY;
    final tX = target.gridX;
    final tY = target.gridY;

    // Aggiorniamo backend (Optimistic UI: il socket poi confermerà)
    await BackendService().updateDeviceGridPosition(source.id, tX, tY);
    await BackendService().updateDeviceGridPosition(target.id, sX, sY);

    setState(() {
      _targetDeviceId = null;
    });
  }

  // --- LOGICA APERTURA MODALI ---
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

  @override
  Widget build(BuildContext context) {
    // 1. Ordiniamo i dispositivi per garantire che appaiano nell'ordine "visivo" corretto
    // (Dall'alto in basso, da sinistra a destra)
    final sortedDevices = List<DeviceConfig>.from(widget.devices)
      ..sort((a, b) {
        if (a.gridY != b.gridY) return a.gridY.compareTo(b.gridY);
        return a.gridX.compareTo(b.gridX);
      });

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(
              bottom: 100,
            ), // Spazio per scrollare oltre
            child: StaggeredGrid.count(
              crossAxisCount: 4, // 4 Colonne fisse
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: sortedDevices.map((device) {
                // Costruiamo il Tile
                Widget tile = _buildDeviceTile(context, device);

                // Se siamo in Edit Mode, avvolgiamo con Drag & Drop
                if (widget.isEditMode) {
                  tile = _buildDraggableWrapper(device, tile);
                }

                return StaggeredGridTile.count(
                  crossAxisCellCount: device.gridW,
                  mainAxisCellCount: device.gridH,
                  child: tile,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildBottomActions(),
      ],
    );
  }

  // --- WRAPPER DRAG & DROP CORRETTO ---
  Widget _buildDraggableWrapper(DeviceConfig device, Widget child) {
    return DragTarget<DeviceConfig>(
      // 1. "onEnter" non esiste. Usiamo onWillAcceptWithDetails per:
      //    A. Decidere se accettare il drop (return true/false)
      //    B. Attivare l'effetto grafico (setState)
      onWillAcceptWithDetails: (details) {
        final isDifferent = details.data.id != device.id;

        // Se è un dispositivo diverso (quindi valido per lo scambio), evidenziamo la cella
        if (isDifferent && _targetDeviceId != device.id) {
          setState(() => _targetDeviceId = device.id);
        }

        return isDifferent;
      },

      // 2. Quando esce dall'area, spegniamo l'effetto grafico
      onLeave: (_) {
        if (_targetDeviceId == device.id) {
          setState(() => _targetDeviceId = null);
        }
      },

      // 3. Quando rilascia il dito (DROP avvenuto)
      onAcceptWithDetails: (details) {
        _handleSwap(details.data, device);
        // Resettiamo l'evidenziazione dopo lo scambio
        setState(() => _targetDeviceId = null);
      },

      builder: (context, candidateData, rejectedData) {
        // Controlliamo se QUESTO è il target attivo
        final bool isHovered = _targetDeviceId == device.id;

        return LongPressDraggable<DeviceConfig>(
          data: device,
          delay: const Duration(milliseconds: 200),
          // Feedback mentre trascini (il "fantasma")
          feedback: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150, maxHeight: 150),
              child: Opacity(
                opacity: 0.8,
                child: ModernGlassCard(
                  opacity: 0.3,
                  child: const Center(
                    child: Icon(Icons.touch_app, color: Colors.white, size: 40),
                  ),
                ),
              ),
            ),
          ),
          // Cosa mostrare al posto dell'originale mentre trascini
          childWhenDragging: Opacity(opacity: 0.3, child: child),
          // Il widget normale (con animazione scale se ci passano sopra)
          child: AnimatedScale(
            scale: isHovered ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: isHovered
                  ? BoxDecoration(
                      border: Border.all(color: AppTheme.accent, width: 2),
                      borderRadius: BorderRadius.circular(24),
                      // Aggiungiamo un leggero sfondo per evidenziare meglio
                      color: AppTheme.accent.withOpacity(0.1),
                    )
                  : null,
              child: child,
            ),
          ),
        );
      },
    );
  }

  // --- BUILD TILE (Stessa logica grafica di prima) ---
  Widget _buildDeviceTile(BuildContext context, DeviceConfig device) {
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
      onTap: widget.isEditMode
          ? null
          : () => ref.read(haServiceProvider).toggleEntity(device.haEntityId),
      onLongPress: widget.isEditMode ? null : () => _openDeviceDetails(device),
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
        child: Stack(
          children: [
            Center(child: innerContent), // Centra il contenuto
            // Pulsante Resize (Solo Edit Mode)
            if (widget.isEditMode)
              Positioned(
                right: -8,
                bottom: -8,
                child: GestureDetector(
                  onTap: () => _showResizeDialog(context, device),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.transparent, // Hitbox aumentata
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.aspect_ratio,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return content;
  }

  // --- ACTIONS & DIALOGS (Invariati) ---
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

  // --- RESIZE DIALOG AGGIORNATO ---
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

                  // WRAP CON LE 5 OPZIONI RICHIESTE
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      // 1. Piccola (1x1)
                      _ResizeOption(
                        w: 1,
                        h: 1,
                        label: "1x1",
                        icon: Icons.crop_square,
                        device: device,
                        ctx: ctx,
                      ),

                      // 2. Orizzontale (2x1) - NUOVA
                      _ResizeOption(
                        w: 2,
                        h: 1,
                        label: "2x1",
                        icon: Icons.crop_landscape,
                        device: device,
                        ctx: ctx,
                      ),

                      // 3. Verticale (1x2)
                      _ResizeOption(
                        w: 1,
                        h: 2,
                        label: "1x2",
                        icon: Icons.crop_portrait,
                        device: device,
                        ctx: ctx,
                      ),

                      // 4. Grande (2x2)
                      _ResizeOption(
                        w: 2,
                        h: 2,
                        label: "2x2",
                        icon: Icons.grid_view,
                        device: device,
                        ctx: ctx,
                      ),

                      // 5. Tower (2x4)
                      _ResizeOption(
                        w: 4,
                        h: 2,
                        label: "Tower",
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

// Helpers
class _ResizeOption extends StatelessWidget {
  final int w, h;
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
