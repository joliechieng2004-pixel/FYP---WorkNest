import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:worknest/widget/leaveitem.dart';

class ManagerSchedule extends StatefulWidget {
  final String deptCode;

  const ManagerSchedule({super.key, required this.deptCode});

  @override
  State<ManagerSchedule> createState() => _ManagerSchedulePageState();
}

class _ManagerSchedulePageState extends State<ManagerSchedule> {
  // often use colors
  final Color primaryBlue = const Color.fromARGB(255, 40, 75, 158);
  final Color bgLightBlue = const Color.fromARGB(255, 240, 250, 255);
  
  late Stream<QuerySnapshot> _shiftStream;
  late Stream<QuerySnapshot> _userStream;

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
  String deptCode = "Loading...";
  String formattedDate = DateFormat('EEEE, d MMM yyyy').format(DateTime.now());
  String formattedTime = DateFormat('h:mm a').format(DateTime.now());

  // --- INITIALIZATION ---
  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now(); // Default selection to today
    initStreams();
  }

  void initStreams(){
    _shiftStream = FirebaseFirestore.instance
            .collection('shifts')
            .where('deptCode', isEqualTo: widget.deptCode)
            .where('shiftDate', isEqualTo: Timestamp.fromDate(_selectedDay!))
            .snapshots();
    _userStream = FirebaseFirestore.instance
            .collection('users')
            .where('deptCode', isEqualTo: widget.deptCode)
            .where('userRole', isEqualTo: 'employee')
            .snapshots();
  }

  @override
  void dispose() {
    _leaveScrollController.dispose(); // Clean up the controller
    super.dispose(); 
  }

  // --- BUILD WIDGETS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLightBlue,
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

                      // RE-INITIALIZE the shift stream for the new date!
                      _shiftStream = FirebaseFirestore.instance
                          .collection('shifts')
                          .where('deptCode', isEqualTo: widget.deptCode)
                          .where('shiftDate', isEqualTo: Timestamp.fromDate(_selectedDay!))
                          .snapshots();
                    });
                    // TODO: Fetch shifts from Firestore for this specific date!
                    print("Selected Date: $_selectedDay");
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  // Custom Styling
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                    selectedDecoration: BoxDecoration(color: Color(0xFF1A3E88), shape: BoxShape.circle),
                    markerDecoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle), // For shifts
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                  ),
                ),
              ),

              // 2. Worker List
              _isDateSelected
                  ? _buildCard( // Moved OUTSIDE the builders
                      color: Colors.white,
                      child: Column(
                        children: [
                          const Text("Worker List", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const Divider(color: Color(0xFF1A3E88)),
                          
                          // Now only the list contents respond to the Stream
                          StreamBuilder<QuerySnapshot>(
                            stream: _shiftStream,
                            builder: (context, shiftSnapshot) {
                              return StreamBuilder<QuerySnapshot>(
                                stream: _userStream,
                                builder: (context, userSnapshot) {
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
                                      child: Text("No workers found in this department."),
                                    );
                                  }

                                  var workers = userSnapshot.data!.docs;
                                  var activeShifts = shiftSnapshot.data?.docs ?? [];

                                  Map<String, String> workerStatusMap = {};
                                  for (var doc in activeShifts) {
                                    var data = doc.data() as Map<String, dynamic>;
                                    workerStatusMap[data['shiftUserID']] = data['shiftStatus'] ?? 'pending';
                                  }

                                  return ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: workers.length,
                                    itemBuilder: (context, index) {
                                      var workerData = workers[index].data() as Map<String, dynamic>;
                                      String name = "${workerData['userFName']} ${workerData['userLName']}";
                                      String workerID = workers[index].id;
                                      String status = workerStatusMap[workerID] ?? "none";

                                      return _buildWorkerRow(name, status, workerID);
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  : _buildCard(
                      color: bgLightBlue,
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
                      child: Scrollbar(
                        controller: _leaveScrollController,
                        thumbVisibility: true, // Makes the scrollbar visible like in your design
                        child: StreamBuilder<QuerySnapshot>(
                          // 1. Fetching leave requests specific to this worker
                          stream: FirebaseFirestore.instance
                              .collection('leaves')
                              .where('deptCode', isEqualTo: widget.deptCode) // Using widget.workerID from your class
                              .orderBy('leaveDate', descending: true)  // Newest requests on top
                              .snapshots(),
                          builder: (context, snapshot) {
                            // 2. Handle Loading & Errors
                            if (snapshot.hasError) 
                              print("$snapshot.error");
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
                            return ListView.builder(
                              controller: _leaveScrollController,
                              padding: const EdgeInsets.only(right: 10),
                              itemCount: leaveDocs.length,
                              itemBuilder: (context, index) {
                                var doc = leaveDocs[index];
                                var data = doc.data() as Map<String, dynamic>;
                                
                                // Extract and format data
                                String status = data['leaveStatus'] ?? "pending";
                                String reason = data['leaveReason'] ?? "No reason provided";
                                DateTime date = (data['leaveDate'] as Timestamp).toDate();
                                String formattedDate = DateFormat('d MMM yyyy, EEE').format(date);
                                
                                return ExpandableLeaveItem(
                                  docId: doc.id,
                                  title: formattedDate,
                                  reason: reason,
                                  status: status,
                                  isManager: true,
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

              // 4. Shift Summary
              _buildCard(
                child: Column(
                  children: [
                    const Text(
                          "Shift Summary",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                    const Divider(color: Color(0xFF1A3E88)),
                    _buildStatRow("Pending Leave", "20"),
                    _buildStatRow("Pending Shift", "20"),
                    _buildStatRow("Accepted Shift", "10"),
                    _buildStatRow("Rejected Shift", "10"),
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
        border: Border.all(color: primaryBlue, width: 2),
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
  // Helper for Building Worker Rows
  Widget _buildWorkerRow(String name, String status, String workerID) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          // Pass the name into the status action
          _buildStatusAction(status, name, workerID), 
        ],
      ),
    );
  }

  // Helper for Building Worker Status
  Widget _buildStatusAction(String status, String workerName, String workerID) {
    switch (status) {
      case 'none':
        return SizedBox(
          height: 30,
          width: 100,
          child: ElevatedButton(
            onPressed: () => _assignShiftAction(workerID, workerName),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text("Assign"),
          ),
        );
      case 'pending':
        return SizedBox(
          height: 30,
          width: 100,
          child: ElevatedButton(
            onPressed: () => _removeShiftConfirmation(workerID),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text("Pending"),
          ),
        );
      case 'accepted':
        return SizedBox(
          height: 30,
          width: 100,
          child: ElevatedButton(
            onPressed: () => _removeShiftConfirmation(workerID),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 16, 117, 54),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text("Accepted"),
          ),
        );
      case 'rejected':
        return SizedBox(
          height: 30,
          width: 100,
          child: ElevatedButton(
            onPressed: () => _removeShiftConfirmation(workerID),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 210, 22, 22),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text("Rejected"),
          ),
        );
      case 'on-leave':
        return const SizedBox(
          height: 30,
          width: 100,
          child: Text("Unavailable"),
        );
      default:
        return const SizedBox();
    }
  }

  // Feature - Assign shift to a worker
  void _assignShiftAction(String workerID, String workerName) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // Use StatefulBuilder to update time inside dialog
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Assign Shift to $workerName", 
            style: TextStyle(color: primaryBlue, fontSize: 18, fontWeight: FontWeight.bold)),
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
                workerID: workerID, 
                taskName: _taskController.text
              );
              
              if (mounted) Navigator.pop(context);
              _taskController.clear();
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
            child: const Text("Confirm"),
          ),
          ],
        ),
      ),
    );
  }

  // Feature - Submit Assigned Shift
  Future<void> _submitShiftToFirestore({
    required String workerID,
    required String taskName,
  }) async {
    try{
      DocumentSnapshot workerDoc = await FirebaseFirestore.instance
        .collection('users') 
        .doc(workerID)
        .get();

      String fullName = "Unknown";

      if (workerDoc.exists) {
        final data = workerDoc.data() as Map<String, dynamic>;
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
        'shiftUserID': workerID,
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
  void _removeShiftConfirmation(String workerID){
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
                _removeShiftAction(workerID);       // Run the reset logic
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
  void _removeShiftAction(String workerID) async {
    // Find the shift for this user on this day and delete it
    var snapshot = await FirebaseFirestore.instance
        .collection('shifts')
        .where('shiftUserID', isEqualTo: workerID)
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
              border: Border.all(color: primaryBlue),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(value, textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}