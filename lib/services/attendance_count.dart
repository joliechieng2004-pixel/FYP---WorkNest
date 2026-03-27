import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceCount {
  /// Private helper to avoid repeating Firebase code
  static Future<Map<String, int>> _getRawCounts(String employeeID) async {
    final scheduledQuery = await FirebaseFirestore.instance
        .collection('shifts')
        .where('shiftUserID', isEqualTo: employeeID)
        .count()
        .get();

    final attendedQuery = await FirebaseFirestore.instance
        .collection('attendances')
        .where('attendanceUserID', isEqualTo: employeeID)
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
    final stats = await _getRawCounts(employeeID);
    if (stats['scheduled'] == 0) return 0.0;
    
    return (stats['attended']! / stats['scheduled']!) * 100;
  }

  /// Returns the total number of missed shifts:
  /// (Scheduled - Attended)
  static Future<int> getAbsentCount(String employeeID) async {
    final stats = await _getRawCounts(employeeID);
    int absent = stats['scheduled']! - stats['attended']!;
    return absent < 0 ? 0 : absent;
  }

  /// PRO-TIP: Returns both values in one go. 
  /// Use this for your Pop-up to save on Firebase performance!
  static Future<Map<String, dynamic>> getFullAttendanceStats(String employeeID) async {
    final stats = await _getRawCounts(employeeID);
    int scheduled = stats['scheduled']!;
    int attended = stats['attended']!;
    
    double rate = scheduled == 0 ? 0.0 : (attended / scheduled) * 100;
    int absent = (scheduled - attended) < 0 ? 0 : (scheduled - attended);

    return {
      'rate': rate,
      'absent': absent,
    };
  }
}