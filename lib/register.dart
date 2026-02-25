import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            const Text("CREATE ACCOUNT", style: TextStyle(fontSize: 30, fontWeight:FontWeight.bold, fontFamily: "Roboto-Bold", color: Color.fromARGB(255, 40, 75, 158)),),
              const SizedBox(height: 20),
              Column(
                children: [
                  RegisterForm(),
                ],
              ),
              const SizedBox(height: 30),
              RegisterRegisterButton(),
              RegisterLoginButton()
            ]
          )
        )
      )
    );
  }

  TextButton RegisterLoginButton() {
    return TextButton(
      onPressed: goLogin,
      child: Text(
        'Back to Login',
        style: TextStyle(
          decoration: TextDecoration.underline, decorationThickness: 2
        ),
      )
    );
  }

  ElevatedButton RegisterRegisterButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color.fromARGB(255, 40, 75, 158),
        foregroundColor: Colors.white
      ),
      onPressed: Register,
      child: Text(
        "Register Account",
        style: TextStyle(
          fontSize: 20,
          fontWeight:FontWeight.w800
        )
      )
    );
  }

  Column RegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Department Name:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextFormField(
          decoration: InputDecoration(
            labelText: 'e.g. IT Department',
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)
              )
          ),
        ),
        SizedBox(height: 10),
        Text("First Name:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextFormField(
          decoration: InputDecoration(
            labelText: 'e.g. John (Given Name)',
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)
              )
          ),
        ),
        SizedBox(height: 10),
        Text("Last Name:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextFormField(
          decoration: InputDecoration(
            labelText: 'e.g. Lim (Family Name)',
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)
              )
          ),
        ),
        SizedBox(height: 10),
        Text("Contact Number:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextFormField(
          decoration: InputDecoration(
            labelText: 'e.g. 0123456789',
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)
              )
          ),
        ),
        SizedBox(height: 10),
        Text("Email:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextFormField(
          decoration: InputDecoration(
            labelText: 'e.g. example@mail.com',
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)
              )
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
              borderRadius: BorderRadius.circular(20)),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)
              )
          ),
        ),
        SizedBox(height: 10),
        Text("Confirm Password:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextFormField(
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Re-enter your password',
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)
              )
          ),
        ),
      ],
    );
  }

  void Register() {
    print("Registering...");
  }

  void goLogin() {
    print("Redirecting to Login Page...");
  }
}