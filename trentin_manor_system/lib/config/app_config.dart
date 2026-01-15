import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // --- HOME ASSISTANT ---
  
  static String get haUrlInternal {
    return dotenv.env['HA_URL_INTERNAL'] ?? 'http://localhost:8123';
  }

  static String get haUrlExternal {
    return dotenv.env['HA_URL_EXTERNAL'] ?? '';
  }
  
  static String get haToken {
    final token = dotenv.env['HA_TOKEN'];
    if (token == null || token.isEmpty) {
      throw Exception('ERRORE: HA_TOKEN non trovato nel file .env!');
    }
    return token;
  }

  // --- BACKEND NODE.JS ---
  
  static String get backendUrl {
    return dotenv.env['BACKEND_URL'] ?? '';
  }
}