import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_models.dart';
import '../providers/app_providers.dart';
import '../config/app_theme.dart';
import 'neon_color_picker.dart';

class DeviceControlModal extends ConsumerStatefulWidget {
  final DeviceConfig device;
  final Map<String, dynamic> currentState;

  const DeviceControlModal({
    super.key,
    required this.device,
    required this.currentState,
  });

  @override
  ConsumerState<DeviceControlModal> createState() => _DeviceControlModalState();
}

class _DeviceControlModalState extends ConsumerState<DeviceControlModal> {
  double _currentValue = 0;
  Color _currentColor = Colors.white;
  bool _supportsColor = false;

  // Valori CLIMA Dinamici
  String _hvacMode = 'off';
  double? _currentRoomTemp;
  double _minTemp = 7.0;
  double _maxTemp = 35.0;
  List<String> _availableModes = ['off', 'heat'];

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  void _initValues() {
    final attrs = widget.currentState['attributes'];

    // 1. Estraiamo lo stato e lo forziamo a Stringa subito
    // Usiamo .toString() così anche se arriva un numero o altro, diventa stringa
    final dynamic rawState = widget.currentState['state'];
    final String? state = rawState?.toString();

    if (widget.device.type == 'light' && attrs != null) {
      if (attrs['brightness'] != null) {
        _currentValue = (attrs['brightness'] as num).toDouble();
      }
      final modes = attrs['supported_color_modes'] as List?;
      bool canDoColor =
          modes != null &&
          (modes.contains('rgb') ||
              modes.contains('hs') ||
              modes.contains('xy'));

      if (attrs['rgb_color'] != null) {
        final List rgb = attrs['rgb_color'];
        if (rgb.length == 3) {
          _currentColor = Color.fromRGBO(rgb[0], rgb[1], rgb[2], 1.0);
          _supportsColor = true;
        }
      } else if (canDoColor) {
        _supportsColor = true;
      }
    } else if (widget.device.type == 'climate') {
      _hvacMode = state ?? 'off';

      // Lettura LIMITI DINAMICI (Min/Max)
      if (attrs != null) {
        if (attrs['min_temp'] != null) {
          _minTemp = (attrs['min_temp'] as num).toDouble();
        }
        if (attrs['max_temp'] != null) {
          _maxTemp = (attrs['max_temp'] as num).toDouble();
        }

        // Lettura MODALITÀ SUPPORTATE
        if (attrs['hvac_modes'] != null) {
          _availableModes = (attrs['hvac_modes'] as List)
              .map((e) => e.toString())
              .toList();
        }
      }

      // Temperatura Target
      if (attrs != null && attrs['temperature'] != null) {
        _currentValue = (attrs['temperature'] as num).toDouble();
      } else {
        _currentValue = 20.0;
      }

      if (_currentValue < _minTemp) _currentValue = _minTemp;
      if (_currentValue > _maxTemp) _currentValue = _maxTemp;

      // Temperatura Attuale
      if (attrs != null && attrs['current_temperature'] != null) {
        _currentRoomTemp = (attrs['current_temperature'] as num).toDouble();
      }
    }
  }

  // Helper per ottenere il colore in base alla modalità Clima
  Color _getClimateColor() {
    switch (_hvacMode) {
      case 'heat':
        return const Color(0xFFFF5722); // Arancione lava
      case 'cool':
        return const Color(0xFF2196F3); // Blu ghiaccio
      case 'auto':
        return const Color(0xFF4CAF50); // Verde eco
      default:
        return Colors.white38; // Grigio spento
    }
  }

  IconData _getModeIcon(String mode) {
    switch (mode) {
      case 'heat':
        return Icons.local_fire_department;
      case 'cool':
        return Icons.ac_unit;
      case 'auto':
        return Icons.hdr_auto;
      case 'heat_cool':
        return Icons.thermostat_auto;
      case 'dry':
        return Icons.water_drop;
      case 'fan_only':
        return Icons.air;
      case 'off':
        return Icons.power_settings_new;
      default:
        return Icons.thermostat;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Backdrop filter per sfocare lo sfondo dietro al modale
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85), // Sfondo molto scuro
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // MANIGLIA
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // TITOLO
                Text(
                  widget.device.friendlyName.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  widget.device.haEntityId,
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 40),

                // CONTROLLO SPECIFICO (Luce Dimmerabile o Termostato)
                if (widget.device.type == 'light') _buildLightControls(),
                if (widget.device.type == 'climate') _buildClimateControls(),

                if (widget.device.type != 'climate') ...[
                  const SizedBox(height: 30),
                  _buildSwitchControls(),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLightControls() {
    return Column(
      children: [
        // SLIDER LUMINOSITÀ
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.brightness_low, color: Colors.white54),
            Text(
              "${((_currentValue / 255) * 100).toInt()}%",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Icon(Icons.brightness_high, color: Colors.white),
          ],
        ),
        const SizedBox(height: 15),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Colors.yellowAccent,
            inactiveTrackColor: Colors.white10,
            thumbColor: Colors.white,
            trackHeight: 6,
            overlayColor: Colors.yellowAccent.withOpacity(0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
          ),
          child: Slider(
            value: _currentValue,
            min: 0,
            max: 255,
            onChanged: (val) => setState(() => _currentValue = val),
            onChangeEnd: (val) {
              ref
                  .read(haServiceProvider)
                  .setLightState(
                    widget.device.haEntityId,
                    brightness: val.toInt(),
                  );
            },
          ),
        ),

        // SELETTORE COLORE (Solo se supportato)
        if (_supportsColor) ...[
          const SizedBox(height: 40),
          Text(
            "COLORE RGB",
            style: GoogleFonts.outfit(
              color: Colors.white54,
              letterSpacing: 2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),

          // NEON COLOR PICKER
          SizedBox(
            height: 220, // Dimensione fissa per il contenitore
            child: NeonColorPicker(
              initialColor: _currentColor,
              onColorChanged: (c) {
                // Aggiornamento solo visivo (opzionale: cambia colore icona titolo?)
              },
              onColorEnd: (color) {
                setState(() => _currentColor = color);

                // Conversione Color -> RGB List [255, 0, 0]
                List<double> rgb = [
                  color.red.toDouble(),
                  color.green.toDouble(),
                  color.blue.toDouble(),
                ];

                // Chiamata al servizio
                ref
                    .read(haServiceProvider)
                    .setLightState(widget.device.haEntityId, rgbColor: rgb);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildClimateControls() {
    final primaryColor = _getClimateColor();

    return Column(
      children: [
        // 1. VISUALIZZATORE
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [primaryColor.withOpacity(0.2), Colors.transparent],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withOpacity(0.5),
                  width: 2,
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "SET TO",
                  style: GoogleFonts.outfit(
                    color: primaryColor.withOpacity(0.7),
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  "${_currentValue.toStringAsFixed(1)}°",
                  style: GoogleFonts.outfit(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                if (_currentRoomTemp != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "ROOM: ${_currentRoomTemp!.toStringAsFixed(1)}°",
                      style: GoogleFonts.outfit(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 30),

        // 2. SLIDER DINAMICO (Usa Min/Max reali)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Text(
                "${_minTemp.toInt()}°",
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: primaryColor,
                    inactiveTrackColor: Colors.white10,
                    thumbColor: Colors.white,
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                    overlayColor: primaryColor.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: _currentValue,
                    min: _minTemp,
                    max: _maxTemp,
                    divisions: ((_maxTemp - _minTemp) * 2)
                        .toInt(), // Step di 0.5
                    onChanged: (val) => setState(() => _currentValue = val),
                    onChangeEnd: (val) {
                      ref.read(haServiceProvider).callService(
                        'climate',
                        'set_temperature',
                        {
                          'entity_id': widget.device.haEntityId,
                          'temperature': val,
                        },
                      );
                    },
                  ),
                ),
              ),
              Text(
                "${_maxTemp.toInt()}°",
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        // 3. SELETTORE MODALITÀ (Generato dinamicamente)
        Wrap(
          spacing: 15, // Spazio orizzontale
          runSpacing: 15, // Spazio verticale se va a capo
          alignment: WrapAlignment.center,
          children: _availableModes.map((mode) {
            Color color;
            switch (mode) {
              case 'heat':
                color = const Color(0xFFFF5722);
                break;
              case 'cool':
                color = const Color(0xFF2196F3);
                break;
              case 'auto':
                color = const Color(0xFF4CAF50);
                break;
              case 'off':
                color = Colors.grey;
                break;
              default:
                color = Colors.purpleAccent;
            }

            return _buildModeButton(
              icon: _getModeIcon(mode),
              label: mode.toUpperCase(),
              mode: mode,
              color: color,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required String mode,
    required Color color,
  }) {
    final bool isSelected = _hvacMode == mode;

    return GestureDetector(
      onTap: () {
        setState(() => _hvacMode = mode);
        ref.read(haServiceProvider).callService('climate', 'set_hvac_mode', {
          'entity_id': widget.device.haEntityId,
          'hvac_mode': mode,
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Importante per Wrap
          children: [
            Icon(icon, color: isSelected ? color : Colors.white38, size: 24),
            const SizedBox(height: 5),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchControls() {
    final state = widget.currentState['state'];
    bool isOn = state == 'on' || state == 'open' || state == 'unlocked';

    Color activeColor = AppTheme.primary;
    if (widget.device.type == 'lock') activeColor = Colors.redAccent;
    if (widget.device.type == 'cover') activeColor = Colors.purpleAccent;

    return GestureDetector(
      onTap: () {
        // Toggle tramite Riverpod
        ref.read(haServiceProvider).toggleEntity(widget.device.haEntityId);
        // Chiudiamo il modale dopo un breve delay per feedback visivo?
        // No, meglio lasciare l'utente decidere, magari vuole solo accendere senza chiudere.
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isOn ? activeColor : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isOn
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ]
              : [],
          border: Border.all(
            color: isOn ? activeColor : Colors.white12,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          isOn
              ? "SPEGNI"
              : "ACCENDI", // O "CHIUDI/APRI" in base al tipo, da migliorare in futuro
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 2,
            color: isOn ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}
