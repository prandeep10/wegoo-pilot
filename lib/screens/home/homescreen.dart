import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:workmanager/workmanager.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getInt('driver_id');
    final isRealtimeActive = prefs.getBool('is_realtime_active') ?? false;

    if (driverId == null || !isRealtimeActive) {
      return Future.value(false);
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latitude = position.latitude.toString();
      final longitude = position.longitude.toString();

      final url = 'https://myaec.site/api/driver-realtime/$driverId';
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'latitude': latitude, 'longitude': longitude}),
      );

      if (response.statusCode == 200) {
        print('Background location update sent successfully.');
      } else {
        print(
            'Failed to send background location update. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending background location update: $e');
    }

    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize workmanager
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );

  // Register a periodic task
  Workmanager().registerPeriodicTask(
    'uniqueName',
    'simpleTask',
    frequency:
        Duration(minutes: 15), // WorkManager's minimum interval is 15 minutes
  );

  // Initialize flutter_background
  final hasPermissions = await FlutterBackground.initialize();
  if (hasPermissions) {
    FlutterBackground.enableBackgroundExecution();
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Background Task Example'),
        ),
        body: HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isRealtimeActive = false;
  String latitude = 'Fetching...';
  String longitude = 'Fetching...';
  Timer? timer;
  int? driverId;

  @override
  void initState() {
    super.initState();
    _loadRealtimeStatus(); // Load real-time status from cache
    _fetchDriverId(); // Fetch driver ID from SharedPreferences
    _fetchLocation(); // Fetch initial location on screen load
  }

  @override
  void dispose() {
    timer?.cancel(); // Cancel the timer when the screen is disposed
    super.dispose();
  }

  Future<void> _loadRealtimeStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // Check if the widget is still mounted
    setState(() {
      isRealtimeActive = prefs.getBool('is_realtime_active') ?? false;
    });

    if (isRealtimeActive) {
      _startLocationUpdates();
    }
  }

  Future<void> _fetchDriverId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // Check if the widget is still mounted
    setState(() {
      driverId = prefs.getInt('driver_id');
    });
  }

  Future<void> _fetchLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return; // Check if the widget is still mounted
      setState(() {
        latitude = position.latitude.toString();
        longitude = position.longitude.toString();
      });
    } catch (e) {
      print('Error fetching location: $e');
      if (!mounted) return; // Check if the widget is still mounted
      setState(() {
        latitude = 'Error';
        longitude = 'Error';
      });
    }
  }

  Future<void> _toggleRealtime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // Check if the widget is still mounted
    setState(() {
      isRealtimeActive = !isRealtimeActive;
    });

    await prefs.setBool('is_realtime_active', isRealtimeActive);

    if (isRealtimeActive) {
      _postDriverId(); // Post driver ID when real-time is activated for the first time
      _startLocationUpdates();
    } else {
      // Cancel the timer if real-time is turned off
      timer?.cancel();
    }
  }

  void _startLocationUpdates() {
    // Start sending periodic updates
    timer = Timer.periodic(Duration(seconds: 8), (Timer t) {
      if (isRealtimeActive) {
        _sendLocationUpdate();
      }
    });
  }

  Future<void> _sendLocationUpdate() async {
    if (driverId == null) {
      print('Driver ID is null, unable to send location update.');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return; // Check if the widget is still mounted
      setState(() {
        latitude = position.latitude.toString();
        longitude = position.longitude.toString();
      });

      if (isRealtimeActive) {
        final url = 'https://myaec.site/api/driver-realtime/$driverId';
        final response = await http.put(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'latitude': latitude,
            'longitude': longitude,
          }),
        );

        if (response.statusCode == 200) {
          print('Location update sent successfully.');
        } else {
          print(
              'Failed to send location update. Status code: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error sending location update: $e');
    }
  }

  Future<void> _postDriverId() async {
    if (driverId == null) {
      print('Driver ID is null, unable to post driver ID.');
      return;
    }

    try {
      final url = 'https://myaec.site/api/driver-realtime';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'driver_id': driverId,
        }),
      );

      if (response.statusCode == 200) {
        print('Driver ID posted successfully.');
      } else {
        print('Failed to post driver ID. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error posting driver ID: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: _toggleRealtime,
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.resolveWith<Color>(
                (Set<MaterialState> states) {
                  return isRealtimeActive ? Colors.blue : Colors.grey;
                },
              ),
              padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
            child: Text(
              isRealtimeActive ? 'Active' : 'Offline',
              style: TextStyle(fontSize: 20),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Driver ID: ${driverId ?? 'Fetching...'}',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          SizedBox(height: 20),
          Text(
            'Latitude: $latitude',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          SizedBox(height: 10),
          Text(
            'Longitude: $longitude',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }
}
