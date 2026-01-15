import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

class HaService {
  WebSocketChannel? _channel;
  
  // Stream controller per diffondere gli stati aggiornati
  final _stateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stateStream => _stateController.stream;

  // Cache locale degli stati per accesso immediato
  Map<String, dynamic> currentStates = {};

  // Variabili di configurazione
  String? _token;
  String? _baseUrl;

  /// 1. Connessione: Riceve URL WebSocket e Token
  void connect(String wsUrl, String token, String baseUrl) {
    if (_channel != null) return;

    _token = token;
    _baseUrl = baseUrl;
    print('🔌 HaService: Tentativo connessione WS a $wsUrl');
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel!.stream.listen(
        (message) => _onMessageReceived(message),
        onError: (e) => print('❌ Errore WS: $e'),
        onDone: () => print('⚠️ WS Disconnesso'),
      );
    } catch (e) {
      print('❌ Errore critico connessione WS: $e');
    }
  }

  void dispose() {
    _channel?.sink.close();
    _stateController.close();
  }

  // 2. Gestione Messaggi 
  void _onMessageReceived(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];

      if (type == 'auth_required') {
        _send({'type': 'auth', 'access_token': _token});
      } else if (type == 'auth_ok') {
        print('✅ Autenticato! Sottoscrizione eventi...');
        _subscribeToEvents();
        _getInitialStates();
      } else if (type == 'event' && data['event']['event_type'] == 'state_changed') {
        final eventData = data['event']['data'];
        final entityId = eventData['entity_id'];
        final newState = eventData['new_state'];
        
        if (newState != null) {
          currentStates[entityId] = newState;
          _stateController.add(currentStates);
        }
      } else if (type == 'result' && data['result'] != null && data['result'] is List) {
        for (var item in data['result']) {
          currentStates[item['entity_id']] = item;
        }
        _stateController.add(currentStates);
      }
    } catch (e) {
      print('Errore parsing messaggio WS: $e');
    }
  }

  void _subscribeToEvents() {
    _send({'id': 1, 'type': 'subscribe_events', 'event_type': 'state_changed'});
  }

  void _getInitialStates() {
    _send({'id': 2, 'type': 'get_states'});
  }

  void _send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (e) {
      print("Errore invio dati WS: $e");
    }
  }

  // 3. Comandi HTTP (Usano l'URL dinamico iniettato)
  Future<void> toggleEntity(String entityId) async {
    if (_baseUrl == null || _token == null) return;
    final url = Uri.parse('$_baseUrl/api/services/homeassistant/toggle');
    await _postRequest(url, {'entity_id': entityId});
  }

  Future<void> setLightState(String entityId, {int? brightness, List<double>? rgbColor}) async {
    if (_baseUrl == null) return;
    final url = Uri.parse('$_baseUrl/api/services/light/turn_on');
    final Map<String, dynamic> body = {'entity_id': entityId};
    if (brightness != null) body['brightness'] = brightness;
    if (rgbColor != null) body['rgb_color'] = rgbColor;
    await _postRequest(url, body);
  }

  Future<void> callService(String domain, String service, Map<String, dynamic> data) async {
    if (_baseUrl == null) return;
    final url = Uri.parse('$_baseUrl/api/services/$domain/$service');
    await _postRequest(url, data);
  }

  Future<void> _postRequest(Uri url, Map<String, dynamic> body) async {
    try {
      await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    } catch (e) {
      print('❌ Errore comando HTTP: $e');
    }
  }
}