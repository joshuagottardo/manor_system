import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_providers.dart';
import '../models/app_models.dart';
import '../widgets/modern_glass_card.dart';
import 'phone_room_detail.dart';

class PhoneLayout extends ConsumerWidget {
  const PhoneLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Leggiamo lo stato delle stanze (Loading / Data / Error)
    final roomsAsync = ref.watch(roomsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true, // L'immagine di sfondo copre anche la status bar
      appBar: AppBar(
        title: Text(
          "MY HOME",
          style: GoogleFonts.outfit(
            fontSize: 24, 
            fontWeight: FontWeight.bold, 
            letterSpacing: 2
          ),
        ),
        actions: [
          // Esempio di indicatore stato connessione
          IconButton(
            icon: const Icon(Icons.cloud_done, color: Colors.greenAccent),
            onPressed: () {}, // Qui potremo mostrare info debug
          )
        ],
      ),
      body: Stack(
        children: [
        // 1. SFONDO GLOBALE (Nero con leggero bagliore in alto a sinistra)
          Container(
            decoration: const BoxDecoration(
              color: Colors.black, // Base Nera
              gradient: RadialGradient(
                center: Alignment(-0.8, -0.6), // Luce dall'angolo in alto a sx
                radius: 1.5,
                colors: [
                  Color(0xFF222222), // Grigio antracite chiaro (il punto luce)
                  Colors.black,      // Nero assoluto
                ],
                stops: [0.0, 0.6],
              ),
            ),
          ),
          // 2. CONTENUTO
          SafeArea(
            child: roomsAsync.when(
              // LOADING
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              // ERRORE
              error: (err, stack) => Center(
                child: Text("Errore: $err", style: const TextStyle(color: Colors.red)),
              ),
              // DATI PRONTI
              data: (rooms) {
                if (rooms.isEmpty) {
                  return const Center(child: Text("Nessuna stanza configurata."));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return _buildRoomCard(context, room);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(BuildContext context, RoomConfig room) {
    return ModernGlassCard(
      margin: const EdgeInsets.only(bottom: 20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PhoneRoomDetail(room: room)),
        );
      },
      child: Row(
        children: [
          // Immagine Stanza (Avatar rotondo con bordo)
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 2),
              image: room.imageUrl != null
                  ? DecorationImage(
                      image: AssetImage(room.imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: Colors.black26,
            ),
            child: room.imageUrl == null
                ? const Icon(Icons.meeting_room, color: Colors.white70)
                : null,
          ),
          const SizedBox(width: 20),
          
          // Testi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.name.toUpperCase(),
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "${room.devices.length} DISPOSITIVI",
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.white54,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          
          // Freccia
          const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
        ],
      ),
    );
  }
}