import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/main_navigation.dart';
import 'widgets/rainbow_border.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool firebaseInitialized = false;
  try {
    debugPrint('--- [main] Starting Firebase Initializtion... ---');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('--- [main] Firebase Initialized. Calling appState.initialize() ---');
    appState.initialize();
    firebaseInitialized = true;
  } catch (e) {
    debugPrint('--- [main] Firebase Initialization FAILED: $e ---');
  }

  runApp(MyApp(firebaseInitialized: firebaseInitialized));
}

class MyApp extends StatelessWidget {
  final bool firebaseInitialized;
  const MyApp({super.key, required this.firebaseInitialized});

  @override
  Widget build(BuildContext context) {
    if (!firebaseInitialized) {
      return MaterialApp(
        title: 'Ai Art - Error',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.red),
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text('Failed to connect to Firebase.', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 8),
                const Text('Please check your internet connection or browser settings.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 24),
                const Text('Refresh the page to retry.', style: TextStyle(color: Colors.deepPurpleAccent)),
              ],
            ),
          ),
        ),
      );
    }

    return ChangeNotifierProvider.value(
      value: appState,
      child: MaterialApp(
        title: 'Ai Art',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          primaryColor: Colors.deepPurple,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
          ),
        ),
        home: const RainbowBorderContainer(child: MainNavigation()),
      ),
    );
  }
}
