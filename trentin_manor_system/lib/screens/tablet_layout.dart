import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';
import '../providers/app_providers.dart';
import '../widgets/visual_room.dart';
import '../widgets/add_device_modal.dart';
import '../widgets/add_room_modal.dart';
import '../widgets/modern_glass_card.dart'; // Assicurati che questo file supporti opacity custom
import '../config/app_theme.dart';
import '../utils/icon_helper.dart';
import '../widgets/room_transition_wrapper.dart';
import '../widgets/control_center_panel.dart';

class TabletLayout extends ConsumerStatefulWidget {
  const TabletLayout({super.key});

  @override
  ConsumerState<TabletLayout> createState() => _TabletLayoutState();
}

class _TabletLayoutState extends ConsumerState<TabletLayout> {
  int? selectedRoomId;
  bool isEditMode = false;
  DateTime? _lastNetworkUpdate;

  @override
  void initState() {
    super.initState();
    // Nasconde status bar per immersione totale (opzionale)
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _handleNetworkUpdate(int deviceId, double x, double y) {
    final now = DateTime.now();
    if (_lastNetworkUpdate == null || now.difference(_lastNetworkUpdate!) > const Duration(milliseconds: 100)) {
      BackendService().updateDevicePosition(deviceId, x, y);
      _lastNetworkUpdate = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomsProvider);
    final entityStatesAsync = ref.watch(entityMapProvider);
    final entityStates = entityStatesAsync.value ?? {};

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. BACKGROUND: PROFONDITÀ SOTTILE
          // Un gradiente impercettibile per evitare l'effetto "piatto"
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.5),
                radius: 1.5,
                colors: [
                  Color(0xFF1A1A1A), // Grigio scurissimo al centro
                  Color(0xFF000000), // Nero assoluto ai bordi
                ],
              ),
            ),
          ),

          roomsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white10)),
            error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
            data: (rooms) {
              if (rooms.isEmpty) return _buildEmptyState();

              // Gestione Selezione
              final currentRoom = selectedRoomId != null 
                  ? rooms.firstWhere((r) => r.id == selectedRoomId, orElse: () => rooms.first)
                  : rooms.first;
              
              if (selectedRoomId == null) {
                 WidgetsBinding.instance.addPostFrameCallback((_) {
                   if(mounted) setState(() => selectedRoomId = currentRoom.id);
                 });
              }

              return Column(
                children: [
                  const SizedBox(height: 20), // Top Padding (Status Bar area)

                  // 2. HEADER FLUTTUANTE (Navigation Capsule)
                  _buildFloatingHeader(rooms, currentRoom),

                  const SizedBox(height: 20),

                  // 3. WORKSPACE (Split View)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // A. LA MAPPA (Main Stage - 60%)
                          Expanded(
                            flex: 60,
                            child: _buildGlassContainer(
                              child: RoomTransitionWrapper(
                                itemKey: ValueKey(currentRoom.id),
                                child: VisualRoom(
                                  room: currentRoom,
                                  isEditMode: isEditMode,
                                  currentStates: entityStates,
                                  onDragStart: (id) => ref.read(roomsProvider.notifier).startDragging(id),
                                  onDeviceMoved: (id, x, y) {
                                    ref.read(roomsProvider.notifier).updateDevicePosition(id, x, y);
                                    _handleNetworkUpdate(id, x, y);
                                  },
                                  onDragEnd: (id, x, y) {
                                    ref.read(roomsProvider.notifier).stopDragging();
                                    BackendService().updateDevicePosition(id, x, y);
                                  },
                                  onDeviceDelete: _deleteDevice,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 24), // Gap elegante

                          // B. PANNELLO CONTROLLI (Context - 40%)
                          Expanded(
                            flex: 40,
                            child: _buildGlassContainer(
                              padding: const EdgeInsets.all(24),
                              child: ControlCenterPanel(
                                devices: currentRoom.devices,
                                isEditMode: isEditMode,
                                entityStates: entityStates,
                                onEditModeToggle: () => setState(() => isEditMode = !isEditMode),
                                onAddDevice: () => _showAddDeviceModal(context, currentRoom),
                                onDeleteRoom: () => _deleteRoom(currentRoom),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20), // Bottom Padding
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- WIDGETS DESIGN SYSTEM ---

  // Il contenitore base per le due aree principali. 
  // Simula una lastra di vetro sospesa.
  Widget _buildGlassContainer({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32), // Curve morbide Apple style
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), // Blur pesante
        child: Container(
          padding: padding ?? EdgeInsets.zero,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E).withOpacity(0.4), // Semi-trasparente scuro
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withOpacity(0.08), // Bordo sottilissimo
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  // L'Header Fluttuante
  Widget _buildFloatingHeader(List<RoomConfig> rooms, RoomConfig currentRoom) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: 60, // Altezza contenuta
        child: Row(
          children: [
            // LOGO / BRAND
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.home_filled, color: Colors.white, size: 20),
            ),
            
            const SizedBox(width: 20),

            // NAVIGATORE STANZE (Pillole)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      scrollDirection: Axis.horizontal,
                      itemCount: rooms.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 5),
                      itemBuilder: (context, index) {
                        // Tasto "+"
                        if (index == rooms.length) {
                          return _buildNavPill(
                            label: "+",
                            isSelected: false,
                            onTap: () => showDialog(context: context, builder: (_) => AddRoomModal(onRoomCreated: (_) => ref.refresh(roomsProvider))),
                            isIcon: true,
                          );
                        }

                        final room = rooms[index];
                        final isSelected = room.id == selectedRoomId;
                        return _buildNavPill(
                          label: room.name,
                          isSelected: isSelected,
                          onTap: () => setState(() => selectedRoomId = room.id),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 20),

            // INFO DESTRE (Ora, Meteo finto, Edit Indicator)
            Row(
              children: [
                if (isEditMode)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
                    ),
                    child: Text(
                      "EDITING",
                      style: GoogleFonts.outfit(
                        color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1
                      ),
                    ),
                  ),
                if (!isEditMode)
                  const Icon(Icons.wifi, color: Colors.white24, size: 18),
              ],
            )
          ],
        ),
      ),
    );
  }

  // La singola pillola di navigazione
  Widget _buildNavPill({required String label, required bool isSelected, required VoidCallback onTap, bool isIcon = false}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: isIcon ? 14 : 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          isIcon ? label : label.toUpperCase(),
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.black : Colors.white54,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.grid_view, size: 60, color: Colors.white12),
          const SizedBox(height: 20),
          Text("BENVENUTO A CASA", style: GoogleFonts.outfit(color: Colors.white30, fontSize: 16, letterSpacing: 4)),
          const SizedBox(height: 40),
          TextButton(
             onPressed: () => showDialog(context: context, builder: (_) => AddRoomModal(onRoomCreated: (_) => ref.refresh(roomsProvider))),
             child: const Text("CREA LA TUA PRIMA STANZA", style: TextStyle(color: AppTheme.accent)),
          )
        ],
      ),
    );
  }

  // --- ACTIONS ---
  void _showAddDeviceModal(BuildContext context, RoomConfig room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddDeviceModal(
        roomId: room.id,
        existingDevices: room.devices,
        onDeviceAdded: (d) {},
      ),
    );
  }

  Future<void> _deleteDevice(int deviceId) async {
    // Implementazione identica a prima...
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text("Elimina Dispositivo", style: TextStyle(color: Colors.white)),
        content: const Text("Questa azione è irreversibile.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annulla")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Elimina", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) await BackendService().deleteDevice(deviceId);
  }

  Future<void> _deleteRoom(RoomConfig room) async {
     final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text("Elimina Stanza", style: TextStyle(color: Colors.white)),
        content: Text("Eliminare ${room.name}?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annulla")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Elimina", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await BackendService().deleteRoom(room.id);
      setState(() => selectedRoomId = null);
      ref.read(roomsProvider.notifier).refresh();
    }
  }
}