import 'package:flutter/material.dart';

class ManagerEmployee extends StatefulWidget {
  final String deptCode;

  const ManagerEmployee({super.key, required this.deptCode});

  @override
  State<ManagerEmployee> createState() => _ManagerEmployeePageState();
}

class _ManagerEmployeePageState extends State<ManagerEmployee> {
  // Track which worker is currently expanded
  int? _expandedIndex;

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
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        itemCount: 6, // Replace with your Firebase data count later
                        itemBuilder: (context, index) {
                          return _buildExpandableWorkerRow(index);
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
      floatingActionButton: FloatingActionButton(
        onPressed: addWorker,
        backgroundColor: const Color(0xFF1A3E88),
        child: const Icon(Icons.add, color: Colors.white),
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
  Widget _buildExpandableWorkerRow(int index) {
    bool isExpanded = _expandedIndex == index;

    // Hardcoded data for UI testing - replace with your model later
    List<Map<String, String>> dummyData = [
      {"id": "001", "name": "Jane Tan", "att": "90%", "status": "Active"},
      {"id": "002", "name": "John Lim", "att": "100%", "status": "Active"},
      {"id": "003", "name": "Charles", "att": "95%", "status": "Inactive"},
      {"id": "004", "name": "Wong", "att": "98%", "status": "Active"},
      {"id": "005", "name": "John Lim", "att": "100%", "status": "Active"},
      {"id": "006", "name": "John Lim", "att": "100%", "status": "Active"},
    ];

    var worker = dummyData[index];

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
          boxShadow: isExpanded ? [BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
        ),
        child: Column(
          children: [
            // Basic Info Row
            Row(
              children: [
                Expanded(flex: 1, child: Center(child: Text(worker['id']!, style: const TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(flex: 3, child: Center(child: Text(worker['name']!))),
                Expanded(flex: 2, child: Center(child: Text(worker['att']!))),
                Expanded(
                  flex: 2, 
                  child: Center(
                    child: Text(worker['status']!, 
                      style: TextStyle(color: worker['status'] == "Active" ? Colors.green : Colors.red, fontWeight: FontWeight.bold)
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
                    print("Viewing profile of ${worker['name']}");
                  }),
                  _actionButton("Remove Worker", Colors.white, () {
                    print("Removing ${worker['name']}");
                  }, isDelete: true),
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
    return Row(children: [const Icon(Icons.filter_list), const SizedBox(width: 5), const Text("Filter")]);
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

  void addWorker() {
    print("Add worker dialog triggered");
  }
}