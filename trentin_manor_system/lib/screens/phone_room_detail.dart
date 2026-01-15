import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_models.dart';
import '../providers/app_providers.dart';
import '../widgets/modern_glass_card.dart';
import '../widgets/device_control_modal.dart';
import '../utils/icon_helper.dart';
import '../widgets/camera_stream_modal.dart';
import '../widgets/tv_control_modal.dart';

class PhoneRoomDetail extends ConsumerWidget {
  final RoomConfig room;

  const PhoneRoomDetail({super.key, required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ascoltiamo lo stato globale
    final entityStatesAsync = ref.watch(entityMapProvider);
    final entityStates = entityStatesAsync.value ?? {};

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          room.name.toUpperCase(),
          style: GoogleFonts.outfit(
            // Usiamo Outfit anche qui
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. SFONDO TOTAL BLACK SPOTLIGHT
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              gradient: RadialGradient(
                center: Alignment(0, -0.4),
                radius: 1.3,
                colors: [Color(0xFF222222), Colors.black],
              ),
            ),
          ),

          // 2. GRIGLIA DISPOSITIVI
          SafeArea(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 2 colonne
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.0, // Quadrati
              ),
              itemCount: room.devices.length,
              itemBuilder: (context, index) {
                return _buildDeviceCard(
                  context,
                  ref,
                  room.devices[index],
                  entityStates,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(
    BuildContext context,
    WidgetRef ref,
    DeviceConfig device,
    Map<String, dynamic> allStates,
  ) {
    // Dati stato
    final stateData = allStates[device.haEntityId];
    final bool isOn = IconHelper.isActive(stateData);
    final Color activeColor = IconHelper.getColor(device.type, stateData);
    final IconData icon = IconHelper.getIcon(device.type, stateData);

    return ModernGlassCard(
      // Se acceso, sfondo leggermente colorato ma trasparente. Se spento, molto scuro.
      opacity: isOn ? 0.15 : 0.05,
      // Se acceso, bordo del colore della luce
      onTap: () {
        // AZIONE 1: TAP (Toggle)
        if (device.type != 'sensor' &&
            device.type != 'camera' &&
            device.type != 'media_player' &&
            device.type != 'climate') {
          ref.read(haServiceProvider).toggleEntity(device.haEntityId);
        } else {
          _showControlModal(context, device, stateData);
        }
      },
      // AZIONE 2: LONG PRESS (Dettagli/Colori)
      // Qui integriamo il modale che abbiamo appena creato!
      child: GestureDetector(
        onLongPress: () => _showControlModal(context, device, stateData),
        child: Container(
          // Container trasparente per catturare il gesto su tutta la card
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ICONA NEON GLOW
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOn
                      ? activeColor.withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                  boxShadow: isOn
                      ? [
                          BoxShadow(
                            color: activeColor.withOpacity(0.6),
                            blurRadius: 20,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                  border: Border.all(
                    color: isOn
                        ? activeColor.withOpacity(0.8)
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isOn ? activeColor : Colors.white38,
                ),
              ),
              const SizedBox(height: 15),

              // NOME
              Text(
                device.friendlyName,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: isOn ? FontWeight.w600 : FontWeight.normal,
                  color: isOn ? Colors.white : Colors.white60,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // INFO EXTRA (Per sensori o stato clima)
              if (stateData != null &&
                  (device.type == 'sensor' || device.type == 'climate')) ...[
                const SizedBox(height: 5),
                Text(
                  _formatState(stateData),
                  style: TextStyle(
                    color: activeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Helper per aprire il modale
  void _showControlModal(
    BuildContext context,
    DeviceConfig device,
    Map<String, dynamic>? state,
  ) {
    if (state == null) return;

    // CASO 1: CAMERA -> Stream a tutto schermo
    if (device.type == 'camera') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraStreamModal(device: device),
        ),
      );
      return;
    }

    // CASO 2: TV -> Telecomando Multimediale
    if (device.type == 'media_player') {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) =>
            TvControlModal(device: device, currentState: state),
      );
      return;
    }

    // CASO 3: TUTTO IL RESTO (Luci, Clima, Sensori) -> Modale Standard
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          DeviceControlModal(device: device, currentState: state),
    );
  }

  String _formatState(Map<String, dynamic> state) {
    final val = state['state'];
    final unit = state['attributes']['unit_of_measurement'] ?? '';
    return "$val $unit";
  }
}
