import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';
import '../providers/app_providers.dart';
import '../widgets/visual_room.dart';
import '../widgets/add_device_modal.dart';
import '../widgets/add_room_modal.dart';
import '../widgets/modern_glass_card.dart';
import '../config/app_theme.dart';
import '../utils/icon_helper.dart';

class TabletLayout extends ConsumerStatefulWidget {
  const TabletLayout({super.key});

  @override
  ConsumerState<TabletLayout> createState() => _TabletLayoutState();
}

class _TabletLayoutState extends ConsumerState<TabletLayout> {
  int? selectedRoomId;
  bool isEditMode = false;
  
  // Variabile per il throttling (limitazione chiamate di rete)
  DateTime? _lastNetworkUpdate;

  // --- IL METODO MANCANTE ---
  void _handleNetworkUpdate(int deviceId, double x, double y) {
    final now = DateTime.now();
    // Se è passato troppo poco tempo dall'ultimo invio (es. 100ms), ignoriamo
    if (_lastNetworkUpdate == null || now.difference(_lastNetworkUpdate!) > const Duration(milliseconds: 100)) {
      BackendService().updateDevicePosition(deviceId, x, y);
      _lastNetworkUpdate = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Usiamo i provider aggiornati (RoomsNotifier e SocketService)
    final roomsAsync = ref.watch(roomsProvider);
    final entityStatesAsync = ref.watch(entityMapProvider);
    final entityStates = entityStatesAsync.value ?? {};

    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        toolbarHeight: 80,
        title: Text(
          isEditMode ? "MODALITÀ MODIFICA" : "TRENTIN MANOR",
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            color: isEditMode ? Colors.redAccent : Colors.white,
          ),
        ),
        actions: [
          if (isEditMode)
            _buildGlassIconButton(
              icon: Icons.delete_forever,
              color: Colors.redAccent,
              onPressed: () {
                 final rooms = roomsAsync.value;
                 if (rooms != null) {
                   final currentRoom = rooms.firstWhere((r) => r.id == selectedRoomId, orElse: () => rooms.first);
                   _deleteRoom(currentRoom);
                 }
              },
            ),
          const SizedBox(width: 15),
          _buildGlassIconButton(
            icon: isEditMode ? Icons.check : Icons.edit,
            color: isEditMode ? Colors.greenAccent : Colors.white,
            onPressed: () => setState(() => isEditMode = !isEditMode),
          ),
          const SizedBox(width: 30),
        ],
      ),
      
      // SFONDO
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.2,
            colors: [Color(0xFF1A1A1A), Colors.black],
          ),
        ),
        child: roomsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
          error: (err, stack) => Center(child: Text("Errore: $err", style: const TextStyle(color: Colors.red))),
          data: (rooms) {
            if (rooms.isEmpty) return const Center(child: Text("Nessuna stanza configurata."));

            final currentRoom = rooms.firstWhere(
              (r) => r.id == selectedRoomId,
              orElse: () {
                Future.microtask(() {
                  if (mounted && rooms.isNotEmpty) setState(() => selectedRoomId = rooms.first.id);
                });
                return rooms.first;
              },
            );

            return Column(
              children: [
                const SizedBox(height: 90), // Spazio AppBar
                
                // BARRA STANZE
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    itemCount: rooms.length + 1,
                    itemBuilder: (context, index) {
                      if (index == rooms.length) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: _buildGlassIconButton(
                            icon: Icons.add, 
                            onPressed: () => _showAddRoomModal(context)
                          ),
                        );
                      }
                      return _buildRoomTab(rooms[index], currentRoom.id == rooms[index].id);
                    },
                  ),
                ),

                // AREA PRINCIPALE
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(40, 20, 40, 40),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. VISUAL ROOM (La mappa)
                        Expanded(
                          flex: 3,
                          child: ModernGlassCard(
                            padding: EdgeInsets.zero,
                            opacity: 0.03,
                            child: VisualRoom(
                              room: currentRoom,
                              isEditMode: isEditMode,
                              currentStates: entityStates,
                              
                              // A. Inizio Drag: Blocca aggiornamenti socket per questo ID
                              onDragStart: (id) {
                                ref.read(roomsProvider.notifier).startDragging(id);
                              },

                              // B. Movimento: Aggiorna UI locale istantaneamente + Network Throttled
                              onDeviceMoved: (id, x, y) {
                                ref.read(roomsProvider.notifier).updateDevicePosition(id, x, y);
                                _handleNetworkUpdate(id, x, y); // <--- Ora esiste!
                              },

                              // C. Fine Drag: Salva finale e sblocca socket
                              onDragEnd: (id, x, y) {
                                ref.read(roomsProvider.notifier).stopDragging();
                                BackendService().updateDevicePosition(id, x, y);
                              },
                              
                              onDeviceDelete: (id) => _deleteDevice(id),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 30),

                        // 2. LISTA DISPOSITIVI
                        SizedBox(
                          width: 350,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "DISPOSITIVI",
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: Colors.white54,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 15),
                              Expanded(
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: currentRoom.devices.length,
                                  separatorBuilder: (c, i) => const SizedBox(height: 12),
                                  itemBuilder: (c, i) => _buildDeviceTile(currentRoom.devices[i], entityStates),
                                ),
                              ),
                              if (isEditMode)
                                Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: ModernGlassCard(
                                    onTap: () => _showAddDeviceModal(context, currentRoom),
                                    opacity: 0.2,
                                    child: const Center(
                                      child: Text(
                                        "+ AGGIUNGI DEVICE",
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- WIDGETS DI SUPPORTO ---

  Widget _buildGlassIconButton({required IconData icon, required VoidCallback onPressed, Color color = Colors.white}) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildRoomTab(RoomConfig room, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() {
        selectedRoomId = room.id;
        isEditMode = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 15),
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
        alignment: Alignment.center, // Centraggio perfetto
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Text(
          room.name.toUpperCase(),
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 1,
            height: 1.0, // Fix interlinea font
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceTile(DeviceConfig device, Map<String, dynamic> entityStates) {
    final stateData = entityStates[device.haEntityId];
    final bool isOn = IconHelper.isActive(stateData);
    final Color color = IconHelper.getColor(device.type, stateData);
    final IconData icon = IconHelper.getIcon(device.type, stateData);

    return ModernGlassCard(
      opacity: isOn ? 0.15 : 0.05,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOn ? color.withOpacity(0.2) : Colors.transparent,
              boxShadow: isOn ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10)] : [],
            ),
            child: Icon(icon, color: isOn ? color : Colors.white38, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.friendlyName,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                if (device.type == 'sensor' || device.type == 'climate')
                   Text(
                     "${stateData?['state'] ?? '--'} ${stateData?['attributes']?['unit_of_measurement'] ?? ''}",
                     style: TextStyle(color: color, fontSize: 12),
                   )
              ],
            ),
          ),
          if (device.type != 'sensor')
             Transform.scale(
               scale: 0.8,
               child: Switch(
                 value: isOn,
                 activeThumbColor: color,
                 activeTrackColor: color.withOpacity(0.3),
                 inactiveThumbColor: Colors.grey,
                 inactiveTrackColor: Colors.white10,
                 onChanged: (v) => ref.read(haServiceProvider).toggleEntity(device.haEntityId),
               ),
             ),
        ],
      ),
    );
  }

  // --- ACTIONS ---

  void _showAddRoomModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      builder: (context) => AddRoomModal(
        onRoomCreated: (newRoom) {
          ref.read(roomsProvider.notifier).refresh(); // Refresh via Notifier
          setState(() => selectedRoomId = newRoom.id);
        },
      ),
    );
  }

  void _showAddDeviceModal(BuildContext context, RoomConfig room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddDeviceModal(
        roomId: room.id,
        existingDevices: room.devices,
        onDeviceAdded: (d) => ref.read(roomsProvider.notifier).refresh(), // Refresh via Notifier
      ),
    );
  }

  Future<void> _deleteDevice(int deviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text("Elimina Dispositivo", style: TextStyle(color: Colors.white)),
        content: const Text("Rimuovere dalla mappa?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Elimina", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await BackendService().deleteDevice(deviceId);
      ref.read(roomsProvider.notifier).refresh();
    }
  }

  Future<void> _deleteRoom(RoomConfig room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text("Elimina Stanza", style: TextStyle(color: Colors.white)),
        content: Text("Eliminare ${room.name} e tutti i dispositivi?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
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