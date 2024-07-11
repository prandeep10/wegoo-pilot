import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import intl for DateFormat
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EarningsScreen extends StatefulWidget {
  @override
  _EarningsScreenState createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  List<RideRequest> rideRequests = [];
  double totalIncome = 0;

  @override
  void initState() {
    super.initState();
    _fetchRideRequests();
  }

  Future<void> _fetchRideRequests() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? driverId = prefs.getInt('driver_id');

    if (driverId == null) {
      print('Driver ID not found in shared preferences');
      return; // Handle case where driver ID is not available
    }

    final url = 'https://myaec.site/api/ride-requests';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);

        setState(() {
          rideRequests = data
              .map((json) => RideRequest.fromJson(json))
              .where((request) =>
                  request.status == 'completed' && request.driverId == driverId)
              .toList();

          totalIncome =
              rideRequests.fold(0, (sum, request) => sum + request.price);
        });
      } else {
        throw Exception('Failed to fetch ride requests');
      }
    } catch (e) {
      print('Error fetching ride requests: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Earnings'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Total Income:',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            Text(
              '\₹$totalIncome',
              style: TextStyle(
                  color: Colors.green,
                  fontSize: 36,
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: rideRequests.length,
                itemBuilder: (context, index) {
                  return _buildRideRequestCard(rideRequests[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideRequestCard(RideRequest request) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ride ID: ${request.id}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Source: ${request.source}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Destination: ${request.destination}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Price: \₹${request.price.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Status: ${request.status}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Created At: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(request.createdAt)}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Updated At: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(request.updatedAt)}',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class RideRequest {
  final int id;
  final String source;
  final String destination;
  final double price;
  final int userId;
  final int driverId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  RideRequest({
    required this.id,
    required this.source,
    required this.destination,
    required this.price,
    required this.userId,
    required this.driverId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RideRequest.fromJson(Map<String, dynamic> json) {
    return RideRequest(
      id: json['id'],
      source: json['source'],
      destination: json['destination'],
      price: double.parse(json['price']),
      userId: json['user_id'],
      driverId: json['driver_id'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
