import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:worknest/widget/leaveitem.dart';

class EmployeeSchedule extends StatefulWidget {
  final String deptCode;
  final String workerID;

  const EmployeeSchedule({super.key, required this.deptCode, required this.workerID});

  @override
  State<EmployeeSchedule> createState() => _EmployeeSchedulePageState();
}

class _EmployeeSchedulePageState extends State<EmployeeSchedule> {
  // often use colors
  final Color primaryBlue = const Color.fromARGB(255, 40, 75, 158);
  final Color bgLightBlue = const Color.fromARGB(255, 240, 250, 255);

  // Calendar
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isDateSelected = false;
  
  final TextEditingController _leaveController = TextEditingController();
  final ScrollController _leaveScrollController = ScrollController();
  String deptCode = "Loading...";
  String formattedDate = DateFormat('EEEE, d MMM yyyy').format(DateTime.now());
  String formattedTime = DateFormat('h:mm a').format(DateTime.now());
  Stream<QuerySnapshot>? _shiftStream;

  // --- INITIALIZATION ---
  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now(); // Default selection to today
    _focusedDay = DateTime.now();
    _isDateSelected = true;
    _updateStream(_selectedDay!);
  }

  @override
  void dispose() {
    _leaveController.dispose();
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
                    });
                    _updateStream(selectedDay);
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

              // 2. Shift List for Employee
              _isDateSelected
                  ? StreamBuilder<QuerySnapshot>(
                      stream: _shiftStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return _buildEmptyShiftWithLeave();
                        }

                        // Get the shift data
                        var shiftDoc = snapshot.data!.docs.first;
                        var shiftData = shiftDoc.data() as Map<String, dynamic>;
                        String shiftID = shiftDoc.id;
                        String status = shiftData['shiftStatus'] ?? 'pending';

                        return _buildEmployeeShiftCard(shiftData, shiftID, status);
                      },
                    )
                  : _buildCard(
                      color: bgLightBlue,
                      child: const Center(child: Text("Select a date to view your shift")),
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
                        child: // Inside your Leave Requests _buildCard
                          ListView.builder(
                            controller: _leaveScrollController,
                            padding: const EdgeInsets.only(right: 10),
                            itemCount: 5, // Example count
                            itemBuilder: (context, index) {
                              return const ExpandableLeaveItem(
                                title: "Employee Name Here",
                                reason: "Family emergency, need to travel back to KL.",
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

  // --- Shift ---
  Widget _buildEmployeeShiftCard(Map<String, dynamic> data, String docID, String status) {
    // Safe conversion helper
    DateTime? safeDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    // Get formatted strings safely
    DateTime? dateVal = safeDate(data['shiftDate']);
    DateTime? startVal = safeDate(data['shiftStartTime']);
    DateTime? endVal = safeDate(data['shiftEndTime']);

    String dateStr = dateVal != null ? DateFormat('d MMM yyyy, EEEE').format(dateVal) : "No Date";
    String timeRange = (startVal != null && endVal != null)
        ? "${DateFormat.jm().format(startVal)} - ${DateFormat.jm().format(endVal)}"
        : "Time Not Set";

    return _buildCard(
      color: Colors.white,
      child: Column(
        children: [
          const Text(
            "Shift Details",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Divider(color: Color(0xFF1A3E88)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side: Shift Details
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(timeRange, style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 8),
                    Text("Location: ${data['shiftLocation'] ?? 'Workplace'}", style: const TextStyle(color: Colors.grey)),
                    if (data['shiftTask'] != null) ...[
                      const SizedBox(height: 8),
                      Text("Task: ${data['shiftTask']}", style: const TextStyle(fontStyle: FontStyle.italic)),
                    ]
                  ],
                ),
              ),

              // Right side: Action Logic
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    if (status == 'accepted') 
                      // 1. If accepted, buttons disappear (Show nothing or a small badge)
                      const Icon(Icons.check_circle, color: Colors.green, size: 40)
                    
                    else if (status == 'rejected') ...[
                      // 2. If rejected, buttons are disabled, Reject is filled
                      _buildActionButton("Accept", Colors.green, () {}, false, isDisabled: true),
                      const SizedBox(height: 10),
                      _buildActionButton("Reject", Colors.red, () {}, true, isDisabled: true),
                    ] 
                    
                    else ...[
                      // 3. If pending, both buttons trigger the confirmation dialog first
                      _buildActionButton(
                        "Accept", 
                        Colors.green, 
                        () => _showStatusConfirmation(docID, 'accepted'), // Changed
                        false
                      ),
                      const SizedBox(height: 10),
                      _buildActionButton(
                        "Reject", 
                        Colors.red, 
                        () => _showStatusConfirmation(docID, 'rejected'), // Changed
                        false
                      ),
                    ],
                  ],
                ),
              ),
            ]
          ),
          const Divider(height: 30),
          
          _buildRequestLeaveButton({
            'shiftDate': Timestamp.fromDate(_selectedDay!),
            'shiftLocation': 'N/A',
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyShiftWithLeave() {
    return _buildCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
                "Shift Details",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
          ),
          const Divider(color: Color(0xFF1A3E88)),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.event_busy, size: 50, color: Colors.grey),
              SizedBox(width: 10),
              Text("No shift assigned for this date.", style: TextStyle(color: Colors.grey, fontSize: 15)),
            ],
          ),
          const Divider(height: 30),
          
          // The button is now here too!
          _buildRequestLeaveButton({
            'shiftDate': Timestamp.fromDate(_selectedDay!),
            'shiftLocation': 'N/A',
          }),
        ],
      ),
    );
  }

  Widget _buildRequestLeaveButton(Map<String, dynamic> data) {
    return OutlinedButton.icon(
      onPressed: () => _handleLeaveRequest(data),
      icon: const Icon(Icons.beach_access, size: 18),
      label: const Text("Request Leave"),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 45),
        side: const BorderSide(color: Colors.black),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        foregroundColor: Colors.black,
      ),
    );
  }

  // Small helper for the Accept/Reject buttons
  Widget _buildActionButton(String label, Color color, VoidCallback onTap, bool isFilled, {bool isDisabled = false}) {
    return SizedBox(
      width: double.infinity,
      height: 35,
      child: ElevatedButton(
        // If isDisabled is true, onPressed is null (disables the button)
        onPressed: isDisabled ? null : onTap,
        style: ElevatedButton.styleFrom(
          // Logic for filled vs outlined
          backgroundColor: isFilled ? color : Colors.white,
          foregroundColor: isFilled ? Colors.white : color,
          
          // Disabled styling
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
        content: Text("Are you sure you want to $newStatus this shift? This action may be permanent."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _updateStatus(docID, newStatus); // Perform update
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'accepted' ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  // Function to update the shift status in Firebase
  Future<void> _updateStatus(String docID, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('shifts')
          .doc(docID)
          .update({'shiftStatus': newStatus});

      if (!mounted) return; // Best practice: check if widget is still in tree
      
      // Success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Shift $newStatus successfully!"), 
          backgroundColor: newStatus == 'accepted' ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating, // Makes it look modern
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.orange),
      );
    }
  }

  // Function to trigger leave request (usually opens a dialog or new page)
  void _handleLeaveRequest(Map<String, dynamic> shiftData) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // Use StatefulBuilder to update time inside dialog
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Request for a Leave", 
            style: TextStyle(color: primaryBlue, fontSize: 18, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Date: ${DateFormat('dd MMM yyyy').format(_selectedDay!)}"),
                const SizedBox(height: 20),

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
            // Cancel Request
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            // Confirm Shift
            ElevatedButton(
              onPressed: () async {
                if (_leaveController.text.trim().isEmpty) {
                // Show a quick error without closing the dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please provide a reason")),
                );
                return;
              }
                // Mapping your local variables to the function parameters
                await _submitLeaveToFirestore(
                  workerID: widget.workerID, 
                  leaveReason: _leaveController.text
                );
                
                if (mounted) Navigator.pop(context);
                _leaveController.clear();
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
              child: const Text("Confirm"),
            ),
          ],
        ),
      ),
    );
  }

  // Feature - Submit Leave
  Future<void> _submitLeaveToFirestore({
    required String workerID,
    required String leaveReason,
  }) async {
    await FirebaseFirestore.instance.collection('leaves').add({
      'leaveDate': Timestamp.fromDate(_selectedDay!), 
      'leaveReason': leaveReason,
      'leaveStatus': 'pending',
      'leaveUserID': workerID,
      'managerReason': null,
    });
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

  void _updateStream(DateTime date) {
    DateTime startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    setState(() {
      _shiftStream = FirebaseFirestore.instance
          .collection('shifts')
          .where('shiftUserID', isEqualTo: widget.workerID)
          .where('shiftDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('shiftDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .snapshots();
    });
  }
}