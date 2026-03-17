import 'package:flutter/material.dart';
import 'package:worknest/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  
  String _selectedRole = "employee";

  final TextEditingController _deptCodeController = TextEditingController(); // Only for Managers or joining
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _deptCodeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
              const SizedBox(height: 20),
              LoginLogo(),
              const SizedBox(height: 20),
              const Text("LOGIN PAGE", style: TextStyle(fontSize: 30, fontWeight:FontWeight.bold, fontFamily: "Roboto-Bold", color: Color.fromARGB(255, 40, 75, 158)),),
              const SizedBox(height: 20),
              Column(
                children: [
                  LoginRadioButton(),
                  const SizedBox(height: 10),
                  LoginForm(),
                ],
              ),
              const SizedBox(height: 30),
              LoginLoginButton(),
              LoginRegisterButton(),
            ]
          )
        )
      )
    );
  }

  TextButton LoginRegisterButton() {
    return TextButton(
      onPressed: goRegister,
      child: const Text(
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
        backgroundColor: const Color.fromARGB(255, 40, 75, 158),
        foregroundColor: Colors.white
      ),
      onPressed: _handleLogin,
      child: const Text(
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
        const Text("Department Code:", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        TextFormField(
          controller: _deptCodeController,
          decoration: InputDecoration(
            labelText: 'e.g. T001',
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
              borderRadius: BorderRadius.circular(20)
              ),
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
              ),
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

  Row LoginRadioButton() {
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

  void _handleLogin() async {
  // 1. Get values from controllers and the radio button
  String enteredEmail = _emailController.text.trim();
  String enteredPassword = _passwordController.text.trim();
  String enteredDeptCode = _deptCodeController.text.trim();
  String selectedRole = _selectedRole; // This is the value from your Radio buttons!

  // 2. Call AuthService (Updated to check role too)
  String? result = await _authService.loginUser(
    email: enteredEmail,
    password: enteredPassword,
    deptCode: enteredDeptCode,
    expectedRole: selectedRole, // Pass the radio button value here
  );

  if (result == null) {
     // Success! Navigate based on the radio button value
     if (selectedRole == 'manager') {
       Navigator.pushReplacementNamed(context, '/manager_home');
     } else {
       Navigator.pushReplacementNamed(context, '/employee_home');
     }
  } else {
     // Show error from SnackBar
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }
}

  void goRegister() {
    Navigator.pushReplacementNamed(context, '/register');
  }
}