import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // This helps with sizing
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircleAvatar(
                    radius: 40, // Reduced from 50
                    backgroundImage: AssetImage('assets/images/photo_pro.jpeg'),
                  ),
                  SizedBox(height: 8), // Reduced from 10
                  Text(
                    'EL AYOUBI Amine',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20, // Reduced from 24
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.apple),
              title: const Text('Fruit Classifier'),
              onTap: () {
                Navigator.pushNamed(context, '/fruit-model');
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Chat with LLM'),
              onTap: () {
                Navigator.pushNamed(context, '/chat');
              },
            ),
          ],
        ),
      ),
      body: const Center(
        child: Text('Welcome to the Home Page'),
      ),
    );
  }
}