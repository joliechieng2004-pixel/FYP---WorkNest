// Registration Logic
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:math';

import 'package:intl/intl.dart';

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

  // 3. CREATE EMPLOYEE (Inside Manager Dashboard)
  Future<String?> createEmployeeByManager({
    required String fName,
    required String lName,
    required String email,
    required String contact,
    required String password,
    required String managerDeptCode,
  }) async {
    // Create a temporary secondary app to avoid logging out the Manager
    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'TemporaryUserCreation',
      options: Firebase.app().options,
    );

    try {
      // 1. Create the Auth Account using the secondary app
      UserCredential result = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(email: email, password: password);

      if (result.user != null) {
        // 2. Create the User Document in Firestore using the NEW UID
        await _db.collection('users').doc(result.user!.uid).set({
          'userFName': fName,
          'userLName': lName,
          'userEmail': email,
          'userContact': contact,
          'userRole': 'employee', // Matches the login check
          'deptCode': managerDeptCode,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 3. Increment the department count
        await _db.collection('departments').doc(managerDeptCode).update({
          'totalMembers': FieldValue.increment(1),
        });

        await secondaryApp.delete(); // Clean up
        return null; // Success
      }
    } on FirebaseAuthException catch (e) {
      await secondaryApp.delete();
      return e.message;
    } catch (e) {
      await secondaryApp.delete();
      return e.toString();
    }
    return 'Employee creation failed';
  }

  // TODO: create employee in employee page
  // // 3. CREATE EMPLOYEE (Inside Manager Dashboard)
  // Future<String?> createEmployeeByManager({
  //   required String email,
  //   required String password,
  //   required String fName,
  //   required String lName,
  //   required String contact,
  //   required String managerDeptCode, // Passed from Manager's current data
  // }) async {
  //   try {
  //     // Create the Employee's Auth Account
  //     UserCredential result = await _auth.createUserWithEmailAndPassword(
  //       email: email,
  //       password: password,
  //     );

  //     if (result.user != null) {
  //       await _db.collection('users').doc(result.user!.uid).set({
  //         'userFName': fName,
  //         'userLName': lName,
  //         'userEmail': email,
  //         'userContact': contact,
  //         'userRole': 'employee', // Hardcoded as Employee
  //         'deptCode': managerDeptCode,
  //         'createdAt': FieldValue.serverTimestamp(),
  //       });
  //       return null;
  //     }
  //   } on FirebaseAuthException catch (e) {
  //     return e.message;
  //   }
  //   return 'Employee creation failed';
  // }

  // 4. LOGIN USER WITH DEPT CODE VERIFICATION
  // Change the return type from Map? to String?
  Future<String?> loginUser({
    required String email,
    required String password,
    required String deptCode,
    required String expectedRole,
  }) async {
    try {
      // 1. Authenticate
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );

      if (result.user != null) {
        // 2. Fetch Firestore Profile
        DocumentSnapshot userDoc = await _db.collection('users').doc(result.user!.uid).get();

        if (userDoc.exists) {
          String actualDeptCode = userDoc.get('deptCode');
          String actualRole = userDoc.get('userRole');

          // 3. Check if Dept Code and Role match the Radio Button/Input
          if (actualDeptCode == deptCode && actualRole == expectedRole) {
            return null; // SUCCESS (No error message)
          } else {
            await _auth.signOut();
            return "Incorrect Department Code or User Role selected.";
          }
        }
      }
      return "User profile not found.";
    } on FirebaseAuthException catch (e) {
      return e.message; // Return the Firebase error (e.g., "Wrong password")
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> clockInUser({
    required String uid,
    required String deptCode,
    required GeoPoint location,
  }) async {
    try {
      // 1. Create a unique ID for the day (e.g., 2026-02-27_UserID)
      String dateId = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String docId = "${dateId}_$uid";

      // 2. Reference the document
      DocumentReference docRef = _db.collection('attendances').doc(docId);

      // 3. Set the data matching your fields
      await docRef.set({
        'attendanceDate': DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day), // Midnight of today
        'attendanceStartTime': FieldValue.serverTimestamp(),
        'attendanceEndTime': null, // Empty until they clock out
        'attendanceLocation': location, // Placeholder for now
        'attendanceStatus': "Present",
        'attendanceUserID': uid,
        'deptCode': deptCode, // Crucial for Manager filtering
      });
      
      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> clockOutUser({
    required String uid,
  }) async {
    try {
      // 1. Recreate the SAME unique ID used in clockIn (yyyy-MM-dd_UserID)
      String dateId = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String docId = "${dateId}_$uid";

      // 2. Reference the existing document
      DocumentReference docRef = _db.collection('attendances').doc(docId);

      // 3. Update the existing document with the end time
      await docRef.update({
        'attendanceEndTime': FieldValue.serverTimestamp(),
        // Optional: change status to 'Completed' if you want to distinguish from just 'Present'
        // 'attendanceStatus': "Completed", 
      });

      return null; // Success
    } catch (e) {
      // If the user tries to clock out but no clock-in record exists for today
      return "Clock-out failed: ${e.toString()}";
    }
  }
}