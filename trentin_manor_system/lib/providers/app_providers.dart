import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';
import '../services/connection_manager.dart';
import '../services/ha_service.dart';
import '../services/backend_service.dart';
import '../models/app_models.dart';

// --- 1. CONNECTION MANAGER & HA SERVICE ---
final connectionManagerProvider =
    StateNotifierProvider<ConnectionManager, String>((ref) {
      return ConnectionManager();
    });

final appStartupProvider = FutureProvider<void>((ref) async {
  final initTask = ref.read(connectionManagerProvider.notifier).init();
  final minWaitTask = Future.delayed(const Duration(seconds: 2));

  await Future.wait([
    initTask,
    minWaitTask,
  ]);
});

final haServiceProvider = Provider<HaService>((ref) {
  final activeUrl = ref.watch(connectionManagerProvider);
  final manager = ref.read(connectionManagerProvider.notifier);
  final service = HaService();
  if (activeUrl.isNotEmpty) {
    service.connect(manager.webSocketUrl, AppConfig.haToken, activeUrl);
  }
  ref.onDispose(() => service.dispose());
  return service;
});

final entityMapProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final haService = ref.watch(haServiceProvider);
  return haService.stateStream;
});

// --- 2. GESTORE STANZE (StateNotifier) ---

class RoomsNotifier extends StateNotifier<AsyncValue<List<RoomConfig>>> {
  RoomsNotifier() : super(const AsyncValue.loading()) {
    _fetchInitialData();
  }

  // ID del dispositivo che l'utente sta trascinando
  int? _draggingDeviceId;

  // Timer per evitare il "Boomerang" del socket dopo il rilascio
  DateTime? _lastDragEndTime;

  Future<void> _fetchInitialData() async {
    try {
      final rooms = await BackendService().getRooms();
      state = AsyncValue.data(rooms);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _fetchInitialData();
  }

  // 1. Inizio Trascinamento
  void startDragging(int deviceId) {
    _draggingDeviceId = deviceId;
  }

  // 2. Fine Trascinamento
  void stopDragging() {
    _draggingDeviceId = null;
    // Segniamo l'ora in cui abbiamo finito.
    // Per i prossimi 1000ms ignoreremo aggiornamenti socket per questo device.
    _lastDragEndTime = DateTime.now();
  }

  // 3. Aggiornamento Posizione (Immutabile + Protetto)
  void updateDevicePosition(
    int deviceId,
    double x,
    double y, {
    bool isRemote = false,
  }) {
    // PROTEZIONE SOCKET:
    // Se è un aggiornamento REMOTO (dal server):
    if (isRemote) {
      // A. Se lo stiamo trascinando ORA, ignoriamo.
      if (deviceId == _draggingDeviceId) return;

      // B. Se lo abbiamo rilasciato da meno di 1 secondo (Cooldown), ignoriamo.
      // Questo previene che il vecchio pacchetto del server ci riporti indietro.
      if (_lastDragEndTime != null) {
        final diff = DateTime.now().difference(_lastDragEndTime!);
        if (diff.inMilliseconds < 1000) {
          // È passato troppo poco tempo dal rilascio, ignoriamo il server per ora.
          return;
        }
      }
    }

    // AGGIORNAMENTO IMMUTABILE (Fix per "Non si muove"):
    state.whenData((rooms) {
      // Creiamo una NUOVA lista di stanze
      final newRooms = rooms.map((room) {
        // Controlliamo se il dispositivo è in questa stanza
        final hasDevice = room.devices.any((d) => d.id == deviceId);

        if (hasDevice) {
          // Se c'è, creiamo una NUOVA stanza (copia)
          return room.copyWith(
            devices: room.devices.map((device) {
              if (device.id == deviceId) {
                // E creiamo un NUOVO dispositivo (copia) con le nuove coordinate
                return device.copyWith(x: x, y: y);
              }
              return device;
            }).toList(),
          );
        }
        return room; // Se non c'è, ritorniamo la stanza invariata
      }).toList();

      // Emettiamo il nuovo stato. Essendo oggetti nuovi, Riverpod aggiornerà la UI.
      state = AsyncValue.data(newRooms);
    });
  }
}

// Il Provider che espone il Notifier
final roomsProvider =
    StateNotifierProvider<RoomsNotifier, AsyncValue<List<RoomConfig>>>((ref) {
      return RoomsNotifier();
    });

// --- 3. SERVIZIO SOCKET.IO (Il Postino) ---
// Questo servizio si connette e "telecomanda" il RoomsNotifier quando arrivano messaggi

final socketServiceProvider = Provider<IO.Socket>((ref) {
  // Prendiamo il notifier per potergli inviare comandi
  final roomsNotifier = ref.read(roomsProvider.notifier);

  print("🔌 SocketService: Inizializzazione verso ${AppConfig.backendUrl}");

  // Configurazione Socket.io Client
  final uri = Uri.parse(AppConfig.backendUrl);
  final cleanUrl = "${uri.scheme}://${uri.host}:${uri.port}";

  IO.Socket socket = IO.io(
    cleanUrl,
    IO.OptionBuilder()
        .setTransports(['websocket']) // Forza websocket per performance
        .enableAutoConnect()
        .build(),
  );

  socket.onConnect((_) {
    print('✅ Socket.io Connesso!');
  });

  socket.onDisconnect((_) => print('❌ Socket.io Disconnesso'));

  // --- ASCOLTO EVENTI DAL SERVER ---

  // A. Qualcuno ha spostato un dispositivo
  socket.on('device_moved', (data) {
    if (data != null) {
      // data = { id: 123, x: 0.5, y: 0.8 }
      final int id = data['id'];
      final double x = (data['x'] as num).toDouble();
      final double y = (data['y'] as num).toDouble();

      print("📡 Socket: updateDevicePosition $id -> $x, $y");
      roomsNotifier.updateDevicePosition(id, x, y, isRemote: true);
    }
  });

  // B. Nuova stanza o dispositivo creato/eliminato
  socket.on('room_created', (_) => roomsNotifier.refresh());
  socket.on('room_deleted', (_) => roomsNotifier.refresh());
  socket.on('device_added', (_) => roomsNotifier.refresh());
  socket.on('device_deleted', (_) => roomsNotifier.refresh());

  // Pulizia alla chiusura dell'app
  ref.onDispose(() {
    socket.dispose();
  });

  return socket;
});
