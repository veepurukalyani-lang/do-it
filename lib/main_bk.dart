import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/main_navigation.dart';
import 'widgets/rainbow_border.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<bool>? _fbInit;

  @override
  void initState() {
    super.initState();
    _fbInit = _initializeFirebase();
  }

  Future<bool> _initializeFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      appState.initialize();
      return true;
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _fbInit,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Color(0xFF0B0B14),
              body: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
                ),
              ),
            ),
          );
        }

        final bool firebaseInitialized = snapshot.data ?? false;

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
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _fbInit = _initializeFirebase();
                        });
                      }, 
                      child: const Text('Retry')
                    ),
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
              primarySwatch: Colors.deepPurple,
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
      },
    );
  }
}
