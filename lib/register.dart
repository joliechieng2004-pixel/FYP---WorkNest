import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:worknest/services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _deptNameController = TextEditingController();
  final TextEditingController _fNameController = TextEditingController();
  final TextEditingController _lNameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final AuthService _authService = AuthService(); // Initialize Service

  @override
  void dispose() {
    // 2. Clean up memory
    _deptNameController.dispose();
    _fNameController.dispose();
    _lNameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
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
      child: const Text(
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
        backgroundColor: const Color.fromARGB(255, 40, 75, 158),
        foregroundColor: Colors.white
      ),
      onPressed: _handleRegister,
      child: const Text(
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
        const Text("Department Name:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextFormField(
          controller: _deptNameController,
          decoration: InputDecoration(
            labelText: 'e.g. IT Department',
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)
              )
          ),
        ),
        const SizedBox(height: 10),
        const Text("First Name:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextFormField(
          controller: _fNameController,
          decoration: InputDecoration(
            labelText: 'e.g. John (Given Name)',
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)
              )
          ),
        ),
        const SizedBox(height: 10),
        const Text("Last Name:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextFormField(
          controller: _lNameController,
          decoration: InputDecoration(
            labelText: 'e.g. Lim (Family Name)',
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)
              )
          ),
        ),
        const SizedBox(height: 10),
        const Text("Contact Number:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextFormField(
          controller: _contactController,
          decoration: InputDecoration(
            labelText: 'e.g. 0123456789',
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)
              )
          ),
        ),
        const SizedBox(height: 10),
        const Text("Email:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'e.g. example@mail.com',
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)
              )
          ),
        ),
        const SizedBox(height: 10),
        const Text("Password:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextFormField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'At least 8 characters',
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)
              )
          ),
        ),
        const SizedBox(height: 10),
        const Text("Confirm Password:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Re-enter your password',
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)
            )
          ),
        ),
      ],
    );
  }

  void _handleRegister() async {
    // Basic Validation (Password & Confirm Password)
    // TODO: validate email
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match!")),
      );
      return;
    }

    // Show loading circle (Optional but recommended)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Call the service
    String? result = await _authService.registerManager(
      deptName: _deptNameController.text.trim(),
      fName: _fNameController.text.trim(),
      lName: _lNameController.text.trim(),
      contact: _contactController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      officeLocation: const GeoPoint(0, 0),
    );

    Navigator.pop(context); // Remove loading circle

    if (result == null) {
      // SUCCESS!
      ScaffoldMessenger.of(context).showSnackBar(
        // TODO: change duration for better experience
        const SnackBar(content: Text("Account Created Successfully!"), backgroundColor: Colors.green,),
      );
      // Navigate to Login or Dashboard
      Navigator.pushReplacementNamed(context, '/manager_home');
    } else {
      // ERROR (e.g., email already in use)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    }
  }

  void goLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }
}