import 'package:flutter/material.dart';

class ExpandableLeaveItem extends StatefulWidget {
  final String title;
  final String reason;

  const ExpandableLeaveItem({super.key, required this.title, required this.reason});

  @override
  State<ExpandableLeaveItem> createState() => _ExpandableLeaveItemState();
}

class _ExpandableLeaveItemState extends State<ExpandableLeaveItem> {
  bool _isExpanded = false;
  final TextEditingController _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        boxShadow: _isExpanded ? [BoxShadow(color: Colors.black12, blurRadius: 5)] : [],
      ),
      child: Column(
        children: [
          // The Clickable Header
          ListTile(
            title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("12 Mar 2026", style: TextStyle(fontSize: 12)),
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
                  const Text("Reason:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(widget.reason, style: const TextStyle(color: Colors.black87)),
                  const SizedBox(height: 15),
                  
                  // Manager Comment Area
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

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleLeave(true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          child: const Text("Accept"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleLeave(false),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          child: const Text("Reject"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _handleLeave(bool isAccepted) {
    print("Leave ${isAccepted ? 'Accepted' : 'Rejected'}: ${_commentController.text}");
    // TODO: Update Firestore leave request status
  }
}