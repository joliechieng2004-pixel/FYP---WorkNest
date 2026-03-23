import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AttendanceRateWidget extends StatelessWidget {
  final String userId;

  const AttendanceRateWidget({super.key, required this.userId});

  Future<double> _calculateRate() async {
    // 1. Get total scheduled shifts
    AggregateQuerySnapshot scheduledQuery = await FirebaseFirestore.instance
        .collection('shifts')
        .where('shiftUserID', isEqualTo: userId)
        .count()
        .get();

    // 2. Get total attendance records
    AggregateQuerySnapshot attendedQuery = await FirebaseFirestore.instance
        .collection('attendances')
        .where('attendanceUserId', isEqualTo: userId)
        //.where('attendanceApproval', isEqualTo: 'Approved')
        .count()
        .get();

    int scheduledCount = scheduledQuery.count ?? 0;
    int attendedCount = attendedQuery.count ?? 0;

    if (scheduledCount == 0) return 0.0;
    
    // Formula: (Attended / Scheduled) * 100
    return (attendedCount / scheduledCount) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: _calculateRate(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print(snapshot.error);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 15, height: 15, 
            child: CircularProgressIndicator(strokeWidth: 2)
          );
        }
        
        double rate = snapshot.data ?? 0.0;
        return Text(
          "${rate.toStringAsFixed(0)}%",
          style: TextStyle(fontWeight: FontWeight.bold, color: _getColor(rate)),
        );
      },
    );
  }
}

Color? _getColor(double rate) {
  if (rate == 100)
    {return Colors.green;}
  else if (rate >= 60 && rate <= 99)
    {return Colors.yellow;}
  else
    {return Colors.red;}
}