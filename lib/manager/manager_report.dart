import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ManagerReportPage extends StatefulWidget {
  final String deptCode;

  const ManagerReportPage({super.key, required this.deptCode});

  @override
  State<ManagerReportPage> createState() => _ManagerReportPageState();
}

class _ManagerReportPageState extends State<ManagerReportPage> {
  final Color primaryBlue = const Color(0xFF1A3E88);
  int? _expandedIndex;
  
  late Stream<QuerySnapshot> _attendanceStream;
  
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
              _buildReportsPlaceholder(),
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
                
                // Scrollable List of Workers
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
                          if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
                            recordDate = (data['timestamp'] as Timestamp).toDate();
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
          Expanded(flex: 2, child: Center(child: Text("Date", style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(flex: 3, child: Center(child: Text("Worker", style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(flex: 2, child: Center(child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold)))),
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
    String formattedStartTime = start != null ? DateFormat('hh:mm:ss a').format(start) : "--:--";
    String formattedEndTime = end != null ? DateFormat('hh:mm:ss a').format(end) : "--:--";
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

    String status = attendance['attendanceStatus']?.toString() ?? 'Pending';
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
          boxShadow: isExpanded ? [BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
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
                Expanded(flex: 2, child: Center(
                  child: Text(
                    status,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: status == "Approved" 
                          ? Colors.green 
                          : status == "Rejected" 
                              ? Colors.red 
                              : Colors.orange, // Orange for "Pending"
                    ),
                  ))),
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
    return Row(children: [const Icon(Icons.filter_list), const SizedBox(width: 5), const Text("Filter")]);
  }

  void addWorker(){
    print("temporary method");
  }

  Widget _buildReportsPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "Report Module Coming Soon",
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 8),
            child: Text(
              "This section will later include data visualization and shift efficiency metrics.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
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
        'attendanceStatus': newStatus,
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
}