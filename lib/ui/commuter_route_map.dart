import 'dart:async';
import 'dart:collection';

import 'package:custom_map_markers/custom_map_markers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart' as poly;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/data/schemas.dart' as lib;
import 'package:kasie_transie_library/isolates/routes_isolate.dart';
import 'package:kasie_transie_library/maps/route_creator_map2.dart';
import 'package:kasie_transie_library/utils/device_location_bloc.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/utils/prefs.dart';

import 'package:kasie_transie_library/l10n/translation_handler.dart';

class CommuterRouteMap extends StatefulWidget {
  final lib.Route route;
  const CommuterRouteMap({
    Key? key,
    required this.route,
  }) : super(key: key);

  @override
  CommuterRouteMapState createState() => CommuterRouteMapState();
}

class CommuterRouteMapState extends State<CommuterRouteMap> {
  static const defaultZoom = 14.0;
  final Completer<GoogleMapController> _mapController = Completer();

  CameraPosition? _myCurrentCameraPosition =
      const CameraPosition(target: LatLng(-25.6, 27.4));
  static const mm = '😡😡😡😡😡😡😡 CommuterRouteMap: 💪 ';
  final _key = GlobalKey<ScaffoldState>();
  bool busy = false;
  bool isHybrid = true;
  lib.Commuter? _commuter;
  geo.Position? _currentPosition;
  final Set<Marker> _markers = HashSet();
  final Set<Circle> _circles = HashSet();
  final Set<Polyline> _polyLines = {};
  final List<lib.RoutePoint> rpList = [];
  List<lib.RoutePoint> existingRoutePoints = [];

  List<poly.PointLatLng>? polylinePoints;
  Color color = Colors.black;
  var routeLandmarks = <lib.RouteLandmark>[];
  int landmarkIndex = 0;
  late lib.Route route;

  @override
  void initState() {
    super.initState();
    _setTexts();
    _getUser();
    _buildPersonIcon();
  }

  Future _setTexts() async {
    final c = await prefs.getColorAndLocale();
    routeMapViewer = await translator.translate('routeMapViewer', c.locale);
    changeColor = await translator.translate('changeColor', c.locale);

    setState(() {});
  }

  Future _setRouteColor() async {
    route = widget.route;
    color = getColor(route.color!);
  }

  @override
  void dispose() {
    super.dispose();
  }

  String? stringColor;
  String routeMapViewer = 'Viewer', changeColor = '';

  Future _getRouteLandmarks() async {
    routeLandmarks =
        await listApiDog.getRouteLandmarks(widget.route.routeId!, false);
    pp('$mm _getRouteLandmarks ...  route: ${widget.route.routeId}; found: ${routeLandmarks.length} ');

    landmarkIndex = 0;
    await _buildLandmarkIcons(routeLandmarks.length);
    for (var landmark in routeLandmarks) {
      final latLng = LatLng(landmark.position!.coordinates.last,
          landmark.position!.coordinates.first);
      _markers.add(Marker(
          markerId: MarkerId('${landmark.landmarkId}'),
          icon: numberMarkers.elementAt(landmarkIndex),
          onTap: () {
            pp('$mm .............. marker tapped, index: $index, $latLng - '
                'landmarkId: ${landmark.landmarkId} - routeId: ${landmark.routeId}');
          },
          infoWindow: InfoWindow(
              snippet:
                  '\nThis landmark is part of the route:\n ${route!.name}\n\n',
              title: '🍎 ${landmark.landmarkName}',
              onTap: () {
                pp('$mm ............. infoWindow tapped, point index: $index');
                //_deleteLandmark(landmark);
              }),
          position: latLng));
      landmarkIndex++;
    }
    final loc = await locationBloc.getLocation();
    var m = LatLng(loc.latitude, loc.longitude);
    await _buildPersonIcon();
    _markers.add(Marker(
        markerId: MarkerId('${DateTime.now().millisecondsSinceEpoch}'),
        icon: personIcon!,
        zIndex: 1,
        onTap: () {
          pp('$mm .............. person marker tapped: $m  ');
        },
        infoWindow: InfoWindow(
            snippet: '\nThis is your current location\n\n',
            title: '🍎 You are here',
            onTap: () {
              pp('$mm ............. infoWindow tapped, point index: $index');
              //_deleteLandmark(landmark);
            }),
        position: m));
    //
    _zoomTo(m);
    setState(() {});
  }

  void _zoomTo(LatLng latLng) async {
    var cameraPos = CameraPosition(target: latLng, zoom: 14.0);
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(cameraPos));
    setState(() {});
  }

  void _showNoPointsDialog() {
    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            elevation: 12,
            title: Text(
              'Route Mapping',
              style: myTextStyleLarge(context),
            ),
            content: Card(
              shape: getDefaultRoundedBorder(),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('This route has no points defined yet.\n\n'
                    'Do you want to start mapping the route?'),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    _popOut();
                  },
                  child: const Text('No')),
              TextButton(
                  onPressed: () {
                    _popOut();
                    navigateWithScale(RouteCreatorMap2(route: route!), context);
                  },
                  child: const Text('Yes')),
            ],
          );
        });
  }

  void _popOut() {
    Navigator.of(context).pop();
    Navigator.of(context).pop();
  }

  Future _getRoutePoints(bool refresh) async {
    setState(() {
      busy = true;
    });
    try {
      _commuter = await prefs.getCommuter();
      pp('$mm getting existing RoutePoints .......');
      existingRoutePoints =
          await routesIsolate.getRoutePoints(widget.route.routeId!, refresh);

      pp('$mm .......... existingRoutePoints ....  🍎 found: '
          '${existingRoutePoints.length} points');
      if (existingRoutePoints.isEmpty) {
        setState(() {
          busy = false;
        });
        _showNoPointsDialog();
        return;
      }
      _addPolyLine();
      setState(() {});
      var point = existingRoutePoints.first;
      var latLng = LatLng(
          point.position!.coordinates.last, point.position!.coordinates.first);
      _myCurrentCameraPosition = CameraPosition(
        target: latLng,
        zoom: defaultZoom,
      );
      final GoogleMapController controller = await _mapController.future;
      controller.animateCamera(
          CameraUpdate.newCameraPosition(_myCurrentCameraPosition!));
    } catch (e) {
      pp(e);
    }
    setState(() {
      busy = false;
    });
  }

  Future _getUser() async {
    _commuter = await prefs.getCommuter();
  }

  Future<void> _zoomToDevice() async {
    pp('$mm .......... get current location ....');
    final loc = await locationBloc.getLocation();
    _currentPosition = loc;
    final latLng = LatLng(loc.latitude, loc.longitude);

    var cameraPos = CameraPosition(target: latLng, zoom: 16.0);
    _myCurrentCameraPosition = cameraPos;
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(cameraPos));
    setState(() {});
  }

  int index = 0;
  final numberMarkers = <BitmapDescriptor>[];
  BitmapDescriptor? personIcon;

  Future _buildPersonIcon() async {
    personIcon = await getBitmapDescriptor(
        path: "assets/person3.png", width: 160, color: widget.route.color!);
    // personIcon = await getBitmapDescriptor(
    //     path: "assets/person4.svg", width: 200, color: widget.route.color!);


  }

  Future _buildLandmarkIcons(int cnt) async {
    for (var i = 0; i < cnt; i++) {
      var intList =
          await getBytesFromAsset("assets/numbers/number_${i + 1}.png", 84);
      numberMarkers.add(BitmapDescriptor.fromBytes(intList));
    }
    pp('$mm have built ${numberMarkers.length} markers for landmarks');
  }

  _clearMap() {
    _polyLines.clear();
    _markers.clear();
  }

  void _addPolyLine() {
    pp('$mm .......... _addPolyLine ....... .');
    _polyLines.clear();
    var mPoints = <LatLng>[];
    existingRoutePoints.sort((a, b) => a.index!.compareTo(b.index!));
    for (var rp in existingRoutePoints) {
      mPoints.add(LatLng(
          rp.position!.coordinates.last, rp.position!.coordinates.first));
    }
    _clearMap();
    var polyLine = Polyline(
        color: color,
        width: 8,
        points: mPoints,
        polylineId: PolylineId(DateTime.now().toIso8601String()));

    _polyLines.add(polyLine);
    setState(() {});
  }

  String waitingForGPS = 'Waiting For GPS ...';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            '${widget.route.name}',
            style: myTextStyleMediumLargeWithColor(
                context, Theme.of(context).primaryColorLight, 13),
          ),
        ),
        key: _key,
        body: Stack(children: [
          GoogleMap(
            mapType: isHybrid ? MapType.hybrid : MapType.normal,
            myLocationEnabled: true,
            markers: _markers,
            circles: _circles,
            polylines: _polyLines,
            initialCameraPosition: _myCurrentCameraPosition!,
            onTap: (latLng) {
              pp('$mm .......... on map tapped : $latLng .');
            },
            onMapCreated: (GoogleMapController controller) async {
              _mapController.complete(controller);
              await _setRouteColor();
              await _getRoutePoints(false);
              _getRouteLandmarks();
            },
          ),
          Positioned(
              right: 12,
              top: 120,
              child: Container(
                color: Colors.black45,
                child: Padding(
                  padding: const EdgeInsets.all(0.0),
                  child: IconButton(
                      onPressed: () {
                        setState(() {
                          isHybrid = !isHybrid;
                        });
                      },
                      icon: Icon(
                        Icons.album_outlined,
                        color: isHybrid ? Colors.yellow : Colors.white,
                      )),
                ),
              )),
          Positioned(
              right: 12,
              top: 40,
              child: Card(
                elevation: 8,
                shape: getRoundedBorder(radius: 12),
                child: Row(
                  children: [
                    IconButton(
                        onPressed: () {
                          _getRoutePoints(true);
                        },
                        icon: Icon(
                          Icons.toggle_on,
                          color: Theme.of(context).primaryColor,
                        )),
                  ],
                ),
              )),
          busy
              ? const Positioned(
                  top: 160,
                  left: 48,
                  child: Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        backgroundColor: Colors.pink,
                      ),
                    ),
                  ),
                )
              : const SizedBox(),
        ]));
  }
}
