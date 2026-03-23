import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:worknest/config.dart';
import 'package:worknest/employee/employee_profile.dart';
import 'package:worknest/employee/employee_report.dart';
import 'package:worknest/employee/employee_schedule.dart';
import 'package:worknest/services/auth_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:worknest/services/auth_wrapper.dart';
import 'package:worknest/services/location_service.dart';
import 'package:worknest/widget/face_verification.dart';

class EmployeeHome extends StatefulWidget {
  const EmployeeHome({super.key});

  @override
  State<EmployeeHome> createState() => _EmployeeHomePageState();
}

class _EmployeeHomePageState extends State<EmployeeHome> {
  // --- DECLARATION ---
  // color
  final Color primaryBlue = const Color.fromARGB(255, 40, 75, 158);
  final Color bgLightBlue = const Color.fromARGB(255, 240, 250, 255);

  // navigation data
  int _selectedIndex = 0;

  // timer
  bool _isClockedIn = false;
  DateTime? _startTime;
  String _workingHours = "00:00:00";
  Timer? _timer;
  bool _isLoading = true;

  final ScrollController _shiftScrollController = ScrollController();
  final ScrollController _mainScrollController = ScrollController();

  // clock in service
  final AuthService _authService = AuthService();

  // clock in data
  double officeLat = 0.0;
  double officeLng = 0.0;
  double officeRadius = 0.0;
  String deptName = "Loading...";
  String deptCode = "Loading...";
  String lName = "Name";
  String workerID = "Worker ID";
  String formattedDate = DateFormat('EEEE, d MMM yyyy').format(DateTime.now());
  String formattedTime = DateFormat('h:mm a').format(DateTime.now());


  // --- INITIALIZATION ---
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() async {
    await _loadEmployeeData();
    await _checkCurrentAttendanceStatus();
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mainScrollController.dispose();
    _shiftScrollController.dispose(); // Clean up the controller
    super.dispose(); 
  }

  // Fetch Employee Data
  Future<void> _loadEmployeeData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Get Dept Code
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          String fetchedDeptCode = userDoc['deptCode'];

          setState(() {
            workerID = userDoc.id;
            deptCode = fetchedDeptCode;
            lName = userDoc['userLName'];
          });

          await _fetchOfficeCoordinates(fetchedDeptCode);
        }
      } catch (e) {
        print("Error loading employee or office data: $e");
      }
    }
  }

  // Fetch Office Data
  Future<void> _fetchOfficeCoordinates(String code) async {
    try {
      DocumentSnapshot deptDoc = await FirebaseFirestore.instance
          .collection('departments')
          .doc(code)
          .get();

      if (deptDoc.exists) {
        Map<String, dynamic> data = deptDoc.data() as Map<String, dynamic>;
        var settings = data['attendanceSettings'] as Map<String, dynamic>?;
        
        if (settings != null) {
          GeoPoint? geoPoint = settings['officeLocation'];
          double radiusMeter = (settings['radiusMeter'] ?? 100.0).toDouble();

          setState(() {
            deptName = deptDoc['deptName'];
            if (geoPoint != null) {
              officeLat = geoPoint.latitude; 
              officeLng = geoPoint.longitude;
              officeRadius = radiusMeter;
            }
          });
        }
        print("DEBUG: Office coordinates loaded for $code");
      }
    } catch (e) {
      print("Error fetching department coordinates: $e");
    }
  }

  // --- HELPER TO FETCH SETTINGS ---
  // Assuming 'deptCode' is available in your State class.
  Future<Map<String, bool>> _getDepartmentSettings() async {
    try {
      QuerySnapshot deptSnapshot = await FirebaseFirestore.instance
          .collection('departments')
          .where('deptCode', isEqualTo: deptCode) 
          .limit(1)
          .get();

      if (deptSnapshot.docs.isNotEmpty) {
        var data = deptSnapshot.docs.first.data() as Map<String, dynamic>;
        if (data.containsKey('attendanceSettings')) {
          var settings = data['attendanceSettings'] as Map<String, dynamic>;
          return {
            'requireGPS': settings['requireGPS'] ?? true, // Default to true for security
            'requireFace': settings['requireFace'] ?? true,
          };
        }
      }
    } catch (e) {
      debugPrint("Error fetching dept settings: $e");
    }
    return {'requireGPS': true, 'requireFace': true}; // Fallback to strict mode if error
  }

  // Ensure Data Persistency
  Future<void>  _checkCurrentAttendanceStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Reconstruct the same doc ID used in your clock-in logic
      String dateId = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String docId = "${dateId}_${user.uid}";

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('attendances')
          .doc(docId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // If there is a start time but NO end time, they are still on shift
        if (data['attendanceStartTime'] != null && data['attendanceEndTime'] == null) {
          Timestamp startTimestamp = data['attendanceStartTime'];
          DateTime startTime = startTimestamp.toDate();

          setState(() {
            _isClockedIn = true;
            _startTime = startTime;
          });

          _startTimerTicker(); // Helper to start the actual timer
        }
      }
    }
  }

  DateTime? safeConvertToDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // --- BUILD WIDGETS ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading){
      return const Scaffold(
        body: Center(child: CircularProgressIndicator())
      );
    }
    
    // Bottom Navigation
      // pages
    final List<Widget> pages = [
      _buildHomeDashboard(context),                               // Index 0 - Home Page
      EmployeeSchedule(deptCode: deptCode, workerID: workerID),   // Index 1 - Schedule Page
      EmployeeReport(deptCode: deptCode, workerID: workerID),     // Index 2 - Report Page
      EmployeeProfile(deptCode: deptCode, workerID: workerID),    // Index 3 - Profile Page
    ];

    return Scaffold(
      backgroundColor: bgLightBlue,
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),

        // styles
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Required for 5 items
        backgroundColor: const Color(0xFF1A3E88), // Dark Blue
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        currentIndex: _selectedIndex,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: (index) {
          print("Swithcing to index: $index");
          setState(() {
            _selectedIndex = index; // This triggers the UI refresh
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: "Schedule"),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: "Tasks"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  // Home Dashboard
  SafeArea _buildHomeDashboard(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        controller: _mainScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Greeting Row + Log Out Button
            Row(
              children: [
                Expanded(
                  flex: 9,
                  child: Text(
                    "$deptName: Worker", 
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 1,
                  child: IconButton.outlined(
                    icon: Icon(Icons.logout, color: primaryBlue),
                    onPressed: _showLogoutConfirmation
                  ),
                ),
              ]),

            const SizedBox(height: 10),

            // Clock In Card
            _buildCard(
              child: Column(
                children: [
                  if (! _isClockedIn)...[
                    Text(formattedDate, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(formattedTime, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    
                    const SizedBox(height: 5),
                    
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C2A0), // Teal Green
                        foregroundColor: Colors.black,
                        minimumSize: const Size(250, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: _clockIn,
                      child: const Text("Clock In", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    )
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formattedDate, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(formattedTime, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Text(_workingHours, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2, color: Color(0xFF00C2A0)),),

                    const SizedBox(height: 5),
                    
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935 ), // Teal Green
                        foregroundColor: Colors.white,
                        minimumSize: const Size(250, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: _showClockOutConfirmation,
                      child: const Text("Clock Out", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    )
                  ]
                ]    
              ),
            ),

            _buildCard(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('shifts')
                    .where('shiftUserID', isEqualTo: workerID)
                    .where('shiftStatus', isEqualTo: 'pending') // Only count those needing action
                    .where('shiftDate', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
                    .snapshots(),
                builder: (context, snapshot) {
                  // 1. Handle Loading State
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: LinearProgressIndicator());
                  }

                  // 2. Get the Count
                  int pendingCount = snapshot.data?.docs.length ?? 0;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notification_important, 
                              color: pendingCount > 0 ? Colors.orange : Colors.grey),
                          const SizedBox(width: 10),
                          const Text(
                            "Pending Shifts",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      // 3. Highlight the number if it's > 0
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: pendingCount > 0 ? Colors.orange.shade900 : Colors.grey.shade600,)
                        ),
                        child: Text(
                          "$pendingCount",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: pendingCount > 0 ? Colors.orange.shade900 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Shift Summary
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Upcoming Shifts",
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),

                  Divider(color: primaryBlue),

                  const SizedBox(height: 10),
                  
                  SizedBox(
                    height: 300, // Set the height you want for the scrollable area
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('shifts')
                          .where('shiftUserID', isEqualTo: workerID)
                          .where('shiftDate', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
                          .where('shiftStatus', isEqualTo: "accepted")
                          .orderBy('shiftDate')
                          .limit(7)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          debugPrint("Firestore Error: ${snapshot.error}");
                          return const Center(child: Text("Error loading data"));
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                    
                        var shifts = snapshot.data!.docs;

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text("No upcoming shifts."));
                        }

                        if (shifts.isEmpty) {
                          return const Center(child: Text("No upcoming shifts."));
                        }
                    
                        return Scrollbar(
                          controller: _shiftScrollController,
                          thumbVisibility: true,
                          child: ListView.separated(
                            controller: _shiftScrollController,
                            primary: false,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(right: 10),
                            itemCount: shifts.length,
                            separatorBuilder: (context, index) => Divider(color: bgLightBlue,),
                            itemBuilder: (context, index) {
                              var data = shifts[index].data() as Map<String, dynamic>;
                
                              // 1. Convert safely using the helper
                              DateTime? start = safeConvertToDateTime(data['shiftStartTime']);
                              DateTime? end = safeConvertToDateTime(data['shiftEndTime']);
                              DateTime? date = safeConvertToDateTime(data['shiftDate']);
                                              
                              // 2. Format Strings
                              String formattedDate = date != null ? DateFormat('d MMM yyyy, EEEE').format(date) : "--";
                              String formattedIn = start != null ? DateFormat('hh:mm a').format(start) : "--:--";
                              String formattedOut = end != null ? DateFormat('hh:mm a').format(end) : "--:--";
                                              
                              return _buildShiftScheduleCard(
                                formattedDate, formattedIn, formattedOut, "Office"
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ]
        ),
      ),
    );
  }

  // --- CLOCK IN FUNCTION ---
  void _clockIn() async {
    User? user = FirebaseAuth.instance.currentUser;
    
    if (user != null){
      try {
        showDialog(
          context: context,
          barrierDismissible:false,
          builder: (context) => const Center(child: CircularProgressIndicator()));

        // --- FETCH DYNAMIC SETTINGS ---
        Map<String, bool> settings = await _getDepartmentSettings();
        bool requireGPS = settings['requireGPS']!;
        bool requireFace = settings['requireFace']!;

        GeoPoint currentGeoPoint;
        
        // --- CHECK LOCATION (CONDITIONAL) ---
        if (requireGPS) {
          // Handle permissions and get position
          bool hasPermission = await LocationService.handleLocationPermission();

          if (!hasPermission) {
            Navigator.pop(context);
            _showSnackBar("Location permissions denied.", Colors.red);
            return;
          }

          //1. Get User's Current GPS Position
          Position position = await _getCurrentLocation() ?? await Geolocator.getCurrentPosition();
          //2. Calculate Distance from Office
          double distanceInMeters = LocationService.getDistance(
            position.latitude,
            position.longitude,
            officeLat,
            officeLng
          );

          // Outside of office radius
          // If not activated, the location is verified successfully
          if (distanceInMeters > officeRadius){
            Navigator.pop(context);
            _showSnackBar("Too far: ${distanceInMeters.toInt()}m away.", Colors.red);
            return;
          }

          // ready to send location to the attendance log
          currentGeoPoint = GeoPoint(position.latitude, position.longitude);
        } else {
          // If GPS is skipped, provide a fallback location so your backend doesn't crash
          currentGeoPoint = GeoPoint(officeLat, officeLng);
        }
        
        // --- CHECK SHIFT ---
        // 1. Get today's date and strip the time (set to 00:00:00)
        DateTime now = DateTime.now();
        DateTime todayMidnight = DateTime(now.year, now.month, now.day);
        DateTime tomorrowMidnight = todayMidnight.add(const Duration(days: 1));

        QuerySnapshot shiftQuery = await FirebaseFirestore.instance
            .collection('shifts')
            .where('shiftUserID', isEqualTo: user.uid)
            .where('shiftStatus', isEqualTo: "accepted")
            .where('shiftDate', isGreaterThanOrEqualTo: Timestamp.fromDate(todayMidnight))
            .where('shiftDate', isLessThan: Timestamp.fromDate(tomorrowMidnight))
            .limit(1)
            .get();

        DocumentSnapshot? assignedShift = shiftQuery.docs.isNotEmpty ? shiftQuery.docs.first : null;

        // Close loading before showing potential Dialog
        Navigator.pop(context);

        if (assignedShift == null) {
          bool insist = await _showNoShiftDialog();
          if (!insist) return; // Exit if they click "Cancel"
        }

        // --- FACE VERIFICATION (OPTIONAL) ---
        bool faceVerified = true;
        
        if (requireFace) {
          // Face verification screen placeholder
          if (AppConfig.useFaceVerificationStub) {
            // Wait for the stub screen to return 'true'
            faceVerified = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FaceVerification()),
            ) ?? false;
            // Real Face Verification Login
          }
        }

        if (faceVerified) { // Face success (fake)
          // Re-open Loading Spinner for the database write
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator()),
          );

          String? error = await _authService.clockInUser(
            uid: user.uid,
            deptCode: deptCode,
            location: currentGeoPoint,
            assignedShift: assignedShift,
          );

          Navigator.pop(context);

          if (error == null) {
            setState(() {
              _isClockedIn = true;
              _startTime = DateTime.now();
            });
            _startTimerTicker();

            _showSnackBar("Clock-in successful", Colors.green);
          } else {_showSnackBar("Clock-in failed: $error", Colors.red);}
        }
      } catch (e) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        _showSnackBar("System Error: $e", Colors.red);
        print(e);
      }
    }
  }

  // --- CLOCK OUT LOGIC (Handles Rule 3) ---
  void _clockOutLogic() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Show loading while verifying location and talking to Firebase
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator())
      );

      // --- FETCH DYNAMIC SETTINGS ---
      Map<String, bool> settings = await _getDepartmentSettings();
      bool requireGPS = settings['requireGPS']!;
      bool requireFace = settings['requireFace']!;

      GeoPoint currentGeoPoint;

      // Rule 3: Verify Location Again (IF NEEDED)
      if (requireGPS) {
        bool hasPermission = await LocationService.handleLocationPermission();

        if (!hasPermission) {
          if (mounted) Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location permissions denied."), backgroundColor: Colors.red));
          return;
        }

        Position position = await _getCurrentLocation() ?? await Geolocator.getCurrentPosition();
        double distanceInMeters = LocationService.getDistance(
          position.latitude,
          position.longitude,
          officeLat,
          officeLng
        );

        if (distanceInMeters > officeRadius) {
          if (mounted) Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Too far to clock out: ${distanceInMeters.toInt()}m away."), backgroundColor: Colors.red)
          );
          return;
        }

        currentGeoPoint = GeoPoint(position.latitude, position.longitude);
      } else {
        // If GPS is skipped, provide a fallback location so your backend doesn't crash
        currentGeoPoint = GeoPoint(officeLat, officeLng);
      }

      // --- FACE VERIFICATION (OPTIONAL) ---
      bool faceVerified = true;
      
      if (requireFace) {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
        
        // Face verification screen placeholder
        if (AppConfig.useFaceVerificationStub) {
          // Wait for the stub screen to return 'true'
          faceVerified = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FaceVerification()),
          ) ?? false;
          // Real Face Verification Login
        }
      }

      if (faceVerified){
        // Re-open Loading Spinner for the database write
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        // Call the backend service function
        String? error = await _authService.clockOutUser(uid: user.uid);

        if (mounted) Navigator.pop(context); // Close loading

        if (error == null) {
          _timer?.cancel();
          _timer = null;

          setState(() {
            _isClockedIn = false;
            _workingHours = "00:00:00";
            _startTime = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Clock-out recorded successfully!"), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        }
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- CLOCK OUT CONFIRMATION (Handles Rules 1 & 2) ---
  void _showClockOutConfirmation() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Rule 1: Minimum 15 minutes attendance duration
    if (_startTime != null) {
      int workedMinutes = DateTime.now().difference(_startTime!).inMinutes;
      if (workedMinutes < 15) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("You must work for at least 15 minutes before clocking out. ($workedMinutes/15 min)"),
            backgroundColor: Colors.red,
          ),
        );
        return; // Stop the process here
      }
    }

    // Show a loading spinner while we check Firestore for the shift end time
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    bool isEarlyLeave = false;

    try {
      // Rule 2: Check if clocking out before Scheduled End Time
      String dateId = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String docId = "${dateId}_${user.uid}";
      
      DocumentSnapshot attDoc = await FirebaseFirestore.instance.collection('attendances').doc(docId).get();

      // If an attendance record exists and it is linked to a specific shift
      if (attDoc.exists && (attDoc.data() as Map<String, dynamic>).containsKey('shiftID') && attDoc['shiftID'] != null) {
        DocumentSnapshot shiftDoc = await FirebaseFirestore.instance.collection('shifts').doc(attDoc['shiftID']).get();
        
        if (shiftDoc.exists) {
          DateTime shiftEndTime = (shiftDoc['shiftEndTime'] as Timestamp).toDate();
          // Compare current time to the scheduled end time
          if (DateTime.now().isBefore(shiftEndTime)) {
            isEarlyLeave = true;
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking shift time: $e");
    }

    // Close the loading spinner
    if (mounted) Navigator.pop(context);

    // Set dynamic text and colors based on the early leave status
    String dialogTitle = isEarlyLeave ? "Early Clock Out Warning" : "Confirm Clock Out";
    String dialogContent = isEarlyLeave 
        ? "You haven't reached your scheduled shift end time yet. Are you sure you want to clock out early?"
        : "Are you sure you want to end your shift?";
    Color confirmButtonColor = isEarlyLeave ? Colors.red : Colors.white;
    Color confirmTextColor = isEarlyLeave ? Colors.white : Colors.black;

    // Show the actual confirmation dialog
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(dialogTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(dialogContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _clockOutLogic();       // Proceed to location check and backend
              },
              style: ElevatedButton.styleFrom(backgroundColor: confirmButtonColor, foregroundColor: confirmTextColor),
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }
  

  // --- LOCATION GETTER ---
  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services are disabled.');

    // 2. Check/Request permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Location permissions are denied');
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    // 3. Get the current position
    return await Geolocator.getCurrentPosition();
  }

  // --- HELPERS ---
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

  void _startTimerTicker() {
    _timer?.cancel(); // Clear any existing timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isClockedIn && _startTime != null) {
        final duration = DateTime.now().difference(_startTime!);
        setState(() {
          _workingHours = duration.toString().split('.').first.padLeft(8, "0");
        });
      } else {
        timer.cancel();
      }
    });
  }

  Widget _buildShiftScheduleCard(String date, String clockIn, String clockOut, String location) {
    return Container(
      width: double.infinity, // Fixed width for horizontal scrolling
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 5),
          Text("Shift Time: $clockIn - $clockOut", style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 5),
          Text("Location: $location", style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }

  // Helper for showing messages
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // Helper for the "Insist" Dialog
  Future<bool> _showNoShiftDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("No Shift Scheduled"),
        content: const Text("You aren't scheduled for today. Do you still insist to clock in as 'Unscheduled'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Clock In anyway")),
        ],
      ),
    ) ?? false;
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
                
                // Final clean up before logout
                _timer?.cancel(); 
                
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