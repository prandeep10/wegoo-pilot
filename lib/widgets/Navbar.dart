import 'package:flutter/material.dart';
import 'package:wegoopilot/screens/activity/activity_screen.dart';
import 'package:wegoopilot/screens/earnings/earnings_screen.dart';
import 'package:wegoopilot/screens/home/homescreen.dart';
import 'package:wegoopilot/screens/profile/profile_screen.dart';

// ignore: use_key_in_widget_constructors
class BottomNavBar extends StatefulWidget {
  @override
  // ignore: library_private_types_in_public_api
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _selectedIndex = 0; // Initial selected index

  final List<Widget> _screens = [
    HomeScreen(),
    ActivityScreen(),
    EarningsScreen(),
    const DriverProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.grey[600], // Gray 600 background color
        selectedItemColor: Colors.white, // White color for selected item
        unselectedItemColor: Colors.white
            .withOpacity(0.6), // White color with opacity for unselected items
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Activity',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Earnings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
