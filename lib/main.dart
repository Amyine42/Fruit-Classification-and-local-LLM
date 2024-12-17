import 'package:elayoubi_app/screens/llm_chat_page.dart';

import 'screens/home_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/register_page.dart';
import 'screens/fruit_model_page.dart';
import 'package:flutter/material.dart';

import 'screens/login_page.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter ElayoubiApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      routes: {
        '/login': (context) =>  Login(),
        '/register': (context) =>  Register(),
        '/home': (context) => const HomePage(), //const HomePage()
        '/fruit-model': (context) => const FruitModelPage(),
        '/chat': (context) => const ChatPage(),  // Add this line
       // '/modeltest': (context) => const HomePage(), // Your test page
      },
      initialRoute: '/login',
    );
  }
}