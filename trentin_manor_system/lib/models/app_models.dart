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

  DeviceConfig({
    required this.id,
    required this.haEntityId,
    required this.friendlyName,
    required this.type,
    this.x = 0.5,
    this.y = 0.5,
  });

  factory DeviceConfig.fromJson(Map<String, dynamic> json) {
    return DeviceConfig(
      id: json['id'],
      haEntityId: json['ha_entity_id'],
      friendlyName: json['friendly_name'] ?? 'Dispositivo',
      type: json['device_type'] ?? 'switch',
      x: (json['position_x'] as num?)?.toDouble() ?? 0.5,
      y: (json['position_y'] as num?)?.toDouble() ?? 0.5,
    );
  }

  DeviceConfig copyWith({double? x, double? y}) {
    return DeviceConfig(
      id: id,
      haEntityId: haEntityId,
      friendlyName: friendlyName,
      type: type,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }
}
