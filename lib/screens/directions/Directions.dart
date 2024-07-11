import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DirectionsPage extends StatefulWidget {
  final String source;
  final String destination;

  DirectionsPage({required this.source, required this.destination});

  @override
  _DirectionsPageState createState() => _DirectionsPageState();
}

class _DirectionsPageState extends State<DirectionsPage> {
  late GoogleMapController mapController;
  List<LatLng> polylineCoordinates = [];
  Set<Polyline> polylines = {};
  late LatLng sourceLatLng;
  late LatLng destinationLatLng;

  @override
  void initState() {
    super.initState();
    _getDirections();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _getDirections() async {
    String apiKey =
        'YOUR_GOOGLE_MAPS_API_KEY'; // Replace with your Google Maps API Key
    String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${widget.source}&destination=${widget.destination}&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      Map<String, dynamic> data = jsonDecode(response.body);
      List<dynamic> routes = data['routes'];
      if (routes.isNotEmpty) {
        polylineCoordinates.clear();
        polylines.clear();

        routes.forEach((route) {
          List<dynamic> points = route['overview_polyline']['points'];
          polylineCoordinates = _convertToLatLng(_decodePoly(points));
        });

        setState(() {
          polylines.add(Polyline(
            polylineId: PolylineId('route1'),
            color: Colors.blue,
            points: polylineCoordinates,
            width: 5,
          ));

          sourceLatLng = polylineCoordinates.first;
          destinationLatLng = polylineCoordinates.last;
        });

        mapController.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(
                sourceLatLng.latitude,
                sourceLatLng.longitude,
              ),
              northeast: LatLng(
                destinationLatLng.latitude,
                destinationLatLng.longitude,
              ),
            ),
            100.0, // Padding
          ),
        );
      }
    } else {
      throw Exception('Failed to load directions');
    }
  }

  List<LatLng> _convertToLatLng(List points) {
    List<LatLng> result = <LatLng>[];
    for (int i = 0; i < points.length; i++) {
      if (i % 2 != 0) {
        result.add(LatLng(points[i - 1], points[i]));
      }
    }
    return result;
  }

  List _decodePoly(String poly) {
    var list = poly.codeUnits;
    var lList = [];
    int index = 0;
    int len = poly.length;
    int c = 0;
    do {
      var shift = 0;
      int result = 0;
      do {
        c = list[index] - 63;
        result |= (c & 0x1F) << (shift * 5);
        index++;
        shift++;
      } while (c >= 32);
      if (result & 1 == 1) {
        result = ~result;
      }
      var result1 = (result >> 1) * 0.00001;
      lList.add(result1);
    } while (index < len);
    for (var i = 2; i < lList.length; i++) lList[i] += lList[i - 2];
    print(lList.toString());
    return lList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Directions'),
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        polylines: polylines,
        initialCameraPosition: CameraPosition(
          target: sourceLatLng,
          zoom: 12.0,
        ),
      ),
    );
  }
}
