import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:worknest/services/auth_service.dart';
import 'package:geolocator/geolocator.dart';

class EmployeeHome extends StatefulWidget {
  const EmployeeHome({super.key});

  @override
  State<EmployeeHome> createState() => _EmployeeHomePageState();
}

class _EmployeeHomePageState extends State<EmployeeHome> {
  bool _isClockedIn = false;
  DateTime? _startTime;
  String _workingHours = "00:00:00";
  Timer? _timer;
  bool _isLoading = true;

  // for navigation
  int _selectedIndex =0;
  final AuthService _authService = AuthService();
  // often use colors
  final Color primaryBlue = const Color.fromARGB(255, 40, 75, 158);
  final Color bgLightBlue = const Color.fromARGB(255, 240, 250, 255);

  final ScrollController _activityScrollController = ScrollController();
  String deptCode = "Loading...";
  String lName = "Name";
  String formattedDate = DateFormat('EEEE, d MMM yyyy').format(DateTime.now());
  String formattedTime = DateFormat('h:mm a').format(DateTime.now());
  
  // Example: Coordinates for your office
  // TODO: change to manager provided location
  // TODO: let manager provide radius allowed
  final double officeLat = 3.145686;
  final double officeLng = 101.579963;
  //final double officeLat = 37.421983;
  //final double officeLng = -122.084049;
  final double maxDistanceInMeters = 100.0; // The radius allowed (m)

  int _totalEmployees = 0;

  // --- INITIALIZATION ---
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() async {
    await _loadManagerData();
    await _checkCurrentAttendanceStatus();
    await _loadEmployeeCount();
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _activityScrollController.dispose(); // Clean up the controller
    super.dispose(); 
  }

  // Fetch the current manager's department details
  Future<void> _loadManagerData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
          
      setState(() {
        deptCode = userDoc['deptCode'];
        lName = userDoc['userLName'];
      });
    }
  }

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

  // --- BUILD WIDGETS ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading){
      return const Scaffold(
        body: Center(child: CircularProgressIndicator())
      );
    }
    
    // 1. Define the pages
    final List<Widget> pages = [
      _buildHomeDashboard(context),                                // Index 0
      const Center(child: Text("Calendar Coming Soon")),    // Index 1
      const Center(child: Text("Tasks Page")),              // Index 2
      const Center(child: Text("Profile Page")),            // Index 3
    ];

    return Scaffold(
      backgroundColor: bgLightBlue,
      // 2. Switches body based on the index
      body: pages[_selectedIndex],

      // 3. Fixed Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Required for 5 items
        backgroundColor: const Color(0xFF1A3E88), // Dark Blue
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        currentIndex: _selectedIndex,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: (index) {
          setState(() {
            _selectedIndex = index; // This triggers the UI refresh
          });
          // If the manager clicks "Home", refresh the count
          if (index == 0) {
            _loadEmployeeCount();
          }
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

  SafeArea _buildHomeDashboard(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- Top Greeting Row ---
            Row(
              children: [
                Expanded(
                  flex: 9,
                  child: Text(
                    "Hi, Employee $lName", 
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 1,
                  child: IconButton.outlined(
                    icon: Icon(Icons.logout, color: primaryBlue),
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                ),
              ]),

            const SizedBox(height: 10),
        
            // 1. Dept Code Card
            _buildCard(
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: const Text(
                      "Department Code:",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                  Expanded(
                    flex: 5,
                    child: SelectableText(
                      deptCode, 
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryBlue,
                        letterSpacing: 5),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Clock In Card
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

            // 3. Summary Card
            _buildCard(
              child: Column(
                children: [
                  _buildStatRow("Today's Employee", "20"),
                  _buildStatRow("Attendance Rate", "90%"),
                  _buildStatRow("Pending Approval", "10"),
                ],
              ),
            ),

            // 4. Activities Card (Scrollable Version)
            // TODO: link employee's activity within the activity card
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      "Activities", 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Fixed height container to enable internal scrolling
                  SizedBox(
                    height: 150, // Set the height you want for the scrollable area
                    child: Scrollbar(
                      controller: _activityScrollController,
                      thumbVisibility: true, // Makes the scrollbar visible like in your design
                      child: ListView.builder(
                        controller: _activityScrollController,
                        padding: const EdgeInsets.only(right: 10), // Space for the scrollbar
                        itemCount: 10, // Replace with your actual list length later
                        itemBuilder: (context, index) {
                          return _buildActivityItem("Activity ${index + 1}");
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CLOCK IN FUNCTION ---
  void _clockIn() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(child: CircularProgressIndicator()));

        //1. Get User's Current GPS Position
        Position position = await _getCurrentLocation() ?? await Geolocator.getCurrentPosition();
        
        //2. Calculate Distance from Office
        double distanceInMeters = Geolocator.distanceBetween(
          position.latitude, 
          position.longitude, 
          officeLat, 
          officeLng
        );

        //3. Check if user is within the allowed radius (e.g., 100m)
        if (distanceInMeters <= maxDistanceInMeters) {
          
          // Success: User is at the office
          GeoPoint currentGeoPoint = GeoPoint(position.latitude, position.longitude);

          String? error = await _authService.clockInUser(
            uid: user.uid,
            deptCode: deptCode,
            location: currentGeoPoint, // Pass this once you uncomment GPS logic
          );

          Navigator.pop(context); // Close loading indicator

          if (error == null) {
            setState(() {
              _isClockedIn = true;
              _startTime = DateTime.now();
            });

            _startTimerTicker();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Clock-in successful! You are on-site."), backgroundColor: Colors.green)
            );
          }
        } else {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Too far from office: ${distanceInMeters.toStringAsFixed(0)}m"), backgroundColor: Colors.red)
          );
        }
      } catch (e) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _clockOutLogic() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Show loading while talking to Firebase
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()));

      // Call the new service function
      String? error = await _authService.clockOutUser(uid: user.uid);

      Navigator.pop(context); // Close loading

      if (error == null) {
        _timer?.cancel();
        _timer = null;

        setState(() {
          _isClockedIn = false;
          _workingHours = "00:00:00";
          _startTime = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Clock-out recorded in Firebase!"), backgroundColor: Colors.orange),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // This handles the UI pop-up
  void _showClockOutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Clock Out", style: TextStyle(fontWeight:FontWeight(5)),),
          content: const Text("Are you sure you want to end your shift?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.black),),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _clockOutLogic();       // Run the reset logic
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
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

  // Helper for Summary Rows
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: primaryBlue),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(value, textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Helper for Activity Items
  Widget _buildActivityItem(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
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

  Future<void> _loadEmployeeCount() async {
    if (deptCode == "Loading...") return; // Wait until we have the deptCode

    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('deptCode', isEqualTo: deptCode)
        .where('role', isEqualTo: 'Employee')
        .get();

    if (mounted) {
      setState(() {
        _totalEmployees = querySnapshot.docs.length;
      });
    }
  }
}