import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key});

  @override
  State<ManagerHome> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHome> {
  String deptName = "Loading...";
  String deptCode = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadManagerData();
  }

  // Fetch the current manager's department details
  void _loadManagerData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
          
      setState(() {
        deptName = userDoc['userRole']; // Or fetch from the departments collection
        deptCode = userDoc['deptCode'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 240, 250, 255),
      appBar: AppBar(
        title: const Text("Welcome back, Manager!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Color.fromARGB(255, 240, 250, 255),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
          
              // --- Clock In ---
              ManagerClockIn(),
              // --- Summary Card ---
              ManagerSummaryCard(),
              // --- Activities ---
              ManagerActivities(),
              // --- Department Code Card ---
              DepartmentCodeCard(),
            ],
          ),
        ),
      ),
    );
  }

  Container DepartmentCodeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color.fromARGB(255, 40, 75, 158)),
      ),
      child: Column(
        children: [
          const Text("Your Department Code", style: TextStyle(fontSize: 16)),
          const SizedBox(height: 10),
          SelectableText(
            deptCode, 
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 40, 75, 158), letterSpacing: 5),
          ),
          const Text("(Share this with your employees)", style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Container ManagerActivities() {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: EdgeInsets.all(10),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color.fromARGB(255, 40, 75, 158), width: 3),
      ),
      child: Column(
        children: [
          Text(
            "Activities",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold
            )
          ),
          Container(
            padding: EdgeInsets.all(5),
            margin: EdgeInsets.all(3),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.grey)
            ),
            child: Text("Activity 1", style: TextStyle(fontWeight: FontWeight.bold),),
          ),
          Container(
            padding: EdgeInsets.all(5),
            margin: EdgeInsets.all(3),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.grey)
            ),
            child: Text("Activity 2", style: TextStyle(fontWeight: FontWeight.bold),),
          ),
          Container(
            padding: EdgeInsets.all(5),
            margin: EdgeInsets.all(3),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.grey)
            ),
            child: Text("Activity 3", style: TextStyle(fontWeight: FontWeight.bold),),
          ),
          Container(
            padding: EdgeInsets.all(5),
            margin: EdgeInsets.all(3),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.grey)
            ),
            child: Text("Activity 4", style: TextStyle(fontWeight: FontWeight.bold),),
          )
        ],
      )
    );
  }

  Container ManagerSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: EdgeInsets.all(10),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color.fromARGB(255, 40, 75, 158), width: 3),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Employee",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold)
                  ),
              Container(
                padding: EdgeInsets.only(left: 15, right: 15, top: 7, bottom: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color.fromARGB(255, 40, 75, 158), width: 2),
                ),
                child: Text("20", style: TextStyle(),)
                ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Attendance Rate",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
              Container(
                padding: EdgeInsets.only(left: 15, right: 15, top: 7, bottom: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color.fromARGB(255, 40, 75, 158), width: 2),
                ),
                child: Text("10", style: TextStyle(),)
                ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Pending Approval",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
              Container(
                padding: EdgeInsets.only(left: 15, right: 15, top: 7, bottom: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color.fromARGB(255, 40, 75, 158), width: 2),
                ),
                child: Text("10", style: TextStyle(),)
                ),
            ],
          ),
        ],
      )
    );
  }

  Container ManagerClockIn() {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: EdgeInsets.all(10),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color.fromARGB(255, 40, 75, 158), width: 3),
      ),
      child: Column(
        children: [
          Text(
            "Date",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold)
              ),
          Text(
            "Time",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold)),
          SizedBox(
            width: 250,
            height:50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.black,
              ),
              onPressed: _clockIn,
              child: Text(
                "Clock In",
                style: TextStyle(
                fontSize: 20,
                fontWeight:FontWeight.w800
              )
              )
            ),
          )
        ],
      )
    );
  }

  void _clockIn(){
    print("Clocked In");
  }
}