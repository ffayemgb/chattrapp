import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'screens/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Essential for preventing that TypeError on Web
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ChattrApp());
}

class ChattrApp extends StatelessWidget {
  const ChattrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chattr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3E5DA), // Keeping your clean cream base
        textTheme: GoogleFonts.poppinsTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B271C),
          primary: const Color(0xFF3B271C),
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}