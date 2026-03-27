import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:worknest/services/connectivity_service.dart';

class ExpandableLeaveItem extends StatefulWidget {
  final String docId;
  final String title;
  final String name;
  final String reason;
  final String status;
  final bool isManager;
  final String? managerNote;

  const ExpandableLeaveItem({
    super.key, 
    required this.docId,
    required this.title, 
    required this.name,
    required this.reason, 
    required this.status,
    required this.isManager,
    this.managerNote});

  @override
  State<ExpandableLeaveItem> createState() => _ExpandableLeaveItemState();
}

class _ExpandableLeaveItemState extends State<ExpandableLeaveItem> {
  // check connection
  late StreamSubscription<bool> _connectivitySubscription;
  bool _isOffline = false;
  
  bool _isExpanded = false;
  final TextEditingController _commentController = TextEditingController();

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
    super.dispose();
  }
  
  // Helper to get color based on status
  Color _getStatusColor() {
    switch (widget.status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isPending = widget.status.toLowerCase() == 'pending';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        boxShadow: _isExpanded ? [const BoxShadow(color: Colors.black12, blurRadius: 5)] : [],
      ),
      child: Column(
        children: [
          // The Clickable Header
          ListTile(
            leading: Icon(Icons.event_note, color: _getStatusColor()),
            title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              widget.status.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _getStatusColor())),
            trailing: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
          ),

          // The Expandable Body
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Employee Name:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(widget.name, style: const TextStyle(color: Colors.black87)),
                  const Divider(),
                  const Text("Reason for Leave:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(widget.reason, style: const TextStyle(color: Colors.black87)),
                  
                  const Divider(),
                  
                  // --- MANAGER'S NOTE VIEW (Visible to Employees if it exists) ---
                  if (!widget.isManager && widget.managerNote != null) ...[
                    const Divider(height: 30),
                    const Text("Manager's Note:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(widget.managerNote!, style: const TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                  ],

                  const SizedBox(height: 15),

                  // --- MANAGER ACTIONS (Visible only to Admin AND only if Pending) ---
                  if (widget.isManager && isPending) ...[
                  const Divider(height: 30),
                  TextField(
                    controller: _commentController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: "Enter reason for approval/rejection...",
                      hintStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      fillColor: Colors.grey.shade50,
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isOffline ? null : () => _handleLeave(true),
                          style: ElevatedButton.styleFrom(backgroundColor: _isOffline ? Colors.grey : Colors.green, foregroundColor: Colors.white),
                          child: Text(_isOffline ? "No Internet" : "Accept"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isOffline ? null : () => _handleLeave(false),
                          style: ElevatedButton.styleFrom(backgroundColor: _isOffline ? Colors.grey : Colors.red, foregroundColor: Colors.white),
                          child: Text(_isOffline ? "No Internet" : "Reject"),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleLeave(bool isAccepted) async {
    // 1. Determine the status string
    String newStatus = isAccepted ? 'approved' : 'rejected';
    String comment = _commentController.text.trim();

    try {
      // 2. Update Firestore
      await FirebaseFirestore.instance
          .collection('leaves')
          .doc(widget.docId) // Use the unique ID from the stream
          .update({
        'leaveStatus': newStatus,
        'managerReason': comment.isEmpty ? null : comment, // Save comment if provided
        'actionedAt': FieldValue.serverTimestamp(), // Optional: track when it was handled
      });

      // 3. UI Feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Request $newStatus successfully!"),
            backgroundColor: isAccepted ? Colors.green : Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );

        // Reset UI state
        setState(() {
          _isExpanded = false;
        });
        _commentController.clear();
      }
    } catch (e) {
      debugPrint("Failed to update leave: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error updating status. Please try again.")),
        );
      }
    }
  }
}