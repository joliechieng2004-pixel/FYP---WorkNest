import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PdfExportService {
  static Future<void> exportAttendanceReport({
    required String title,
    required List<QueryDocumentSnapshot> docs,
    required String period,
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
                pw.Text("Period: $period", style: pw.TextStyle(fontSize: 12)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          
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