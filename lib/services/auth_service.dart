import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:math';
import 'package:intl/intl.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. GENERATE RANDOM 8-CHAR DEPT CODE
  Future<String> generateDeptCode() async {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789'; // Changed to lowercase
    final random = Random();
    final FirebaseFirestore db = FirebaseFirestore.instance;

    while (true) {
      // 1. Generate an 8-character lowercase code
      String newCode = List.generate(
        8, 
        (index) => chars[random.nextInt(chars.length)]
      ).join();

      // 2. Check if this code already exists in the 'departments' collection
      final query = await db
          .collection('departments')
          .where('deptCode', isEqualTo: newCode)
          .limit(1)
          .get();

      // 3. If no document is found, the code is unique! Return it.
      if (query.docs.isEmpty) {
        return newCode;
      }
    }
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    // RegEx explained:
    // (?=.*[A-Z])       : At least one uppercase letter
    // (?=.*[a-z])       : At least one lowercase letter
    // (?=.*\d)          : At least one digit (number)
    // .{8,}             : At least 8 characters long
    final passwordRegExp = RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$');

    if (!passwordRegExp.hasMatch(value)) {
      return 'Must be 8+ chars with at least an Uppercase, a Lowercase, and a Number';
    }
    
    return null; // Password is valid
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
        // --- TRIGGER VERIFICATION EMAIL HERE ---
        await result.user!.sendEmailVerification();

        String newCode = await generateDeptCode();

        // Create Manager Profile
        await _db.collection('users').doc(result.user!.uid).set({
          'userFName': fName,
          'userLName': lName,
          'userContact': contact,
          'userEmail': email,
          'userRole': 'manager', // Hardcoded as Manager
          'deptCode': newCode,
          'createdAt': FieldValue.serverTimestamp(),
          'settings': {
            'notifyOnCheckIn': true,
            'notifyOnLate': true,
            'notifyOnAbsent': true,
          },
        });

        // Create Department Document
        await _db.collection('departments').doc(newCode).set({
          'deptName': deptName,
          'managerID': result.user!.uid,
          'deptCode': newCode,
          'totalMembers': 1,
          'attendanceSettings': {
            'officeAddress': null,
            'officeLocation': officeLocation ?? const GeoPoint(0, 0),
            'radiusMeter': 100,
            'requireFace': false,
            'requireGPS': false,
            'gracePeriod': 0,
          },
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
          'settings': {'notifyShift': 15,}
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
    DocumentSnapshot? assignedShift,
  }) async {
    try {
      // 1. Check User Profile FIRST (Fail fast)
      DocumentSnapshot userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) return "User profile not found.";
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String fullName = "${userData['userFName']} ${userData['userLName']}";
      DateTime now = DateTime.now();

      // Document ID Generation
      String todayDate = DateFormat('yyyy-MM-dd').format(now);

      // Save TimeStamp
      DateTime todayMidnight = DateTime(now.year, now.month, now.day);
      // Convert to Firestore Timestamp
      Timestamp todayTimestamp = Timestamp.fromDate(todayMidnight);

      String status = "Unscheduled";
      String? shiftID;

      // 2. Fetch gracePeriod
      DocumentSnapshot deptDoc = await _db.collection('departments').doc(deptCode).get();
      int gracePeriod = 0;
      if (deptDoc.exists) {
        var settings = deptDoc['attendanceSettings'] as Map<String, dynamic>?;
        gracePeriod = settings?['gracePeriod'] ?? 15; // Default to 15 if missing
      }

      // 2. CHECK FOR APPROVED LEAVE (Integration Step)
      // We check if a leave document exists for today for this user
      var leaveQuery = await _db.collection('leaves')
          .where('leaveUserID', isEqualTo: uid)
          .where('leaveDate', isEqualTo: todayDate)
          .where('status', isEqualTo: 'Approved')
          .get();

      if (leaveQuery.docs.isNotEmpty) {
        status = "On-Leave";}
      else if (assignedShift != null && assignedShift.exists) {
        shiftID = assignedShift.id;
        
        // Ensure startTime is a Timestamp in Firestore
        DateTime scheduledStart = (assignedShift['shiftStartTime'] as Timestamp).toDate();
        DateTime deadline = scheduledStart.add(Duration(minutes: gracePeriod));

        status = now.isAfter(deadline) ? "Late" : "On-Time";
      }

      // 4. Atomic Write
      await _db.collection('attendances').doc("${todayDate}_$uid").set({
        'attendanceUserId': uid,
        'attendanceUserName': fullName,
        'deptCode': deptCode,
        'attendanceLocation': location,
        'attendanceDate': todayTimestamp,
        'attendanceStartTime': FieldValue.serverTimestamp(),
        'attendanceEndTime': null,
        'attendanceStatus': status,
        'shiftID': shiftID,
        'attendanceApproval': "Pending",
      });

      return null;
    } catch (e) {
      return "System Error: ${e.toString()}";
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