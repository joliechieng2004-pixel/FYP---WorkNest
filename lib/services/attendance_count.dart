import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceCount {
  /// Private helper to avoid repeating Firebase code
  static Future<Map<String, int>> _getRawCounts(String employeeID) async {
    Timestamp now = Timestamp.now();

    final scheduledQuery = await FirebaseFirestore.instance
        .collection('shifts')
        .where('shiftUserID', isEqualTo: employeeID)
        .where('shiftStatus', isEqualTo: 'accepted')
        .where('shiftDate', isLessThanOrEqualTo: now)
        .count()
        .get();

    final attendedQuery = await FirebaseFirestore.instance
        .collection('attendances')
        .where('attendanceUserID', isEqualTo: employeeID)
        .where('attendanceStartTime', isLessThanOrEqualTo: now)
        .count()
        .get();

    return {
      'scheduled': scheduledQuery.count ?? 0,
      'attended': attendedQuery.count ?? 0,
    };
  }

  /// Returns the percentage of shifts attended: 
  /// (Attended / Scheduled) * 100
  static Future<double> getAttendanceRate(String employeeID) async {
    final stats = await getFullAttendanceStats(employeeID);
    return stats['rate'];
  }

  /// Returns the total number of missed shifts:
  /// (Scheduled - Attended)
  static Future<int> getAbsentCount(String employeeID) async {
    final stats = await getFullAttendanceStats(employeeID);
    return stats['absent'];
  }

  /// Returns both values in one go. 
  static Future<Map<String, dynamic>> getFullAttendanceStats(String employeeID) async {
    final stats = await _getRawCounts(employeeID);
    int scheduled = stats['scheduled']!;
    int attended = stats['attended']!;
    
    double rate = 0.0;
    if (scheduled > 0) {
      rate = (attended / scheduled) * 100;
    } else if (attended > 0) {
      rate = 100.0; // They worked even though 0 shifts were scheduled
    }
    
    // If they attended more than scheduled (early clock-in), just show 100%
    if (rate > 100) rate = 100.0;

    int absent = (scheduled - attended) < 0 ? 0 : (scheduled - attended);

    return {
      'rate': rate,
      'absent': absent,
    };
  }
}