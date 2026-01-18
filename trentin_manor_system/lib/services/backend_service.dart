import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_models.dart';
import '../config/app_config.dart';

class BackendService {
  
  // Helper privato per ottenere l'URL
  String get _baseUrl => AppConfig.backendUrl;

  // 1. Scarica tutte le stanze e i dispositivi
  Future<List<RoomConfig>> getRooms() async {
    final url = Uri.parse('$_baseUrl/rooms');

    try {
      // print('📥 Backend: Scarico configurazione da $url');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => RoomConfig.fromJson(json)).toList();
      } else {
        throw Exception('Errore server: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Errore Backend getRooms: $e');
      rethrow;
    }
  }

  // 2. Salva la posizione MAPPA VISUALE (Tablet - Float X/Y)
  Future<void> updateDevicePosition(int deviceId, double x, double y) async {
    final url = Uri.parse('$_baseUrl/devices/$deviceId/position');

    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'x': x, 'y': y}),
      );
    } catch (e) {
      print('❌ Errore Backend updateDevicePosition: $e');
    }
  }

  // 3. Aggiungi dispositivo
  Future<DeviceConfig> addDevice(int roomId, String entityId, String friendlyName, String type) async {
    final url = Uri.parse('$_baseUrl/devices');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'room_id': roomId,
          'ha_entity_id': entityId,
          'friendly_name': friendlyName,
          'device_type': type,
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return DeviceConfig.fromJson(json);
      } else {
        throw Exception('Errore salvataggio: ${response.body}');
      }
    } catch (e) {
      print('❌ Errore Backend addDevice: $e');
      rethrow;
    }
  }

  // 4. Elimina dispositivo
  Future<void> deleteDevice(int deviceId) async {
    final url = Uri.parse('$_baseUrl/devices/$deviceId');

    try {
      final response = await http.delete(url);
      if (response.statusCode != 200) {
        throw Exception('Errore server durante eliminazione');
      }
    } catch (e) {
      print('❌ Errore Backend deleteDevice: $e');
      rethrow;
    }
  }

  // 5. Crea Stanza
  Future<RoomConfig> createRoom(String name, String imageAsset) async {
    final url = Uri.parse('$_baseUrl/rooms');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'image_asset': imageAsset}),
      );

      if (response.statusCode == 200) {
        return RoomConfig.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Errore creazione stanza: ${response.body}');
      }
    } catch (e) {
      print('❌ Errore Backend createRoom: $e');
      rethrow;
    }
  }

  // 6. Elimina Stanza
  Future<void> deleteRoom(int roomId) async {
    final url = Uri.parse('$_baseUrl/rooms/$roomId');
    try {
      await http.delete(url);
    } catch (e) {
      print('❌ Errore Backend deleteRoom: $e');
      rethrow;
    }
  }

  // --- METODI PER IL CENTRO DI CONTROLLO (GRIGLIA) ---

  // 7. Aggiorna DIMENSIONE Griglia (Resize W/H)
  Future<void> updateDeviceGridSize(int deviceId, int w, int h) async {
    final url = Uri.parse('$_baseUrl/devices/$deviceId/resize');

    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'w': w, 'h': h}),
      );
    } catch (e) {
      print('❌ Errore Backend updateDeviceGridSize: $e');
      // Fire & Forget: non blocchiamo l'UI
    }
  }

  // 8. Aggiorna POSIZIONE Griglia (Spostamento X/Y Interi)
  Future<void> updateDeviceGridPosition(int deviceId, int x, int y) async {
    final url = Uri.parse('$_baseUrl/devices/$deviceId/grid_position');

    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'x': x, 'y': y}),
      );
    } catch (e) {
      print('❌ Errore Backend updateDeviceGridPosition: $e');
    }
  }
}