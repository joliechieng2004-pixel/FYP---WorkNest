import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:worknest/manager/manager_profile.dart';
import 'package:worknest/manager/manager_report.dart';
import 'package:worknest/manager/manager_schedule.dart';
import 'manager_employee.dart';

class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key});

  @override
  State<ManagerHome> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHome> {
  bool _isLoading = true;

  // for navigation
  int _selectedIndex = 0;
  // often use colors
  final Color primaryBlue = const Color.fromARGB(255, 40, 75, 158);
  final Color bgLightBlue = const Color.fromARGB(255, 240, 250, 255);

  final ScrollController _activityScrollController = ScrollController();
  String deptCode = "Loading...";
  String lName = "Name";

  // ignore: unused_field
  int _totalEmployees = 0;

  // --- INITIALIZATION ---
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() async {
    await _loadManagerData();
    await _loadEmployeeCount();
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
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
      _buildHomeDashboard(deptCode),                         // Index 0 - Home Page
      ManagerSchedule(deptCode: deptCode),                  // Index 1 - Schedule Page
      ManagerEmployee(deptCode: deptCode),                  // Index 2 - Employee Page
      ManagerReportPage(deptCode: deptCode),                // Index 3 - Report Page
      ManagerProfile(deptCode: deptCode),                   // Index 4 - Profile Page
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
          print("Swithcing to index: $index");
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
          BottomNavigationBarItem(icon: Icon(Icons.people_alt), label: "Staff"),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: "Tasks"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  SafeArea _buildHomeDashboard(String deptCode) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
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

            _buildCard(
              child: _buildReportsTab(deptCode)
            ),

            const SizedBox(height: 10),
        
            // 1. Dept Code Card
            _buildCard(
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const Expanded(
                    flex: 5,
                    child: Text(
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
            child: Text(value, textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
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

  Widget _buildStatChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: bgLightBlue,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 5),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab(String deptCode) {
    // 1. Define 'Today' at Midnight for the query
    DateTime now = DateTime.now();
    Timestamp todayStart = Timestamp.fromDate(DateTime(now.year, now.month, now.day));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendances')
          .where('deptCode', isEqualTo: deptCode)
          .where('attendanceDate', isEqualTo: todayStart)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        // 2. Calculate Metrics from the snapshot
        int totalPresent = snapshot.data!.docs.length;
        int lateCount = snapshot.data!.docs.where((d) => d['attendanceStatus'] == "Late").length;
        int onTimeCount = snapshot.data!.docs.where((d) => d['attendanceStatus'] == "On-Time").length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Today's Overview", 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A3E88))),
              const SizedBox(height: 20),
              
              // 3. The Summary Row
              Row(
                children: [
                  _buildStatChip("Present", totalPresent.toString(), Colors.blue),
                  const SizedBox(width: 10),
                  _buildStatChip("On-Time", onTimeCount.toString(), Colors.green),
                  const SizedBox(width: 10),
                  _buildStatChip("Late", lateCount.toString(), Colors.orange),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // 4. Visual Progress Section (Great for FYP marks!)
              const Text("Punctuality Rate", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: totalPresent == 0 ? 0 : onTimeCount / totalPresent,
                  minHeight: 12,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ),
              const SizedBox(height: 5),
              Text("${totalPresent == 0 ? 0 : ((onTimeCount / totalPresent) * 100).toInt()}% of arrived staff are on time",
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              
              const SizedBox(height: 40),
              
              // 5. Quick Actions or Notifications
              if (lateCount > 0)
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text("$lateCount staff members arrived after the grace period today.",
                          style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}