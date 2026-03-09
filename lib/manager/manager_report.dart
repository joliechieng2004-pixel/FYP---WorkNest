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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Number of tabs
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Manager Reports"),
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
        body: TabBarView(
          children: [
            // --- LEFT TAB: ATTENDANCE LOG ---
            _buildAttendanceTab(),

            // --- RIGHT TAB: REPORT (PLACEHOLDER) ---
            _buildReportsPlaceholder(),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTab() {
    return StreamBuilder<QuerySnapshot>(
      // Update this query to match your 'attendance' or 'clock_in' collection
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('deptCode', isEqualTo: widget.deptCode)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No attendance logs found for this department."));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            DateTime time = (data['timestamp'] as Timestamp).toDate();

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: primaryBlue.withOpacity(0.1),
                child: Icon(Icons.person, color: primaryBlue),
              ),
              title: Text(data['workerName'] ?? "Unknown Employee", 
                style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Clock-in: ${DateFormat('jm').format(time)}"),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(DateFormat('dd MMM').format(time)),
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                ],
              ),
            );
          },
        );
      },
    );
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
}