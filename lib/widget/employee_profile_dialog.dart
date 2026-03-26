import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EmployeeProfileDialog extends StatelessWidget {
  final Map<String, dynamic> workerData;
  final double attendanceRate;
  final int totalAbsences;

  const EmployeeProfileDialog({
    super.key,
    required this.workerData,
    required this.attendanceRate,
    required this.totalAbsences,
  });

  // Style constants from your previous widgets
  final Color primaryBlue = const Color(0xFF284B9E);
  final Color bgLightBlue = const Color(0xFFF0FAFF);

  @override
  Widget build(BuildContext context) {
    String fullName = "${workerData['userFName'] ?? ''} ${workerData['userLName'] ?? 'Unknown User'}";
    String email = workerData['userEmail'] ?? "No email provided";
    String contact = workerData['userContact'] ?? "No contact provided";
    
    // Formatting the 'adding date' (createdAt)
    String joinedDate = "Unknown";
    if (workerData['createdAt'] != null) {
      DateTime date = (workerData['createdAt']).toDate();
      joinedDate = DateFormat('dd MMM yyyy').format(date);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primaryBlue, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Avatar & Name
            CircleAvatar(
              radius: 40,
              backgroundColor: primaryBlue,
              child: Text(
                workerData['userFName']?[0].toUpperCase() ?? "?",
                style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              fullName,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryBlue),
              textAlign: TextAlign.center,
            ),
            const Divider(height: 30, thickness: 1),

            // Info Section
            _buildInfoRow(Icons.email_outlined, "Email", email),
            _buildInfoRow(Icons.phone_android_outlined, "Contact", contact),
            _buildInfoRow(Icons.calendar_today_outlined, "Joined", joinedDate),

            const SizedBox(height: 20),

            // Stats Section (Attendance Rate & Absences)
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    "Attendance", 
                    "${attendanceRate.toStringAsFixed(1)}%", 
                    Colors.green
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard(
                    "Absences", 
                    totalAbsences.toString(), 
                    Colors.red
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Close Profile"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: primaryBlue),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgLightBlue,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}