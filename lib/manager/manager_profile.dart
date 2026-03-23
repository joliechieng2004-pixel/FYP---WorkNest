import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:worknest/services/auth_wrapper.dart';
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

  // New settings state
  bool requireGPS = true;
  bool requireFace = true;
  int? gracePeriod;
  int? radiusMeter;
  GeoPoint? officeLocation;
  bool _isLoadingSettings = true;

  int _expandedIndex = 0;

  // --- INITIALIZATION ---
  @override
  void initState() {
    super.initState();
    docID = FirebaseAuth.instance.currentUser?.uid ?? ""; // Get ID first
    _loadDeptSettings();
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

  Future<void> _loadDeptSettings() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('departments')
          .doc(widget.deptCode) // RDQ3P2YF
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        var settings = data['attendanceSettings'] ?? {}; // Handle missing settings map

        setState(() {
          requireGPS = settings['requireGPS'] ?? true;
          requireFace = settings['requireFace'] ?? true;
          gracePeriod = settings['gracePeriod'] ?? 15;
          radiusMeter = settings['radiusMeter'] ?? 50;
          officeLocation = settings['officeLocation'];
          _isLoadingSettings = false;
        });
      } else {
        // If no settings exist yet, initialize them
        setState(() => _isLoadingSettings = false);
      }
    } catch (e) {
      print("Error loading settings: $e");
    }
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

        // 1. Get the nested map first
        Map<String, dynamic>? attendanceSettings = data['attendanceSettings'] as Map<String, dynamic>?;

        // 2. Extract the values from that map
        if (attendanceSettings != null) {
          GeoPoint? geoPoint = attendanceSettings['officeLocation']; 
          String? savedAddress = attendanceSettings['officeAddress'];

          // 3. Update the UI state
          setState(() {
            if (geoPoint != null) {
              selectedLat = geoPoint.latitude;
              selectedLng = geoPoint.longitude;
            }
            addressName = savedAddress ?? "No address set";
          });
        }
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Manager Profile
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
                                  onPressed: () =>_changeProfileConfirmation(), 
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 40, 75, 158),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                  ),
                                  child: const Text("Update")),
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
                                  onPressed: () =>_validateAndUpdatePassword(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 40, 75, 158),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                  ),
                                  child: const Text("Update")),
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
                                  onPressed: _saveNotification, 
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 40, 75, 158),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                  ),
                                  child: const Text("Save")
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

              // 2. Expandable Department Settings Card
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Department Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const Divider(),
                    _buildExpandableSetting(
                      index: 4,
                      title: "Department Location",
                      icon: Icons.work_outline_outlined,
                      expandedChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                    ElevatedButton.icon(
                                      onPressed: () => _pickLocationFromMap(context), 
                                      icon: const Icon(Icons.map_rounded),
                                      label: const Text("Select on Map"),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () => _testOfficeRange(),
                                          icon: const Icon(Icons.checklist_rounded),
                                          label: const Text("Test Geofence"),
                                        ),
                                        const SizedBox(width: 20),
                                        if (currentDistance != null)
                                          Text("Distance to Office: ${currentDistance!.toInt()}m", 
                                            style: TextStyle(color: currentDistance! <= 50 ? Colors.green : Colors.red)),
                                      ]
                                    ),
                                  ],
                                )
                              ),
                            ],
                          ),
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
                                  onPressed: _saveLocation, 
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 40, 75, 158),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                  ),
                                  child: const Text("Save")
                                ),
                              )
                            ]
                          )
                        ],
                      ),
                    ),

                    _buildExpandableSetting(
                      index: 5,
                      title: "Attendance Settings",
                      icon: Icons.event_available_outlined,
                      expandedChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        // Verification
                          const Text("Verification Requirement", 
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 40, 75, 158))),
                          const SizedBox(height: 10),
                          _buildSwitchOption("Require GPS Verification", requireGPS, (val) => setState(() => requireGPS = val)),
                          _buildSwitchOption("Require Face Verification", requireFace, (val) => setState(() => requireFace = val)),

                        // Face Verification
                          const Text("Attendance Settings", 
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 40, 75, 158))),
                          const SizedBox(height: 10),

                        // Grace Period
                          ListTile(
                            title: const Text("Grace Period"),
                            trailing: SizedBox(
                              width: 100,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  isExpanded: true,
                                  value: gracePeriod,
                                  icon: const Icon(Icons.arrow_drop_down_circle_outlined),
                                  items: [0, 5, 10, 15, 30, 60].map((int value) {
                                    return DropdownMenuItem<int>(
                                      value: value,
                                      child: Text("$value mins"),
                                    );
                                  }).toList(),
                                  onChanged: (int? newValue) {
                                    if (newValue != null) {
                                      setState(() => gracePeriod = newValue);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          ListTile(
                            title: const Text("Geofencing Radius"),
                            trailing: SizedBox(
                              width: 100,
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  isExpanded: true,
                                  value: radiusMeter,
                                  icon: const Icon(Icons.arrow_drop_down_circle_outlined),
                                  items: [0, 50, 100, 150, 200].map((int value) {
                                    return DropdownMenuItem<int>(
                                      value: value,
                                      child: Text("$value meters"),
                                    );
                                  }).toList(),
                                  onChanged: (int? newValue) {
                                    if (newValue != null) {
                                      setState(() => radiusMeter = newValue);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
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
                                  onPressed: _saveAttendanceSettings, 
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 40, 75, 158),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                  ),
                                  child: const Text("Save")
                                ),
                              )
                            ]
                          )
                        ],
                      )
                    )
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

  // --- BUILD HELPER ---

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
    bool showDivider = true,
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
        if (showDivider) const Divider(height: 1), // Don't show divider for last item
      ],
    );
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

  // --- ACCOUNT SETTINGS ---
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

  // Confirm before Change
  Future<void> _changeProfileConfirmation() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Save Changes", style: TextStyle(fontWeight:FontWeight(5)),),
          content: const Text("The profile information will be updated?"),
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


  // --- PASSWORD SETTINGS ---
  // Validation and Update of Password
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
              email: email, // Uses the 'email' variable loaded in _loadEmployeeData
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

  // Helper to clean up after successful update
  void _onSuccessUpdate() {
    _showSnackBar("Password updated successfully!", Colors.green);
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    setState(() => _expandedIndex = 0);
  }

  // --- NOTIFICATION SETTINGS ---
  Future<void> _saveNotification() async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(docID).update({
        'settings.notifyShift': notifyShift, // Assuming this variable exists
        if (userRole == "manager") ...{
          'settings.notifyCheckIn': notifyCheckIn,
          'settings.notifyLate': notifyLate,
          'settings.notifyAbsent': notifyAbsent,
        }
      });
      _showSnackBar("Notification preferences saved!", Colors.green);
      setState(() => _expandedIndex = -1);
    } catch (e) {
      _showSnackBar("Failed to save notifications: $e", Colors.red);
    }
  }

  // --- DEPARTMENT LOCATION ---
  Future<void> _saveLocation() async {
    if (selectedLat == null || selectedLng == null) {
      _showSnackBar("Please pick a location on the map first", Colors.orange);
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('departments')
          .doc(deptCode)
          .update({
        'attendanceSettings.officeLocation': GeoPoint(selectedLat!, selectedLng!),
        'attendanceSettings.officeAddress': addressName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar("Office location updated successfully!", Colors.green);
      setState(() => _expandedIndex = -1);
    } catch (e) {
      _showSnackBar("Failed to save location: $e", Colors.red);
    }
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

    // Start a 3-second countdown to hide the text
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) { // Safety check to ensure page is still open
        setState(() {
          currentDistance = null; // This makes the 'if' condition false
        });
      }
    });

    if (currentDistance! <= 50) {
      _showSnackBar("Test Passed: You are in range!", Colors.green);
    } else {
      _showSnackBar("Test Failed: You are ${currentDistance!.toInt()}m away.", Colors.red);
    }
  }

  // --- ATTENDANCE SETTINGS ---
  Future<void> _saveAttendanceSettings() async {
    try {
      await FirebaseFirestore.instance
          .collection('departments')
          .doc(widget.deptCode)
          .update({
        'attendanceSettings.requireGPS': requireGPS,
        'attendanceSettings.requireFace': requireFace,
        'attendanceSettings.gracePeriod': gracePeriod,
        'attendanceSettings.radiusMeter': radiusMeter,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      _showSnackBar("Attendance rules updated!", Colors.green);
      setState(() => _expandedIndex = -1);
    } catch (e) {
      _showSnackBar("Failed to save settings: $e", Colors.red);
    }
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
              child: const Text("Logout"),
            ),
          ],
        );
      },
    );
  }
}