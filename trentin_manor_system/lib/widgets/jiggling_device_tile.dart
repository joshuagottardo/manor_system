import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// Import necessari del tuo progetto
import '../models/app_models.dart';
import '../providers/app_providers.dart';
import '../services/backend_service.dart';
import '../utils/icon_helper.dart';
import 'modern_glass_card.dart';
import '../config/app_theme.dart';

class JigglingDeviceTile extends ConsumerStatefulWidget {
  final DeviceConfig device;
  final bool isEditMode;
  final Map<String, dynamic> entityStates;
  
  // Callback dal padre (ControlCenterPanel)
  final Function(DeviceConfig source, DeviceConfig target) onSwap;
  final Function(int? deviceId) onHoverChanged;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final int? currentHoveredId;

  const JigglingDeviceTile({
    super.key,
    required this.device,
    required this.isEditMode,
    required this.entityStates,
    required this.onSwap,
    required this.onHoverChanged,
    required this.onTap,
    required this.onLongPress,
    required this.currentHoveredId,
  });

  @override
  ConsumerState<JigglingDeviceTile> createState() => _JigglingDeviceTileState();
}

class _JigglingDeviceTileState extends ConsumerState<JigglingDeviceTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _jiggleController;
  late Animation<double> _jiggleAnimation;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    // Configura l'animazione "traballante"
    _jiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250), // Velocità tremolio
    );

    // Angolo di rotazione molto piccolo (circa 1.5 gradi)
    const double angle = 0.025;
    _jiggleAnimation = Tween<double>(begin: -angle, end: angle).animate(
      CurvedAnimation(parent: _jiggleController, curve: Curves.easeInOutSine),
    );

    if (widget.isEditMode) {
      _startJiggling();
    }
  }

  void _startJiggling() async {
    // Ritardo casuale per evitare effetto robotico (tutti insieme)
    await Future.delayed(Duration(milliseconds: _random.nextInt(200)));
    if (mounted && widget.isEditMode) {
      _jiggleController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(JigglingDeviceTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditMode != oldWidget.isEditMode) {
      if (widget.isEditMode) {
        _startJiggling();
      } else {
        _jiggleController.stop();
        _jiggleController.reset();
      }
    }
  }

  @override
  void dispose() {
    _jiggleController.dispose();
    super.dispose();
  }

  // --- LOGICA ELIMINAZIONE ---
  void _confirmDelete() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E).withOpacity(0.9),
          title: Text("Eliminare dispositivo?", style: GoogleFonts.outfit(color: Colors.white)),
          content: Text(
            "Vuoi rimuovere '${widget.device.friendlyName}'? L'azione è irreversibile.",
            style: GoogleFonts.montserrat(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("ANNULLA", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx); 
                // Elimina tramite API
                await BackendService().deleteDevice(widget.device.id);
                // NOTA: Il socket dovrebbe aggiornare la UI automaticamente
              },
              child: const Text("ELIMINA", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Dati per la grafica
    final stateData = widget.entityStates[widget.device.haEntityId];
    final bool isOn = IconHelper.isActive(stateData);
    final Color color = IconHelper.getColor(widget.device.type, stateData);
    final IconData icon = IconHelper.getIcon(widget.device.type, stateData);
    final Color iconColor = isOn ? color : const Color(0xFFE0E0E0);
    final bool isTower = (widget.device.gridW == 2 && widget.device.gridH == 4);

    // 2. Costruiamo il contenuto interno (Icone, Testi, Neon)
    Widget innerContent = _buildInnerContent(isOn, color, icon, iconColor, isTower);

    // 3. Card Base (Vetro)
    Widget card = ModernGlassCard(
      padding: EdgeInsets.zero,
      opacity: isOn ? 0.12 : 0.08,
      onTap: widget.isEditMode ? null : widget.onTap,
      onLongPress: widget.isEditMode ? null : widget.onLongPress,
      onSecondaryTap: widget.isEditMode ? null : widget.onLongPress, // Tasto destro
      child: Container(
        padding: const EdgeInsets.all(12),
        width: double.infinity, 
        height: double.infinity,
        decoration: BoxDecoration(
          color: isOn ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isOn ? color.withOpacity(0.5) : Colors.transparent, 
            width: 1
          ),
        ),
        child: innerContent,
      ),
    );

    // 4. Se in Edit Mode, applica animazione Jiggle
    Widget animatedCard = widget.isEditMode
        ? AnimatedBuilder(
            animation: _jiggleController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _jiggleAnimation.value,
                child: child,
              );
            },
            child: card,
          )
        : card;

    // 5. Se in Edit Mode, avvolgi con DragLogic + Stack Icone (X e Resize)
    if (widget.isEditMode) {
      return _buildDraggableWrapper(animatedCard);
    }

    return animatedCard;
  }

  // --- LOGICA GRAFICA INTERNA ---
  Widget _buildInnerContent(bool isOn, Color color, IconData icon, Color iconColor, bool isTower) {
    
    // CASO 1: 1x1 (Piccolo quadrato)
    if (widget.device.gridW == 1 && widget.device.gridH == 1) {
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Icon(icon, color: iconColor, size: 28),
        ),
      );
    } 
    
    // CASO 2: 1x2 (Striscia Verticale)
    else if (widget.device.gridW == 1 && widget.device.gridH > 1) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          if (widget.device.type == 'light' && isOn)
            Container(
              width: 4, height: 30,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8)],
              ),
            ),
          Icon(icon, color: iconColor, size: 28),
          const Spacer(),
        ],
      );
    } 
    
    // CASO 3: TOWER (2x4)
    else if (isTower) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              const Icon(Icons.more_vert, color: Colors.white24, size: 16),
            ],
          ),
          const Spacer(),
          Text(
            widget.device.friendlyName.toUpperCase(),
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 2, overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            isOn ? "ATTIVO" : "SPENTO",
            style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      );
    } 
    
    // CASO 4: STANDARD (2x1, 2x2, Ecc.)
    else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 26),
              if (isOn)
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 6, spreadRadius: 1)]),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              widget.device.friendlyName.toUpperCase(),
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
              maxLines: 2, overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
  }

  // --- WRAPPER DRAG & DROP + STACK EDITING ---
  Widget _buildDraggableWrapper(Widget child) {
    final bool isHovered = widget.currentHoveredId == widget.device.id;

    return DragTarget<DeviceConfig>(
      onWillAcceptWithDetails: (details) {
        final isDifferent = details.data.id != widget.device.id;
        if (isDifferent && widget.currentHoveredId != widget.device.id) {
          widget.onHoverChanged(widget.device.id);
        }
        return isDifferent;
      },
      onLeave: (_) {
        if (widget.currentHoveredId == widget.device.id) {
          widget.onHoverChanged(null);
        }
      },
      onAcceptWithDetails: (details) {
        widget.onSwap(details.data, widget.device);
        widget.onHoverChanged(null);
      },
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<DeviceConfig>(
          data: widget.device,
          delay: const Duration(milliseconds: 200),
          feedback: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
               constraints: const BoxConstraints.tightFor(width: 100, height: 100),
               child: Opacity(opacity: 0.7, child: child)
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: child),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // IL CONTENUTO CHE TRABALLA
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: isHovered
                    ? BoxDecoration(
                        border: Border.all(color: AppTheme.accent, width: 2),
                        borderRadius: BorderRadius.circular(24),
                        color: AppTheme.accent.withOpacity(0.1),
                      )
                    : null,
                child: child, 
              ),

              // --- X ROSSA (ELIMINA) ---
              Positioned(
                top: -8,
                left: -8,
                child: GestureDetector(
                  onTap: _confirmDelete,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),

              // --- RESIZE HANDLE ---
               Positioned(
                right: -8, bottom: -8,
                child: GestureDetector(
                  onTap: () => _showResizeDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.transparent, // Hitbox estesa
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.aspect_ratio, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- DIALOG RESIZE ---
  void _showResizeDialog(BuildContext context) {
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
                  Icon(IconHelper.getIcon(widget.device.type, null), color: Colors.white54, size: 40),
                  const SizedBox(height: 15),
                  Text("DIMENSIONI WIDGET", style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  Wrap(
                    spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
                    children: [
                      _ResizeOption(w: 1, h: 1, label: "1x1", icon: Icons.crop_square, device: widget.device, ctx: ctx),
                      _ResizeOption(w: 2, h: 1, label: "2x1", icon: Icons.crop_landscape, device: widget.device, ctx: ctx),
                      _ResizeOption(w: 1, h: 2, label: "1x2", icon: Icons.crop_portrait, device: widget.device, ctx: ctx),
                      _ResizeOption(w: 2, h: 2, label: "2x2", icon: Icons.grid_view, device: widget.device, ctx: ctx),
                      _ResizeOption(w: 2, h: 4, label: "Tower", icon: Icons.view_week, device: widget.device, ctx: ctx),
                    ],
                  ),
                  const SizedBox(height: 30),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ANNULLA", style: TextStyle(color: Colors.white30))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- HELPER PER LE OPZIONI DI RESIZE ---
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
    required this.ctx
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
        width: 85, height: 85, 
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E676).withOpacity(0.2) : Colors.white.withOpacity(0.05), 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(
            color: isSelected ? const Color(0xFF00E676) : Colors.white.withOpacity(0.1), 
            width: isSelected ? 2 : 1
          )
        ), 
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white54, size: 28), 
            const SizedBox(height: 8), 
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontWeight: FontWeight.bold, fontSize: 11))
          ]
        )
      )
    ); 
  }
}