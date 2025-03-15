import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

// Import your screens
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'firebase/auth_service.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase first
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDKsu1auXSwrzXOPzqmgdiOVSbRCoqH0ws',
        appId: '1:716193298227:android:1e50b2768155708ecc3046',
        messagingSenderId: '716193298227',
        projectId: 'pu-circle-cddb9',
        storageBucket: 'pu-circle-cddb9.firebasestorage.app'
      ),
    );

    print("DEBUG: Firebase core initialized");

    // Initialize App Check with more specific error handling
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
      print("DEBUG: App Check activated successfully");
    } catch (appCheckError) {
      print("DEBUG: App Check activation error: $appCheckError");
      // Continue anyway as this might be an emulator issue
    }

  } catch (e) {
    print('Firebase initialization error: $e');
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().authStateChanges,
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'PU Circle',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const AuthenticationWrapper(),
      ),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User?>();

    if (firebaseUser != null) {
      // User is signed in
      return const HomeScreen();
    }
    // User is not signed in
    return const LoginScreen();
  }
}