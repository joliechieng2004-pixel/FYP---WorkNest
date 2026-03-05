import 'package:flutter/material.dart';
import 'package:worknest/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class ManagerSchedule extends StatefulWidget {
  final String deptCode;

  const ManagerSchedule({super.key, required this.deptCode});

  @override
  State<ManagerSchedule> createState() => _ManagerSchedulePageState();
}

class _ManagerSchedulePageState extends State<ManagerSchedule> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;


  final AuthService _authService = AuthService();
  // often use colors
  final Color primaryBlue = const Color.fromARGB(255, 40, 75, 158);
  final Color bgLightBlue = const Color.fromARGB(255, 240, 250, 255);

  final ScrollController _activityScrollController = ScrollController();
  String deptCode = "Loading...";
  String lName = "Name";
  String formattedDate = DateFormat('EEEE, d MMM yyyy').format(DateTime.now());
  String formattedTime = DateFormat('h:mm a').format(DateTime.now());

  // --- INITIALIZATION ---
  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay; // Default selection to today
  }

  @override
  void dispose() {
    _activityScrollController.dispose(); // Clean up the controller
    super.dispose(); 
  }

  // --- BUILD WIDGETS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLightBlue,
      appBar: AppBar(
        title: const Text("Manage Schedule"),
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
              // 1. Calendar
              Card(
                margin: const EdgeInsets.all(10),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: TableCalendar(
                  firstDay: DateTime.utc(2025, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) {
                    // Tells the calendar which day to highlight as "selected"
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay; // update focusedDay as well
                    });
                    
                    // TODO: Fetch shifts from Firestore for this specific date!
                    print("Selected Date: $_selectedDay");
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  // Custom Styling
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                    selectedDecoration: BoxDecoration(color: Color(0xFF1A3E88), shape: BoxShape.circle),
                    markerDecoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle), // For shifts
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                  ),
                ),
              ),

              // 2. Worker List
              _buildCard(
                color: bgLightBlue,
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: const Text(
                        "Worker List",
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

              // 3. Leave Requests (Scrollable Version)
              // TODO: link employee's activity within the activity card
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        "Leave Requests", 
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

              // 4. Shift Summary
              _buildCard(
                child: Column(
                  children: [
                    _buildStatRow("Pending Leave", "20"),
                    _buildStatRow("Pending Shift", "20"),
                    _buildStatRow("Accepted Shift", "10"),
                    _buildStatRow("Rejected Shift", "10"),
                  ],
                ),
              ),
            ],
          ),
        ),
      )
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
}