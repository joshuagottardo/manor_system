import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class MjpegViewer extends StatefulWidget {
  final String streamUrl;
  final Map<String, String>? headers;
  final Widget Function(BuildContext)? loadingBuilder;
  final Widget Function(BuildContext, dynamic, StackTrace?)? errorBuilder;
  final bool isLive;

  const MjpegViewer({
    super.key,
    required this.streamUrl,
    this.headers,
    this.loadingBuilder,
    this.errorBuilder,
    this.isLive = true,
  });

  @override
  State<MjpegViewer> createState() => _MjpegViewerState();
}

class _MjpegViewerState extends State<MjpegViewer> {
  HttpClient? _httpClient;
  StreamSubscription? _subscription;
  ImageProvider? _currentImage;
  final List<int> _buffer = [];

  @override
  void initState() {
    super.initState();
    if (widget.isLive) _startStream();
  }

  @override
  void didUpdateWidget(MjpegViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive != oldWidget.isLive || widget.streamUrl != oldWidget.streamUrl) {
      _stopStream();
      if (widget.isLive) _startStream();
    }
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  void _stopStream() {
    _subscription?.cancel();
    _httpClient?.close(force: true);
    _buffer.clear();
  }

  Future<void> _startStream() async {
    try {
      _httpClient = HttpClient();
      // Ignora certificati SSL non validi (spesso accade con IP locali)
      _httpClient!.badCertificateCallback = (cert, host, port) => true;

      final request = await _httpClient!.getUrl(Uri.parse(widget.streamUrl));
      
      if (widget.headers != null) {
        widget.headers!.forEach((key, value) {
          request.headers.add(key, value);
        });
      }

      final response = await request.close();

      _subscription = response.listen(
        (List<int> chunk) {
          _buffer.addAll(chunk);
          _processBuffer();
        },
        onError: (error) {
          print("Stream Error: $error");
        },
        cancelOnError: true,
      );
    } catch (e) {
      print("Connection Error: $e");
    }
  }

  void _processBuffer() {
    // Cerchiamo i magic numbers del JPEG: 
    // Inizio: 0xFF, 0xD8
    // Fine: 0xFF, 0xD9
    
    // Semplificazione robusta: cerchiamo l'header e il footer
    while (true) {
      final start = _findPattern(_buffer, [0xFF, 0xD8]);
      if (start == -1) break; // Nessun inizio immagine trovato

      final end = _findPattern(_buffer, [0xFF, 0xD9], startIndex: start);
      if (end == -1) break; // Immagine non ancora completa

      // Abbiamo un'immagine completa!
      final jpgBytes = Uint8List.fromList(_buffer.sublist(start, end + 2));
      
      // Aggiorniamo la UI
      if (mounted) {
        setState(() {
          _currentImage = MemoryImage(jpgBytes);
        });
        
        // Puliamo il buffer fino alla fine di questa immagine
        // Rimuoviamo i dati processati per risparmiare memoria
        _buffer.removeRange(0, end + 2);
      } else {
        break;
      }
    }
    
    // Evitiamo overflow di memoria se il buffer diventa enorme senza trovare immagini
    if (_buffer.length > 5 * 1024 * 1024) { // 5MB limit
      _buffer.clear();
    }
  }

  int _findPattern(List<int> data, List<int> pattern, {int startIndex = 0}) {
    for (int i = startIndex; i < data.length - pattern.length + 1; i++) {
      bool match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    if (_currentImage == null) {
      return widget.loadingBuilder?.call(context) ?? 
             const Center(child: CircularProgressIndicator());
    }

    return Image(
      image: _currentImage!,
      fit: BoxFit.contain,
      gaplessPlayback: true, // Evita sfarfallio tra un frame e l'altro
      errorBuilder: widget.errorBuilder,
    );
  }
}