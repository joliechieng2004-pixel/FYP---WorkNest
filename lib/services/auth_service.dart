// Registration Logic
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // TODO: check if the code existed
  // 1. GENERATE RANDOM 8-CHAR DEPT CODE
  String generateDeptCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(8, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  // 2. MANAGER REGISTRATION (With Incremental Staff ID)
  Future<String?> registerManager({
    required String deptName,
    required String fName,
    required String lName,
    required String contact,
    required String email,
    required String password,
    GeoPoint? officeLocation,
  }) async {
    try {
      // Create Auth Account
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      // If user not existed
      if (result.user != null) {
        // A. GET AND INCREMENT THE TOTAL USER COUNT
        DocumentReference counterRef = _db.collection('metadata').doc('users_stats');
        
        // This runs a "Transaction" to make sure two users don't get the same number
        int newStaffNumber = await _db.runTransaction((transaction) async {
          DocumentSnapshot snapshot = await transaction.get(counterRef);
          int newCount = (snapshot.get('count') as int) + 1;
          transaction.update(counterRef, {'count': newCount});
          return newCount;
        });

        String newCode = generateDeptCode();

        // Create Manager Profile
        await _db.collection('users').doc(result.user!.uid).set({
          'staffID': newStaffNumber.toString().padLeft(4, '0'), // Becomes "0001"
          'userFName': fName,
          'userLName': lName,
          'userContact': contact,
          'userEmail': email,
          'userRole': 'manager', // Hardcoded as Manager
          'deptCode': newCode,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // TODO: code for register office location for attendance later
        // Create Department Document
        await _db.collection('departments').doc(newCode).set({
          'deptName': deptName,
          'managerID': result.user!.uid,
          'deptCode': newCode,
          'totalMembers': 1,
          'attendanceLocation': officeLocation ?? const GeoPoint(0, 0), // Default to 0,0 for now
          'createdAt': FieldValue.serverTimestamp(),
        });
        return null; 
      }
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
    return 'Registration failed';
  }

  // TODO: create employee in employee page
  // 3. CREATE EMPLOYEE (Inside Manager Dashboard)
  Future<String?> createEmployeeByManager({
    required String email,
    required String password,
    required String fName,
    required String lName,
    required String contact,
    required String managerDeptCode, // Passed from Manager's current data
  }) async {
    try {
      // Create the Employee's Auth Account
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        await _db.collection('users').doc(result.user!.uid).set({
          'userFName': fName,
          'userLName': lName,
          'userEmail': email,
          'userContact': contact,
          'userRole': 'employee', // Hardcoded as Employee
          'deptCode': managerDeptCode,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return null;
      }
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
    return 'Employee creation failed';
  }

  // 4. LOGIN USER & GET ROLE
  Future<Map<String, dynamic>?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      // Step A: Sign in with Auth
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );

      if (result.user != null) {
        // Step B: Fetch the user document from Firestore
        DocumentSnapshot doc = await _db.collection('users').doc(result.user!.uid).get();
        
        if (doc.exists) {
          return {
            'role': doc.get('userRole'),
            'uid': result.user!.uid,
            'deptCode': doc.get('deptCode'),
          };
        }
      }
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "An error occurred";
    }
    return null;
  }
}