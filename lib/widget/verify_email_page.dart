import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

// ... imports

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool isEmailVerified = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;

    if (!isEmailVerified) {
      timer = Timer.periodic(const Duration(seconds: 3), (_) => checkEmailVerified());
    }
  }

  Future checkEmailVerified() async {
    await FirebaseAuth.instance.currentUser?.reload();

    // Check if the widget is still in the tree before calling setState/Navigator
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.emailVerified) {
      timer?.cancel();
      // Use the Navigator to move them permanently to the Home Screen
      Navigator.pushReplacementNamed(context, '/manager_home');
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Return the Scaffold directly. The Navigator handles the transition.
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'A verification email has been sent to your inbox.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.currentUser?.sendEmailVerification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Verification email resent!")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: ${e.toString()}")),
                  );
                }
              },
              icon: const Icon(Icons.email),
              label: const Text('Resend Email'),
            ),
            TextButton(
              onPressed: () async {
                timer?.cancel();
                await FirebaseAuth.instance.signOut();
                // Send them back to the Login/Landing page
                Navigator.of(context).pop(); 
              },
              child: const Text('Cancel / Back to Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}