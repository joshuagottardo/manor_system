import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_models.dart';
import '../providers/app_providers.dart';
import '../config/app_config.dart';

class TvControlModal extends ConsumerStatefulWidget {
  final DeviceConfig device;
  final Map<String, dynamic> currentState;

  const TvControlModal({
    super.key,
    required this.device,
    required this.currentState,
  });

  @override
  ConsumerState<TvControlModal> createState() => _TvControlModalState();
}

class _TvControlModalState extends ConsumerState<TvControlModal> {
  double _volume = 0;
  
  @override
  void initState() {
    super.initState();
    final attrs = widget.currentState['attributes'];
    if (attrs != null && attrs['volume_level'] != null) {
      _volume = (attrs['volume_level'] as num).toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final attrs = widget.currentState['attributes'];
    final String? state = widget.currentState['state'];
    final bool isPlaying = state == 'playing';
    final bool isOn = state != 'off' && state != 'unavailable';
    
    // Recuperiamo l'immagine di copertina se c'è
    String? artworkPath = attrs?['entity_picture'];
    String? fullArtworkUrl;
    if (artworkPath != null) {
      fullArtworkUrl = "${AppConfig.haUrlExternal}$artworkPath";
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.black, // Base nera
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // 1. SFONDO ARTWORK SFOCATO
          if (fullArtworkUrl != null && isOn)
            Positioned.fill(
              child: Image.network(
                fullArtworkUrl,
                fit: BoxFit.cover,
                headers: {'Authorization': 'Bearer ${AppConfig.haToken}'},
                errorBuilder: (c,e,s) => Container(color: Colors.black),
              ),
            ),
          
          // 2. VETRO SCURO SOPRA L'IMMAGINE
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                color: Colors.black.withOpacity(0.7), // Oscuriamo per leggibilità
              ),
            ),
          ),

          // 3. CONTENUTO
          Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                // MANIGLIA
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 30),

                // COPERTINA PICCOLA (Se disponibile)
                if (fullArtworkUrl != null && isOn)
                  Container(
                    width: 120, height: 180,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))],
                      image: DecorationImage(
                        image: NetworkImage(fullArtworkUrl, headers: {'Authorization': 'Bearer ${AppConfig.haToken}'}),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Icon(Icons.tv, size: 80, color: Colors.white.withOpacity(0.1)),

                const SizedBox(height: 20),

                // TITOLO E SOTTOTITOLO
                Text(
                  (attrs?['media_title'] ?? widget.device.friendlyName).toString().toUpperCase(),
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                if (attrs?['app_name'] != null)
                  Text(
                    attrs!['app_name'],
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.blueAccent, letterSpacing: 2),
                  ),

                const Spacer(),

                // VOLUME SLIDER
                if (isOn) ...[
                  Row(
                    children: [
                      const Icon(Icons.volume_mute, color: Colors.white54),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white10,
                            thumbColor: Colors.blueAccent,
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            overlayColor: Colors.blueAccent.withOpacity(0.2),
                          ),
                          child: Slider(
                            value: _volume,
                            onChanged: (v) => setState(() => _volume = v),
                            onChangeEnd: (v) {
                              ref.read(haServiceProvider).callService('media_player', 'volume_set', {
                                'entity_id': widget.device.haEntityId,
                                'volume_level': v
                              });
                            },
                          ),
                        ),
                      ),
                      const Icon(Icons.volume_up, color: Colors.white54),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],

                // CONTROLLI PLAYBACK
                if (isOn)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMediaBtn(Icons.skip_previous, () => _mediaCmd('media_previous_track')),
                      const SizedBox(width: 20),
                      _buildMediaBtn(
                        isPlaying ? Icons.pause : Icons.play_arrow, 
                        () => _mediaCmd('media_play_pause'),
                        isMain: true
                      ),
                      const SizedBox(width: 20),
                      _buildMediaBtn(Icons.skip_next, () => _mediaCmd('media_next_track')),
                    ],
                  ),
                
                const SizedBox(height: 40),

                // APP LAUNCHER (Sorgenti)
                if (isOn && attrs?['source_list'] != null) ...[
                  SizedBox(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: (attrs!['source_list'] as List).map((source) {
                        final String s = source.toString();
                        final bool isSelected = attrs['source'] == s;
                        return GestureDetector(
                          onTap: () {
                            ref.read(haServiceProvider).callService('media_player', 'select_source', {
                              'entity_id': widget.device.haEntityId,
                              'source': s
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blueAccent : Colors.white10,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white12),
                            ),
                            child: Text(
                              s, 
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],

                // TASTO POWER
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                       ref.read(haServiceProvider).toggleEntity(widget.device.haEntityId);
                       if (isOn) Navigator.pop(context); // Chiudi se spegni
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOn ? Colors.red.withOpacity(0.2) : Colors.green,
                      foregroundColor: isOn ? Colors.red : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: isOn ? Colors.red : Colors.transparent),
                    ),
                    child: Text(isOn ? "SPEGNI TV" : "ACCENDI TV", style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaBtn(IconData icon, VoidCallback onTap, {bool isMain = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isMain ? 70 : 50,
        height: isMain ? 70 : 50,
        decoration: BoxDecoration(
          color: isMain ? Colors.white : Colors.white10,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isMain ? Colors.black : Colors.white, size: isMain ? 32 : 24),
      ),
    );
  }

  void _mediaCmd(String service) {
    ref.read(haServiceProvider).callService('media_player', service, {
      'entity_id': widget.device.haEntityId
    });
  }
}