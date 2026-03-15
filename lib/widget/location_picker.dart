import 'package:flutter/material.dart';
import 'package:open_street_map_search_and_pick/open_street_map_search_and_pick.dart';

class LocationPicker extends StatelessWidget {
  const LocationPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Office Location'),
        backgroundColor: const Color(0xFF284B9E), // WorkNest Blue
        foregroundColor: Colors.white,
      ),
      body: OpenStreetMapSearchAndPick(
        buttonColor: const Color(0xFF284B9E),
        buttonText: 'Confirm Location',
        onPicked: (pickedData) {
          String finalAddress = pickedData.addressName.toString();
          
          if (finalAddress == "{}" || finalAddress.isEmpty) {
            finalAddress = "Lat: ${pickedData.latLong.latitude.toStringAsFixed(4)}, Lng: ${pickedData.latLong.longitude.toStringAsFixed(4)}";
          }

          debugPrint("FINAL CHECK: Sending Address -> $finalAddress");
          
          // Returns the coordinates and address name back to the previous screen
          Navigator.pop(context, {
            'lat': pickedData.latLong.latitude,
            'lng': pickedData.latLong.longitude,
            'address': finalAddress,
          });
        },
      ),
    );
  }
}