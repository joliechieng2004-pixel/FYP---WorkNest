import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        margin: EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.red[100]),
        child: Column(
          children: [
            ClipOval(
              child: Image.asset(
                "assets/images/logo.png",
                height: 200,
                width: 200, fit: BoxFit.cover),
            ),
            Text("Login Page", style: TextStyle(fontSize: 20, fontFamily: "Roboto-Bold", color: Color.fromARGB(255, 40, 75, 158)),),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio(value: "Manager"), Radio(value: "Worker"),
              ],
            ),
            Column(
              children: [
                Text("Department Code:"),
                TextField(),
              ],
            ),
            Column(
              children: [
                Text("Email:"),
                TextField(),
              ],
            ),
            Column(
              children: [
                Text("Password:"),
                TextField( obscureText: true),
              ]
            ),
            ElevatedButton(onPressed: Login, child: Text("Login")),
            TextButton(onPressed: Register, child: Text("Register New Account"))
          ]
        )
      )
    );
  }

  void Login() {
    print("Logging In...");
  }

  void Register() {
    print("Redirecting to Register Page...");
  }
}