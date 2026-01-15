import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class IconHelper {
  // 1. Logica per scegliere l'ICONA
  static IconData getIcon(String type, Map<String, dynamic>? state) {
    // Se lo stato è null, usiamo icone di default basate solo sul tipo
    if (state == null) {
      switch (type) {
        case 'light':
          return Icons.lightbulb_outline;
        case 'switch':
          return Icons.power_settings_new;
        case 'sensor':
          return Icons.thermostat;
        case 'climate':
          return Icons.thermostat;
        case 'camera':
          return Icons.videocam;
        case 'media_player':
          return Icons.speaker; // Default generico
        case 'lock':
          return Icons.lock_outline;
        case 'cover':
          return Icons.blinds;
        default:
          return Icons.devices;
      }
    }

    // LOGICA INTELLIGENTE BASATA SUGLI ATTRIBUTI
    final attributes = state['attributes'] ?? {};
    final String deviceClass = (attributes['device_class'] ?? '').toString();
    final String friendlyName = (attributes['friendly_name'] ?? '')
        .toString()
        .toLowerCase();

    switch (type) {
      case 'light':
        return Icons.lightbulb;

      case 'switch':
        // Se è una presa smart (outlet) usa un'icona diversa
        if (deviceClass == 'outlet') return Icons.outlet;
        return Icons.power_settings_new;

      case 'media_player':
        // 1. È UNA TV?
        if (deviceClass == 'tv' ||
            friendlyName.contains('tv') ||
            friendlyName.contains('television')) {
          return Icons.tv;
        }
        // 2. È UN NEST HUB / SMART DISPLAY?
        if (friendlyName.contains('hub') ||
            friendlyName.contains('display') ||
            friendlyName.contains('show') ||
            friendlyName.contains('monitor')) {
          return Icons.smart_display_sharp;
        }
        // 3. È UN RICEVITORE / AMPLI?
        if (deviceClass == 'receiver') {
          return Icons.settings_input_hdmi;
        }
        // 4. ALTRIMENTI È UNO SPEAKER
        return Icons.speaker;

      case 'sensor':
        if (deviceClass == 'temperature') return Icons.thermostat;
        if (deviceClass == 'humidity') return Icons.water_drop;
        if (deviceClass == 'battery') return Icons.battery_std;
        if (deviceClass == 'power') return Icons.flash_on;
        return Icons.insights; // Icona generica sensori cool

      case 'climate':
        return Icons.thermostat;

      case 'camera':
        return Icons.videocam;

      case 'lock':
        final s = state['state'];
        return (s == 'locked') ? Icons.lock : Icons.lock_open;

      case 'cover':
        final s = state['state'];
        return (s == 'open') ? Icons.blinds : Icons.blinds_closed;

      default:
        return Icons.device_unknown;
    }
  }

  // 2. Logica per scegliere il COLORE
  static Color getColor(
    String type,
    Map<String, dynamic>? state, {
    bool isEditMode = false,
  }) {
    if (isEditMode) return Colors.white; // In edit mode sempre bianco

    final bool isOn =
        state?['state'] == 'on' ||
        state?['state'] == 'open' ||
        state?['state'] == 'unlocked';

    // Se è spento/chiuso, restituiamo un grigio o bianco spento
    if (!isOn && type != 'sensor') {
      // I sensori sono sempre "attivi"
      return Colors.white54;
    }

    // Gestione specifica per le LUCI RGB
    if (type == 'light' && state != null) {
      if (state['attributes'] != null &&
          state['attributes']['rgb_color'] != null) {
        final List<dynamic> rgb = state['attributes']['rgb_color'];
        if (rgb.length == 3) {
          return Color.fromRGBO(rgb[0], rgb[1], rgb[2], 1.0);
        }
      }
      return Colors.yellowAccent; // Luce standard accesa
    }

    // Colori per altri tipi
    switch (type) {
      case 'switch':
        return AppTheme.primary; // Ciano
      case 'cover':
        return Colors.purpleAccent;
      case 'lock':
        return Colors.redAccent;
      case 'climate':
        return Colors.orangeAccent;
      case 'sensor':
        return Colors.blueAccent;
      case 'camera':
        return state?['state'] == 'recording' ? Colors.green : Colors.blueGrey;
      default:
        return AppTheme.primary;
    }
  }

  // 3. Helper per capire se è "Attivo" (per switch, toggle e cam)
  static bool isActive(Map<String, dynamic>? entityState) {
    if (entityState == null) return false;
    final state = entityState['state']?.toString().toLowerCase();

    // Lista di stati che consideriamo "ACCESI"
    const onStates = [
      'on',
      'open',
      'unlocked',
      'home',
      'occupied',
      'playing',
      'paused',
      'buffering',
    ];

    // PER LE TELECAMERE:
    // 'idle' = Accesa ma in attesa
    // 'recording' = Sta registrando
    // 'streaming' = Sta trasmettendo
    if (state == 'idle' || state == 'recording' || state == 'streaming') {
      return true;
    }

    return onStates.contains(state);
  }
}
