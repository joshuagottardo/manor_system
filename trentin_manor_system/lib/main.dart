import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/app_theme.dart';
import 'providers/app_providers.dart';
import 'screens/tablet_layout.dart';
import 'screens/phone_layout.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const ProviderScope(child: MyDomoticaApp()));
}

class DashboardSelector extends ConsumerWidget {
  const DashboardSelector({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          return const TabletLayout();
        } else {
          return const PhoneLayout(); 
        }
      },
    );
  }
}

class MyDomoticaApp extends ConsumerWidget {
  const MyDomoticaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Inizializza Connessione HA
    final startupStatus = ref.watch(appStartupProvider);
    
    // 2. Inizializza Socket
    ref.watch(socketServiceProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Domotica Future',
      theme: AppTheme.darkTheme,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 2000),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,

          // TRANSIZIONE PERSONALIZZATA
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },

          child: startupStatus.when(            
            data: (_) => const DashboardSelector(key: ValueKey('dashboard')),
            loading: () => const SplashScreen(key: ValueKey('splash')),
            
            error: (err, stack) => Center(
              key: const ValueKey('error'),
              child: Text("Errore Critico: $err", style: const TextStyle(color: Colors.red)),
            ),
          ),
        ),
      ),
    );
  }
}