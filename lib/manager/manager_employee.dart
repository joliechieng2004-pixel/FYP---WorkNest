// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:worknest/services/attendance_count.dart';
import 'package:worknest/services/auth_service.dart';
import 'package:worknest/services/connectivity_service.dart';
import 'package:worknest/utils/app_colors.dart';
import 'package:worknest/widget/employee_profile_dialog.dart';

class ManagerEmployee extends StatefulWidget {
  final String deptCode;

  const ManagerEmployee({super.key, required this.deptCode});

  @override
  State<ManagerEmployee> createState() => _ManagerEmployeePageState();
}

class _ManagerEmployeePageState extends State<ManagerEmployee> {
  final TextEditingController _searchController = TextEditingController();
  
  // check connection
  late StreamSubscription<bool> _connectivitySubscription;
  bool _isOffline = false;
  
  String _searchQuery = "";

  // Track which employee is currently expanded
  String? _expandedIndex;
  
  late Stream<QuerySnapshot> _userStream;

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
    _userStream = FirebaseFirestore.instance
            .collection('users')
            .where('deptCode', isEqualTo: widget.deptCode)
            .where('userRole', isEqualTo: 'employee') // Only show employees
            .snapshots();
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

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _searchController.dispose(); // Always clean up controllers!
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FAFF), // Light blue background
      appBar: AppBar(
        title: const Text("Manage Employees"),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A3E88),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: firstRowElements(),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 20, top: 10),
              child: Text("Employee List:", 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            
            // The Styled List Container
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFF1A3E88), width: 2),
                ),
                child: Column(
                  children: [
                    // Fixed Header Row
                    _buildCustomHeader(),
                    const Divider(height: 1, color: Color(0xFF1A3E88)),
                    
                    // Scrollable List of Employees
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _userStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Center(child: Text("Something went wrong"));
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.data!.docs.isEmpty) {
                            return const Center(child: Text("No employees found in this department."));
                          }

                          // --- FILTERING LOGIC ---
                          final allDocs = snapshot.data!.docs;
                          
                          final filteredDocs = allDocs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            String fName = (data['userFName'] ?? '').toString().toLowerCase();
                            String lName = (data['userLName'] ?? '').toString().toLowerCase();
                            String fullName = "$fName $lName";
                            
                            return fullName.contains(_searchQuery);
                          }).toList();

                          if (filteredDocs.isEmpty) {
                            return const Center(
                              child: Text("No employees found matching your search."),
                            );
                          }

                          return ListView.builder(
                            key: ValueKey(_searchQuery),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            itemCount: filteredDocs.length,
                            itemBuilder: (context, index) {
                              return _buildExpandableEmployeeRow(filteredDocs[index], index);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Header Row to match your table design
  Widget _buildCustomHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Center(child: Text("Name", style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(flex: 3, child: Center(child: Text("Enroll Date", style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(flex: 3, child: Center(child: Text("Attendance", style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(flex: 1, child: Center(child: Text(" "),),),
        ],
      ),
    );
  }

  // Each individual Employee Row that expands
  Widget _buildExpandableEmployeeRow(DocumentSnapshot doc, int index) {
    bool isExpanded = _expandedIndex == doc.id;
    // Extract data from Firestore document
    Map<String, dynamic> employee = doc.data() as Map<String, dynamic>;
    String fName = employee['userFName' ] ?? 'Unknown';
    String lName = employee['userLName' ] ?? 'Unknown';
    DateTime? addDate = _safeDate(employee['createdAt']);
    String formattedDate = addDate != null ? DateFormat('dd MMM yyyy').format(addDate) : "--";
    String employeeID = doc.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedIndex = isExpanded ? null : doc.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: isExpanded ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
        ),
        child: Column(
          children: [
            // Basic Info Row
            Row(
              children: [
                Expanded(flex: 3, child: Center(child: Text("$fName $lName"))),
                Expanded(flex: 3, child: Center(child: Text(formattedDate))),
                Expanded(flex: 3, child: Center(
                  child: FutureBuilder<double>(
                    future: AttendanceCount.getAttendanceRate(employeeID),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 12, 
                          width: 12, 
                          child: CircularProgressIndicator(strokeWidth: 2)
                        );
                      }
                      
                      // Use a default value of 0.0 if data is null
                      double rate = snapshot.data ?? 0.0;
                      return Text("${rate.toStringAsFixed(0)}%");
                    },
                  )
                )),
                Expanded(flex: 1, child: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 18)),
              ],
            ),
            
            // Expandable Action Buttons
            if (isExpanded) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionButton("View Profile", Colors.white, () {
                    _openEmployeeProfile(employee, employeeID);
                    debugPrint("Viewing profile of $fName $lName");
                  }),
                  _actionButton("Remove Employee", Colors.white, () {
                    _showRemoveConfirmation(doc.id);}, isDelete: true),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onPressed, {bool isDelete = false}) {
    return OutlinedButton(
      onPressed: _isOffline ? null : onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.black87),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        backgroundColor: _isOffline ? Colors.grey : Colors.white
      ),
      child: Text(_isOffline ? "No Internet" : label, style: const TextStyle(color: Colors.black87, fontSize: 12)),
    );
  }

  // --- STUBS FOR YOUR EXISTING WIDGETS ---

  Widget firstRowElements() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Search Bar Implementation
        Expanded(
          child: Container(
            height: 35,
            margin: const EdgeInsets.only(right: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: "Search name...",
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primaryBlue),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20, color: AppColors.primaryBlue),
                      onPressed: () {
                        _searchController.clear();
                        setState(() { _searchQuery = ""; });
                      },
                    ) 
                  : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2.0)
                ),
              ),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isOffline ? null : addEmployee,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primaryBlue,
            side: const BorderSide(color: AppColors.primaryBlue),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          icon: _isOffline ? const Icon(Icons.signal_wifi_connected_no_internet_4) : const Icon(Icons.add, size: 18),
          label: Text(_isOffline ? "No Internet" : "Add"),
        )
      ]
    );
  }

  void _showRemoveConfirmation(String docId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Remove Employee", style: TextStyle(fontWeight:FontWeight(5)),),
          content: const Text("Are you sure you want to remove the employee?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.black),),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                _removeEmployee(docId);       // Run the reset logic
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  void addEmployee() {
    final fNameController = TextEditingController();
    final lNameController = TextEditingController();
    final emailController = TextEditingController();
    final contactController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Register New Employee", 
          style: TextStyle(color: Color(0xFF1A3E88), fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPopupField(fNameController, "First Name", Icons.person),
                _buildPopupField(lNameController, "Last Name", Icons.person),
                _buildPopupField(emailController, "Email Address", Icons.email),
                _buildPopupField(contactController, "Contact Number", Icons.phone),
                _buildPopupField(passwordController, "Temporary Password", Icons.lock, isPassword: true),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              
              if (formKey.currentState!.validate()) {
                // 1. Show loading
                showDialog(
                  context: context, 
                  barrierDismissible: false, 
                  builder: (context) => const Center(child: CircularProgressIndicator())
                );

                // 2. Call the logic to save to Firebase
                String? result = await AuthService().createEmployeeByManager(
                  fName: fNameController.text.trim(),
                  lName: lNameController.text.trim(),
                  email: emailController.text.trim(),
                  contact: contactController.text.trim(),
                  password: passwordController.text.trim(),
                  managerDeptCode: widget.deptCode,
                );

                if (mounted) Navigator.pop(context); // Close loading

                if (result == null) {
                  if (mounted) Navigator.pop(context); // Close the Add Employee dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Employee account created!"), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $result"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A3E88)),
            child: const Text("Register", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Helper to build the text fields inside the popup
  Widget _buildPopupField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF1A3E88)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        validator: (val) => val!.isEmpty ? "Required field" : null,
      ),
    );
  }

  Future<void> _removeEmployee(String docId) async {
    try {
      // 1. Show loading spinner
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final DateTime now = DateTime.now();
      // Find all shifts for this user that haven't happened yet
      var futureShifts = await FirebaseFirestore.instance
          .collection('shifts')
          .where('shiftUserID', isEqualTo: docId)
          .where('shiftStartTime', isGreaterThan: now)
          .get();

      // 2. Use a Batch to update both User and Department
      WriteBatch batch = FirebaseFirestore.instance.batch();
      
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(docId);
      DocumentReference deptRef = FirebaseFirestore.instance.collection('departments').doc(widget.deptCode);

      batch.update(userRef, {
        'status': 'disabled', // The key flag
        'deptCode': null,     // Disconnect them from the department
        'removedAt': FieldValue.serverTimestamp(),
      });

      batch.update(deptRef, {
        'totalMembers': FieldValue.increment(-1),
      });

      for (var shift in futureShifts.docs) {
        batch.delete(shift.reference);
      }

      await batch.commit();

      if (mounted) Navigator.pop(context); // Close spinner

      _showSnackBar("Employee deactivated. (Note: Admin must manually delete Auth account to reuse email)", Colors.orange);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar("Error: $e", Colors.red);
    }
  }

  void _openEmployeeProfile(Map<String, dynamic> employeeData, String employeeID) async {
    // 1. Show a simple loading indicator so the user knows something is happening
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 2. Fetch the combined stats (Rate and Absent Count) in one call
      final stats = await AttendanceCount.getFullAttendanceStats(employeeID);

      // 3. Close the loading indicator
      if (mounted) Navigator.pop(context);

      // 4. Open the actual Profile Dialog with REAL data
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => EmployeeProfileDialog(
            employeeData: employeeData,
            attendanceRate: stats['rate'], // Dynamic double
            totalAbsences: stats['absent'], // Dynamic int
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loader on error
      debugPrint("Error fetching employee stats: $e");
    }
  }

  // Helper for showing messages
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // Helper for safe date conversion
  DateTime? _safeDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}