import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';
import '../config/app_theme.dart';
import '../utils/icon_helper.dart';

class AddDeviceModal extends ConsumerStatefulWidget {
  final int roomId;
  final List<DeviceConfig> existingDevices; 
  final Function(DeviceConfig) onDeviceAdded;

  const AddDeviceModal({
    super.key,
    required this.roomId,
    required this.existingDevices,
    required this.onDeviceAdded,
  });

  @override
  ConsumerState<AddDeviceModal> createState() => _AddDeviceModalState();
}

class _AddDeviceModalState extends ConsumerState<AddDeviceModal> {
  bool isSaving = false;

  @override
  Widget build(BuildContext context) {
    // 1. ASCOLTIAMO
    final haStateAsync = ref.watch(entityMapProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppTheme.surface, 
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 50, spreadRadius: 5)
        ],
      ),
      child: Column(
        children: [
          // --- HEADER (Glass style) ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "AGGIUNGI DISPOSITIVO",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // --- LISTA DISPOSITIVI ---
          Expanded(
            child: haStateAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              error: (err, stack) => Center(child: Text("Errore: $err", style: const TextStyle(color: Colors.red))),
              data: (allStates) {
                // 2. FILTRAGGIO LOGICO
                
                final availableEntities = _filterEntities(allStates);

                if (availableEntities.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 60, color: Colors.white24),
                        const SizedBox(height: 20),
                        Text(
                          "Nessun nuovo dispositivo trovato su HA",
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: availableEntities.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = availableEntities[index];
                    return _buildDeviceItem(item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Logica di Filtraggio
  List<Map<String, dynamic>> _filterEntities(Map<String, dynamic> allStates) {
    // Set degli ID già presenti NELLA STANZA CORRENTE
    final existingIds = widget.existingDevices.map((d) => d.haEntityId).toSet();
    
    final List<Map<String, dynamic>> filtered = [];

    allStates.forEach((entityId, data) {
      // a. Escludiamo entità di sistema inutili
      bool isSystemEntity =
          entityId.startsWith('zone.') ||
          entityId.startsWith('person.') ||
          entityId.startsWith('sun.') ||
          entityId.startsWith('weather.') ||
          entityId.startsWith('device_tracker.') || // Spesso ridondante
          entityId.startsWith('update.') ||
          entityId.startsWith('automation.') ||
          entityId.startsWith('script.') ||
          entityId.startsWith('scene.'); 

      // b. Escludiamo quelli già presenti nella stanza
      bool alreadyAdded = existingIds.contains(entityId);

      if (!isSystemEntity && !alreadyAdded) {
        // Aggiungiamo l'ID all'oggetto per comodità
        final cleanData = Map<String, dynamic>.from(data);
        cleanData['entity_id'] = entityId; 
        filtered.add(cleanData);
      }
    });

    // Ordiniamo alfabeticamente per nome
    filtered.sort((a, b) {
      String nameA = a['attributes']['friendly_name'] ?? a['entity_id'];
      String nameB = b['attributes']['friendly_name'] ?? b['entity_id'];
      return nameA.toLowerCase().compareTo(nameB.toLowerCase());
    });

    return filtered;
  }

  Widget _buildDeviceItem(Map<String, dynamic> item) {
    final entityId = item['entity_id'];
    final friendlyName = item['attributes']['friendly_name'] ?? entityId;
    final domain = entityId.split('.').first; // light, switch, sensor...

    // Icona e Colore presi dall'helper
    final IconData icon = IconHelper.getIcon(domain, item);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white70),
        ),
        title: Text(
          friendlyName,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        subtitle: Text(
          entityId,
          style: const TextStyle(color: Colors.white30, fontSize: 12),
        ),
        trailing: isSaving 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : ElevatedButton(
              onPressed: () => _importDevice(entityId, friendlyName, domain),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(12),
              ),
              child: const Icon(Icons.add, size: 20),
            ),
      ),
    );
  }

  Future<void> _importDevice(String entityId, String friendlyName, String type) async {
    setState(() => isSaving = true);
    try {
      // Chiamata al backend per salvare nel DB
      final newDevice = await BackendService().addDevice(
        widget.roomId,
        entityId,
        friendlyName,
        type,
      );

      // Notifica e Chiudi
      widget.onDeviceAdded(newDevice);
      if (mounted) Navigator.pop(context);
      
    } catch (e) {
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore: $e"), backgroundColor: Colors.red),
      );
    }
  }
}