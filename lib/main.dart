import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
//import 'package:flutter_application_1/manager_screens/manager_home.dart';
import 'package:worknest/splash.dart';
//import 'package:flutter_application_1/login.dart';

void main() async {
  // 1. This line ensures all Flutter widgets are loaded before starting Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // 2. This line "turns on" the connection to your specific Firebase project
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'OpenSans'),
      home: const SplashScreen(),
      //home: const LoginPage(),
    );
  }
}
