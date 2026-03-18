import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:worknest/services/auth_service.dart';

class ManagerEmployee extends StatefulWidget {
  final String deptCode;

  const ManagerEmployee({super.key, required this.deptCode});

  @override
  State<ManagerEmployee> createState() => _ManagerEmployeePageState();
}

class _ManagerEmployeePageState extends State<ManagerEmployee> {
  // Track which worker is currently expanded
  int? _expandedIndex;
  
  late Stream<QuerySnapshot> _userStream;

  @override
  void initState() {
    super.initState();

    _userStream = FirebaseFirestore.instance
            .collection('users')
            .where('deptCode', isEqualTo: widget.deptCode)
            .where('userRole', isEqualTo: 'employee') // Only show employees
            .snapshots();
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
              child: FirstRowElements(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: WorkerFilter(),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 20, top: 10),
              child: Text("Worker List:", 
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
                    
                    // Scrollable List of Workers
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

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            itemCount: snapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              return _buildExpandableWorkerRow(snapshot.data!.docs[index], index);
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
          Expanded(flex: 1, child: Center(child: Text("ID", style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(flex: 3, child: Center(child: Text("Name", style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(flex: 2, child: Center(child: Text("Attendance", style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(flex: 2, child: Center(child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  // Each individual Worker Row that expands
  Widget _buildExpandableWorkerRow(DocumentSnapshot doc, int index) {
    bool isExpanded = _expandedIndex == index;
    // Extract data from Firestore document
    Map<String, dynamic> worker = doc.data() as Map<String, dynamic>;
    String fName = worker['userFName' ] ?? 'Unknown';
    String lName = worker['userLName' ] ?? 'Unknown';
    String status = (worker['isActive'] ?? true) ? "Active" : "Inactive";
    // For now, ID can be the last 3 digits of the Doc ID or a specific field
    String workerId = doc.id.substring(doc.id.length - 3).toUpperCase();

    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedIndex = isExpanded ? null : index;
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
                Expanded(flex: 1, child: Center(child: Text(workerId, style: const TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(flex: 3, child: Center(child: Text("$fName $lName"))),
                const Expanded(flex: 2, child: Center(child: Text("90%"))), // Attendance logic later
                Expanded(
                  flex: 2, 
                  child: Center(
                    child: Text(status, 
                      style: TextStyle(color: status == "Active" ? Colors.green : Colors.red, fontWeight: FontWeight.bold)
                    )
                  )
                ),
              ],
            ),
            
            // Expandable Action Buttons
            if (isExpanded) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionButton("View Profile", Colors.white, () {
                    print("Viewing profile of $fName $lName");
                  }),
                  _actionButton("Remove Worker", Colors.white, () {
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
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.black87),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 15),
      ),
      child: Text(label, style: const TextStyle(color: Colors.black87, fontSize: 12)),
    );
  }

  // --- STUBS FOR YOUR EXISTING WIDGETS ---
  Widget WorkerFilter() {
    return const Row(children: [Icon(Icons.filter_list), SizedBox(width: 5), Text("Filter")]);
  }

  Widget FirstRowElements() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Search Bar Placeholder"), // Replace with a real TextField later
        OutlinedButton.icon(
          onPressed: addWorker,
          icon: const Icon(Icons.add, size: 18),
          label: const Text("Add"),
        )
      ]
    );
  }

  void _showRemoveConfirmation(String docId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Clock Out", style: TextStyle(fontWeight:FontWeight(5)),),
          content: const Text("Are you sure you want to end your shift?"),
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

  void addWorker() {
    final fNameController = TextEditingController();
    final lNameController = TextEditingController();
    final emailController = TextEditingController();
    final contactController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Register New Worker", 
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
                  if (mounted) Navigator.pop(context); // Close the Add Worker dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Worker account created!"), backgroundColor: Colors.green),
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

  // Future<String?> _registerWorkerInFirestore({
  //   required String fname,
  //   required String lname,
  //   required String email,
  //   required String contact,
  //   required String password,
  // }) async {
  //   try {
  //     // Note: In a production app, you'd use Firebase Auth to create the account.
  //     // For now, we create a user document that the worker can 'claim' or log into.
  //     await FirebaseFirestore.instance.collection('users').add({
  //       'userFName': fname,
  //       'userLName': lname,
  //       'email': email,
  //       'contact': contact,
  //       'password': password, // Ideally, don't store plain text passwords in production!
  //       'deptCode': widget.deptCode, // Pass from the manager
  //       'role': 'Employee',
  //       'isActive': true,
  //       'createdAt': FieldValue.serverTimestamp(),
  //     });
  //     // 2. UPDATE THE TOTAL MEMBER COUNT IN FIREBASE
  //     // We target the specific department document using the deptCode
  //     await FirebaseFirestore.instance
  //         .collection('departments')
  //         .doc(widget.deptCode) 
  //         .update({
  //       'totalMembers': FieldValue.increment(1), // Adds 1 to the existing value
  //     });
  //     return null;
  //   } catch (e) {
  //     return e.toString();
  //   }
  // }

  Future<void> _removeEmployee(String docId) async {
    try {
      // 1. Show a loading spinner so the manager knows it's processing
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 2. Perform the deletions and updates
      // It's good practice to do these together
      await FirebaseFirestore.instance.collection('users').doc(docId).delete();
      await FirebaseFirestore.instance
          .collection('departments')
          .doc(widget.deptCode)
          .update({
        'totalMembers': FieldValue.increment(-1),
      });

      // 3. Close the loading spinner
      if (mounted) Navigator.pop(context);

      // 4. Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Employee removed successfully"), backgroundColor: Colors.red),
      );
    } catch (e) {
      // Close loading spinner if error occurs
      if (mounted) Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error removing employee: $e")),
      );
    }
  }
}