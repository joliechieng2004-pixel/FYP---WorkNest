import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EmployeeReport extends StatefulWidget {
  final String deptCode;
  final String workerID;

  const EmployeeReport({super.key, required this.deptCode, required this.workerID});

  @override
  State<EmployeeReport> createState() => _EmployeeReportPageState();
}

class _EmployeeReportPageState extends State<EmployeeReport> {
  // often use colors
  final Color primaryBlue = const Color.fromARGB(255, 40, 75, 158);
  final Color bgLightBlue = const Color.fromARGB(255, 240, 250, 255);
  
  final ScrollController _timesheetScrollController = ScrollController();
  Stream<QuerySnapshot>? _attendanceStream;

  // --- INITIALIZATION ---
  @override
  void initState() {
    super.initState();
    debugPrint(widget.workerID);
    _initAttendanceStream();
  }

  @override
  void dispose() {
    _timesheetScrollController.dispose(); // Clean up the controller
    super.dispose(); 
  }

  // --- BUILD WIDGETS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLightBlue,
      appBar: AppBar(
        title: const Text("Report"),
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
              // Shift Summary
              _buildCard(
                child: Column(
                  children: [
                    const Text(
                          "Personal Summary",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                    const Divider(color: Color(0xFF1A3E88)),
                    _buildStatRow("Attendance Rate", "20"),
                    _buildStatRow("Punctuality Rate", "20"),
                    _buildStatRow("Total Absence", "10"),
                  ],
                ),
              ),

              // Leave Requests (Scrollable Version)
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                          "Timesheet",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                    ),
                    const Divider(color: Color(0xFF1A3E88)),
                    const SizedBox(height: 10),
                    
                    // Fixed height container to enable internal scrolling
                    SizedBox(
                      height: 300, // Set the height you want for the scrollable area
                      child: Scrollbar(
                        controller: _timesheetScrollController,
                        thumbVisibility: true, // Makes the scrollbar visible like in your design
                        child: // Inside your Leave Requests _buildCard
                          StreamBuilder<QuerySnapshot>(
                            stream: _attendanceStream,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                debugPrint("Firestore Error: ${snapshot.error}");
                                return const Center(child: Text("Error loading data"));
                              }
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return const Center(child: Text("No attendance records found."));
                              }

                              final docs = snapshot.data!.docs;

                              return ListView.separated(
                                controller: _timesheetScrollController,
                                shrinkWrap: true,
                                padding: const EdgeInsets.only(right: 10),
                                itemCount: docs.length,
                                separatorBuilder: (context, index) => const Divider(),
                                itemBuilder: (context, index) {
                                  var data = docs[index].data() as Map<String, dynamic>;

                                  DateTime? safeConvertToDateTime(dynamic value) {
                                    if (value == null) return null;
                                    if (value is Timestamp) return value.toDate();
                                    if (value is String) return DateTime.tryParse(value);
                                    return null;
                                  }

                                  // 1. Convert safely using the helper
                                  DateTime? start = safeConvertToDateTime(data['attendanceStartTime']);
                                  DateTime? end = safeConvertToDateTime(data['attendanceEndTime']);
                                  DateTime? date = safeConvertToDateTime(data['attendanceDate']);

                                  // 2. Format Strings
                                  String formattedDate = date != null ? DateFormat('dd MMM').format(date) : "--";
                                  String formattedIn = start != null ? DateFormat('hh:mm a').format(start) : "--:--";
                                  String formattedOut = end != null ? DateFormat('hh:mm a').format(end) : "--:--";
                                  String status = data['attendanceStatus'] ?? "Unscheduled";
                                  String approval = data['attendanceApproval'] ?? "Pending";

                                  // 3. Calculate Duration
                                  String duration = "--";
                                  if (start != null && end != null) {
                                    Duration diff = end.difference(start);
                                    duration = "${diff.inHours}h ${diff.inMinutes.remainder(60)}m";
                                  }

                                  return _buildTimesheetRow(
                                    date: formattedDate,
                                    clockIn: formattedIn,
                                    clockOut: formattedOut,
                                    duration: duration,
                                    status: status,
                                    approval: approval,
                                  );
                                },
                              );
                            },
                          )
                      ),
                    ),
                  ],
                ),
              ),
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

  Widget _buildTimesheetRow({
    required String date,
    required String clockIn,
    required String clockOut,
    required String duration,
    required String approval,
    required String status,
  }) {
    // Define color based on status
    Color statusColor = status == "On-Time" 
        ? Colors.green 
        : status == "Late" ? Colors.red : Colors.orange;
    
    Color approvalColor = approval == "Approved" 
        ? Colors.green 
        : approval == "Rejected" ? Colors.red : Colors.orange;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // Date Column
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // Time Info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("In: $clockIn", style: const TextStyle(fontSize: 15)),
                Text("Out: $clockOut", style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
          // Duration Info
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  duration,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
                Text(
                  approval,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.bold, color: approvalColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _initAttendanceStream() {
    // We initialize the stream ONCE here.
    // This prevents the flickering issue.
    _attendanceStream = FirebaseFirestore.instance
        .collection('attendances')
        .where('attendanceUserId', isEqualTo: widget.workerID)
        .orderBy('attendanceDate', descending: true)
        .snapshots();
  }
}