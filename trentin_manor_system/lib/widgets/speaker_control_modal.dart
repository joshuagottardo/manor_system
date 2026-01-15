import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_models.dart';
import '../providers/app_providers.dart';
import '../config/app_config.dart';
import '../config/app_theme.dart';

class SpeakerControlModal extends ConsumerStatefulWidget {
  final DeviceConfig device;
  final Map<String, dynamic> currentState;

  const SpeakerControlModal({
    super.key,
    required this.device,
    required this.currentState,
  });

  @override
  ConsumerState<SpeakerControlModal> createState() => _SpeakerControlModalState();
}

class _SpeakerControlModalState extends ConsumerState<SpeakerControlModal> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final TextEditingController _ttsController = TextEditingController();
  double _volume = 0;
  bool _isSendingTTS = false;

  @override
  void initState() {
    super.initState();
    // Animazione per il vinile (gira in 5 secondi)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _initValues();
  }

  void _initValues() {
    final attrs = widget.currentState['attributes'];
    final state = widget.currentState['state'];

    // Volume
    if (attrs != null && attrs['volume_level'] != null) {
      _volume = (attrs['volume_level'] as num).toDouble();
    }

    // Gestione Animazione
    if (state == 'playing') {
      _animController.repeat();
    } else {
      _animController.stop();
    }
  }

  @override
  void didUpdateWidget(SpeakerControlModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se cambia lo stato (da play a pause), aggiorniamo l'animazione
    if (widget.currentState['state'] == 'playing' && !_animController.isAnimating) {
      _animController.repeat();
    } else if (widget.currentState['state'] != 'playing' && _animController.isAnimating) {
      _animController.stop();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _ttsController.dispose();
    super.dispose();
  }

  // Funzione per inviare TTS (Text to Speech)
  Future<void> _sendTTS() async {
    if (_ttsController.text.isEmpty) return;

    setState(() => _isSendingTTS = true);

    // Servizio standard per Google Home. 
    // Se usi un altro motore (es. Polly, Nabu Casa), cambia 'tts.google_translate_say'
    await ref.read(haServiceProvider).callService('tts', 'google_translate_say', {
      'entity_id': widget.device.haEntityId,
      'message': _ttsController.text,
    });

    _ttsController.clear();
    setState(() => _isSendingTTS = false);
    
    // Feedback visivo
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Annuncio inviato!"), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final attrs = widget.currentState['attributes'];
    final state = widget.currentState['state'];
    final bool isPlaying = state == 'playing';
    
    // Recuperiamo Copertina
    String? artworkPath = attrs?['entity_picture'];
    String? fullArtworkUrl;
    if (artworkPath != null) {
      fullArtworkUrl = "${AppConfig.haUrlExternal}$artworkPath";
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: SingleChildScrollView( // Per evitare overflow con la tastiera
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // MANIGLIA
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 30),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),

                // 1. VINILE ANIMATO
                RotationTransition(
                  turns: _animController,
                  child: Container(
                    width: 220, height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                      boxShadow: isPlaying 
                        ? [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 30, spreadRadius: 5)] 
                        : [],
                      border: Border.all(color: Colors.white12, width: 2),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Copertina Album (Ritagliata a cerchio)
                        if (fullArtworkUrl != null)
                          ClipOval(
                            child: Image.network(
                              fullArtworkUrl,
                              width: 215, height: 215,
                              fit: BoxFit.cover,
                              headers: {'Authorization': 'Bearer ${AppConfig.haToken}'},
                              errorBuilder: (c,e,s) => const Icon(Icons.music_note, size: 80, color: Colors.white24),
                            ),
                          )
                        else
                          const Icon(Icons.speaker, size: 80, color: Colors.white24),
                        
                        // Buco del vinile centrale
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A), // Grigio scuro quasi nero
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // INFO BRANO
                Text(
                  (attrs?['media_title'] ?? "Nessuna riproduzione").toString().toUpperCase(),
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                Text(
                  attrs?['media_artist'] ?? widget.device.friendlyName,
                  style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.primary, letterSpacing: 1),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 30),

                // CONTROLLI MUSIC
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

                const SizedBox(height: 20),
                
                // SLIDER VOLUME
                Row(
                  children: [
                    const Icon(Icons.volume_mute, color: Colors.white54, size: 20),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppTheme.primary,
                          inactiveTrackColor: Colors.white10,
                          thumbColor: Colors.white,
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
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
                    const Icon(Icons.volume_up, color: Colors.white54, size: 20),
                  ],
                ),

                const SizedBox(height: 30),
                const Divider(color: Colors.white10),
                const SizedBox(height: 20),

                // SEZIONE INTERCOM (TTS)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "INTERCOM / ANNUNCIO",
                    style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ttsController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Scrivi un messaggio...",
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FloatingActionButton.small(
                      backgroundColor: AppTheme.primary,
                      onPressed: _isSendingTTS ? null : _sendTTS,
                      child: _isSendingTTS 
                        ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Icon(Icons.send, color: Colors.black),
                    )
                  ],
                ),
                
                // Padding per tastiera
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaBtn(IconData icon, VoidCallback onTap, {bool isMain = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isMain ? 60 : 45,
        height: isMain ? 60 : 45,
        decoration: BoxDecoration(
          color: isMain ? Colors.white : Colors.white10,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isMain ? Colors.black : Colors.white, size: isMain ? 30 : 22),
      ),
    );
  }

  void _mediaCmd(String service) {
    ref.read(haServiceProvider).callService('media_player', service, {
      'entity_id': widget.device.haEntityId
    });
  }
}