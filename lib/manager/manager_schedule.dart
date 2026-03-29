// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:worknest/services/connectivity_service.dart';
import 'package:worknest/utils/app_colors.dart';
import 'package:worknest/widget/leaveitem.dart';

class ManagerSchedule extends StatefulWidget {
  final String deptCode;

  const ManagerSchedule({super.key, required this.deptCode});

  @override
  State<ManagerSchedule> createState() => _ManagerSchedulePageState();
}

class _ManagerSchedulePageState extends State<ManagerSchedule> {
  // check connection
  late StreamSubscription<bool> _connectivitySubscription;
  bool _isOffline = false;
  
  late Stream<QuerySnapshot> _shiftStream;
  late Stream<QuerySnapshot> _userStream;
  late Stream<QuerySnapshot> _leaveStream;

  // Calendar
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isDateSelected = false;
  
  // Shift
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  final TextEditingController _taskController = TextEditingController();

  final ScrollController _leaveScrollController = ScrollController();
  final ScrollController _mainScrollController = ScrollController();

  String deptCode = "Loading...";
  String formattedDate = DateFormat('EEEE, d MMM yyyy').format(DateTime.now());
  String formattedTime = DateFormat('h:mm a').format(DateTime.now());

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
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).clearMaterialBanners();
      }
    });
    _selectedDay = DateTime.now(); // Default selection to today
    initStreams();
    // Debug Check
    _debugCheckDatabase();
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

  void initStreams(){
    if (_selectedDay == null) return;

    // 1. Force the date to the very beginning of the LOCAL day
    DateTime localStart = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day, 0, 0, 0);
    
    // 2. Force the date to the very end of the LOCAL day
    DateTime localEnd = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day, 23, 59, 59, 999);

    debugPrint("Querying from: ${localStart.toIso8601String()}");
    debugPrint("Querying to: ${localEnd.toIso8601String()}");

    _shiftStream = FirebaseFirestore.instance
            .collection('shifts')
            .where('deptCode', isEqualTo: widget.deptCode)
            .where('shiftDate', isGreaterThanOrEqualTo: Timestamp.fromDate(localStart))
            .where('shiftDate', isLessThanOrEqualTo: Timestamp.fromDate(localEnd))
            .snapshots();
    _leaveStream = FirebaseFirestore.instance
            .collection('leaves')
            .where('leaveStatus', isEqualTo: 'approved')
            .where('leaveDate', isGreaterThanOrEqualTo: Timestamp.fromDate(localStart))
            .where('leaveDate', isLessThanOrEqualTo: Timestamp.fromDate(localEnd))
            .snapshots();
    _userStream = FirebaseFirestore.instance
            .collection('users')
            .where('deptCode', isEqualTo: widget.deptCode)
            .where('userRole', isEqualTo: 'employee')
            .snapshots();
  }

  // DEBUG PURPOSE
  void _debugCheckDatabase() async {
    debugPrint("--- DATABASE INSPECTION START ---");
    var snapshot = await FirebaseFirestore.instance
        .collection('shifts')
        .where('deptCode', isEqualTo: widget.deptCode)
        .get();

    if (snapshot.docs.isEmpty) {
      debugPrint("Zero shifts found even WITHOUT date filtering. Check your deptCode!");
    }

    for (var doc in snapshot.docs) {
      var data = doc.data();
      var dateField = data['shiftDate'];
      
      if (dateField is Timestamp) {
        debugPrint("Doc ID: ${doc.id} | Date: ${dateField.toDate()} | Type: Timestamp");
      } else {
        debugPrint("Doc ID: ${doc.id} | Date: $dateField | Type: ${dateField.runtimeType} (ERROR: Should be Timestamp)");
      }
    }
    debugPrint("--- DATABASE INSPECTION END ---");
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _leaveScrollController.dispose(); // Clean up the controller
    _mainScrollController.dispose();
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
          controller: _mainScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Calendar
              Card(
                margin: const EdgeInsets.all(10),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: TableCalendar(
                  firstDay: DateTime.now().subtract(const Duration(days: 0)),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  enabledDayPredicate: (day) {
                    // Only allow dates that are today or in the future
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    return day.isAfter(today.subtract(const Duration(days: 1)));
                  },
                  selectedDayPredicate: (day) {
                    // Tells the calendar which day to highlight as "selected"
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay; // update focusedDay as well
                      _isDateSelected = true;

                      _updateStreams(selectedDay);
                    });
                    debugPrint("Selected Date: $_selectedDay");
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  // Custom Styling
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                    selectedDecoration: BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
                    markerDecoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle), // For shifts
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                  ),
                ),
              ),

              // 2. Employee List
              _isDateSelected
                  ? _buildCard( // Moved OUTSIDE the builders
                      color: Colors.white,
                      child: Column(
                        children: [
                          const Text("Employee List", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const Divider(color: Color(0xFF1A3E88)),
                          
                          // Now only the list contents respond to the Stream
                          StreamBuilder<QuerySnapshot>(
                            stream: _shiftStream,
                            builder: (context, shiftSnapshot) {
                              if (shiftSnapshot.hasError) {
                                debugPrint("Firestore Error: ${shiftSnapshot.error}");
                                return const Center(child: Text("Error loading shifts. Check console for index link."));
                              }

                              return StreamBuilder<QuerySnapshot>(
                                stream: _leaveStream,
                                builder: (context, leaveSnapshot) {
                                  if (leaveSnapshot.hasError) {
                                    debugPrint("Firestore Error: ${leaveSnapshot.error}");
                                    return const Center(child: Text("Error loading leaves. Check console for index link."));
                                  }

                                  return StreamBuilder<QuerySnapshot>(
                                    stream: _userStream,
                                    builder: (context, userSnapshot) {
                                      if (userSnapshot.hasError) {
                                        debugPrint("Firestore Error: ${userSnapshot.error}");
                                        return const Center(child: Text("Error loading users. Check console for index link."));
                                      }
                                      
                                      // This loading indicator is now inside the card!
                                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                                        return const Padding(
                                          padding: EdgeInsets.all(20.0),
                                          child: Center(child: CircularProgressIndicator()),
                                        );
                                      }
                                  
                                      if (!userSnapshot.hasData || userSnapshot.data!.docs.isEmpty) {
                                        return const Padding(
                                          padding: EdgeInsets.all(20.0),
                                          child: Text("No employees found in this department."),
                                        );
                                      }
                                  
                                      var employees = userSnapshot.data!.docs;
                                      var activeShifts = shiftSnapshot.data?.docs ?? [];
                                      var activeLeaves = leaveSnapshot.data?.docs ?? [];

                                      // --- DEBUGGING PRINTS ---
                                      debugPrint("--- DEBUG START ---");
                                      debugPrint("Active Shifts Found: ${activeShifts.length}");
                                      debugPrint("Active Leaves Found: ${activeLeaves.length}");
                                  
                                      Map<String, String> employeeStatusMap = {};

                                      // 3. Process Leaves FIRST. 
                                      // If they are on leave, mark them as 'on-leave'.
                                      for (var doc in activeLeaves) {
                                        var data = doc.data() as Map<String, dynamic>;
                                        debugPrint("Leave Document Data: $data"); // Check what fields actually exist!
                                        
                                        // REPLACE 'leaveUserID' with your actual field name if it's different
                                        String? leaveUser = data['leaveUserID']; 
                                        if (leaveUser != null) {
                                          employeeStatusMap[leaveUser] = 'on-leave'; 
                                          debugPrint("Marked $leaveUser as on-leave");
                                        } else {
                                          debugPrint("WARNING: 'leaveUserID' is null for document ${doc.id}");
                                        }
                                      }
                                      debugPrint("--- DEBUG END ---");

                                      // 4. Process Shifts SECOND.
                                      // Only add the shift status if they are NOT on leave.
                                      for (var doc in activeShifts) {
                                        var data = doc.data() as Map<String, dynamic>;
                                        String uid = data['shiftUserID'];
                                        
                                        if (employeeStatusMap[uid] != 'on-leave') {
                                          employeeStatusMap[uid] = data['shiftStatus'] ?? 'pending';
                                        }
                                      }
                                  
                                      return ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: employees.length,
                                        itemBuilder: (context, index) {
                                          var employeeData = employees[index].data() as Map<String, dynamic>;
                                          String name = "${employeeData['userFName']} ${employeeData['userLName']}";
                                          String employeeID = employees[index].id;
                                          String status = employeeStatusMap[employeeID] ?? "none";
                                  
                                          return _buildEmployeeRow(name, status, employeeID);
                                        },
                                      );
                                    },
                                  );
                                }
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  : _buildCard(
                      color: AppColors.bgLightBlue,
                      child: const Center(child: Text("Select a date to view shift status")),
                    ),

              // 3. Leave Requests (Scrollable Version)
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
                    
                    // Fixed height container to enable internal scrolling
                    SizedBox(
                      height: 300, // Set the height you want for the scrollable area
                      child: StreamBuilder<QuerySnapshot>(
                        // 1. Fetching leave requests specific to this employee
                        stream: FirebaseFirestore.instance
                            .collection('leaves')
                            .where('deptCode', isEqualTo: widget.deptCode) // Using widget.employeeID from your class
                            .where('leaveDate', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 0, 0, 0)))
                            .orderBy('leaveDate', descending: false)  // Newest requests on top
                            .snapshots(),
                        builder: (context, snapshot) {
                          // 2. Handle Loading & Errors
                          if (snapshot.hasError) {
                            debugPrint("$snapshot.error");
                          }
                          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                      
                          final leaveDocs = snapshot.data?.docs ?? [];
                      
                          // 3. Handle Empty State (UX Polish)
                          if (leaveDocs.isEmpty) {
                            return const Center(
                              child: Text("No leave requests found.", 
                              style: TextStyle(color: Colors.grey))
                            );
                          }
                      
                          // 4. Build the dynamic list
                          return Scrollbar(
                            controller: _leaveScrollController,
                            thumbVisibility: true,
                            child: ListView.builder(
                              controller: _leaveScrollController,
                              primary: false,
                              padding: const EdgeInsets.only(right: 10),
                              itemCount: leaveDocs.length,
                              itemBuilder: (context, index) {
                                var doc = leaveDocs[index];
                                var data = doc.data() as Map<String, dynamic>;
                                
                                // Extract and format data
                                String employeeID = data['leaveUserID'] ?? "Unknown";
                                String employeeName = data['leaveUserName'] ?? "Unknown";
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
                                  isManager: true,
                                  managerNote: data['managerReason']
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Shift Summary
              StreamBuilder<QuerySnapshot>(
                stream:  FirebaseFirestore.instance
                    .collection('shifts')
                    .where('deptCode', isEqualTo: widget.deptCode)
                    .where('shiftDate', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 0, 0, 0)))
                    .snapshots(),
                builder: (context, shiftSnapshot) {
                  // Initialize counters
                  int pendingShift = 0;
                  int acceptedShift = 0;
                  int rejectedShift = 0;

                  // Tally up the statuses if data exists
                  if (shiftSnapshot.hasData) {
                    for (var doc in shiftSnapshot.data!.docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      String status = data['shiftStatus'] ?? 'none';
                      
                      if (status == 'pending') pendingShift++;
                      if (status == 'accepted') acceptedShift++;
                      if (status == 'rejected') rejectedShift++;
                    }
                  }

                  // A nested StreamBuilder specifically to count department-wide pending leaves
                  return _buildCard(
                    child: Column(
                      children: [
                        const Text(
                          "Shift Summary",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Divider(color: Color(0xFF1A3E88)),
                        _buildStatRow("Pending Shift", pendingShift.toString()),
                        _buildStatRow("Accepted Shift", acceptedShift.toString()),
                        _buildStatRow("Rejected Shift", rejectedShift.toString()),
                      ],
                    ),
                  );
                },
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

  // --- Shift Assignment ---
  // Helper for Building Employee Rows
  Widget _buildEmployeeRow(String name, String status, String employeeID) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          // Pass the name into the status action
          _buildStatusAction(status, name, employeeID), 
        ],
      ),
    );
  }

  // Helper for Building Employee Status
  Widget _buildStatusAction(String status, String employeeName, String employeeID) {
    switch (status) {
      case 'none':
        return SizedBox(
          height: 30,
          width: 100,
          child: ElevatedButton(
            onPressed: _isOffline ? null : () => _assignShiftAction(employeeID, employeeName),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isOffline ? Colors.grey : Colors.white,
              foregroundColor: Colors.black,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text(_isOffline ? "No Internet" : "Assign"),
          ),
        );
      case 'pending':
        return SizedBox(
          height: 30,
          width: 120,
          child: ElevatedButton(
            onPressed: _isOffline ? null : () => _removeShiftConfirmation(employeeID),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isOffline ? Colors.grey : Colors.blueGrey,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text(_isOffline ? "No Internet" : "Pending"),
          ),
        );
      case 'accepted':
        return SizedBox(
          height: 30,
          width: 120,
          child: ElevatedButton(
            onPressed: _isOffline ? null : () => _removeShiftConfirmation(employeeID),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isOffline ? Colors.grey : const Color.fromARGB(255, 16, 117, 54),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text(_isOffline ? "No Internet" : "Accepted"),
          ),
        );
      case 'rejected':
        return SizedBox(
          height: 30,
          width: 120,
          child: ElevatedButton(
            onPressed: _isOffline ? null : () => _removeShiftConfirmation(employeeID),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isOffline ? Colors.grey : const Color.fromARGB(255, 210, 22, 22),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text(_isOffline ? "No Internet" : "Rejected"),
          ),
        );
      case 'on-leave':
        return SizedBox(
          height: 30,
          width: 120,
          child: ElevatedButton(
            onPressed: null, 
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[700],
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text(_isOffline ? "No Internet" : "On-Leave"),
          ),
        );
      default:
        return const SizedBox();
    }
  }

  // Feature - Assign shift to a employee
  void _assignShiftAction(String employeeID, String employeeName) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // Use StatefulBuilder to update time inside dialog
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Assign Shift to $employeeName", 
            style: const TextStyle(color: AppColors.primaryBlue, fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Date: ${DateFormat('dd MMM yyyy').format(_selectedDay!)}"),
                const SizedBox(height: 20),
                
                // Start Time Picker
                ListTile(
                  title: const Text("Start Time"),
                  trailing: Text(_startTime.format(context)),
                  onTap: () async {
                    TimeOfDay? picked = await showTimePicker(context: context, initialTime: _startTime);
                    if (picked != null) setDialogState(() => _startTime = picked);
                  },
                ),

                // End Time Picker
                ListTile(
                  title: const Text("End Time"),
                  trailing: Text(_endTime.format(context)),
                  onTap: () async {
                    TimeOfDay? picked = await showTimePicker(context: context, initialTime: _endTime);
                    if (picked != null) setDialogState(() => _endTime = picked);
                  },
                ),

                const SizedBox(height: 10),
                TextField(
                  controller: _taskController,
                  decoration: InputDecoration(
                    labelText: "Task Description",
                    hintText: "e.g. Morning Reception, Inventory",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // Cancel Shift
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            // Confirm Shift
            ElevatedButton(
              onPressed: () async {
              // Mapping your local variables to the function parameters
              await _submitShiftToFirestore(
                employeeID: employeeID, 
                taskName: _taskController.text
              );
              
              if (mounted) Navigator.pop(context);
              _taskController.clear();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
            child: const Text("Confirm"),
          ),
          ],
        ),
      ),
    );
  }

  // Feature - Submit Assigned Shift
  Future<void> _submitShiftToFirestore({
    required String employeeID,
    required String taskName,
  }) async {
    try{
      DocumentSnapshot employeeDoc = await FirebaseFirestore.instance
        .collection('users') 
        .doc(employeeID)
        .get();

      String fullName = "Unknown";

      if (employeeDoc.exists) {
        final data = employeeDoc.data() as Map<String, dynamic>;
        String fName = data['userFName'] ?? "";
        String lName = data['userLName'] ?? "";
        fullName = "$fName $lName".trim();
      }

      // Convert TimeOfDay to String for easy storage
      DateTime startDateTime = DateTime(
        _selectedDay!.year,
        _selectedDay!.month,
        _selectedDay!.day,
        _startTime.hour,
        _startTime.minute,
      );

      DateTime endDateTime = DateTime(
        _selectedDay!.year,
        _selectedDay!.month,
        _selectedDay!.day,
        _endTime.hour,
        _endTime.minute,
      );

      await FirebaseFirestore.instance.collection('shifts').add({
        'shiftDate': Timestamp.fromDate(_selectedDay!), 
        'shiftStartTime': Timestamp.fromDate(startDateTime),
        'shiftEndTime': Timestamp.fromDate(endDateTime),
        'shiftStatus': 'pending',
        'shiftUserID': employeeID,
        'shiftUserName': fullName,
        'shiftTask': taskName,
        'deptCode': widget.deptCode, // Using widget.deptCode from the constructor
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
    debugPrint("Error assigning shift: $e");
    }
  }

  // Feature - Confirm Before Removing a Shift Under Status [pending, accepted, rejected]
  void _removeShiftConfirmation(String employeeID){
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Remove Shift", style: TextStyle(fontWeight:FontWeight(5)),),
          content: const Text("Are you sure you want to remove the shift?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.black),),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _removeShiftAction(employeeID);       // Run the reset logic
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  // Feature - Remove a Shift After Confirmation
  void _removeShiftAction(String employeeID) async {
    // Find the shift for this user on this day and delete it
    var snapshot = await FirebaseFirestore.instance
        .collection('shifts')
        .where('shiftUserID', isEqualTo: employeeID)
        .where('shiftDate', isEqualTo: Timestamp.fromDate(_selectedDay!))
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // Helper for Summary Rows
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primaryBlue),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(value, textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 1. Create a helper function to avoid code duplication
  void _updateStreams(DateTime date) {
    // Force the range to cover the FULL day
    DateTime start = DateTime(date.year, date.month, date.day, 0, 0, 0);
    DateTime end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    setState(() {
      _shiftStream = FirebaseFirestore.instance
          .collection('shifts')
          .where('deptCode', isEqualTo: widget.deptCode)
          .where('shiftDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('shiftDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .snapshots();

      _leaveStream = FirebaseFirestore.instance
          .collection('leaves')
          .where('deptCode', isEqualTo: widget.deptCode) // Filter by dept too!
          .where('leaveStatus', isEqualTo: 'approved')
          .where('leaveDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('leaveDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .snapshots();

      _userStream = FirebaseFirestore.instance
            .collection('users')
            .where('deptCode', isEqualTo: widget.deptCode)
            .where('userRole', isEqualTo: 'employee')
            .snapshots();
    });
  }
}