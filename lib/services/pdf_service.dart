import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PdfExportService {
  static Future<void> exportAttendanceReport({
    required String title,
    required List<QueryDocumentSnapshot> docs,
    List<Map<String, dynamic>>? absentShifts,
    required String period,
    String? userRole,
    double? attendanceRate,
    int? absentCount,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text("Period: $period", style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),

          if (userRole == 'employee' && attendanceRate != null && absentCount != null) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.start,
              children: [
                pw.Text("Attendance Rate: ${attendanceRate.toStringAsFixed(1)}%", 
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                pw.SizedBox(width: 20),
                pw.Text("Total Absences: $absentCount", 
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 10),
          ],

          pw.Text("Absences List", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          
          // The Table
          if (absentShifts == null || absentShifts.isEmpty)
            pw.Text("No absent records for this period.")
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headers: ['Date', 'Name', 'Schedule In', 'Schedule Out', 'Status'],
              data: absentShifts.map((data) {
                // Safe Date Formatting
                String dateStr = "--";
                if (data['shiftDate'] != null) {
                  dateStr = DateFormat('yyyy-MM-dd').format((data['shiftDate'] as Timestamp).toDate());
                }

                // Safe Time Formatting
                String timeIn = (data['shiftStartTime'] != null) 
                    ? DateFormat.jm().format((data['shiftStartTime'] as Timestamp).toDate()) 
                    : "--";
                    
                String timeOut = (data['shiftEndTime'] != null) 
                    ? DateFormat.jm().format((data['shiftEndTime'] as Timestamp).toDate()) 
                    : "--";

                return [
                  dateStr,
                  (data['shiftUserName'] ?? "Unknown").toString(),
                  timeIn,
                  timeOut,
                  "Absent"
                ];
              }).toList(),
            ),

          pw.SizedBox(height: 20),

          pw.Text("Attendance List", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          
          // The Table
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Date', 'Name', 'Status', 'In', 'Out', 'Approval'],
            data: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              
              // Safe Date Formatting
              String dateStr = "--";
              if (data['attendanceDate'] != null) {
                dateStr = DateFormat('yyyy-MM-dd').format((data['attendanceDate'] as Timestamp).toDate());
              }

              // Safe Time Formatting
              String timeIn = (data['attendanceStartTime'] != null) 
                  ? DateFormat.jm().format((data['attendanceStartTime'] as Timestamp).toDate()) 
                  : "--";
                  
              String timeOut = (data['attendanceEndTime'] != null) 
                  ? DateFormat.jm().format((data['attendanceEndTime'] as Timestamp).toDate()) 
                  : "--";

              return [
                dateStr,
                (data['attendanceUserName'] ?? data['shiftUserName'] ?? "Unknown").toString(),
                (data['attendanceStatus'] ?? "N/A").toString(),
                timeIn,
                timeOut,
                (data['attendanceApproval'] ?? "Pending").toString(),
              ];
            }).toList(),
          ),
          
          pw.Footer(
            margin: const pw.EdgeInsets.only(top: 20),
            trailing: pw.Text("Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}"),
          ),
        ],
      ),
    );

    // This opens the native print/save dialog
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}