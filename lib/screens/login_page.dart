import 'package:flutter/material.dart';
import '../services/AuthService.dart';
import 'home_page.dart';
import 'register_page.dart';

class Login extends StatefulWidget {
  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  String email = '';
  String password = '';
  final _formKey = GlobalKey<FormState>();
  final AuthService _auth = AuthService();
  String error = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[50],
      appBar: AppBar(
        title: Text('Fruit app and LLM'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Register()),
              );
            },
            icon: Icon(Icons.person, color: Colors.cyan),
            label: Text('Register', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
      body: SingleChildScrollView(  // Make the whole body scrollable to prevent overflow
        padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 50.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 100.0, // Width of the image container
                height: 100.0, // Height of the image container
                decoration: BoxDecoration(
                  shape: BoxShape.circle, // Make it round
                  image: DecorationImage(
                    image: AssetImage('assets/images/logo.jpg'),
                    fit: BoxFit.cover, // This makes sure the image covers the container
                  ),
                ),
              ),
              SizedBox(height: 50.0),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Email',
                  prefixIcon: Icon(Icons.person),
                  fillColor: Colors.white,
                  filled: true,
                ),
                onChanged: (val) {
                  setState(() {
                    email = val;
                  });
                },
                validator: (val) => val != null && val.isEmpty ? 'Enter a valid email' : null,
              ),
              SizedBox(height: 20),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  fillColor: Colors.white,
                  filled: true,
                ),
                onChanged: (val) {
                  setState(() {
                    password = val;
                  });
                },
                validator: (val) => val!.length < 6
                    ? 'Enter a valid password 6+ Chars'
                    : null,
                obscureText: true,
              ),
              SizedBox(height: 40),
              ElevatedButton(
                child: Text(
                  'Sign In',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                onPressed: () async {
                  if (_formKey.currentState != null && _formKey.currentState!.validate()) {
                    dynamic result = await _auth.signInWithEmailAndPassword(email, password);
                    if (result == null) {
                      setState(() {
                        error = 'Error SignIn!!!';
                      });
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const HomePage()),//HomePage()
                      );
                    }
                  }
                },
              ),
              SizedBox(height: 12.0),
              Text(
                error,
                style: TextStyle(color: Colors.red, fontSize: 14.0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
