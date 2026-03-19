import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:worknest/services/pdf_service.dart';

class ManagerReportPage extends StatefulWidget {
  final String deptCode;

  const ManagerReportPage({super.key, required this.deptCode});

  @override
  State<ManagerReportPage> createState() => _ManagerReportPageState();
}

class _ManagerReportPageState extends State<ManagerReportPage> {
  final Color primaryBlue = const Color.fromARGB(255, 40, 75, 158);
  final Color bgLightBlue = const Color.fromARGB(255, 240, 250, 255);
  int? _expandedIndex;
  String _selectedPeriod = "Weekly";
  
  Stream<QuerySnapshot>? _attendanceStream;
  
  @override
  void initState() {
    super.initState();
    // Initialize the stream once so it doesn't "restart" on every setState
    _attendanceStream = FirebaseFirestore.instance
        .collection('attendances')
        .where('deptCode', isEqualTo: widget.deptCode)
        .orderBy('attendanceDate', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Number of tabs
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Manage Reports"),
          centerTitle: true,
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.assignment_ind), text: "Attendance"),
              Tab(icon: Icon(Icons.bar_chart), text: "Reports"),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              // --- LEFT TAB: ATTENDANCE LOG ---
              _buildAttendanceTab(),
          
              // --- RIGHT TAB: REPORT (PLACEHOLDER) ---
              _buildReportsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: attendanceFilter(),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 20, top: 10),
          child: Text("Attendance Log:", 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        
        // The Styled List Container
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFF1A3E88), width: 2),
            ),
            child: Column(
              children: [
                // Fixed Header Row
                _buildCustomHeader(),
                const Divider(height: 1, color: Color(0xFF1A3E88)),
                
                // Scrollable List of Attendance
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _attendanceStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        debugPrint("Firestore Error: ${snapshot.error}");
                        return const Center(child: Text("Something went wrong"));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text("No attendance logs found for this department."));
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        itemCount: snapshot.data!.docs.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          var doc = snapshot.data!.docs[index];
                          var data = doc.data() as Map<String, dynamic>;
                          DateTime recordDate;
                          if (data['attendanceDate'] != null && data['attendanceDate'] is Timestamp) {
                            recordDate = (data['attendanceDate'] as Timestamp).toDate();
                          } else {
                            recordDate = DateTime.now(); 
                          }

                          // Pass these strings to your row widget
                          return _buildExpandableAttendanceRow(doc, index);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Header Row to match your table design
  Widget _buildCustomHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: const Row(
        children: [
          //TODO: change from ID to checkbox
          Expanded(flex: 1, child: Center(child: Text("#", style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(flex: 3, child: Center(child: Text("Date", style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(flex: 3, child: Center(child: Text("Worker", style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(flex: 2, child: Center(child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(flex: 1, child: Center(child: Text(" ", style: TextStyle(fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  // Each individual Attendance Row that expands
  Widget _buildExpandableAttendanceRow(DocumentSnapshot doc, int index) {
    Map<String, dynamic> attendance = doc.data() as Map<String, dynamic>;

    // 1. Safe extraction and conversion of Timestamps
    // We check if the data is a Timestamp before calling .toDate()
    DateTime? day;
    if (attendance['attendanceDate'] is Timestamp) {
      day = (attendance['attendanceDate'] as Timestamp).toDate();
    }

    DateTime? start;
    if (attendance['attendanceStartTime'] is Timestamp) {
      start = (attendance['attendanceStartTime'] as Timestamp).toDate();
    }
    
    DateTime? end;
    if (attendance['attendanceEndTime'] is Timestamp) {
      end = (attendance['attendanceEndTime'] as Timestamp).toDate();
    }

    // 2. Format the times for display
    String formattedStartTime = start != null ? DateFormat.jm().format(start) : "--:--";
    String formattedEndTime = end != null ? DateFormat.jm().format(end) : "--:--";
    String formattedDate = day != null ? DateFormat('dd MMM yyyy').format(day) : "No Date Recorded";

    // 1.5 Calculate Duration
    String formattedDuration = "--";

    if (start != null && end != null) {
      Duration diff = end.difference(start);
      
      int hours = diff.inHours;
      int minutes = diff.inMinutes.remainder(60);
      
      formattedDuration = "${hours}h ${minutes}m";
    } else if (start != null && end == null) {
      formattedDuration = "In Progress";
    }

    String status = attendance['attendanceApproval']?.toString() ?? 'Pending';
    String workerName = attendance['attendanceUserName']?.toString() ?? 'Unknown User';

    bool isExpanded = _expandedIndex == index;

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
            // Basic Info Row
            Row(
              children: [
                // Fixed: Checkbox requires a local state variable to work properly
                Expanded(
                  flex: 1, 
                  child: Center(
                    child: Checkbox(
                      value: false, // You'll need a list of bools to manage this state properly
                      onChanged: (bool? val) {
                        // Handle checkbox selection logic here
                      }
                    )
                  )
                ),
                Expanded(flex: 3, child: Center(child: Text(formattedDate))),
                Expanded(flex: 3, child: Center(child: Text(workerName))),
                Expanded(
                  flex: 2, 
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Punctuality Status (The one calculated by auth_service)
                      Text(
                        attendance['attendanceStatus'] ?? 'Unscheduled',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: attendance['attendanceStatus'] == "Late" ? Colors.red : Colors.blue,
                        ),
                      ),
                      // Approval Status (The one the manager clicks)
                      Text(
                        status, // Your existing 'Pending/Approved' variable
                        style: TextStyle(
                          fontSize: 10,
                          color: status == "Approved" ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  )
                ),
                Expanded(flex: 1, child: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 18)),
              ],
            ),
            
            // Expandable Action Buttons
            if (isExpanded) ...[
              const Divider(height: 20),
              Column( // Changed to Column for better layout when expanded
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _actionButton("Reject", Colors.red, () => _updateAttendanceStatus(doc.id, "Rejected")),
                      const SizedBox(width: 20),
                      _actionButton("Approve", Colors.green, () => _updateAttendanceStatus(doc.id, "Approved")),
                    ],
                  ),
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

  // --- STUBS FOR YOUR EXISTING WIDGETS ---
  Widget attendanceFilter() {
    return const Row(children: [Icon(Icons.filter_list), SizedBox(width: 5), Text("Filter")]);
  }

  Widget _buildReportsTab() {
  DateTime startDate = _getStartTime(_selectedPeriod);
  
  return SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      children: [
        _buildPeriodToggle(), // Moved to the TOP, outside the Stream

        const SizedBox(height: 20),
        
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('attendances')
              .where('deptCode', isEqualTo: widget.deptCode)
              .where('attendanceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Center(child: Text("No records found."));
            
            // 1. Logic: Extract counts into a Map for cleaner access
            final stats = _calculateStats(docs);
            
            // 2. UI: Return a scrollable view of pre-made components
            return Column(
              children: [
                // --- Section 1: Status ---
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    // Access the values using the keys defined in the Map
                    _buildStatChip("Total", "${stats['total']}", Colors.blue),
                    _buildStatChip("On-Time", "${stats['onTime']}", Colors.green),
                    _buildStatChip("Late", "${stats['late']}", Colors.red),
                    _buildStatChip("Other", "${stats['unscheduled']}", Colors.orange),
                  ],
                ),
                const SizedBox(height: 20),
            
                // --- Section 2: Chart ---
                _buildSimpleBarChart(stats['onTime']!, stats['late']!),

                const SizedBox(height: 20),
            
                // --- Section 3: Absent List ---
                const Text("Today's Missing Staff", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                
                const SizedBox(height: 10),
                
                _buildAbsentReportSection(),

                const SizedBox(height: 10),

                // --- Section 4: Export Button ---
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Export Department Report", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: bgLightBlue,
                    foregroundColor: primaryBlue,
                    side: BorderSide(width: 2, color: primaryBlue),
                    padding: EdgeInsets.all(20)),
                  onPressed: () {
                    if (docs.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("No data available for the selected period.")),
                      );
                      return;
                    }
                    PdfExportService.exportAttendanceReport(
                      title: "Department Attendance Report",
                      docs: docs, // This is the 'docs' variable from your StreamBuilder
                      period: _selectedPeriod,
                    );
                  },
                ),

                const SizedBox(height: 10),
              ],
            );
          },
        ),
      ],
    ),
  );
}

  void onChanged(bool? value) {}
  
  Future<void> _updateAttendanceStatus(String docId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('attendances')
          .doc(docId)
          .update({
        'attendanceApproval': newStatus,
      });

      // Show a small confirmation to the manager
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Attendance $newStatus"),
            backgroundColor: newStatus == "Approved" ? Colors.green : Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update status")),
        );
      }
    }
  }

  DateTime _getStartTime(String period) {
    DateTime now = DateTime.now();
    switch (period) {
      case "Weekly":
        // Gets the start of the current week (Monday)
        return now.subtract(Duration(days: now.weekday - 1)).copyWith(hour: 0, minute: 0, second: 0);
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

  Widget _buildStatChip(String label, String value, Color color) {
    // Calculates width to fit 2 chips per row comfortably
    double cardWidth = (MediaQuery.of(context).size.width / 4) - 20;

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
      decoration: BoxDecoration(
        color: bgLightBlue,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
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
            border: Border.all(color: primaryBlue, width: 2),
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

  Widget _buildPeriodToggle() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: SegmentedButton<String>(
        // Define the choices
        segments: const [
          ButtonSegment(value: "Weekly", label: Text("Week")),
          ButtonSegment(value: "Monthly", label: Text("Month")),
          ButtonSegment(value: "Yearly", label: Text("Year")),
        ],
        // Tell it which one is currently highlighted
        selected: {_selectedPeriod},
        // What happens when a user clicks a new one
        onSelectionChanged: (Set<String> newSelection) {
          setState(() {
            _selectedPeriod = newSelection.first;
            // This triggers the StreamBuilder to restart with new dates!
          });
        },
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: primaryBlue,
          selectedForegroundColor: bgLightBlue,
          side: const BorderSide(width: 1),
        ),
      ),
    );
  }

  Map<String, int> _calculateStats(List<QueryDocumentSnapshot> docs) {
    int onTime = 0;
    int late = 0;
    int unscheduled = 0;

    for (var doc in docs) {
      // 1. Safely extract the data
      final data = doc.data() as Map<String, dynamic>;
      
      // 2. Get the status string (default to Unscheduled if null)
      final String status = data['attendanceStatus']?.toString() ?? 'Unscheduled';

      // 3. Increment the correct counter in one single loop
      switch (status) {
        case 'On-Time':
          onTime++;
          break;
        case 'Late':
          late++;
          break;
        default:
          unscheduled++;
          break;
      }
    }

    // 4. Return everything in a tidy Map
    return {
      'onTime': onTime,
      'late': late,
      'unscheduled': unscheduled,
      'total': docs.length,
    };
  }

  Widget _buildAbsentReportSection() {
    DateTime now = DateTime.now();
    DateTime todayStart = DateTime(now.year, now.month, now.day);
    DateTime tomorrowStart = todayStart.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      // Fetch today's shifts
      stream: FirebaseFirestore.instance
          .collection('shifts')
          .where('deptCode', isEqualTo: widget.deptCode)
          .where('shiftStatus', isEqualTo: 'accepted')
          .where('shiftDate', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('shiftDate', isLessThan: Timestamp.fromDate(tomorrowStart))
          .snapshots(),
      builder: (context, shiftSnapshot) {
        if (!shiftSnapshot.hasData)
          print(shiftSnapshot.error);

        return StreamBuilder<QuerySnapshot>(
          // Fetch today's attendances
          stream: FirebaseFirestore.instance
              .collection('attendances')
              .where('deptCode', isEqualTo: widget.deptCode)
              .where('attendanceDate', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
              .snapshots(),
          builder: (context, attendanceSnapshot) {
            if (!attendanceSnapshot.hasData) return const SizedBox();

            // Compare UIDs
            final presentUIDs = attendanceSnapshot.data!.docs
                .map((doc) => (doc.data() as Map<String, dynamic>)['uid'].toString())
                .toSet();

            final absentDocs = shiftSnapshot.data!.docs.where((shiftDoc) {
              final shiftData = shiftDoc.data() as Map<String, dynamic>;
              return !presentUIDs.contains(shiftData['shiftUserID']);
            }).toList();

            if (absentDocs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                child: const Text("✨ Everyone has reported for duty today.", 
                  style: TextStyle(color: Colors.green, fontSize: 13)),
              );
            }

            // THE REPORT TABLE STYLE
            return Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: primaryBlue, width: 2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  // Minimalist Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                    decoration: BoxDecoration(color: bgLightBlue, borderRadius: BorderRadius.circular(15),),
                    child: const Row(
                      children: [
                        Expanded(flex: 3, child: Text("Date", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                        Expanded(flex: 3, child: Text("Name", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                        Expanded(flex: 2, child: Text("Shift Start", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                        Expanded(flex: 2, child: Text("Status", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                      ],
                    ),
                  ),
                  // Table Rows
                  ...absentDocs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    String time = data['shiftStartTime'] != null 
                      ? DateFormat.jm().format((data['shiftStartTime'] as Timestamp).toDate()) 
                      : "--";
                    String date = data['shiftDate'] != null 
                      ? DateFormat('dd MMM yyyy').format((data['shiftDate'] as Timestamp).toDate())
                      : "--";
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(15),),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              date,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14))),
                          Expanded(
                            flex: 3,
                            child: Text(
                              data['shiftUserName'] ?? "Unknown",
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14))),
                          Expanded(
                            flex: 2,
                            child: Text(
                              time,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14))),
                          const Expanded(
                            flex: 2,
                            child: Text(
                              "Absent",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 14, 
                                color: Colors.red))),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}