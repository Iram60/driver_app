import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';


enum TripState {
  startTrip,
  enRouteToRestaurant,
  arrivedAtRestaurant,
  pickedUp,
  enRouteToCustomer,
  arrivedAtCustomer,
  delivered,
}

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final Map<String, dynamic> _order = {
    'id': 'ORD-12345',
    'restaurant': {
      'name': 'Burger Barn',
      'latitude': 22.723926,
      'longitude': 75.884597,
      'address': 'Vijay Nagar Square, Indore, Madhya Pradesh 452010, India',
    },
    'customer': {
      'name': 'Priya singh',
      'latitude': 22.764177,
      'longitude': 75.898834,
      'address': 'Super Corridor, Indore, Madhya Pradesh 453111, India',
    },
    'amount': '₹250.50',
  };

  TripState _tripState = TripState.startTrip;
  Position? _currentPosition;
  Timer? _locationTimer;
  String _geofenceMessage = '';
  final double _geofenceRadius = 50.0; // meters

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied.')),
        );
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
      });
      _checkPeriodicGeofence();
    } catch (e) {
      print("Error getting initial location: $e");
    }

    _locationTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) async {
          try {
            Position position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high);
            setState(() {
              _currentPosition = position;
            });
            _checkPeriodicGeofence();
          } catch (e) {
            print('Error getting location: $e');
          }
        });
  }

  void _checkPeriodicGeofence() {
    if (_currentPosition == null) return;

    if (_tripState == TripState.enRouteToRestaurant) {
      final double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _order['restaurant']['latitude'],
        _order['restaurant']['longitude'],
      );
      if (distance <= _geofenceRadius) {
        setState(() {
          _tripState = TripState.arrivedAtRestaurant;
          _geofenceMessage = 'Arrived at restaurant! Ready to pickup.';
        });
        return;
      } else {
        setState(() {
          _geofenceMessage =
          'En route to restaurant. Distance: ${distance.toStringAsFixed(0)} m';
        });
      }
    }

    if (_tripState == TripState.enRouteToCustomer) {
      final double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _order['customer']['latitude'],
        _order['customer']['longitude'],
      );
      if (distance <= _geofenceRadius) {
        setState(() {
          _tripState = TripState.arrivedAtCustomer;
          _geofenceMessage = 'Arrived at customer! Ready to deliver.';
        });
        return;
      } else {
        setState(() {
          _geofenceMessage =
          'En route to customer. Distance: ${distance.toStringAsFixed(0)} m';
        });
      }
    }
  }

  void _nextState() {
    setState(() {
      switch (_tripState) {
        case TripState.startTrip:
          _tripState = TripState.enRouteToRestaurant;
          _geofenceMessage = 'Trip started! Heading to restaurant.';
          break;

        case TripState.arrivedAtRestaurant:
          _tripState = TripState.pickedUp;
          _geofenceMessage = 'Order picked up! Heading to customer.';
          break;

        case TripState.pickedUp:
          _tripState = TripState.enRouteToCustomer;
          _geofenceMessage = 'Started delivery to customer.';
          break;

        case TripState.arrivedAtCustomer:
          _tripState = TripState.delivered;
          _geofenceMessage = 'Delivery complete! Trip finished.';
          break;

        case TripState.enRouteToRestaurant:
        case TripState.enRouteToCustomer:
        case TripState.delivered:
          break;
      }
    });
  }

  String _getStatusText() {
    switch (_tripState) {
      case TripState.startTrip:
        return 'Ready to start trip';
      case TripState.enRouteToRestaurant:
        return 'En Route to Restaurant';
      case TripState.arrivedAtRestaurant:
        return 'At Restaurant - Pickup Ready';
      case TripState.pickedUp:
        return 'Order Picked Up';
      case TripState.enRouteToCustomer:
        return 'En Route to Customer';
      case TripState.arrivedAtCustomer:
        return 'At Customer - Delivery Ready';
      case TripState.delivered:
        return 'Delivery Complete';
    }
  }

  String _getButtonText() {
    switch (_tripState) {
      case TripState.startTrip:
        return 'Start Trip';
      case TripState.enRouteToRestaurant:
        return 'On Way to Restaurant';
      case TripState.arrivedAtRestaurant:
        return 'Pickup Order';
      case TripState.pickedUp:
        return 'Start Delivery to Customer';
      case TripState.enRouteToCustomer:
        return 'On Way to Customer';
      case TripState.arrivedAtCustomer:
        return 'Confirm Delivery';
      case TripState.delivered:
        return 'Trip Complete';
    }
  }


  ({String origin, String destination}) _getNavigationPoints() {
    if (_tripState == TripState.startTrip || _tripState == TripState.enRouteToRestaurant || _tripState == TripState.arrivedAtRestaurant) {
      // Current location → Restaurant
      String origin = _currentPosition != null
          ? '${_currentPosition!.latitude},${_currentPosition!.longitude}'
          : '';
      String destination =
          '${_order['restaurant']['latitude']},${_order['restaurant']['longitude']}';
      return (origin: origin, destination: destination);
    } else if (_tripState == TripState.pickedUp || _tripState == TripState.enRouteToCustomer || _tripState == TripState.arrivedAtCustomer) {
      // Restaurant → Customer
      String origin =
          '${_order['restaurant']['latitude']},${_order['restaurant']['longitude']}';
      String destination =
          '${_order['customer']['latitude']},${_order['customer']['longitude']}';
      return (origin: origin, destination: destination);
    }
    return (origin: '', destination: '');
  }

  Future<void> _launchGoogleMaps() async {
    final points = _getNavigationPoints();

    if (points.origin.isEmpty || points.destination.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No destination to navigate to.')),
        );
      }
      return;
    }

    final Uri url = Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        'origin': points.origin,
        'destination': points.destination,
      },
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Google Maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canNavigate = _currentPosition != null &&
        _tripState != TripState.delivered;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Assigned Order',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your Current Location',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_currentPosition == null
                        ? 'Fetching location...'
                        : 'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        const Text('Order ID: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_order['id']}'),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Text('Restaurant: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_order['restaurant']['name']}'),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Restaurant Address: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text('${_order['restaurant']['address']}')),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Text('Customer: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_order['customer']['name']}'),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Customer Address: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text('${_order['customer']['address']}')),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Text('Amount: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_order['amount']}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),


            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Trip Status: ${_getStatusText()}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    if (_geofenceMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          _geofenceMessage,
                          style: const TextStyle(
                              color: Colors.green, fontSize: 14),
                        ),
                      ),
                    ElevatedButton(
                      onPressed: (_tripState == TripState.startTrip ||
                          _tripState == TripState.arrivedAtRestaurant ||
                          _tripState == TripState.pickedUp)
                          ? _nextState
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: Text(_getButtonText()),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: canNavigate ? _launchGoogleMaps : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: Text(canNavigate
                          ? 'Navigate'
                          : 'Navigation unavailable'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
