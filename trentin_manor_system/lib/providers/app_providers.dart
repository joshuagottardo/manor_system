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

  // Variabili Drag Map (Tablet)
  int? _draggingDeviceId;
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

  // --- LOGICA AGGIUNTA DISPOSITIVO ---
  void addDeviceLocally(Map<String, dynamic> deviceJson) {
    state.whenData((rooms) {
      final int targetRoomId = deviceJson['room_id'];
      final newDevice = DeviceConfig.fromJson(deviceJson);

      final newRooms = rooms.map((room) {
        if (room.id == targetRoomId) {
          return room.copyWith(
            devices: [...room.devices, newDevice],
          );
        }
        return room;
      }).toList();

      state = AsyncValue.data(newRooms);
    });
  }
  
  // --- LOGICA RIMOZIONE DISPOSITIVO ---
  void removeDeviceLocally(int deviceId) {
    state.whenData((rooms) {
      final newRooms = rooms.map((room) {
        final newDevices = room.devices.where((d) => d.id != deviceId).toList();
        if (newDevices.length != room.devices.length) {
          return room.copyWith(devices: newDevices);
        }
        return room;
      }).toList();

      state = AsyncValue.data(newRooms);
    });
  }

  // --- UPDATE PROPRIETÀ (Dimensione e Posizione Griglia) ---
  // Ora gestiamo GridW, GridH, GridX, GridY
  void updateDeviceProperties(int deviceId, {int? gridW, int? gridH, int? gridX, int? gridY}) {
    state.whenData((rooms) {
      final newRooms = rooms.map((room) {
        // Ottimizzazione: se il device non è qui, salta
        if (!room.devices.any((d) => d.id == deviceId)) return room;

        return room.copyWith(
          devices: room.devices.map((device) {
            if (device.id == deviceId) {
              return device.copyWith(
                gridW: gridW, 
                gridH: gridH,
                gridX: gridX,
                gridY: gridY,
              );
            }
            return device;
          }).toList(),
        );
      }).toList();

      state = AsyncValue.data(newRooms);
    });
  }

  // --- LOGICA MAPPA VISUALE (Coordinate Float X/Y) ---
  void startDragging(int deviceId) {
    _draggingDeviceId = deviceId;
  }

  void stopDragging() {
    _draggingDeviceId = null;
    _lastDragEndTime = DateTime.now();
  }

  void updateDevicePosition(int deviceId, double x, double y, {bool isRemote = false}) {
    if (isRemote) {
      if (deviceId == _draggingDeviceId) return;
      if (_lastDragEndTime != null) {
        final diff = DateTime.now().difference(_lastDragEndTime!);
        if (diff.inMilliseconds < 1000) return;
      }
    }

    state.whenData((rooms) {
      final newRooms = rooms.map((room) {
        if (!room.devices.any((d) => d.id == deviceId)) return room;
        
        return room.copyWith(
          devices: room.devices.map((device) {
            if (device.id == deviceId) {
              return device.copyWith(x: x, y: y);
            }
            return device;
          }).toList(),
        );
      }).toList();
      state = AsyncValue.data(newRooms);
    });
  }
}

final roomsProvider =
    StateNotifierProvider<RoomsNotifier, AsyncValue<List<RoomConfig>>>((ref) {
      return RoomsNotifier();
    });

// --- 3. SERVIZIO SOCKET.IO ---

final socketServiceProvider = Provider<IO.Socket>((ref) {
  final roomsNotifier = ref.read(roomsProvider.notifier);

  print("🔌 SocketService: Inizializzazione verso ${AppConfig.backendUrl}");

  final uri = Uri.parse(AppConfig.backendUrl);
  final cleanUrl = "${uri.scheme}://${uri.host}:${uri.port}";

  IO.Socket socket = IO.io(
    cleanUrl,
    IO.OptionBuilder()
        .setTransports(['websocket']) 
        .enableAutoConnect()
        .build(),
  );

  socket.onConnect((_) {
    print('✅ Socket.io Connesso!');
  });

  socket.onDisconnect((_) => print('❌ Socket.io Disconnesso'));

  // --- ASCOLTO EVENTI DAL SERVER ---

  // A. Movimento Mappa Visuale (Float)
  socket.on('device_moved', (data) {
    if (data != null) {
      final int id = data['id'];
      final double x = (data['x'] as num).toDouble();
      final double y = (data['y'] as num).toDouble();
      roomsNotifier.updateDevicePosition(id, x, y, isRemote: true);
    }
  });

  // B. Gestione Struttura
  socket.on('room_created', (_) => roomsNotifier.refresh());
  socket.on('room_deleted', (_) => roomsNotifier.refresh());
  socket.on('device_added', (data) {
    if (data != null) roomsNotifier.addDeviceLocally(data);
  });
  socket.on('device_deleted', (data) {
    if (data != null && data['id'] != null) {
      roomsNotifier.removeDeviceLocally(data['id']);
    }
  });

  // C. UPDATE GRIGLIA (Resize & Spostamento X/Y)
  socket.on('device_updated', (data) {
    if (data != null) {
      final int id = data['id'];
      // Mapping dei campi dal DB (snake_case) al Dart (camelCase)
      final int? w = data['grid_w']; 
      final int? h = data['grid_h'];
      final int? x = data['grid_x']; // Nuovo campo
      final int? y = data['grid_y']; // Nuovo campo
      
      print("📡 Socket: Update Griglia ID $id -> Pos:($x,$y) Dim:(${w}x$h)");
      
      roomsNotifier.updateDeviceProperties(
        id, 
        gridW: w, gridH: h, 
        gridX: x, gridY: y
      );
    }
  });
  
  // NOTA: 'devices_reordered' è stato rimosso perché non usiamo più gli indici.

  ref.onDispose(() {
    socket.dispose();
  });

  return socket;
});