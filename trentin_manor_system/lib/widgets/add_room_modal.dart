import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/app_models.dart';
import '../services/backend_service.dart';

class AddRoomModal extends StatefulWidget {
  final Function(RoomConfig) onRoomCreated;

  const AddRoomModal({super.key, required this.onRoomCreated});

  @override
  State<AddRoomModal> createState() => _AddRoomModalState();
}

class _AddRoomModalState extends State<AddRoomModal> {
  final TextEditingController _nameController = TextEditingController();
  
  // Immagini disponibili (assicurati di averle negli assets!)
  final List<String> availableAssets = [
    'assets/images/dining_room_render.png', 
    'assets/images/veranda_render.png',
  ];

  String? selectedAsset;
  bool isLoading = false;

  Future<void> _save() async {
    if (_nameController.text.isEmpty || selectedAsset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Inserisci un nome e scegli un'immagine"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final newRoom = await BackendService().createRoom(
        _nameController.text,
        selectedAsset!,
      );
      
      widget.onRoomCreated(newRoom);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gestione tastiera per non coprire il bottone
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 50, spreadRadius: 5)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "NUOVA STANZA",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 30),

          // INPUT NOME
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              labelText: "NOME STANZA",
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.5),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primary)),
              prefixIcon: const Icon(Icons.meeting_room, color: Colors.white54),
            ),
          ),
          
          const SizedBox(height: 30),
          Text(
            "SCEGLI LO SFONDO",
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white54, letterSpacing: 1.5),
          ),
          const SizedBox(height: 15),

          // GRIGLIA IMMAGINI
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.5, // Rettangolari orizzontali
              ),
              itemCount: availableAssets.length,
              itemBuilder: (context, index) {
                final asset = availableAssets[index];
                final isSelected = selectedAsset == asset;

                return GestureDetector(
                  onTap: () => setState(() => selectedAsset = asset),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : Colors.white10,
                        width: isSelected ? 3 : 1,
                      ),
                      image: DecorationImage(
                        image: AssetImage(asset),
                        fit: BoxFit.cover,
                        // Oscura le non selezionate per far risaltare la scelta
                        colorFilter: isSelected 
                          ? null 
                          : const ColorFilter.mode(Colors.black54, BlendMode.darken),
                      ),
                      boxShadow: isSelected 
                        ? [BoxShadow(color: AppTheme.primary.withOpacity(0.4), blurRadius: 15)] 
                        : [],
                    ),
                    child: isSelected 
                      ? const Center(child: Icon(Icons.check_circle, color: AppTheme.primary, size: 30))
                      : null,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // TASTO SALVA
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text("CREA STANZA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}