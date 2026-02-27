import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:worknest/services/auth_service.dart';
import 'package:geolocator/geolocator.dart';

class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key});

  @override
  State<ManagerHome> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHome> {
  final AuthService _authService = AuthService();

  final Color primaryBlue = const Color.fromARGB(255, 40, 75, 158);
  final Color bgLightBlue = const Color.fromARGB(255, 240, 250, 255);
  
  final ScrollController _activityScrollController = ScrollController();
  String deptCode = "Loading...";
  String lName = "Name";
  
  // Example: Coordinates for your office
  // TODO: change to manager provided location
  // TODO: let manager provide radius allowed
  final double officeLat = 37.421983;
  final double officeLng = -122.084049;
  final double maxDistanceInMeters = 100.0; // The radius allowed (m)

  String formattedDate = DateFormat('EEEE, d MMM yyyy').format(DateTime.now());
  String formattedTime = DateFormat('h:mm a').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadManagerData();
  }

  @override
  void dispose() {
    _activityScrollController.dispose(); // Clean up the controller
    super.dispose();
  }

  // Fetch the current manager's department details
  void _loadManagerData() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLightBlue,
      body: SafeArea(
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
                      "Hi, Manager $lName", 
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
                    Text(formattedDate, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(formattedTime, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C2A0), // Teal Green
                        foregroundColor: Colors.white,
                        minimumSize: const Size(250, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: _clockIn,
                      child: const Text("Clock In", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    )
                  ],
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
      ),
    );
  }

  void _clockIn() async {
  User? user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    try {
      showDialog(context: context, builder: (context) => const Center(child: CircularProgressIndicator()));

      // 1. Get User's Current GPS Position
      Position position = await _getCurrentLocation() ?? await Geolocator.getCurrentPosition();
      
      // 2. Calculate Distance from Office
      double distanceInMeters = Geolocator.distanceBetween(
        position.latitude, 
        position.longitude, 
        officeLat, 
        officeLng
      );

      // 3. Check if user is within the allowed radius (e.g., 100m)
      if (distanceInMeters <= maxDistanceInMeters) {
        // Success: User is at the office
        GeoPoint currentGeoPoint = GeoPoint(position.latitude, position.longitude);

        String? error = await _authService.clockInUser(
          uid: user.uid,
          deptCode: deptCode,
          location: currentGeoPoint,
        );

        Navigator.pop(context); // Close loading

        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Clock-in successful! You are on-site."), backgroundColor: Colors.green)
          );
        }
      } else {
        // Failure: User is too far away
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Clock-in failed. You are ${distanceInMeters.toStringAsFixed(0)}m away from the office."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}
}