import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:worknest/services/pdf_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:worknest/utils/app_colors.dart';

class ManagerReportPage extends StatefulWidget {
  final String deptCode;

  const ManagerReportPage({super.key, required this.deptCode});

  @override
  State<ManagerReportPage> createState() => _ManagerReportPageState();
}

class _ManagerReportPageState extends State<ManagerReportPage> {
  int? _expandedIndex;
  String _selectedPeriod = "All";

  final Map<String, TextEditingController> _reasonControllers = {};

  // The master stream variable
  late Stream<ReportData> _masterReportStream;

  @override
  void initState() {
    super.initState();
    _initStreams(); // Initialize the stream immediately
  }

  // Centralized stream initialization
  void _initStreams() {
    DateTime startDate = _getStartTime(_selectedPeriod);
    DateTime endDate = DateTime.now(); // Upper bound to prevent fetching future absences
    
    // a. Load Shifts
    var schedulesStream = FirebaseFirestore.instance.collection('shifts')
        .where('deptCode', isEqualTo: widget.deptCode)
        .where('shiftDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('shiftDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .where('shiftStatus', isEqualTo: 'accepted')
        .snapshots();

    // b. Load Leaves
    var leavesStream = FirebaseFirestore.instance.collection('leaves')
        .where('deptCode', isEqualTo: widget.deptCode)
        .where('leaveDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('leaveDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .where('leaveStatus', isEqualTo: 'approved')
        .snapshots();

    // c. Load Attendances
    var attendancesStream = FirebaseFirestore.instance.collection('attendances')
        .where('deptCode', isEqualTo: widget.deptCode)
        .where('attendanceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .orderBy('attendanceDate', descending: true)
        .snapshots();

    // Combine all three streams into one ReportData object
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

  // Core comparison logic
  List<Map<String, dynamic>> _calculateAbsences(
    List<QueryDocumentSnapshot> schedules,
    List<QueryDocumentSnapshot> leaves,
    List<QueryDocumentSnapshot> attendances,
  ) {
    List<Map<String, dynamic>> absentList = [];
    DateFormat dateKeyFormat = DateFormat('yyyy-MM-dd');

    for (var shift in schedules) {
      var shiftData = shift.data() as Map<String, dynamic>;
      if (shiftData['shiftDate'] == null) continue;

      DateTime shiftDate = (shiftData['shiftDate'] as Timestamp).toDate();
      String shiftDateString = dateKeyFormat.format(shiftDate);
      String shiftUserId = shiftData['shiftUserID'] ?? ''; 

      // --- SHIFT LOGIC ---
      // Eliminate future shifts
      if (shiftDate.isAfter(DateTime.now())) continue;

      // Eliminate ongoing shifts
      DateTime? shiftEndTime = shiftData['shiftEndTime'] != null ? (shiftData['shiftEndTime'] as Timestamp).toDate() : null;
      if (shiftEndTime != null && shiftEndTime.isAfter(DateTime.now())) continue;

      // --- LEAVE LOGIC ---
      // Eliminate shift with approved leave
      bool hasLeave = leaves.any((leaveDoc) {
        var leaveData = leaveDoc.data() as Map<String, dynamic>;
        
        if (leaveData['leaveUserID'] != shiftUserId || leaveData['leaveDate'] == null) return false;
        
        return dateKeyFormat.format((leaveData['leaveDate'] as Timestamp).toDate()) == shiftDateString;
      });

      if (hasLeave) continue;

      // --- ATTENDANCE LOGIC ---
      // Eliminate shifts with ANY attendance
      bool hasAnyAttendance = attendances.any((attDoc) {
        var attData = attDoc.data() as Map<String, dynamic>;
        
        if (attData['attendanceUserID'] != shiftUserId || attData['attendanceDate'] == null) return false;
        
        String attDateString = dateKeyFormat.format((attData['attendanceDate'] as Timestamp).toDate());
        return attDateString == shiftDateString; 
      });

      if (hasAnyAttendance) continue;

      // Others are counted as absences
      absentList.add(shiftData);
    }

    return absentList;
  }

  @override
  void dispose() {
    // Clean up controllers when page closes
    for (var controller in _reasonControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Report"),
        centerTitle: true,
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppColors.bgLightBlue,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. The Period Toggle
              _buildPeriodToggle(),

              const SizedBox(height: 10),
              
              // 5. The Master StreamBuilder holding both sections
              SizedBox(
                height: 800,
                child: StreamBuilder<ReportData>(
                  stream: _masterReportStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      debugPrint("Firestore Error: ${snapshot.error}");
                      return const Center(child: Text("Something went wrong. Check console for Index URL."));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
          
                    final absentShifts = snapshot.data?.absentShifts ?? [];
                    final attendanceDocs = snapshot.data?.attendances ?? [];
          
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- ABSENT SHIFTS SECTION ---
                        const Padding(
                          padding: EdgeInsets.only(left: 20, top: 5),
                          child: Text("Absent / Unattended Shifts:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                        ),
                        Expanded(
                          flex: 1, // Takes up half the list space
                          child: _buildAbsentContainer(absentShifts),
                        ),

                        const SizedBox(height: 10),
          
                        // --- ATTENDANCE SECTION ---
                        const Padding(
                          padding: EdgeInsets.only(left: 20, top: 10),
                          child: Text("Attendance Log:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          flex: 2, // Takes up half the list space
                          child: _buildAttendanceContainer(attendanceDocs),
                        ),

                        const SizedBox(height: 10),
          
                        // --- EXPORT BUTTON ---
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text("Export Attendance Report", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primaryBlue,
                                side: const BorderSide(width: 2, color: AppColors.primaryBlue),
                                padding: const EdgeInsets.all(15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                              ),
                              onPressed: () {
                                if (attendanceDocs.isEmpty && absentShifts.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("No data available to export.")),
                                  );
                                  return;
                                }
                                // Updated call passing BOTH lists
                                PdfExportService.exportAttendanceReport(
                                  title: "Department Attendance Report",
                                  docs: attendanceDocs,
                                  absentShifts: absentShifts, // NEW PARAMETER
                                  period: _selectedPeriod,
                                  userRole: 'manager',
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ADDED: UI Container for Absent List
  Widget _buildAbsentContainer(List<Map<String, dynamic>> absentShifts) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red.shade900, width: 2), // Red border to stand out
      ),
      child: absentShifts.isEmpty 
        ? const Center(child: Text("No absent shifts for this period.", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))
        : ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            itemCount: absentShifts.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              var shift = absentShifts[index];
              DateTime? date = shift['shiftDate'] != null ? (shift['shiftDate'] as Timestamp).toDate() : null;
              String formattedDate = date != null ? DateFormat('dd MMM yyyy').format(date) : "No Date";
              
              return ListTile(
                leading: const Icon(Icons.warning, color: Colors.red),
                title: Text(shift['shiftUserName'] ?? 'Unknown Employee', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Expected Shift: $formattedDate"),
                trailing: const Text("Absent", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              );
            },
          ),
    );
  }

  // EXTRACTED: Original Attendance Container UI
  Widget _buildAttendanceContainer(List<QueryDocumentSnapshot> docs) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF1A3E88), width: 2),
      ),
      child: Column(
        children: [
          _buildCustomHeader(),
          const Divider(height: 1, color: Color(0xFF1A3E88)),
          Expanded(
            child: docs.isEmpty 
              ? const Center(child: Text("No records found for this period."))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    return _buildExpandableAttendanceRow(docs[index], index);
                  },
              ),
          ),
        ],
      ),
    );
  }

  // Header Row to match your table design
  Widget _buildCustomHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Center(child: Text("Date", style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(flex: 3, child: Center(child: Text("Employee", style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(flex: 2, child: Center(child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(flex: 1, child: Center(child: Text("", style: TextStyle(fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  // Each individual Attendance Row that expands
  Widget _buildExpandableAttendanceRow(DocumentSnapshot doc, int index) {
    Map<String, dynamic> attendance = doc.data() as Map<String, dynamic>;

    DateTime? day = attendance['attendanceDate'] is Timestamp ? (attendance['attendanceDate'] as Timestamp).toDate() : null;
    DateTime? start = attendance['attendanceStartTime'] is Timestamp ? (attendance['attendanceStartTime'] as Timestamp).toDate() : null;
    DateTime? end = attendance['attendanceEndTime'] is Timestamp ? (attendance['attendanceEndTime'] as Timestamp).toDate() : null;

    String formattedStartTime = start != null ? DateFormat.jm().format(start) : "--:--";
    String formattedEndTime = end != null ? DateFormat.jm().format(end) : "--:--";
    String formattedDate = day != null ? DateFormat('dd MMM yyyy').format(day) : "No Date";

    String formattedDuration = "--";
    if (start != null && end != null) {
      Duration diff = end.difference(start);
      formattedDuration = "${diff.inHours}h ${diff.inMinutes.remainder(60)}m";
    } else if (start != null) {
      formattedDuration = "In Progress";
    }

    String status = attendance['attendanceApproval']?.toString() ?? 'Pending';
    String employeeName = attendance['attendanceUserName']?.toString() ?? 'Unknown';
    String? approvalReason = attendance.containsKey('approvalReason') ? attendance['approvalReason'] : null;
    bool isExpanded = _expandedIndex == index;

    _reasonControllers.putIfAbsent(doc.id, () => TextEditingController());

    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedIndex = isExpanded ? null : index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: isExpanded ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(flex: 3, child: Center(child: Text(formattedDate))),
                Expanded(flex: 3, child: Center(child: Text(employeeName))),
                Expanded(
                  flex: 2, 
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        attendance['attendanceStatus'] ?? 'Extra',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: {
                            'Extra': Colors.orange,
                            'Late': Colors.red,
                          }[attendance['attendanceStatus']] ?? Colors.blue,
                        ),
                      ),
                      Text(
                        status, 
                        style: TextStyle(
                          fontSize: 10,
                          color: status == "Approved"
                            ? Colors.green
                            : status == "Pending"
                                ? Colors.orange
                                : Colors.red,
                        ),
                      ),
                    ],
                  )
                ),
                Expanded(flex: 1, child: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 18)),
              ],
            ),

            if (isExpanded) ...[
              const Divider(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, 
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text("In: $formattedStartTime", style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.green)),
                      Text("Out: $formattedEndTime", style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.red)),
                      Text("Duration: $formattedDuration", style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (status == 'Pending') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _actionButton("Reject", Colors.red, () => _updateAttendanceStatus(doc.id, "Rejected", null)),
                        const SizedBox(width: 20),
                        _actionButton("Approve", Colors.green, () => _updateAttendanceStatus(doc.id, "Approved", null)),
                      ],
                    ),
                  ]
                  else if (status != 'Pending' && approvalReason == null) ...[
                    TextField(
                      controller: _reasonControllers[doc.id],
                      decoration: const InputDecoration(
                        hintText: 'Reason for changing the approval status',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _actionButton("Reject", Colors.red, () {
                          String reason = _reasonControllers[doc.id]!.text.trim();
                          if (reason.isNotEmpty) {
                            _updateAttendanceStatus(doc.id, "Rejected", reason);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a reason")));
                          }
                        }),
                        const SizedBox(width: 20),
                        _actionButton("Approve", Colors.green, () {
                          String reason = _reasonControllers[doc.id]!.text.trim();
                          if (reason.isNotEmpty) {
                            _updateAttendanceStatus(doc.id, "Approved", reason);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a reason")));
                          }
                        }),
                      ],
                    ),
                  ]
                  else if (status != 'Pending' && approvalReason != null) ...[
                    TextField(
                      controller: TextEditingController(text: approvalReason), 
                      enabled: false, 
                      decoration: InputDecoration(
                        labelText: 'Reason for change to $status (Locked)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      style: const TextStyle(color: Colors.black87), 
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        "Status can no longer be changed.",
                        style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ]
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.black87),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 15),
      ),
      child: Text(label, style: const TextStyle(color: Colors.black87, fontSize: 12)),
    );
  }

  Future<void> _updateAttendanceStatus(String docId, String newStatus, String? reason) async {
    try {
      Map<String, dynamic> updateData = {
        'attendanceApproval': newStatus,
      };

      if (reason != null) {
        updateData['approvalReason'] = reason;
      }

      await FirebaseFirestore.instance
          .collection('attendances')
          .doc(docId)
          .update(updateData);

      if (reason != null && _reasonControllers.containsKey(docId)) {
        _reasonControllers[docId]!.clear();
      }

      if (mounted) {
        setState(() {
          _expandedIndex = null; 
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reason == null ? "Attendance $newStatus" : "Status changed and locked!"),
            backgroundColor: newStatus == "Approved" ? Colors.green : Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update status"), backgroundColor: Colors.red),
        );
      }
    }
  }

  DateTime _getStartTime(String period) {
    DateTime now = DateTime.now();
    switch (period) {
      case "All":
        return DateTime(2000, 1, 1);
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

  Widget _buildPeriodToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
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
              _initStreams();
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
}

class ReportData {
  final List<Map<String, dynamic>> absentShifts;
  final List<QueryDocumentSnapshot> attendances;
  ReportData(this.absentShifts, this.attendances);
}