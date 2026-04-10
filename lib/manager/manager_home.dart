// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:worknest/manager/manager_profile.dart';
import 'package:worknest/manager/manager_report.dart';
import 'package:worknest/manager/manager_schedule.dart';
import 'package:worknest/services/auth_wrapper.dart';
import 'package:worknest/utils/app_colors.dart';
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

  final ScrollController _activityScrollController = ScrollController();
  String deptCode = "Loading...";
  String deptName = "Loading...";
  String lName = "Name";

  String _selectedPeriod = "All";

  // --- INITIALIZATION ---
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() async {
    await _loadManagerData();
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

      deptCode = userDoc['deptCode'];

      DocumentSnapshot deptDoc = await FirebaseFirestore.instance
          .collection('departments')
          .doc(deptCode)
          .get();
          
      setState(() {
        deptName = deptDoc['deptName'];
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
    
    final List<Widget> pages = [
      _buildHomeDashboard(deptCode),                        // Index 0 - Home Page
      ManagerSchedule(deptCode: deptCode),                  // Index 1 - Schedule Page
      ManagerEmployee(deptCode: deptCode),                  // Index 2 - Employee Page
      ManagerReportPage(deptCode: deptCode),                // Index 3 - Report Page
      ManagerProfile(deptCode: deptCode),                   // Index 4 - Profile Page
    ];

    return Scaffold(
      backgroundColor: AppColors.bgLightBlue,
      body: pages[_selectedIndex],

      // Fixed Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Required for 5 items
        backgroundColor: const Color(0xFF1A3E88), // Dark Blue
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        currentIndex: _selectedIndex,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        onTap: (index) {
          debugPrint("Swithcing to index: $index");
          setState(() {
            _selectedIndex = index; // This triggers the UI refresh
          });
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
            // 1. Top Greeting Row
            Row(
              children: [
                Expanded(
                  flex: 9,
                  child: Text(
                    "$deptName: Manager", 
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 1,
                  child: IconButton.outlined(
                    icon: const Icon(Icons.logout, color: AppColors.primaryBlue),
                    onPressed: _showLogoutConfirmation
                  ),
                ),
              ]),

            const SizedBox(height: 10),

            // 2. Dept Code Card
            _buildCard(
              color: Colors.white,
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
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                        letterSpacing: 5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 3. Today's Attendance
            const Text("Today's Attendance Overview", 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),            
            _buildCard(
              child: _buildTodayOverview(deptCode)
            ),

            const SizedBox(height: 10),

            // 4. Report Tab
            const Text("Department's Attendance Overview", 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),            
            _buildCard(child: _buildReportsTab()),

            const SizedBox(height: 10),
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
        border: Border.all(color: AppColors.primaryBlue, width: 2),
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

  Widget _buildStatChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.bgLightBlue,
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

  Widget _buildTodayOverview(String deptCode) {
    // Define 'Today' at Midnight for the query
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

        int totalPresent = snapshot.data!.docs.length;
        int lateCount = snapshot.data!.docs.where((d) => d['attendanceStatus'] == "Late").length;
        int onTimeCount = snapshot.data!.docs.where((d) => d['attendanceStatus'] == "On-Time").length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // The Summary Row
              Row(
                spacing: 7,
                children: [
                  _buildStatChip("Present", totalPresent.toString(), Colors.blue),
                  _buildStatChip("On-Time", onTimeCount.toString(), Colors.green),
                  _buildStatChip("Late", lateCount.toString(), Colors.red),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // Quick Actions or Notifications
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

  // --- PERIOD TOGGLE ---
  Widget _buildPeriodToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          showSelectedIcon: false, 
          segments: const [
            ButtonSegment(
              value: "All", 
              label: Center(child: Text("All")),
            ),
            ButtonSegment(
              value: "Weekly", 
              label: Center(child: Text("Week")),
            ),
            ButtonSegment(
              value: "Monthly", 
              label: Center(child: Text("Month")),
            ),
            ButtonSegment(
              value: "Yearly", 
              label: Center(child: Text("Year")),
            ),
          ],
          selected: {_selectedPeriod},
          onSelectionChanged: (Set<String> newSelection) {
            setState(() {
              _selectedPeriod = newSelection.first;
            });
          },
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.primaryBlue,
            selectedForegroundColor: AppColors.bgLightBlue,
            visualDensity: VisualDensity.comfortable,
            side: const BorderSide(width: 1, color: Colors.grey),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  DateTime _getStartTime(String period) {
    DateTime now = DateTime.now();
    switch (period) {
      case "All":
        return DateTime(2000, 1, 1);
      case "Weekly":
        // Gets the start of the current week (Monday)
        DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1))
            .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
        return startOfWeek;
      case "Monthly":
        // Gets the 1st day of the current month
        return DateTime(now.year, now.month, 1);
      case "Yearly":
        // Gets Jan 1st of the current year
        return DateTime(now.year, 1, 1);
      default:
        return now;
    }
  }

  Widget _buildReportsTab() {
    DateTime startDate = _getStartTime(_selectedPeriod);
    
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildPeriodToggle(),

          const SizedBox(height: 20),
          
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('attendances')
                .where('deptCode', isEqualTo: deptCode)
                .where('attendanceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              if (snapshot.hasError) debugPrint(snapshot.error as String?);
              
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text("No records found."));
              
              final stats = _calculateStats(docs);
              
              return Column(
                children: [
                  // --- Section 1: Status ---
                  Row(
                    spacing: 7,
                    children: [
                      // Access the values using the keys defined in the Map
                      _buildStatChip("Total", "${stats['total']}", Colors.blue),
                      _buildStatChip("On-Time", "${stats['onTime']}", Colors.green),
                      _buildStatChip("Late", "${stats['late']}", Colors.red),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.bgLightBlue,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.withOpacity(0.5), width: 5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Extra:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                              Text("${stats['extra']}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.withOpacity(0.8))),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
              
                  // --- Section 2: Chart ---
                  _buildSimpleBarChart(stats['onTime']!, stats['late']!),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildSimpleBarChart(int onTime, int late) {
    int total = onTime + late;
    // Prevent division by zero
    double onTimeWidth = total == 0 ? 0.5 : (onTime / total);
    double lateWidth = total == 0 ? 0.5 : (late / total);

    return Column(
      children: [
        const Text("Punctuality Distribution", 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: AppColors.primaryBlue, width: 2),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLegendItem("On-Time", Colors.green, "${(onTimeWidth * 100).toInt()}%"),
                  _buildLegendItem("Late", Colors.orange, "${(lateWidth * 100).toInt()}%"),
                ],
              ),
              
              const SizedBox(height: 10),
              
              // The actual Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  children: [
                    // On-Time Segment
                    Expanded(
                      flex: (onTimeWidth * 100).toInt().clamp(1, 100),
                      child: Container(height: 30, color: Colors.green),
                    ),
                    // Late Segment
                    Expanded(
                      flex: (lateWidth * 100).toInt().clamp(1, 100),
                      child: Container(height: 30, color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildLegendItem(String label, Color color, String percentage) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text("$label ($percentage)", style: const TextStyle(fontSize: 14, color: Colors.black87)),
      ],
    );
  }

  Map<String, int> _calculateStats(List<QueryDocumentSnapshot> docs) {
    int onTime = 0;
    int late = 0;
    int extra = 0;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      
      final String status = data['attendanceStatus']?.toString() ?? 'Extra';

      // Increment the correct counter in one single loop
      switch (status) {
        case 'On-Time':
          onTime++;
          break;
        case 'Late':
          late++;
          break;
        default:
          extra++;
          break;
      }
    }

    // Return everything in a tidy Map
    return {
      'onTime': onTime,
      'late': late,
      'extra': extra,
      'total': docs.length,
    };
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.logout, color: AppColors.primaryBlue),
              SizedBox(width: 10),
              Text("Confirm Logout"),
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