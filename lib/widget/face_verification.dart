import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:worknest/config.dart';

class FaceVerification extends StatefulWidget {
  const FaceVerification({super.key});

  @override
  State<FaceVerification> createState() => _FaceVerificationState();
}

class _FaceVerificationState extends State<FaceVerification> {
  CameraController? _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    final cameras = await availableCameras();
    // Use front camera for "Selfie" style verification
    final front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
    _controller = CameraController(front, ResolutionPreset.medium);
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  void _handleVerification() async {
    setState(() => _isProcessing = true);
    
    // Simulate AI "Thinking" time
    await Future.delayed(const Duration(seconds: AppConfig.mockDelaySeconds));
    
    if (mounted) {
      // Return 'true' to indicate success to the previous screen
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Face Identity Check"), backgroundColor: Colors.black),
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          CameraPreview(_controller!),
          
          // Scanning Frame Overlay
          Container(
            width: 280,
            height: 350,
            decoration: BoxDecoration(
              border: Border.all(color: _isProcessing ? Colors.green : Colors.blue, width: 2),
              borderRadius: BorderRadius.circular(30),
            ),
          ),

          if (_isProcessing)
            const Positioned(
              bottom: 100,
              child: Column(
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 10),
                  Text("Analyzing Bio-metrics...", style: TextStyle(color: Colors.white)),
                ],
              ),
            ),

          Positioned(
            bottom: 40,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _handleVerification,
              icon: const Icon(Icons.face),
              label: const Text("Verify & Clock In"),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
            ),
          ),
        ],
      ),
    );
  }
}