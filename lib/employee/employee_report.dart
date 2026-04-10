import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:worknest/services/attendance_count.dart';
import 'package:worknest/services/pdf_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:worknest/utils/app_colors.dart';

class EmployeeReport extends StatefulWidget {
  final String deptCode;
  final String employeeID;

  const EmployeeReport({super.key, required this.deptCode, required this.employeeID});

  @override
  State<EmployeeReport> createState() => _EmployeeReportPageState();
}

class _EmployeeReportPageState extends State<EmployeeReport> {
  final ScrollController _timesheetScrollController = ScrollController();
  final ScrollController _absentScrollController = ScrollController();

  String _selectedPeriod = "Weekly";
  
  Stream<ReportData>? _masterReportStream;
  List<QueryDocumentSnapshot> _currentDocs = [];
  List<Map<String, dynamic>> _currentAbsences = [];

  // --- INITIALIZATION ---
  @override
  void initState() {
    super.initState();
    debugPrint(widget.employeeID);
    _initStreams(); 
  }

  @override
  void dispose() {
    _timesheetScrollController.dispose();
    _absentScrollController.dispose();
    super.dispose(); 
  }

  // Helper for safe date conversion
  DateTime? _safeDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // --- STREAM LOGIC ---
  void _initStreams() {
    DateTime startDate = _getStartDate(_selectedPeriod);
    DateTime endDate = DateTime.now(); 

    var schedulesStream = FirebaseFirestore.instance.collection('shifts')
        .where('shiftUserID', isEqualTo: widget.employeeID) 
        .where('shiftDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('shiftDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .where('shiftStatus', isEqualTo: 'accepted')
        .snapshots();

    var leavesStream = FirebaseFirestore.instance.collection('leaves')
        .where('leaveUserID', isEqualTo: widget.employeeID) 
        .where('leaveDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('leaveDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .where('leaveStatus', isEqualTo: 'approved')
        .snapshots();

    var attendancesStream = FirebaseFirestore.instance.collection('attendances')
        .where('attendanceUserID', isEqualTo: widget.employeeID)
        .where('attendanceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('attendanceDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('attendanceDate', descending: true)
        .snapshots();

    _masterReportStream = Rx.combineLatest3(
      schedulesStream,
      leavesStream,
      attendancesStream,
      (QuerySnapshot schedules, QuerySnapshot leaves, QuerySnapshot attendances) {
        List<Map<String, dynamic>> absentList = _calculateAbsences(
          schedules.docs, leaves.docs, attendances.docs
        );
        return ReportData(absentList, attendances.docs);
      }
    );
  }

  // --- Employee View Absence Logic ---
  List<Map<String, dynamic>> _calculateAbsences(
    List<QueryDocumentSnapshot> schedules,
    List<QueryDocumentSnapshot> leaves,
    List<QueryDocumentSnapshot> attendances,
  ) {
    List<Map<String, dynamic>> absences = [];
    DateFormat dateKeyFormat = DateFormat('yyyyMMdd');
    
    for (var shift in schedules) {
      var shiftData = shift.data() as Map<String, dynamic>;
      if (shiftData['shiftDate'] == null) continue;

      DateTime shiftDate = (shiftData['shiftDate'] as Timestamp).toDate();
      
      // Eliminate future shifts
      if (shiftDate.isAfter(DateTime.now())) continue;

      // Eliminate ongoing shifts
      DateTime? shiftEndTime = shiftData['shiftEndTime'] != null ? (shiftData['shiftEndTime'] as Timestamp).toDate() : null;
      if (shiftEndTime != null && shiftEndTime.isAfter(DateTime.now())) continue;

      // Eliminate shift with ANY attendance
      bool hasAttendance = attendances.any((att) {
        var attData = att.data() as Map<String, dynamic>;
        DateTime? attDate = _safeDate(attData['attendanceDate']);
        if (attDate == null) return false;
        return dateKeyFormat.format(shiftDate) == dateKeyFormat.format(attDate);
      });

      if (hasAttendance) continue;

      // Eliminate shift with leave
      bool hasLeave = leaves.any((leave) {
        var leaveData = leave.data() as Map<String, dynamic>;
        DateTime? leaveDate = _safeDate(leaveData['leaveDate']);
        if (leaveDate == null) return false;
        
        return dateKeyFormat.format(shiftDate) == dateKeyFormat.format(leaveDate); 
      });

      if (hasLeave) continue;

      //Others all are absence
      absences.add(shiftData);
    }
    return absences;
  }

  // --- BUILD WIDGETS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLightBlue,
      appBar: AppBar(
        title: const Text("Report"),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A3E88),
        foregroundColor: Colors.white,
      ),
      // Use Column instead of SingleChildScrollView for Expanded layout to work
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),     
              // 1. Overall Attendance & Period Toggle at top
              _buildCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const Expanded(flex: 5, child: Text("My Overall Attendance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FutureBuilder<double>(
                        future: AttendanceCount.getAttendanceRate(widget.employeeID),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                          return Text("${snapshot.data?.toStringAsFixed(0)}%");
                        },
                      ),
                    )
                  ],
                )),

              _buildCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const Expanded(flex: 5, child: Text("My Total Absence", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FutureBuilder<int>(
                        future: AttendanceCount.getAbsentCount(widget.employeeID),
                        builder: (context, snapshot) {
                          if (snapshot.hasError){
                            debugPrint("Error: $snapshot.error");
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                          return Text("${snapshot.data?.toStringAsFixed(0)}");
                        },
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 10),

              _buildPeriodToggle(),

              const SizedBox(height: 10),

              // Single StreamBuilder for both lists
              SizedBox(
                height: 800,
                child: StreamBuilder<ReportData>(
                  stream: _masterReportStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text("Error loading data"));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    _currentDocs = snapshot.data?.attendances ?? []; 
                    _currentAbsences = snapshot.data?.absentList ?? []; 

                    return Column(
                      children: [
                        // Absent List
                        Expanded(
                          flex: 1,
                          child: _buildCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Center(
                                  child: Text("Missed Shifts", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                                ),
                                const Divider(color: Colors.redAccent),
                                Expanded(
                                  child: _currentAbsences.isEmpty 
                                    ? const Center(child: Text("Perfect attendance! No missed shifts.", style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)))
                                    : Scrollbar(
                                        controller: _absentScrollController,
                                        thumbVisibility: true,
                                        child: ListView.separated(
                                          controller: _absentScrollController,
                                          itemCount: _currentAbsences.length,
                                          separatorBuilder: (context, index) => const Divider(height: 1),
                                          itemBuilder: (context, i) {
                                            final data = _currentAbsences[i];
                                            DateTime date = (data['shiftDate'] as Timestamp).toDate();

                                            // Inline formatting for the subtitle (startTime - endTime)
                                            String startTime = data['shiftStartTime'] != null 
                                                ? DateFormat('hh:mm a').format((data['shiftStartTime'] as Timestamp).toDate()) 
                                                : "--:--";
                                            String endTime = data['shiftEndTime'] != null 
                                                ? DateFormat('hh:mm a').format((data['shiftEndTime'] as Timestamp).toDate()) 
                                                : "--:--";

                                            return ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                                              title: Text(
                                                DateFormat('dd MMM yyyy').format(date), 
                                                style: const TextStyle(fontWeight: FontWeight.bold)
                                              ),
                                              subtitle: Text("$startTime - $endTime"),
                                            );
                                          },
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Attendance List
                        Expanded(
                          flex: 2,
                          child: _buildCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Center(
                                  child: Text("Timesheet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                                const Divider(color: Color(0xFF1A3E88)),
                                Expanded(
                                  child: _currentDocs.isEmpty 
                                    ? const Center(child: Text("No attendance records found."))
                                    : Scrollbar(
                                        controller: _timesheetScrollController,
                                        thumbVisibility: true,
                                        child: ListView.separated(
                                          controller: _timesheetScrollController,
                                          padding: const EdgeInsets.only(right: 10),
                                          itemCount: _currentDocs.length,
                                          separatorBuilder: (context, index) => const Divider(),
                                          itemBuilder: (context, index) {
                                            var data = _currentDocs[index].data() as Map<String, dynamic>;

                                            DateTime? start = _safeDate(data['attendanceStartTime']);
                                            DateTime? end = _safeDate(data['attendanceEndTime']);
                                            DateTime? date = _safeDate(data['attendanceDate']);

                                            String formattedDate = date != null ? DateFormat('dd MMM').format(date) : "--";
                                            String formattedIn = start != null ? DateFormat('hh:mm a').format(start) : "--:--";
                                            String formattedOut = end != null ? DateFormat('hh:mm a').format(end) : "--:--";
                                            String status = data['attendanceStatus'] ?? "Extra";
                                            String approval = data['attendanceApproval'] ?? "Pending";

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
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              // Export PDF Button
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Export My Report", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bgLightBlue,
                  foregroundColor: AppColors.primaryBlue,
                  side: const BorderSide(width: 2, color: AppColors.primaryBlue),
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  if (_currentDocs.isEmpty && _currentAbsences.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("No data available for the selected period.")),
                    );
                    return;
                  }
                  
                  int attendedCount = _currentDocs.length;
                  int absentCount = _currentAbsences.length;
                  int totalScheduled = attendedCount + absentCount;
                  double attendanceRate = totalScheduled == 0 ? 0.0 : (attendedCount / totalScheduled) * 100;

                  PdfExportService.exportAttendanceReport(
                    title: "My Attendance Report",
                    docs: _currentDocs, 
                    absentShifts: _currentAbsences, 
                    period: _selectedPeriod,
                    userRole: 'employee',
                    attendanceRate: attendanceRate,
                    absentCount: absentCount,
                  );
                },
              ),

              const SizedBox(height: 10),
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
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBlue, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: child,
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
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("In: $clockIn", style: const TextStyle(fontSize: 14)),
                Text("Out: $clockOut", style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  duration,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 14),
                ),
                Text(
                  approval,
                  style: TextStyle(fontWeight: FontWeight.bold, color: approvalColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- PERIOD TOGGLE ---
  Widget _buildPeriodToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          showSelectedIcon: false, 
          segments: const [
            ButtonSegment(value: "Weekly", label: Center(child: Text("Week"))),
            ButtonSegment(value: "Monthly", label: Center(child: Text("Month"))),
            ButtonSegment(value: "Yearly", label: Center(child: Text("Year"))),
          ],
          selected: {_selectedPeriod},
          onSelectionChanged: (Set<String> newSelection) {
            setState(() {
              _selectedPeriod = newSelection.first;
              _initStreams(); // Automatically bind to new date constraints on tap
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

  DateTime _getStartDate(String period) {
    DateTime now = DateTime.now();
    switch (period) {
      case "Weekly":
        DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1))
            .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
        return startOfWeek;
      case "Monthly":
        return DateTime(now.year, now.month, 1);
      case "Yearly":
        return DateTime(now.year, 1, 1);
      default:
        return now;
    }
  }
}

class ReportData {
  final List<Map<String, dynamic>> absentList;
  final List<QueryDocumentSnapshot> attendances;
  ReportData(this.absentList, this.attendances);
}