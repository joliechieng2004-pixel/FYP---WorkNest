// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:worknest/services/connectivity_service.dart';
import 'package:worknest/utils/app_colors.dart';
import 'package:worknest/widget/leaveitem.dart';

class EmployeeSchedule extends StatefulWidget {
  final String deptCode;
  final String employeeID;

  const EmployeeSchedule({super.key, required this.deptCode, required this.employeeID});

  @override
  State<EmployeeSchedule> createState() => _EmployeeSchedulePageState();
}

class _EmployeeSchedulePageState extends State<EmployeeSchedule> {
  final TextEditingController _leaveController = TextEditingController();
  final ScrollController _leaveScrollController = ScrollController();
  final ScrollController _shiftScrollController = ScrollController();

  // check connection
  late StreamSubscription<bool> _connectivitySubscription;
  bool _isOffline = false;

  String deptCode = "Loading...";
  
  String formattedDate = DateFormat('EEEE, d MMM yyyy').format(DateTime.now());
  String formattedTime = DateFormat('h:mm a').format(DateTime.now());
  
  // --- DECLARE ALL STREAMS---
  // ignore: unused_field
  late Stream<QuerySnapshot> _upcomingShiftStream;
  late Stream<QuerySnapshot> _pendingLeaveStream;
  late Stream<QuerySnapshot> _pendingShiftStream;
  late Stream<QuerySnapshot> _acceptedShiftStream;
  late Stream<QuerySnapshot> _leaveRequestsStream;

  // --- INITIALIZATION ---
  @override
  void initState() {
    super.initState();
    // Start listening
    _connectivitySubscription = ConnectivityService().connectionStream.listen((isOnline) {
      setState(() {
        _isOffline = !isOnline;
      });
      
      if (_isOffline) {
        _showOfflineBanner();
      } else {
        ScaffoldMessenger.of(context).clearMaterialBanners();
      }
    });
    _updateStream();
  }

  void _showOfflineBanner() {
    ScaffoldMessenger.of(context).showMaterialBanner(
      const MaterialBanner(
        content: Text(
          'No Internet Connection. Actions are disabled.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        actions: [
          Icon(Icons.wifi_off, color: Colors.white),
        ],
      ),
    );
  }

  // 
  void _updateStream() {
    final date = DateTime.now();
    final startOfToday = DateTime(date.year, date.month, date.day, 0, 0, 0);

    setState(() {
      _upcomingShiftStream = FirebaseFirestore.instance
          .collection('shifts')
          .where('shiftUserID', isEqualTo: widget.employeeID)
          .where('shiftDate', isGreaterThanOrEqualTo: Timestamp.fromDate(
              startOfToday.subtract(const Duration(hours: 1)))) // Current & Future
          .orderBy('shiftDate', descending: false) 
          .snapshots();

      _pendingLeaveStream = FirebaseFirestore.instance
          .collection('leaves')
          .where('leaveUserID', isEqualTo: widget.employeeID)
          .where('leaveStatus', isEqualTo: 'pending')
          .where('leaveDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .snapshots();

      _pendingShiftStream = FirebaseFirestore.instance
          .collection('shifts')
          .where('shiftUserID', isEqualTo: widget.employeeID)
          .where('shiftStatus', isEqualTo: 'pending')
          .where('shiftDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .snapshots();

      _acceptedShiftStream = FirebaseFirestore.instance
          .collection('shifts')
          .where('shiftUserID', isEqualTo: widget.employeeID)
          .where('shiftStatus', isEqualTo: 'accepted')
          .where('shiftDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .snapshots();

      _leaveRequestsStream = FirebaseFirestore.instance
          .collection('leaves')
          .where('leaveUserID', isEqualTo: widget.employeeID)
          .orderBy('leaveDate', descending: false)
          .snapshots();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _leaveController.dispose();
    _leaveScrollController.dispose();
    _shiftScrollController.dispose();
    super.dispose(); 
  }

  // --- BUILD WIDGETS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLightBlue,
      appBar: AppBar(
        title: const Text("Manage Schedule"),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A3E88),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Shift Summary
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      "Shift Summary",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Divider(color: Color(0xFF1A3E88)),

                    _buildDynamicStatRow(
                      label: "Pending Leave",
                      stream: _pendingLeaveStream,
                    ),
                    _buildDynamicStatRow(
                      label: "Pending Shift",
                      stream: _pendingShiftStream,
                    ),
                    _buildDynamicStatRow(
                      label: "Upcoming Shift",
                      stream: _acceptedShiftStream,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Shift List for Employee
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        "Upcoming Shifts",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(color: Color(0xFF1A3E88)),
                    const SizedBox(height: 10),
                    
                    SizedBox(
                      height: 300, 
                      child: Scrollbar(
                        controller: _shiftScrollController,
                        thumbVisibility: true, 
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _upcomingShiftStream,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              debugPrint("Shift Stream Error: ${snapshot.error}");
                              return const Center(child: Text("Error loading shifts"));
                            }
                            
                            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final shiftDocs = snapshot.data?.docs ?? [];

                            if (shiftDocs.isEmpty) {
                              return const Center(
                                child: Text("No upcoming shifts found.", 
                                style: TextStyle(color: Colors.grey))
                              );
                            }

                            return ListView.builder(
                              controller: _shiftScrollController,
                              padding: const EdgeInsets.only(right: 10),
                              itemCount: shiftDocs.length,
                              itemBuilder: (context, index) {
                                var doc = shiftDocs[index];
                                var data = doc.data() as Map<String, dynamic>;
                                String status = data['shiftStatus'] ?? 'pending';
                                
                                return _buildEmployeeShiftCard(data, doc.id, status);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Request Leave Button
              _buildGlobalLeaveRequestCard(),

              const SizedBox(height: 10),

              // Leave Requests (Scrollable Version)
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                          "Leave Requests",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                    ),
                    const Divider(color: Color(0xFF1A3E88)),
                    const SizedBox(height: 10),
                    
                    SizedBox(
                      height: 300, 
                      child: Scrollbar(
                        controller: _leaveScrollController,
                        thumbVisibility: true, 
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _leaveRequestsStream,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              debugPrint("${snapshot.error}");
                            }
                            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final leaveDocs = snapshot.data?.docs ?? [];

                            if (leaveDocs.isEmpty) {
                              return const Center(
                                child: Text("No leave requests found.", 
                                style: TextStyle(color: Colors.grey))
                              );
                            }

                            return ListView.builder(
                              controller: _leaveScrollController,
                              padding: const EdgeInsets.only(right: 10),
                              itemCount: leaveDocs.length,
                              itemBuilder: (context, index) {
                                var doc = leaveDocs[index]; 
                                var data = doc.data() as Map<String, dynamic>;
                                
                                String employeeID = data['leaveUserID'] ?? "Unknown";
                                String employeeName = data['leaveUserName'] ?? "pending";
                                String status = data['leaveStatus'] ?? "pending";
                                String reason = data['leaveReason'] ?? "No reason provided";
                                DateTime date = (data['leaveDate'] as Timestamp).toDate();
                                String formattedDate = DateFormat('d MMM yyyy, EEE').format(date);
                                
                                return ExpandableLeaveItem(
                                  docId: doc.id,
                                  title: formattedDate,
                                  leaveDate: date,
                                  id: employeeID,
                                  name: employeeName,
                                  reason: reason,
                                  status: status,
                                  isManager: false,
                                  managerNote: data['managerReason']
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      )
    );
  }

  // Helper for Cards
  Widget _buildCard({required Widget child, Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBlue, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.blueGrey,
            blurRadius: 10,
            offset: Offset(2, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // --- SHIFT ---
  Widget _buildEmployeeShiftCard(Map<String, dynamic> data, String docID, String status) {
    DateTime? safeDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    DateTime? dateVal = safeDate(data['shiftDate']);
    DateTime? startVal = safeDate(data['shiftStartTime']);
    DateTime? endVal = safeDate(data['shiftEndTime']);

    String dateStr = dateVal != null ? DateFormat('d MMM yyyy, EEEE').format(dateVal) : "No Date";
    String timeRange = (startVal != null && endVal != null)
        ? "${DateFormat.jm().format(startVal)} - ${DateFormat.jm().format(endVal)}"
        : "Time Not Set";

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(timeRange, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 8),
                if (data['shiftTask'] != null) ...[
                  const SizedBox(height: 8),
                  Text("Task: ${data['shiftTask']}", style: const TextStyle(fontStyle: FontStyle.italic)),
                ]
              ],
            ),
          ),

          Expanded(
            flex: 3,
            child: Column(
              children: [
                if (status == 'accepted') 
                  const Icon(Icons.check_circle, color: Colors.green, size: 40)
                else if (status == 'rejected') ...[
                  const Icon(Icons.cancel, color: Colors.red, size: 40)
                ] 
                else if (status == 'on-leave') ...[
                  const Icon(Icons.calendar_month, color: Colors.grey, size: 40)
                ] 
                else ...[
                  _buildActionButton(
                    "Accept", 
                    Colors.green, 
                    () => _showStatusConfirmation(docID, 'accepted'), 
                    false
                  ),
                  const SizedBox(height: 10),
                  _buildActionButton(
                    "Reject", 
                    Colors.red, 
                    () => _showStatusConfirmation(docID, 'rejected'), 
                    false
                  ),
                ],
              ],
            ),
          ),
        ]
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap, bool isFilled, {bool isDisabled = false}) {
    return SizedBox(
      width: double.infinity,
      height: 35,
      child: ElevatedButton(
        onPressed: isDisabled ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFilled ? color : Colors.white,
          foregroundColor: isFilled ? Colors.white : color,
          disabledBackgroundColor: isFilled ? color.withOpacity(0.5) : Colors.grey.shade200,
          disabledForegroundColor: isFilled ? Colors.white70 : Colors.grey,
          side: BorderSide(color: isDisabled && !isFilled ? Colors.grey : color),
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  void _showStatusConfirmation(String docID, String newStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Confirm ${newStatus[0].toUpperCase()}${newStatus.substring(1)}"),
        content: Text("Your action to $newStatus this shift may be permanent."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: _isOffline ? null : () {
              Navigator.pop(context); 
              _updateStatus(docID, newStatus); 
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isOffline ? Colors.grey : (newStatus == 'accepted' ? Colors.green : Colors.red),
              foregroundColor: Colors.white,
            ),
            child: Text(_isOffline ? "No Internet" : "Confirm"),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String docID, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('shifts')
          .doc(docID)
          .update({'shiftStatus': newStatus});

      if (!mounted) return; 
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Shift $newStatus successfully!"), 
          backgroundColor: newStatus == 'accepted' ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating, 
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.orange),
      );
    }
  }

  // --- LEAVE REQUEST ---
  Widget _buildGlobalLeaveRequestCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBlue, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.blueGrey,
            blurRadius: 10,
            offset: Offset(2, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.event_note, color: Colors.orange, size: 28),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Need time off? Request a leave.",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: _isOffline ? null : () => _selectDateAndRequestLeave(context),
              icon: const Icon(Icons.beach_access, size: 18),
              label: Text(_isOffline ? "Waiting for Connection" : "Select Date & Request Leave"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
                backgroundColor: _isOffline ? Colors.grey : AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateAndRequestLeave(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(), 
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue, 
              onPrimary: Colors.white, 
              onSurface: Colors.black, 
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      Map<String, dynamic> leaveData = {
        'shiftDate': Timestamp.fromDate(picked),
      };
      _handleLeaveRequest(leaveData); 
    }
  }

  void _handleLeaveRequest(Map<String, dynamic> shiftData) {
    DateTime selectedLeaveDate = (shiftData['shiftDate'] as Timestamp).toDate();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( 
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Request for a Leave", 
            style: TextStyle(color: AppColors.primaryBlue, fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Date: ${DateFormat('dd MMM yyyy').format(selectedLeaveDate)}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _leaveController, 
                  decoration: InputDecoration(
                    labelText: "Leave Request Reason",
                    hintText: "e.g. Sick, Family Manner",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (_leaveController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please provide a reason")),
                );
                return;
              }
                try {
                  DateTime start = DateTime(selectedLeaveDate.year, selectedLeaveDate.month, selectedLeaveDate.day, 0, 0, 0);
                  DateTime end = DateTime(selectedLeaveDate.year, selectedLeaveDate.month, selectedLeaveDate.day, 23, 59, 59);

                  var shiftConflictQuery = await FirebaseFirestore.instance
                      .collection('shifts')
                      .where('shiftUserID', isEqualTo: widget.employeeID)
                      .where('shiftStatus', isEqualTo: 'accepted')
                      .where('shiftDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
                      .where('shiftDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
                      .get();

                  if (shiftConflictQuery.docs.isNotEmpty) {
                    bool? proceed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Shift Conflict Detected"),
                        content: const Text(
                            "You have already accepted a shift for this day. Do you want to proceed?"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes, Proceed")),
                        ],
                      ),
                    );

                    if (proceed != true) return; 
                  }

                  DocumentSnapshot userDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.employeeID)
                      .get();

                  Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
                  String fullName = "${userData['userFName']} ${userData['userLName']}";

                  await _submitLeaveToFirestore(
                    deptCode: widget.deptCode,
                    employeeID: widget.employeeID,
                    employeeName: fullName,
                    leaveReason: _leaveController.text,
                    leaveDate: selectedLeaveDate,
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    _leaveController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Leave request submitted!"),
                        duration: Duration(seconds: 1),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint("Error submitting leave: $e");
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
              child: const Text("Confirm"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitLeaveToFirestore({
    required String deptCode,
    required String employeeID,
    required String employeeName,
    required String leaveReason,
    required DateTime leaveDate,
  }) async {
    String dateString = DateFormat('yyyy-MM-dd').format(leaveDate);
    String customDocId = "${dateString}_$employeeID";

    try {
      await FirebaseFirestore.instance
          .collection('leaves')
          .doc(customDocId) 
          .set({
        'deptCode': deptCode,
        'leaveUserID': employeeID,
        'leaveUserName': employeeName,
        'leaveDate': Timestamp.fromDate(leaveDate),
        'leaveReason': leaveReason,
        'leaveStatus': 'pending',
        'leaveAppliedDate': FieldValue.serverTimestamp(), 
        'managerReason': null,
      }, SetOptions(merge: true)); 
    } catch (e) {
      rethrow; 
    }
  }

  // --- SHIFT SUMMARY ---
  Widget _buildDynamicStatRow({required String label, required Stream<QuerySnapshot> stream}) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        // --- 6. HANDLE WAITING STATE SMOOTHLY TO PREVENT "0" FLICKER ---
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          );
        }

        String value = snapshot.hasData ? snapshot.data!.docs.length.toString() : "0";

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Container(
                width: 50,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: (label.contains("Pending") && value != "0") 
                      ? Colors.red.shade50 
                      : Colors.transparent,
                  border: Border.all(color: AppColors.primaryBlue.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: (label.contains("Pending") && value != "0") 
                        ? Colors.red 
                        : AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}