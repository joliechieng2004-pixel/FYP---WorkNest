import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:worknest/services/auth_wrapper.dart';
import 'package:worknest/services/connectivity_service.dart';

class EmployeeProfile extends StatefulWidget {
  final String deptCode;
  final String workerID;

  const EmployeeProfile({super.key, required this.deptCode, required this.workerID});

  @override
  State<EmployeeProfile> createState() => _EmployeeProfilePageState();
}

class _EmployeeProfilePageState extends State<EmployeeProfile> {
  // often use colors
  final Color primaryBlue = const Color.fromARGB(255, 40, 75, 158);
  final Color bgLightBlue = const Color.fromARGB(255, 240, 250, 255);

  final TextEditingController _profileFNameController = TextEditingController();
  final TextEditingController _profileLNameController = TextEditingController();
  final TextEditingController _profileEmailController = TextEditingController();
  final TextEditingController _profileContactController = TextEditingController();

  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // check connection
  late StreamSubscription<bool> _connectivitySubscription;
  bool _isOffline = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  int notifyShift = 0;
  bool notifyCheckIn = false;
  bool notifyLate = false;
  bool notifyAbsent = false;
  String userRole = "";
  
  String docID = "Unknown";
  String deptCode = "Loading...";
  String fName = "First Name";
  String lName = "Last Name";
  String email = "Email";
  String contact = "0XX-XXXXXXX";

  bool isWaitingForVerification = false;

  int _expandedIndex = 0;

  // --- INITIALIZATION ---
  @override
  void initState() {
    super.initState();
    // Start listening
    _connectivitySubscription = ConnectivityService().connectionStream.listen((isOnline) {
      setState(() {
        _isOffline = !isOnline;
      });
      
      if (_isOffline) {
        _showOfflineBanner();
      } else {
        ScaffoldMessenger.of(context).clearMaterialBanners();
      }
    });
    docID = FirebaseAuth.instance.currentUser?.uid ?? ""; // Get ID first
    _initializeData();
  }

  void _showOfflineBanner() {
    ScaffoldMessenger.of(context).showMaterialBanner(
      const MaterialBanner(
        content: Text(
          'No Internet Connection. Actions are disabled.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        actions: [
          Icon(Icons.wifi_off, color: Colors.white),
        ],
      ),
    );
  }

  void _initializeData() async {
    await _loadEmployeeData();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _profileFNameController.dispose();
    _profileLNameController.dispose();
    _profileEmailController.dispose();
    _profileContactController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose(); 
  }

   // Fetch the current employee's department details
  Future<void> _loadEmployeeData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(docID)
          .get();

      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        var settings = data['settings'] ?? {};

        // Stops the code if user left the screen
        if (!mounted) return;

        setState(() {
          userRole = data['userRole'] ?? "employee";
          
          // Load settings with defaults if they don't exist
          notifyShift = (settings['notifyShift'] ?? 0).toInt();
          notifyCheckIn = settings['notifyCheckIn'] ?? false;
          notifyLate = settings['notifyLate'] ?? false;
          notifyAbsent = settings['notifyAbsent'] ?? false;

          deptCode = userDoc['deptCode'];
          lName = userDoc['userLName'];
          fName = userDoc['userFName'];
          email = userDoc['userEmail'];
          contact = userDoc['userContact'];

          _profileFNameController.text = fName;
          _profileLNameController.text = lName;
          _profileEmailController.text = email;
          _profileContactController.text = contact;
        });
      }
    }
  }

  // --- BUILD WIDGETS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLightBlue,
      appBar: AppBar(
        title: const Text("Profile"),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A3E88),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Worker Profile
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$fName $lName", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text("Department ID: $deptCode", style: const TextStyle(fontSize: 15, color: Colors.blueGrey)),
                    Text("Email: $email", style: const TextStyle(fontSize: 15, color: Colors.blueGrey)),
                  ],
                ),
              ),

              // 2. Expandable Account Settings Card
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Account Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const Divider(),
                    
                    // --- Edit Profile ---
                    _buildExpandableSetting(
                      index: 1,
                      title: "Edit Profile",
                      icon: Icons.person_outline,
                      expandedChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("First Name:", style: TextStyle(fontSize: 16)),
                                    TextFormField(
                                      controller: _profileFNameController,
                                      decoration: InputDecoration(
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
                                          borderRadius: BorderRadius.circular(20)),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
                                          borderRadius: BorderRadius.circular(20)
                                        )
                                      )
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Last Name:", style: TextStyle(fontSize: 16)),
                                    TextFormField(
                                      controller: _profileLNameController,
                                      decoration: InputDecoration(
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
                                          borderRadius: BorderRadius.circular(20)),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: const BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
                                          borderRadius: BorderRadius.circular(20)
                                        )
                                      )
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const SizedBox(height: 10),
                              const Text("Email:", style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),

                              // Dynamic Status Indicator
                              if (isWaitingForVerification || !(FirebaseAuth.instance.currentUser?.emailVerified ?? false)) ...[
                                const Text("(Pending Verification)", 
                                    style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: _refreshVerificationStatus,
                                  child: const Icon(Icons.refresh, color: Color.fromARGB(255, 40, 75, 158), size: 18),
                                ),
                              ]
                              else ...[
                                const Icon(Icons.verified, color: Colors.green, size: 20),
                                const SizedBox(width: 4),
                                // The Refresh Button
                                GestureDetector(
                                  onTap: _refreshVerificationStatus,
                                  child: const Icon(Icons.refresh, color: Color.fromARGB(255, 40, 75, 158), size: 18),
                                ),
                              ],
                            ],
                          ),
                          TextFormField(
                            controller: _profileEmailController,
                            decoration: InputDecoration(
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
                          const Text("Contact Number:", style: TextStyle(fontSize: 18)),
                          TextFormField(
                            controller: _profileContactController,
                            decoration: InputDecoration(
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _cancelEdit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 40, 75, 158),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                  ),
                                  child: const Text("Cancel")),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isOffline ? null : () => _changeProfileConfirmation(), 
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isOffline ? Colors.grey : const Color.fromARGB(255, 40, 75, 158),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                  ),
                                  child: Text(_isOffline ? "Waiting for Connection" : "Update")),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),

                    // --- Change Password ---
                    _buildExpandableSetting(
                      index: 2,
                      title: "Change Password",
                      icon: Icons.lock_outline,
                      expandedChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("New Password:", style: TextStyle(fontSize: 18)),
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: true,
                            decoration: InputDecoration(
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
                          const Text("Confirm Password:", style: TextStyle(fontSize: 18)),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: InputDecoration(
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _cancelEdit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 40, 75, 158),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                  ),
                                  child: const Text("Cancel")),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isOffline ? null : () => _validateAndUpdatePassword(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isOffline ? Colors.grey : const Color.fromARGB(255, 40, 75, 158),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                  ),
                                  child: Text(_isOffline ? "Waiting for Connection" : "Update")),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),

                    // --- Notifications ---
                    _buildExpandableSetting(
                      index: 3,
                      title: "Notification Settings",
                      icon: Icons.notifications_none,
                      expandedChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (userRole == "employee") ...[
                            const Text("Shift Reminder", 
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 40, 75, 158))),
                            const SizedBox(height: 5),
                            
                            // Radio Buttons for Reminder
                            _buildRadioOption("Off", 0),
                            _buildRadioOption("15 minutes before shift", 15),
                            _buildRadioOption("30 minutes before shift", 30),
                            _buildRadioOption("45 minutes before shift", 45),
                            _buildRadioOption("60 minutes before shift", 60)
                          ],

                          // Manager Specific Alerts
                          if (userRole == "manager") ...[
                            const Divider(height: 30),
                            const Text("Attendance Alerts", 
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 40, 75, 158))),
                            const SizedBox(height: 10),
                            _buildSwitchOption("Notify on Check-in", notifyCheckIn, (val) => setState(() => notifyCheckIn = val)),
                            _buildSwitchOption("Notify on Late", notifyLate, (val) => setState(() => notifyLate = val)),
                            _buildSwitchOption("Notify on Absent", notifyAbsent, (val) => setState(() => notifyAbsent = val)),
                          ],

                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _cancelEdit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 40, 75, 158),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                  ),
                                  child: const Text("Cancel")
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isOffline ? null : () => _updateNotificationSettings, 
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isOffline ? Colors.grey : const Color.fromARGB(255, 40, 75, 158),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                  ),
                                  child: Text(_isOffline ? "Waiting for Connection" : "Save")
                                ),
                              )
                            ]
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935 ), // Teal Green
                  foregroundColor: Colors.white,
                  minimumSize: const Size(250, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _showLogoutConfirmation,
                child: const Text(
                  "Log Out",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20))
              )
            ],
          ),
        ),
      )
    );
  }

  // Helper for Cards
  Widget _buildCard({required Widget child, Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryBlue, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.blueGrey,
            blurRadius: 10,
            offset: Offset(2, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // Helper to build the expandable rows
  Widget _buildExpandableSetting({
    required int index,
    required String title,
    required IconData icon,
    required Widget expandedChild,
  }) {
    bool isExpanded = _expandedIndex == index;

    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: primaryBlue),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          trailing: Icon(isExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down),
          onTap: () {
            setState(() {
              _expandedIndex = isExpanded ? 0 : index;
            });
          },
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 15, left: 10, right: 10),
            child: expandedChild,
          ),
        if (index != 3) const Divider(height: 1), // Don't show divider for last item
      ],
    );
  }

  Future<void> _changeProfileConfirmation() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Save Changes", style: TextStyle(fontWeight:FontWeight(5)),),
          content: const Text("Are you sure you want to save the changes made to your profile?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.black),),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _saveProfile();       // Run the reset logic
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  // Save Settings
  Future<void> _saveProfile() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String newEmail = _profileEmailController.text.trim();
      String oldEmail = user?.email ?? "";
      bool emailChanged = (user != null && newEmail != oldEmail);

      // 2. Update Firestore for other fields
      await FirebaseFirestore.instance.collection('users').doc(docID).update({
        'userFName': _profileFNameController.text.trim(),
        'userLName': _profileLNameController.text.trim(),
        'userContact': _profileContactController.text.trim(),
      });

      // 1. If email changed, handle Auth verification
      if (emailChanged) {
        try {
          await user.verifyBeforeUpdateEmail(newEmail);
          setState(() => isWaitingForVerification = true);
          _showSnackBar("Verification email sent to $newEmail!", Colors.blue);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            _showPasswordDialog(newEmail); // Triggers re-auth flow
            return; 
          } else {
            _showSnackBar("Auth Error: ${e.message}", Colors.red);
            return;
          }
        }
      }

      _showSnackBar("Profile updated successfully!", Colors.green);
      setState(() => _expandedIndex = -1); // Close card
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    }
  }

  // Verify User Credential before Update New Email
  Future<void> _showPasswordDialog(String newEmail) async {
    final TextEditingController passwordController = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false, // User must interact with the dialog
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Password"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Please enter your current password to authorize the email change."),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                String password = passwordController.text.trim();
                if (password.isNotEmpty) {
                  Navigator.pop(context);
                  _reauthenticateAndChangeEmail(password, newEmail);
                }
              },
              child: const Text("Verify & Update"),
            ),
          ],
        );
      },
    );
  }
  
  // Authenticate New Email
  Future<void> _reauthenticateAndChangeEmail(String password, String newEmail) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      AuthCredential credential = EmailAuthProvider.credential(
        email: user!.email!, 
        password: password
      );

      // Re-authenticate
      await user.reauthenticateWithCredential(credential);
      // Trigger the Verification Email
      await user.verifyBeforeUpdateEmail(newEmail);

      setState(() {
        isWaitingForVerification = true; // Trigger the UI change
      });
      
      // Update Firestore NOW so the UI reflects the "Pending" change
      await FirebaseFirestore.instance.collection('users').doc(docID).update({
        'userEmail': newEmail,
        'emailVerified': false, // Add this field to track status
      });
      _showSnackBar("Success! Please check $newEmail to verify your account.", Colors.blue);
    } catch (e) {
      _showSnackBar("Error: ${e.toString()}", Colors.red);
    }
  }

  Future<void> _validateAndUpdatePassword() async {
    String newPass = _newPasswordController.text.trim();
    String confirmPass = _confirmPasswordController.text.trim();

    if (newPass.isEmpty || confirmPass.isEmpty) {
      _showSnackBar("Please fill in both fields", Colors.orange);
      return;
    }

    if (newPass.length < 6) {
      _showSnackBar("Password must be at least 6 characters", Colors.orange);
      return;
    }

    if (newPass != confirmPass) {
      _showSnackBar("Passwords do not match", Colors.red);
      return;
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      await user?.updatePassword(newPass);
      _onSuccessUpdate();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // 1. Show the dialog to get the current password
        String? currentPassword = await _showReAuthDialog();

        if (currentPassword != null && currentPassword.isNotEmpty) {
          try {
            // 2. Create the credential
            AuthCredential credential = EmailAuthProvider.credential(
              email: email,
              password: currentPassword,
            );

            // 3. Re-authenticate
            await FirebaseAuth.instance.currentUser?.reauthenticateWithCredential(credential);

            // 4. Retry the update now that the session is fresh
            await FirebaseAuth.instance.currentUser?.updatePassword(newPass);
            _onSuccessUpdate();
            
          } catch (reAuthError) {
            _showSnackBar("Re-authentication failed. Please check your password.", Colors.red);
          }
        }
      } else {
        _showSnackBar("Error: ${e.message}", Colors.red);
      }
    }
  }

  Future<String?> _showReAuthDialog() async {
    TextEditingController passwordController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Re-authenticate"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("For security, please enter your CURRENT password to continue."),
            const SizedBox(height: 15),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: "Current Password",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, passwordController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 40, 75, 158)),
            child: const Text("Verify", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Email Verification Status
  Future<void> _refreshVerificationStatus() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      
      // This is the key command—it forces a fetch from Firebase Auth
      await user?.reload(); 

      if (user?.emailVerified ?? false) {
        setState(() {
          isWaitingForVerification = false; // Switch back to the green icon
        });

        _showSnackBar("Email verified successfully!", Colors.green);
        
        // Also update Firestore to keep the 'emailVerified' flag in sync
        await FirebaseFirestore.instance.collection('users').doc(docID).update({
          'emailVerified': true,
        });
      } else {
        _showSnackBar("Email not verified yet. Please check your inbox.", Colors.orange);
      }
    } catch (e) {
      _showSnackBar("Error refreshing status: $e", Colors.red);
    }
  }

  // Helper to clean up after successful update
  void _onSuccessUpdate() {
    _showSnackBar("Password updated successfully!", Colors.green);
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    setState(() => _expandedIndex = 0);
  }

  // Helper for showing messages
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Widget _buildRadioOption(String title, int value) {
    return RadioListTile<int>(
      title: Text(title),
      value: value,
      groupValue: notifyShift,
      activeColor: const Color.fromARGB(255, 40, 75, 158),
      onChanged: (int? val) => setState(() => notifyShift = val!),
    );
  }

  Widget _buildSwitchOption(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      activeThumbColor: const Color.fromARGB(255, 40, 75, 158),
      onChanged: onChanged,
    );
  }

  Future<void> _updateNotificationSettings() async {
    try {
      await _db.collection('users').doc(docID).update({
        'settings.notifyShift': notifyShift,
        if (userRole == "manager") ...{
          'settings.notifyCheckIn': notifyCheckIn,
          'settings.notifyLate': notifyLate,
          'settings.notifyAbsent': notifyAbsent,
        }
      });
      _showSnackBar("Settings updated successfully!", Colors.green);
      setState(() => _expandedIndex = 0); // Collapse the card
    } catch (e) {
      _showSnackBar("Update failed: $e", Colors.red);
    }
  }

  void _cancelEdit() {
    setState(() {
      // 1. Reset text controllers to the original variables fetched from Firestore
      _profileFNameController.text = fName;
      _profileLNameController.text = lName;
      _profileEmailController.text = email;
      _profileContactController.text = contact;

      // 2. Collapse the card
      _expandedIndex = 0;
    });
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.logout, color: primaryBlue),
              const SizedBox(width: 10),
              const Text("Confirm Logout"),
            ],
          ),
          content: const Text("Are you sure you want to log out of WorkNest?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Stay", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  // This clears the entire history so the app "starts over"
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthWrapper()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
              child: const Text("Log Out"),
            ),
          ],
        );
      },
    );
  }
}