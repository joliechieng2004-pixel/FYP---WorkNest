// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:worknest/services/auth_service.dart';
import 'package:worknest/utils/app_colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();

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
              const Text("LOGIN PAGE", style: TextStyle(fontSize: 30, fontWeight:FontWeight.bold, fontFamily: "Roboto-Bold", color: AppColors.primaryBlue),),
              const SizedBox(height: 20),
              LoginForm(),
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
        backgroundColor: AppColors.primaryBlue,
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
              borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
              borderRadius: BorderRadius.circular(20)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
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
              borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
              borderRadius: BorderRadius.circular(20)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
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
              borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
              borderRadius: BorderRadius.circular(20)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
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

  void _handleLogin() async {
  // 1. Get values from controllers and the radio button
  String enteredEmail = _emailController.text.trim();
  String enteredPassword = _passwordController.text.trim();
  String enteredDeptCode = _deptCodeController.text.trim();

  // 2. Call AuthService (Updated to check role too)
  String? result = await _authService.loginUser(
    email: enteredEmail,
    password: enteredPassword,
    deptCode: enteredDeptCode,
  );

  if (!mounted) return;

  if (result == null) {
     // Success! Navigate based on the radio button value
     debugPrint("Login successful. Waiting for AuthWrapper to switch...");
  } else {
     // Show error from SnackBar
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }
}

  void goRegister() {
    Navigator.pushReplacementNamed(context, '/register');
  }
}