import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_models.dart';
import '../providers/app_providers.dart';
import '../services/backend_service.dart';
import 'modern_glass_card.dart';
import '../config/app_theme.dart';

// Import Modali
import 'device_control_modal.dart';
import 'camera_stream_modal.dart';
import 'tv_control_modal.dart';
import 'speaker_control_modal.dart';

// IMPORTA IL NUOVO WIDGET
import 'jiggling_device_tile.dart';

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

  // --- LOGICA SWAP ---
  Future<void> _handleSwap(DeviceConfig source, DeviceConfig target) async {
    if (source.id == target.id) return;

    final sX = source.gridX;
    final sY = source.gridY;
    final tX = target.gridX;
    final tY = target.gridY;

    // Ottimisticamente aggiorna la UI locale (opzionale, se vuoi che sia istantaneo)
    // setState(() { ... scambia nella lista locale ... });

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

  // --- LOGICA TAP (Semplice vs Complesso) ---
  VoidCallback _getTapAction(DeviceConfig device) {
    final bool isTower = (device.gridW == 2 && device.gridH == 4);
    final bool isComplex = [
      'climate',
      'media_player',
      'camera',
      'lock',
      'sensor',
    ].contains(device.type);

    if (isTower) return () {}; // Tower non fa nulla al tap singolo
    if (isComplex) return () => _openDeviceDetails(device);
    return () => ref.read(haServiceProvider).toggleEntity(device.haEntityId);
  }

  @override
  Widget build(BuildContext context) {
    final sortedDevices = List<DeviceConfig>.from(widget.devices)
      ..sort((a, b) {
        if (a.gridY != b.gridY) return a.gridY.compareTo(b.gridY);
        return a.gridX.compareTo(b.gridX);
      });

    return Stack(
      children: [
        // 1. GRIGLIA SCROLLABILE
        Positioned.fill(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(
              bottom: 120,
              top: 20,
              left: 12,
              right: 12,
            ), // Padding migliorato
            child: StaggeredGrid.count(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: sortedDevices.map((device) {
                // USIAMO IL NUOVO WIDGET JIGGLING
                return StaggeredGridTile.count(
                  crossAxisCellCount: device.gridW,
                  mainAxisCellCount: device.gridH,
                  child: JigglingDeviceTile(
                    device: device,
                    isEditMode: widget.isEditMode,
                    entityStates: widget.entityStates,
                    currentHoveredId: _targetDeviceId,
                    // Callback:
                    onSwap: _handleSwap,
                    onHoverChanged: (id) =>
                        setState(() => _targetDeviceId = id),
                    onTap: _getTapAction(device),
                    onLongPress: () => _openDeviceDetails(device),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // 2. MENU FLUTTUANTE (FAB)
        Positioned(
          bottom: 20,
          right: 12,
          child: _FloatingMenu(
            isEditMode: widget.isEditMode,
            onAdd: widget.onAddDevice,
            onEditToggle: widget.onEditModeToggle,
            onDeleteRoom: widget.onDeleteRoom,
          ),
        ),
      ],
    );
  }
}

// --- MENU FLUTTUANTE INTELLIGENTE ---
class _FloatingMenu extends StatefulWidget {
  final bool isEditMode;
  final VoidCallback onAdd;
  final VoidCallback onEditToggle;
  final VoidCallback? onDeleteRoom;

  const _FloatingMenu({
    required this.isEditMode,
    required this.onAdd,
    required this.onEditToggle,
    this.onDeleteRoom,
  });

  @override
  State<_FloatingMenu> createState() => _FloatingMenuState();
}

class _FloatingMenuState extends State<_FloatingMenu>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Usiamo AnimatedSwitcher per transizione fluida tra MODALITÀ NORMALE e MODALITÀ EDIT
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        // Effetto Slide + Fade
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.2, 0.0), // Arriva leggermente da destra
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: widget.isEditMode
          ? _buildEditModeToolbar() // Barra Orizzontale (Editing)
          : _buildNormalMenu(), // Menu Verticale (Normale)
    );
  }

  // --- MODALITÀ EDITING: BARRA ORIZZONTALE ---
  Widget _buildEditModeToolbar() {
    return Container(
      key: const ValueKey("EditToolbar"), // Key per l'animazione
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(
          0.3,
        ), // Sfondo scuro leggero per unire i tasti
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. TASTO ELIMINA STANZA (Rosso)
          if (widget.onDeleteRoom != null) ...[
            _buildCircleBtn(
              icon: Icons.delete_forever,
              color: Colors.redAccent,
              onTap: widget.onDeleteRoom!,
              tooltip: "Elimina Stanza",
            ),
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 20,
              color: Colors.white10,
            ), // Separatore
            const SizedBox(width: 8),
          ],

          // 2. TASTO AGGIUNGI (Blu/Bianco)
          _buildCircleBtn(
            icon: Icons.add,
            color: Colors.white,
            onTap: widget.onAdd,
            tooltip: "Aggiungi Device",
          ),

          const SizedBox(width: 12),

          // 3. TASTO FINE (Verde - Sostituisce il menu)
          GestureDetector(
            onTap: widget.onEditToggle,
            child: ModernGlassCard(
              width: 50,
              height: 50,
              borderRadius: 25,
              opacity: 0.2,
              padding: EdgeInsets.zero,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withOpacity(0.2),
                  border: Border.all(color: AppTheme.accent, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- MODALITÀ NORMALE: MENU VERTICALE (A SCOMPARSA) ---
  Widget _buildNormalMenu() {
    return Column(
      key: const ValueKey("NormalMenu"),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Voci del menu (Modifica, Aggiungi...)
        // Nota: Qui teniamo solo "Modifica" e "Aggiungi" come shortcut rapida
        _buildMenuItem(
          label: "Modifica Griglia",
          icon: Icons.edit,
          color: Colors.white,
          onTap: () {
            _toggle(); // Chiudi menu verticale
            widget.onEditToggle(); // Attiva Edit Mode
          },
          delay: 1,
        ),

        _buildMenuItem(
          label: "Aggiungi",
          icon: Icons.add,
          color: AppTheme.accent,
          onTap: () {
            _toggle();
            widget.onAdd();
          },
          delay: 0,
        ),

        const SizedBox(height: 10),

        // FAB PRINCIPALE
        GestureDetector(
          onTap: _toggle,
          child: ModernGlassCard(
            width: 60,
            height: 60,
            borderRadius: 30,
            opacity: 0.15,
            padding: EdgeInsets.zero,
            child: Center(
              child: RotationTransition(
                turns: Tween(begin: 0.0, end: 0.25).animate(
                  CurvedAnimation(parent: _controller, curve: Curves.easeOut),
                ),
                child: Icon(
                  _isOpen ? Icons.add : Icons.grid_view_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Helper per bottoni circolari nella toolbar orizzontale
  Widget _buildCircleBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? "",
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  // Helper per voci menu verticale (Codice precedente ottimizzato)
  Widget _buildMenuItem({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required int delay,
  }) {
    if (!_isOpen) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double start = delay * 0.1;
        final double end = (start + 0.4).clamp(0.0, 1.0);
        final curve = CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        );

        final double scale = curve.value;
        final double opacity = curve.value.clamp(0.0, 1.0);

        return Transform.scale(
          scale: scale,
          alignment: Alignment.bottomRight,
          child: Opacity(
            opacity: opacity,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: Text(
                      label,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          const BoxShadow(color: Colors.black, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: onTap,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withOpacity(0.5),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
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

// --- HELPER RESIZE OPTION ---
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
