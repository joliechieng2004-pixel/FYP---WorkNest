import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    String _selectedRole = "employee";

    return Scaffold(
      body: Container(
        margin: EdgeInsets.only(left: 40, right: 40, top: 60, bottom: 10),
        child: Column(
          children: [
            SizedBox(height: 20),
            LoginLogo(),
            SizedBox(height: 20),
            Text("LOGIN PAGE", style: TextStyle(fontSize: 30, fontWeight:FontWeight.bold, fontFamily: "Roboto-Bold", color: Color.fromARGB(255, 40, 75, 158)),),
            SizedBox(height: 20),
            Column(
              children: [
                LoginRadioButton(_selectedRole),
                SizedBox(height: 10),
                LoginForm(),
              ],
            ),
            SizedBox(height: 30),
            LoginLoginButton(),
            LoginRegisterButton(),
          ]
        )
      )
    );
  }

  TextButton LoginRegisterButton() {
    return TextButton(
      onPressed: Register,
      child: Text(
        'Register New Account',
        style: TextStyle(
          decoration: TextDecoration.underline, decorationThickness: 2
        ),
      )
    );
  }

  ElevatedButton LoginLoginButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color.fromARGB(255, 40, 75, 158),
        foregroundColor: Colors.white
      ),
      onPressed: Login,
      child: Text(
        "Login",
        style: TextStyle(
          fontSize: 20,
          fontWeight:FontWeight.w800
        )
      )
    );
  }

  Column LoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Department Code:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextFormField(
          decoration: InputDecoration(
            labelText: 'e.g. T001',
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20))
          ),
        ),
        SizedBox(height: 10),
        Text("Email:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextFormField(
          decoration: InputDecoration(
            labelText: 'e.g. example@mail.com',
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20))
          ),
        ),
        SizedBox(height: 10),
        Text("Password:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextFormField(
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'At least 8 characters',
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)
            ),
          ),
        ),
      ],
    );
  }

  ClipOval LoginLogo() {
    return ClipOval(
      child: Image.asset(
        "assets/images/logo.png",
        height: 200,
        width: 200, fit: BoxFit.cover),
    );
  }

  Row LoginRadioButton(String _selectedRole) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // Centers the group
      children: [
        // --- Employee Option ---
        Radio<String>(
          value: "employee",
          groupValue: _selectedRole,
          onChanged: (value) {
            setState(() {
              _selectedRole = value!;
            });
          },
        ),

        const Text("Employee", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),

        const SizedBox(width: 20), // Spacing between the two options
        
        // --- Manager Option ---
        Radio<String>(
          value: "manager",
          groupValue: _selectedRole,
          onChanged: (value) {
            setState(() {
              _selectedRole = value!;
            });
          },
        ),

        const Text("Manager", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void Login() {
    print("Logging In...");
  }

  void Register() {
    print("Redirecting to Register Page...");
  }
}