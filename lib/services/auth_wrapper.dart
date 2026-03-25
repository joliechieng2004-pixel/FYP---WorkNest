import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:worknest/employee/employee_home.dart';
import 'package:worknest/login.dart';
import 'package:worknest/manager/manager_home.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // This stream emits a new value whenever the user logs in or out
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. If the connection is still loading, show a splash screen
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. If snapshot has data, a user is already logged in!
        if (snapshot.hasData && snapshot.data != null) {
          // STEP 2: We have a user, now check their role in Firestore
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                String role = userData['userRole'] ?? 'employee'; // Default to employee

                if (role == 'manager') {
                  return const ManagerHome(); 
                } else {
                  return const EmployeeHome();
                }
              }

              // If document doesn't exist, they might be a new user or error
              return const LoginPage();
            },
          );
        }

        return const LoginPage();
      }
    );
  }
}