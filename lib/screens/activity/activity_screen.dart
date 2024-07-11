import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

class ActivityScreen extends StatefulWidget {
  @override
  _ActivityScreenState createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<RideRequest> rideRequests = [];
  bool _isDisposed = false; // Flag to track if the widget is disposed
  int driverId = -1;

  @override
  void initState() {
    super.initState();
    _loadDriverId();
    _fetchRideRequests();
  }

  Future<void> _loadDriverId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      driverId = prefs.getInt('driver_id') ?? -1;
    });
  }

  @override
  void dispose() {
    _isDisposed = true; // Set flag to true when disposing
    super.dispose();
  }

  Future<void> _fetchRideRequests() async {
    const url = 'https://myaec.site/api/ride-requests';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200 && !_isDisposed) {
        List<dynamic> data = jsonDecode(response.body);

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        double driverLat = position.latitude;
        double driverLng = position.longitude;

        if (!_isDisposed) {
          setState(() {
            rideRequests = data
                .map((json) => RideRequest.fromJson(json))
                .where((ride) =>
                    ride.driverId == null || ride.driverId == driverId)
                .where((ride) => ride.status != 'completed')
                .where((ride) {
              final sourceCoords = _parseLatLng(ride.source);
              return _calculateDistance(
                    driverLat,
                    driverLng,
                    sourceCoords['lat']!,
                    sourceCoords['lng']!,
                  ) <
                  6;
            }).toList();

            rideRequests.sort((a, b) => b.id.compareTo(a.id));
          });
        }
      } else {
        if (!_isDisposed) {
          throw Exception('Failed to fetch ride requests');
        }
      }
    } catch (e) {
      if (!_isDisposed) {
        // Handle error
        print('Error fetching ride requests: $e');
      }
    }
  }

  Map<String, double> _parseLatLng(String latLngStr) {
    final coords = latLngStr.replaceAll(RegExp(r'LatLng\(|\)'), '').split(', ');
    return {
      'lat': double.parse(coords[0]),
      'lng': double.parse(coords[1]),
    };
  }

  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371; // Radius of the Earth in kilometers
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<void> _updateRideStatus(int rideId, String newStatus) async {
    final url = 'https://myaec.site/api/ride-requests/$rideId';

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatus, 'driver_id': driverId}),
      );

      if (response.statusCode == 200 && !_isDisposed) {
        if (!_isDisposed) {
          _fetchRideRequests(); // Refresh ride requests after updating status
        }
      } else {
        if (!_isDisposed) {
          // Handle failure
          print('Failed to update ride status');
        }
      }
    } catch (e) {
      if (!_isDisposed) {
        // Handle error
        print('Error updating ride status: $e');
      }
    }
  }

  Future<void> _completeRideWithOTP(int rideId) async {
    String otp = await _showOTPPrompt();
    if (otp == '1234' && !_isDisposed) {
      _updateRideStatus(rideId, 'journey');
    } else {
      if (!_isDisposed) {
        // Handle invalid OTP scenario
        print('Invalid OTP entered');
      }
    }
  }

  Future<String> _showOTPPrompt() async {
    TextEditingController otpController = TextEditingController();
    String otp = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter OTP'),
          content: TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: InputDecoration(
              hintText: '1234',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Submit'),
              onPressed: () {
                Navigator.of(context).pop(otpController.text);
              },
            ),
          ],
        );
      },
    );
    return otp ?? '';
  }

  void _openGoogleMaps(String source, String destination, String status) async {
    final sourceCoords = _getCoordinates(source);
    final destCoords = _getCoordinates(destination);
    String googleMapsUrl;

    if (status == 'pickup') {
      googleMapsUrl =
          'https://www.google.com/maps/dir/?api=1&destination=${sourceCoords['lat']},${sourceCoords['lng']}';
    } else if (status == 'journey') {
      googleMapsUrl =
          'https://www.google.com/maps/dir/?api=1&destination=${destCoords['lat']},${destCoords['lng']}';
    } else {
      return;
    }

    if (await canLaunch(googleMapsUrl)) {
      await launch(googleMapsUrl);
    } else {
      _showErrorDialog('Could not launch $googleMapsUrl');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Map<String, double> _getCoordinates(String latLngStr) {
    final coords = latLngStr.replaceAll(RegExp(r'LatLng\(|\)'), '').split(', ');
    return {
      'lat': double.parse(coords[0]),
      'lng': double.parse(coords[1]),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Activity'),
        backgroundColor: Colors.blue, // Set app bar background to blue
      ),
      body: Container(
        color: Colors.blue[50], // Set container background to light blue
        child: ListView.builder(
          itemCount: rideRequests.length,
          itemBuilder: (context, index) {
            return _buildRideRequestCard(rideRequests[index]);
          },
        ),
      ),
    );
  }

  Widget _buildRideRequestCard(RideRequest request) {
    String buttonText = '';
    Color buttonColor = Colors.blue;
    Function()? buttonAction;

    switch (request.status) {
      case 'pickup':
        buttonText = 'Start Ride';
        buttonAction = () => _completeRideWithOTP(request.id);
        break;
      case 'journey':
        buttonText = 'Complete Ride';
        buttonAction = () => _updateRideStatus(request.id, 'completed');
        buttonColor = Colors.green;
        break;
      default:
        buttonText = 'Accept';
        buttonAction = () => _updateRideStatus(request.id, 'pickup');
    }

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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Created At: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(request.createdAt)}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 16),
            if (request.status != 'completed') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: buttonAction,
                    child: Text(buttonText),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith<Color>(
                        (Set<MaterialState> states) {
                          return buttonColor; // Dynamic button color
                        },
                      ),
                      foregroundColor: MaterialStateProperty.resolveWith<Color>(
                        (Set<MaterialState> states) {
                          return Colors.white; // Text color
                        },
                      ),
                      textStyle: MaterialStateProperty.resolveWith<TextStyle>(
                        (Set<MaterialState> states) {
                          return TextStyle(fontSize: 16); // Text style
                        },
                      ),
                      padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                        EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ), // Button padding
                      ),
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          // Button border radius
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _openGoogleMaps(
                      request.source,
                      request.destination,
                      request.status,
                    ),
                    child: Text('Show Directions'),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith<Color>(
                        (Set<MaterialState> states) {
                          return Colors.orange; // Background color
                        },
                      ),
                      foregroundColor: MaterialStateProperty.resolveWith<Color>(
                        (Set<MaterialState> states) {
                          return Colors.white; // Text color
                        },
                      ),
                      textStyle: MaterialStateProperty.resolveWith<TextStyle>(
                        (Set<MaterialState> states) {
                          return TextStyle(fontSize: 16); // Text style
                        },
                      ),
                      padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                        EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ), // Padding
                      ),
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          // Button border radius
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
  final String status;
  final DateTime createdAt;
  final int? driverId;

  RideRequest({
    required this.id,
    required this.source,
    required this.destination,
    required this.status,
    required this.createdAt,
    this.driverId,
  });

  factory RideRequest.fromJson(Map<String, dynamic> json) {
    return RideRequest(
      id: json['id'],
      source: json['source'],
      destination: json['destination'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      driverId: json['driver_id'],
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: ActivityScreen(),
  ));
}
