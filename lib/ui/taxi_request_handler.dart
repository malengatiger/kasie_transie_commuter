import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kasie_transie_commuter/ui/commuter_qr_code.dart';
import 'package:kasie_transie_commuter/ui/commuter_route_map.dart';
import 'package:kasie_transie_library/bloc/data_api_dog.dart';
import 'package:kasie_transie_library/data/schemas.dart' as lib;
import 'package:kasie_transie_library/l10n/translation_handler.dart';
import 'package:kasie_transie_library/utils/device_location_bloc.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/local_finder.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/utils/parsers.dart';
import 'package:kasie_transie_library/utils/prefs.dart';
import 'package:kasie_transie_library/widgets/vehicle_passenger_count.dart';
import 'package:flutter_analog_clock/flutter_analog_clock.dart';
import 'package:realm/realm.dart';

class TaxiRequestHandler extends StatefulWidget {
  const TaxiRequestHandler({Key? key, required this.route}) : super(key: key);

  final lib.Route route;

  @override
  TaxiRequestHandlerState createState() => TaxiRequestHandlerState();
}

class TaxiRequestHandlerState extends State<TaxiRequestHandler>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  static const mm = '🔵🔵🔵 TaxiRequestHandler 🔵🔵🔵';
  bool busy = false;
  var passengers = 'passengers';
  var timeTaxiRequired = 'timeTaxiRequired';
  var sendTaxiRequest = 'sendTaxiRequest';
  var taxiRequest = 'Taxi Request';
  var hours = 'Hours';
  var openRouteMap = 'Open Route Map';

  lib.Commuter? commuter;
  int totalPassengers = 0;

  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
    _setTexts();
  }

  Future _setTexts() async {
    commuter = await prefs.getCommuter();
    final c = await prefs.getColorAndLocale();
    final loc = c.locale;
    passengers = await translator.translate('passengers', loc);
    timeTaxiRequired = await translator.translate('timeTaxiRequired', loc);
    sendTaxiRequest = await translator.translate('SendTaxiRequest', loc);
    taxiRequest = await translator.translate('taxiRequest', loc);

    setState(() {});
  }

  void _sendRequest(lib.Route route) async {
    pp('$mm ... _sendRequest ... for ${route.name}');

    setState(() {
      busy = true;
      _showTimer = true;
    });
    try {
      final loc = await locationBloc.getLocation();
      final routeLandmark = await localFinder.findNearestRouteLandmark(
          latitude: loc.latitude,
          longitude: loc.longitude,
          radiusInMetres: 5000);

      final routePoint = await localFinder.findNearestRoutePoint(
          latitude: loc.latitude,
          longitude: loc.longitude,
          radiusInMetres: 5000);

      double distanceFromLandmark = 0.0;
      double distanceFromRoutePoint = 0.0;

      if (routeLandmark != null) {
        distanceFromLandmark = GeolocatorPlatform.instance.distanceBetween(
            loc.latitude,
            loc.longitude,
            routeLandmark.position!.coordinates[1],
            routeLandmark.position!.coordinates[0]);
      }
      if (routePoint != null) {
        distanceFromRoutePoint = GeolocatorPlatform.instance.distanceBetween(
            loc.latitude,
            loc.longitude,
            routePoint.position!.coordinates[1],
            routePoint.position!.coordinates[0]);
      }
      final req = lib.CommuterRequest(ObjectId(),
          associationId: route.associationId,
          commuterId: commuter!.commuterId,
          routeName: route.name,
          routeId: route.routeId,
          scanned: false,
          routeLandmarkId: routeLandmark?.landmarkId,
          routeLandmarkName: routeLandmark?.landmarkName,
          currentPosition: lib.Position(
            type: point,
            coordinates: [loc.longitude, loc.longitude],
          ),
          dateRequested: DateTime.now().toUtc().toIso8601String(),
          distanceToRouteLandmarkInMetres: distanceFromLandmark,
          distanceToRoutePointInMetres: distanceFromRoutePoint,
          numberOfPassengers: totalPassengers,
          commuterRequestId: Uuid.v4().toString());
      await dataApiDog.addCommuterRequest(req);
      if (mounted) {
        showSnackBar(
            textStyle:
            myTextStyleMediumLargeWithColor(context, Colors.white, 14),
            message: 'Request has been sent',
            context: context);
      }
    } catch (e) {
      pp(e);
      if (mounted) {
        showSnackBar(
            backgroundColor: Colors.red,
            textStyle:
            myTextStyleMediumLargeWithColor(context, Colors.white, 14),
            message: 'Request has failed',
            context: context);
      }
    }
    setState(() {
      busy = false;
    });
  }

  void _navigateToRouteMap() async {
    pp('$mm ... _navigateToRouteMap ... ');
    navigateWithScale(CommuterRouteMap(route: widget.route), context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _showQRCode = false;
  bool _showTimer = false;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.now();
    return SafeArea(
        child: Scaffold(
          appBar: AppBar(
            title: Text(taxiRequest),
            actions: [
              IconButton(
                  onPressed: () {
                    setState(() {
                      _showQRCode = true;
                    });
                  },
                  icon: Icon(
                    Icons.scanner,
                    color: Theme
                        .of(context)
                        .primaryColor,
                  ))
            ],
          ),
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  shape: getRoundedBorder(radius: 16),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Taxi Route',
                          style: myTextStyleLarge(context),
                        ),
                        const SizedBox(
                          height: 24,
                        ),
                        Text(
                          '${widget.route.name}',
                          style: myTextStyleMediumLargeWithColor(
                              context, Theme
                              .of(context)
                              .primaryColor, 18),
                        ),
                        const SizedBox(
                          height: 24,
                        ),
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: AnalogClock(
                            dateTime: date,
                            isKeepTime: true,
                            child: const Align(
                              alignment: FractionalOffset(0.5, 0.75),
                              child: Text('GMT+2'),
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 48,
                        ),
                        Card(
                          shape: getRoundedBorder(radius: 16),
                          elevation: 8,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                SizedBox(width: 160, child: Text(passengers)),
                                const SizedBox(
                                  width: 2,
                                ),
                                Text(
                                  '$totalPassengers',
                                  style: myTextStyleMediumLargeWithColor(
                                      context, Theme
                                      .of(context)
                                      .primaryColor, 24),
                                ),
                                const SizedBox(
                                  width: 24,
                                ),
                                NumberDropDown(
                                    onNumberPicked: (n) {
                                      setState(() {
                                        totalPassengers = n;
                                      });
                                    },
                                    count: 16,
                                    color: Colors.white,
                                    fontSize: 16)
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 48,
                        ),
                        TextButton(
                            onPressed: () {
                              _navigateToRouteMap();
                            },
                            child: Text(openRouteMap)),
                        const SizedBox(
                          height: 24,
                        ),
                        _showTimer ? const BasicTimer() : ElevatedButton.icon(
                            style: const ButtonStyle(
                              elevation: MaterialStatePropertyAll(12.0),
                            ),
                            onPressed: () {
                              _sendRequest(widget.route);
                            },
                            icon: const Icon(Icons.send),
                            label: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(sendTaxiRequest),
                            )),
                        const SizedBox(
                          height: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _showQRCode
                  ? Positioned(
                  child: Center(
                    child: CommuterQrCode(
                      commuter: commuter!,
                      onClose: () {
                        setState(() {
                          _showQRCode = false;
                        });
                      },
                    ),
                  ))
                  : const SizedBox(),
              busy
                  ? const Positioned(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ))
                  : const SizedBox(),
            ],
          ),
        ));
  }
}

class BasicTimer extends StatefulWidget {
  const BasicTimer({super.key});

  @override
  State<BasicTimer> createState() => _BasicTimerState();
}

class _BasicTimerState extends State<BasicTimer> {

  late Timer timer;
  int elapsed = 0;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    pp('... timer starting ....');
    timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      elapsed = timer.tick;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 48,
      child: Card(
        elevation: 12,
        shape: getRoundedBorder(radius: 8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            getFormattedTime(timeInSeconds: elapsed),
            style: myTextStyleMediumLargeWithColor(
                context, Theme
                .of(context)
                .primaryColor, 24),
          ),
        ),
      ),
    );
  }
}

