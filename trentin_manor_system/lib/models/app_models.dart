class RoomConfig {
  final int id;
  final String name;
  final String? imageUrl;
  final List<DeviceConfig> devices;

  RoomConfig({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.devices,
  });

  factory RoomConfig.fromJson(Map<String, dynamic> json) {
    var deviceList = json['devices'] as List?;
    List<DeviceConfig> devices = deviceList != null
        ? deviceList.map((i) => DeviceConfig.fromJson(i)).toList()
        : [];

    return RoomConfig(
      id: json['id'],
      name: json['name'],
      imageUrl: json['image_asset'],
      devices: devices,
    );
  }

  RoomConfig copyWith({
    int? id,
    String? name,
    String? imageUrl,
    List<DeviceConfig>? devices,
  }) {
    return RoomConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      devices: devices ?? this.devices,
    );
  }
}

class DeviceConfig {
  final int id;
  final String haEntityId;
  final String friendlyName;
  final String type;
  final double x;
  final double y;
  final int gridW;
  final int gridH;
  final int gridX;
  final int gridY;

  DeviceConfig({
    required this.id,
    required this.haEntityId,
    required this.friendlyName,
    required this.type,
    this.x = 0.5,
    this.y = 0.5,
    this.gridW = 1,
    this.gridH = 1,
    this.gridX = 0,
    this.gridY = 0,
  });

  factory DeviceConfig.fromJson(Map<String, dynamic> json) {
    return DeviceConfig(
      id: json['id'],
      haEntityId: json['ha_entity_id'],
      friendlyName: json['friendly_name'] ?? 'Dispositivo',
      type: json['device_type'] ?? 'switch',
      x: (json['position_x'] as num?)?.toDouble() ?? 0.5,
      y: (json['position_y'] as num?)?.toDouble() ?? 0.5,
      gridW: json['grid_w'] ?? 1,
      gridH: json['grid_h'] ?? 1,
      gridX: json['grid_x'] ?? 0,
      gridY: json['grid_y'] ?? 0,
    );
  }

  DeviceConfig copyWith({double? x, double? y, int? gridW, int? gridH,int? gridX, int? gridY,}) {
    return DeviceConfig(
      id: id,
      haEntityId: haEntityId,
      friendlyName: friendlyName,
      type: type,
      x: x ?? this.x,
      y: y ?? this.y,
      gridW: gridW ?? this.gridW,
      gridH: gridH ?? this.gridH,
      gridX: gridX ?? this.gridX,
      gridY: gridY ?? this.gridY,
    );
  }
}
