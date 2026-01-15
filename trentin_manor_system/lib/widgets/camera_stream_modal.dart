import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mjpeg_viewer.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_models.dart';
import '../providers/app_providers.dart';
import '../config/app_config.dart';

class CameraStreamModal extends ConsumerStatefulWidget {
  final DeviceConfig device;
  const CameraStreamModal({super.key, required this.device});

  @override
  ConsumerState<CameraStreamModal> createState() => _CameraStreamModalState();
}

class _CameraStreamModalState extends ConsumerState<CameraStreamModal> {
  late Timer _timer;
  String _timeString = "";

  @override
  void initState() {
    super.initState();
    _timeString = _formatDateTime(DateTime.now());
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer t) => _getTime(),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _getTime() {
    final DateTime now = DateTime.now();
    final String formattedDateTime = _formatDateTime(now);
    if (mounted) {
      setState(() {
        _timeString = formattedDateTime;
      });
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy  HH:mm:ss').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final streamUrl =
        "${AppConfig.haUrlExternal}/api/camera_proxy_stream/${widget.device.haEntityId}";

    // 4. Ascoltiamo lo stato reale della camera
    final entityStates = ref.watch(entityMapProvider).value ?? {};
    final stateData = entityStates[widget.device.haEntityId];
    final state = stateData?['state'];

    // È accesa se non è 'off' e non è 'unavailable'
    final bool isCameraOn = state != 'off' && state != 'unavailable';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. STREAM VIDEO (Mostriamo solo se è accesa)
          if (isCameraOn)
            Center(
              child: MjpegViewer(
                isLive: true,
                streamUrl: streamUrl,
                headers: {'Authorization': 'Bearer ${AppConfig.haToken}'},
                errorBuilder: (c, e, s) => _buildOfflineView("SEGNALE PERSO"),
                loadingBuilder: (c) => _buildLoadingView(),
              ),
            )
          else
            _buildOfflineView("CAMERA SPENTA (PRIVACY MODE)"),

          // 2. OVERLAY CCTV
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // REC Indicator (Solo se accesa)
                      if (isCameraOn)
                        Row(
                          children: [
                            _BlinkingRedDot(),
                            const SizedBox(width: 8),
                            Text(
                              "LIVE",
                              style: GoogleFonts.outfit(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          "OFFLINE",
                          style: GoogleFonts.outfit(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                      Text(
                        widget.device.friendlyName.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),

                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  // FOOTER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "CAM-0${widget.device.id}",
                            style: GoogleFonts.shareTechMono(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _timeString,
                            style: GoogleFonts.shareTechMono(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),

                      // 5. TASTO POWER (Accendi/Spegni da qui)
                      FloatingActionButton.small(
                        backgroundColor: isCameraOn
                            ? Colors.red.withOpacity(0.2)
                            : Colors.green.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isCameraOn ? Colors.red : Colors.green,
                          ),
                        ),
                        elevation: 0,
                        onPressed: () {
                          // Toggle tramite Home Assistant
                          ref
                              .read(haServiceProvider)
                              .toggleEntity(widget.device.haEntityId);
                        },
                        child: Icon(
                          Icons.power_settings_new,
                          color: isCameraOn ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, color: Colors.white24, size: 60),
          const SizedBox(height: 20),
          Text(
            message,
            style: GoogleFonts.outfit(color: Colors.white54, letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.redAccent),
          const SizedBox(height: 20),
          Text(
            "CONNESSIONE SATELLITARE...",
            style: GoogleFonts.outfit(color: Colors.white54, letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}

// Widget pallino rosso che lampeggia
class _BlinkingRedDot extends StatefulWidget {
  @override
  State<_BlinkingRedDot> createState() => _BlinkingRedDotState();
}

class _BlinkingRedDotState extends State<_BlinkingRedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
