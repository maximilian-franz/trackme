import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(
    MaterialApp(
      title: 'Track my Location',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
        ),
      ),
      home: TrackMe(storage: LocationStorage()),
    ),
  );
}

class LocationStorage {
  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/locations.jsonl');
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> clearLocations() async {
    final file = await _localFile;
    return file.writeAsString("");
  }

  Future<List<LatLng>> readLocations() async {
    try {
      final file = await _localFile;

      // Read the file
      final contents = await file.readAsString();

      print('Read locations: $contents');
      return jsonDecode(
        contents,
      ).map<LatLng>((line) => LatLng.fromJson(line)).toList();
    } catch (e) {
      // If encountering an error, return an empty list
      print('Error reading locations: $e');
      return [];
    }
  }

  Future<File> writeLocations(List<LatLng> locations) async {
    final file = await _localFile;
    final content = jsonEncode(
      locations.map((location) => location.toJson()).toList(),
    );
    print('Write locations: $content');

    // Write the file
    return file.writeAsString(content);
  }
}

enum MenuAction { clearLocations, getCurrentLocation, toggleLocations }

class TrackMe extends StatefulWidget {
  final LocationStorage storage;

  const TrackMe({super.key, required this.storage});

  @override
  State<TrackMe> createState() => _TrackMeState();
}

class _TrackMeState extends State<TrackMe> {
  bool _showLocations = false;
  List<LatLng> _locations = [];
  final MapController _mapController = MapController();
  final LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Track my Location')),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          _locations.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _locations.last,
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _locations,
                        strokeWidth: 4.0,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _locations.last,
                        alignment: Alignment.topCenter,
                        rotate: true,
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.location_pin,
                          color: Theme.of(context).colorScheme.primary,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          if (_showLocations)
            Column(
              children:
                  _locations.reversed
                      .map((location) => Text(location.toString()))
                      .toList(),
            ),
          Positioned(
            bottom: 16,
            right: 16,
            child: PopupMenuButton(
              onSelected: _handleMenuSelect,
              itemBuilder:
                  (BuildContext context) => <PopupMenuEntry>[
                    const PopupMenuItem(
                      value: MenuAction.getCurrentLocation,
                      child: ListTile(
                        leading: Icon(Icons.pin_drop),
                        title: Text('Get Current Location'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: MenuAction.toggleLocations,
                      child: ListTile(
                        leading: Icon(Icons.article),
                        title: Text('Toggle Locations'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: MenuAction.clearLocations,
                      child: ListTile(
                        leading: Icon(Icons.delete),
                        title: Text('Clear locations'),
                      ),
                    ),
                  ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<File> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition();
    print('Current location: ${position.latitude}, ${position.longitude}');
    setState(() {
      _locations.add(LatLng(position.latitude, position.longitude));
    });

    // Write the variable as a string to the file.
    return widget.storage.writeLocations(_locations);
  }

  Future<void> _getPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      SystemNavigator.pop();
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        SystemNavigator.pop();
      }
    }
  }

  void _handleMenuSelect(value) {
    switch (value) {
      case MenuAction.clearLocations:
        widget.storage.clearLocations().then((value) {
          setState(() {
            _locations = [];
          });
        });
        break;
      case MenuAction.getCurrentLocation:
        _getCurrentLocation();
        break;
      case MenuAction.toggleLocations:
        setState(() {
          _showLocations = !_showLocations;
        });
        break;
    }
  }

  Future<void> _initApp() async {
    widget.storage.readLocations().then((value) {
      setState(() {
        _locations = value;
      });
    });
    await _getPermission();
    await _getCurrentLocation();
    await _startTracking();
  }

  Future<File> _startTracking() async {
    Geolocator.getPositionStream().listen((Position position) {
      print('New position: ${position.latitude}, ${position.longitude}');
      setState(() {
        _locations.add(LatLng(position.latitude, position.longitude));
      });
    });

    // Write the variable as a string to the file.
    return widget.storage.writeLocations(_locations);
  }
}
