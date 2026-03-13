import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  int _expandedIndex = 0;

  // --- INITIALIZATION ---
  @override
  void initState() {
    super.initState();
    docID = FirebaseAuth.instance.currentUser?.uid ?? ""; // Get ID first
    _initializeData();
  }

  void _initializeData() async {
    await _loadEmployeeData();
  }

  @override
  void dispose() {
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
        var settings = data['settings'] ?? {}; // Handle missing settings map

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
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Worker Profile
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$fName $lName", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text("Department ID: $deptCode", style: TextStyle(fontSize: 15, color: Colors.blueGrey)),
                    Text("Email: $email", style: TextStyle(fontSize: 15, color: Colors.blueGrey)),
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
                              Flexible( // Use Flexible instead of Expanded here
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("First Name:", style: TextStyle(fontSize: 16)),
                                    TextFormField(
                                      controller: _profileFNameController,
                                      decoration: InputDecoration(
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
                                          borderRadius: BorderRadius.circular(20)),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
                                          borderRadius: BorderRadius.circular(20)
                                        )
                                      )
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 15),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Last Name:", style: TextStyle(fontSize: 16)),
                                    TextFormField(
                                      controller: _profileLNameController,
                                      decoration: InputDecoration(
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
                                          borderRadius: BorderRadius.circular(20)),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(color: Color.fromARGB(255, 40, 75, 158), width: 2),
                                          borderRadius: BorderRadius.circular(20)
                                        )
                                      )
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text("Email:", style: TextStyle(fontSize: 18)),
                          TextFormField(
                            controller: _profileEmailController,
                            decoration: InputDecoration(
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
                          Text("Contact Number:", style: TextStyle(fontSize: 18)),
                          TextFormField(
                            controller: _profileContactController,
                            decoration: InputDecoration(
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              ElevatedButton(
                                onPressed: _cancelEdit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 40, 75, 158),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                ),
                                child: const Text("Cancel")),
                              ElevatedButton(
                                onPressed: () =>_changeProfileConfirmation(), 
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 40, 75, 158),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                ),
                                child: const Text("Update Profile")),
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
                          Text("New Password:", style: TextStyle(fontSize: 18)),
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: true,
                            decoration: InputDecoration(
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
                          Text("Confirm Password:", style: TextStyle(fontSize: 18)),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: InputDecoration(
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              ElevatedButton(
                                onPressed: _cancelEdit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 40, 75, 158),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                ),
                                child: const Text("Cancel")),
                              ElevatedButton(
                                onPressed: () =>_validateAndUpdatePassword(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 40, 75, 158),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                ),
                                child: const Text("Update Password")),
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
                          const Text("Shift Reminder", 
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 40, 75, 158))),
                          const SizedBox(height: 5),
                          
                          // Radio Buttons for Reminder
                          _buildRadioOption("Off", 0),
                          _buildRadioOption("15 minutes before shift", 15),
                          _buildRadioOption("30 minutes before shift", 30),
                          _buildRadioOption("45 minutes before shift", 45),
                          _buildRadioOption("60 minutes before shift", 60),

                          // Manager Specific Alerts
                          if (userRole == "manager") ...[
                            const Divider(height: 30),
                            const Text("Manager Alerts", 
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
                              ElevatedButton(
                                onPressed: _cancelEdit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 40, 75, 158),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                ),
                                child: const Text("Cancel")
                              ),
                              ElevatedButton(
                                onPressed: _updateNotificationSettings, 
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 40, 75, 158),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                ),
                                child: const Text("Save Settings")
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
                onPressed: () {
                      FirebaseAuth.instance.signOut();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                child: Text(
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
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey,
            blurRadius: 10,
            offset: const Offset(2, 4),
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
                _updateProfile();       // Run the reset logic
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  // Function to update the profile in Firebase
  Future<void> _updateProfile() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      String newEmail = _profileEmailController.text.trim();

      // 1. Update the actual Login Credential first
      if (user != null && user.email != newEmail) {
        // Modern Firebase way: Sends a verification link to the NEW email
        // The login email ONLY changes once they click the link in their inbox
        await user.verifyBeforeUpdateEmail(newEmail);
      }

      // 2. Update the Firestore Database (What you already have)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(docID)
          .update({
        'userFName': _profileFNameController.text.trim(),
        'userLName': _profileLNameController.text.trim(),
        'userEmail': newEmail,
        'userContact': _profileContactController.text.trim(),
      });

      // ... rest of your success logic ...
    } on FirebaseAuthException catch (e) {
      // Handle the "Recent Login Required" error
      if (e.code == 'requires-recent-login') {
        print("Please log out and log back in to change your email for security.");
      }
    } catch (e) {
      print("Error: $e");
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
      
      _showSnackBar("Password updated successfully!", Colors.green);
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _expandedIndex = 0);
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showSnackBar("Please log out and log in again to update your password.", Colors.red);
      } else {
        _showSnackBar("Error: ${e.message}", Colors.red);
      }
    }
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
      activeColor: const Color.fromARGB(255, 40, 75, 158),
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
}