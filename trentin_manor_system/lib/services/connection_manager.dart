import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ConnectionManager extends StateNotifier<String> {
  
  ConnectionManager() : super(''); 

  bool get isInternal => state == AppConfig.haUrlInternal;

  /// Inizializza la connessione
  Future<void> init() async {
    print('🔄 ConnectionManager: Controllo connettività...');
    
    final bool localWorks = await _checkUrl(AppConfig.haUrlInternal, timeoutSec: 2);

    if (localWorks) {
      state = AppConfig.haUrlInternal;
      print('✅ Connesso via LAN LOCALE: $state');
      return;
    }

    // 2. Proviamo l'Esterno
    print('⚠️ Locale non raggiungibile, provo Esterno...');
    final bool remoteWorks = await _checkUrl(AppConfig.haUrlExternal, timeoutSec: 5);

    if (remoteWorks) {
      state = AppConfig.haUrlExternal;
      print('✅ Connesso via CLOUD/NAS: $state');
    } else {
      print('❌ OFFLINE: Nessuna connessione riuscita.');
      state = ''; // Restiamo offline
    }
  }

  /// Helper per fare un ping leggero
  Future<bool> _checkUrl(String baseUrl, {required int timeoutSec}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${AppConfig.haToken}',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: timeoutSec));

      return response.statusCode == 200;
    } catch (e) {
      return false; 
    }
  }
  
  // Helper WebSocket
  String get webSocketUrl {
    if (state.isEmpty) return '';
    if (state.startsWith('https')) {
      return '${state.replaceAll('https://', 'wss://')}/api/websocket';
    } else {
      return '${state.replaceAll('http://', 'ws://')}/api/websocket';
    }
  }
}