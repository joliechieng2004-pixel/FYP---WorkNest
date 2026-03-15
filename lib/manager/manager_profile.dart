import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:worknest/services/location_service.dart';
import 'package:worknest/widget/location_picker.dart';

class ManagerProfile extends StatefulWidget {
  final String deptCode;

  const ManagerProfile({super.key, required this.deptCode});

  @override
  State<ManagerProfile> createState() => _ManagerProfilePageState();
}

class _ManagerProfilePageState extends State<ManagerProfile> {
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

  bool isWaitingForVerification = false;

  double? selectedLat;
  double? selectedLng;
  String addressName = "Unknown Location";

  double? currentDistance;

  int _expandedIndex = 0;

  // --- INITIALIZATION ---
  @override
  void initState() {
    super.initState();
    docID = FirebaseAuth.instance.currentUser?.uid ?? ""; // Get ID first
    _initializeData();
  }

  void _initializeData() async {
    await _loadManagerData();
    DocumentSnapshot userDoc = await _db.collection('users').doc(docID).get();
  
    if (userDoc.exists) {
      setState(() {
        // Get the deptCode from the user document
        deptCode = userDoc.get('deptCode') ?? ""; 
      });
      
      // Step 2: Now that we have the code, get the office location
      if (deptCode.isNotEmpty) {
        await _loadOfficeData();
      }
    }
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

  Future<void> _loadOfficeData() async {
    if (deptCode.isEmpty) {
      print("DEBUG: deptCode is empty. Waiting for user data...");
      // If it's empty, we might need to fetch the user profile first
      await _loadManagerData(); 
    }
    try {
      // 1. Get the document from the 'departments' collection
      DocumentSnapshot deptDoc = await _db.collection('departments').doc(deptCode).get();

      if (deptDoc.exists && deptDoc.data() != null) {
        Map<String, dynamic> data = deptDoc.data() as Map<String, dynamic>;

        print("DEBUG: Found department: ${deptDoc.id}");

        // 2. Extract the GeoPoint and Address
        // Note: Firebase stores location as a 'GeoPoint' type
        GeoPoint? geoPoint = data['officeLocation']; 
        String? savedAddress = data['officeAddress'];

        // 3. Update the UI state
        setState(() {
          if (geoPoint != null) {
            selectedLat = geoPoint.latitude;
            selectedLng = geoPoint.longitude;
          }
          addressName = savedAddress ?? "No address set";
        });
      } else {
        print("DEBUG: No document found at departments/$deptCode");
        setState(() => addressName = "Department Not Found ($deptCode)");
      }
    } catch (e) {
      print("Error loading office data: $e");
      setState(() => addressName = "Error loading location");
    }
  }

  // Fetch the current employee's department details
  Future<void> _loadManagerData() async {
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
          userRole = data['userRole'] ?? "manager";
          
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
              // Manager Profile
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
                          // Radio Buttons for Reminder
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
                                onPressed: _updateSettingsAndLocation, 
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

              // 2. Expandable Department Settings Card
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Department Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const Divider(),
                    _buildExpandableSetting(
                      index: 4,
                      title: "Attendance Settings",
                      icon: Icons.timer_outlined,
                      expandedChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Office Location
                          const Text(
                            "Office Location",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 40, 75, 158)),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Current Address:",
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      addressName, // This will now show the Firestore value on load
                                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                                    ),
                                    const SizedBox(height: 10),
                                    if (currentDistance != null)
                                      Text("Distance to Office: ${currentDistance!.toInt()}m", 
                                        style: TextStyle(color: currentDistance! <= 50 ? Colors.green : Colors.red)),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        ElevatedButton.icon(
                                          // Change: Now calls the Map Picker instead of just GPS
                                          onPressed: () => _pickLocationFromMap(context), 
                                          icon: const Icon(Icons.map_rounded),
                                          label: const Text("Select on Map"),
                                        ),
                                        ElevatedButton(onPressed: _testOfficeRange, child: Text("Test Geofence")),
                                      ]
                                    ),
                                  ],
                                )
                              ),
                            ],
                          ),

                          // Location Verification
                            const Text("Location Verification", 
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 40, 75, 158))),
                            const SizedBox(height: 10),
                            _buildSwitchOption("Require for clock in", notifyCheckIn, (val) => setState(() => notifyCheckIn = val)),
                            _buildSwitchOption("Require for clock out", notifyLate, (val) => setState(() => notifyLate = val)),

                          // Face Verification
                            const Text("Face Verification", 
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 40, 75, 158))),
                            const SizedBox(height: 10),
                            _buildSwitchOption("Require for clock in", notifyCheckIn, (val) => setState(() => notifyCheckIn = val)),
                            _buildSwitchOption("Require for clock out", notifyLate, (val) => setState(() => notifyLate = val)),

                          // Grace Period
                            const Text("Grace Period", 
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 40, 75, 158))),
                            const SizedBox(height: 10),
                            _buildSwitchOption("Notify on Check-in", notifyCheckIn, (val) => setState(() => notifyCheckIn = val)),
                            _buildSwitchOption("Notify on Late", notifyLate, (val) => setState(() => notifyLate = val)),

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
                                onPressed: _updateSettingsAndLocation, 
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
      String oldEmail = user?.email ?? "";

      bool emailChanged = (user != null && newEmail != oldEmail);

      // 1. Handle Auth Email Change if necessary
      if (emailChanged) {
        try {
          await user!.verifyBeforeUpdateEmail(newEmail);
          setState(() {
            isWaitingForVerification = true; // Trigger the UI change
          });
          _showSnackBar("Verification email sent to $newEmail!", Colors.blue);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            _showPasswordDialog(newEmail);
            return; // EXIT: Don't update Firestore yet if re-auth is needed
          } else {
            _showSnackBar("Auth Error: ${e.message}", Colors.red);
            return; // EXIT: Stop if there's another auth error
          }
        }
      }

      // 2. Update Firestore
      // NOTICE: We only update the 'userEmail' field in Firestore 
      // IF it didn't require a re-auth, OR we can choose to keep the old email 
      // in Firestore until they actually verify.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(docID)
          .update({
        'userFName': _profileFNameController.text.trim(),
        'userLName': _profileLNameController.text.trim(),
        'userContact': _profileContactController.text.trim(),
        // Option: Only update this if you want Firestore to show the "pending" email
        'userEmail': newEmail, 
      });

      _showSnackBar("Profile updated successfully!", Colors.green);
      
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> _reauthenticateAndChangeEmail(String password, String newEmail) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      AuthCredential credential = EmailAuthProvider.credential(
        email: user!.email!, 
        password: password
      );

      // 1. Re-authenticate
      await user.reauthenticateWithCredential(credential);

      // 2. Trigger the Verification Email
      await user.verifyBeforeUpdateEmail(newEmail);

      setState(() {
        isWaitingForVerification = true; // Trigger the UI change
      });
      
      // 3. Update Firestore NOW so the UI reflects the "Pending" change
      await FirebaseFirestore.instance.collection('users').doc(docID).update({
        'userEmail': newEmail,
        'emailVerified': false, // Add this field to track status
      });

      _showSnackBar("Success! Please check $newEmail to verify your account.", Colors.blue);
    } catch (e) {
      _showSnackBar("Error: ${e.toString()}", Colors.red);
    }
  }

  Future<void> _showPasswordDialog(String newEmail) async {
    final TextEditingController _passwordController = TextEditingController();

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
                controller: _passwordController,
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
                String password = _passwordController.text.trim();
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

  Future<void> _updateSettingsAndLocation() async {
    try {
      // 1. Create a Write Batch to ensure both updates succeed or both fail
      WriteBatch batch = _db.batch();

      // 2. Reference for User Settings
      DocumentReference userRef = _db.collection('users').doc(docID);
      batch.update(userRef, {
        'settings.notifyShift': notifyShift,
        if (userRole == "manager") ...{
          'settings.notifyCheckIn': notifyCheckIn,
          'settings.notifyLate': notifyLate,
          'settings.notifyAbsent': notifyAbsent,
        }
      });

      // 3. Reference for Department Location (if user is a manager and location is set)
      if (userRole == "manager" && selectedLat != null && selectedLng != null) {
        // Ensure you have the departmentId variable available in your class
        DocumentReference deptRef = _db.collection('departments').doc(deptCode);
        
        batch.update(deptRef, {
          'officeLocation': GeoPoint(selectedLat!, selectedLng!),
          'officeAddress': addressName,
          'updatedAt': FieldValue.serverTimestamp(), // Good practice for FYP
        });
      }

      // 4. Commit the batch
      await batch.commit();

      _showSnackBar("All settings and location updated!", Colors.green);
      setState(() => _expandedIndex = 0); 
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

  Future<void> _pickLocationFromMap(BuildContext context) async {
    // Navigate to the screen we created in the previous step
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPicker()),
    );

    // If the user picked a location and didn't just press 'back'
    if (result != null && result is Map<String, dynamic>) {
      // check what is actually coming back from the location_picker
      print("Map Result Recieved: $result");
      
      setState(() {
        selectedLat = result['lat'];
        selectedLng = result['lng'];

        // If you have an address controller, you can update it here too:
        var incomingAddress = result['address'];

        if (incomingAddress is String && incomingAddress.isNotEmpty && incomingAddress != "{}") {
          addressName = incomingAddress;
        } else {
          addressName = "Office Location (${selectedLat!.toStringAsFixed(3)})";
        }

        debugPrint("MANAGER PROFILE: Received $addressName");
      });

      print("State Updated: $addressName at $selectedLat, $selectedLng");
    }
  }

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

  void _testOfficeRange() async {
    bool hasPermission = await LocationService.handleLocationPermission();
    if (!hasPermission) return;

    Position position = await Geolocator.getCurrentPosition();

    setState(() {
      currentDistance = LocationService.getDistance(
        position.latitude, 
        position.longitude, 
        selectedLat!, 
        selectedLng!
      );
    });

    if (currentDistance! <= 50) {
      _showSnackBar("Test Passed: You are in range!", Colors.green);
    } else {
      _showSnackBar("Test Failed: You are ${currentDistance!.toInt()}m away.", Colors.red);
    }
  }
}