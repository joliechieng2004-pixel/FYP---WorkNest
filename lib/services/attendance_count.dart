import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceCount {
  
  /// Returns the percentage of shifts attended
  static Future<double> getAttendanceRate(String employeeID) async {
    final stats = await getFullAttendanceStats(employeeID);
    return stats['rate'];
  }

  /// Returns the total number of missed shifts
  static Future<int> getAbsentCount(String employeeID) async {
    final stats = await getFullAttendanceStats(employeeID);
    return stats['absent'];
  }

  /// Core logic: Processes Shifts, Leaves, and Attendances to perfectly 
  /// match the logic used in the ManagerReportPage.
  static Future<Map<String, dynamic>> getFullAttendanceStats(String employeeID) async {
    DateTime now = DateTime.now();
    DateFormat dateKeyFormat = DateFormat('yyyy-MM-dd');

    // 1. Get all accepted shifts for this employee
    final shiftsQuery = await FirebaseFirestore.instance
        .collection('shifts')
        .where('shiftUserID', isEqualTo: employeeID)
        .where('shiftStatus', isEqualTo: 'accepted')
        .get();

    // 2. Get all approved leaves for this employee
    final leavesQuery = await FirebaseFirestore.instance
        .collection('leaves')
        .where('leaveUserID', isEqualTo: employeeID)
        .where('leaveStatus', isEqualTo: 'approved')
        .get();

    // 3. Get all attendances for this employee
    final attendancesQuery = await FirebaseFirestore.instance
        .collection('attendances')
        .where('attendanceUserID', isEqualTo: employeeID)
        .get();

    int scheduled = 0;
    int attended = 0;
    int absent = 0;

    // Run the exact same logic as the Report Page
    for (var shift in shiftsQuery.docs) {
      var shiftData = shift.data();
      if (shiftData['shiftDate'] == null) continue;

      DateTime shiftDate = (shiftData['shiftDate'] as Timestamp).toDate();
      String shiftDateString = dateKeyFormat.format(shiftDate);
      String shiftId = shift.id;

      // --- 1. SHIFT LOGIC: Eliminate future/ongoing shifts ---
      if (shiftDate.isAfter(now)) continue;
      DateTime? shiftEndTime = shiftData['shiftEndTime'] != null 
          ? (shiftData['shiftEndTime'] as Timestamp).toDate() 
          : null;
      if (shiftEndTime != null && shiftEndTime.isAfter(now)) continue;

      // --- 2. LEAVE LOGIC: Eliminate shifts covered by an approved leave ---
      bool hasLeave = leavesQuery.docs.any((leaveDoc) {
        var leaveData = leaveDoc.data();
        if (leaveData['leaveDate'] == null) return false;
        return dateKeyFormat.format((leaveData['leaveDate'] as Timestamp).toDate()) == shiftDateString;
      });

      if (hasLeave) continue; // Skip this shift completely

      // If it passed the above, it counts as a scheduled shift they needed to work
      scheduled++;

      // --- 3. ATTENDANCE LOGIC: Check if they attended this specific shift ---
      bool hasAttendance = attendancesQuery.docs.any((attDoc) {
        var attData = attDoc.data();
        
        // Match 1: By explicit shiftID (as you requested)
        bool matchById = attData['shiftID'] == shiftId; 
        
        // Match 2: By exact Date String (matching the ManagerReportPage logic)
        bool matchByDate = false;
        if (attData['attendanceDate'] != null) {
          String attDateString = dateKeyFormat.format((attData['attendanceDate'] as Timestamp).toDate());
          matchByDate = (attDateString == shiftDateString);
        }

        return matchById || matchByDate;
      });

      if (hasAttendance) {
        attended++;
      } else {
        absent++;
      }
    }

    // --- MATH LOGIC ---
    double rate = 0.0;
    if (scheduled > 0) {
      rate = (attended / scheduled) * 100;
    } else if (attended > 0) {
      rate = 100.0; // They worked even though 0 past shifts were officially scheduled
    }
    
    if (rate > 100) rate = 100.0;

    return {
      'rate': rate,
      'absent': absent,
      'scheduled': scheduled,
      'attended': attended,
    };
  }
}