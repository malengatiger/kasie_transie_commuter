import 'package:flutter/material.dart';
import 'package:focused_menu/focused_menu.dart';
import 'package:focused_menu/modals.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kasie_transie_commuter/ui/commuter_route_map.dart';
import 'package:kasie_transie_commuter/ui/taxi_request_handler.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/data/schemas.dart' as lib;
import 'package:kasie_transie_library/l10n/translation_handler.dart';
import 'package:kasie_transie_library/providers/kasie_providers.dart';
import 'package:kasie_transie_library/utils/device_location_bloc.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/local_finder.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/utils/parsers.dart';
import 'package:kasie_transie_library/utils/prefs.dart';
import 'package:kasie_transie_library/widgets/city_selection.dart';
import 'package:badges/badges.dart' as bd;
import 'package:realm/realm.dart';

class CommuterTripSetup extends StatefulWidget {
  const CommuterTripSetup({Key? key}) : super(key: key);

  @override
  CommuterTripSetupState createState() => CommuterTripSetupState();
}

class CommuterTripSetupState extends State<CommuterTripSetup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  static const mm = '🍎🍎🍎🍎🍎 CommuterTripSetup 🍎🍎🍎🍎🍎';
  lib.Commuter? commuter;
  lib.City? startCity, endCity;
  bool _showOriginCitySearch = false;
  bool _showDestinationCitySearch = false;
  bool _showRequestButton = false;
  var routes = <lib.Route>[];
  var routeLandmarks = <lib.RouteLandmark>[];

  bool busy = false;

  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
    _setTexts();
    _getCommuter();
    _getCities();
  }

  void _getCommuter() async {
    commuter = await prefs.getCommuter();
    setState(() {
      busy = true;
    });
    try {
      await _getNearestRoutes();
    } catch (e) {
      pp(e);
    }
    setState(() {
      busy = false;
    });
  }

  _refreshRoutes() async {
    final loc = await locationBloc.getLocation();

    routes = await listApiDog.findRoutesByLocation(LocationFinderParameter(
        latitude: loc.latitude,
        limit: 2000,
        longitude: loc.longitude,
        radiusInKM: 10 * 1000));
  }

  Future _getNearestRoutes() async {
    pp('$mm ... _getNearestRoutes ...');
    final loc = await locationBloc.getLocation();
    routes = await localFinder.findNearestRoutes(
        latitude: loc.latitude,
        longitude: loc.longitude,
        radiusInMetres: 5 * 1000);
    if (routes.isEmpty) {
      routes = await listApiDog.findRoutesByLocation(LocationFinderParameter(
          latitude: loc.latitude,
          limit: 2000,
          longitude: loc.longitude,
          radiusInKM: 5 * 1000));
    }
    routeLandmarks = await localFinder.findNearestRouteLandmarks(
        latitude: loc.latitude, longitude: loc.longitude, radiusInMetres: 5000);
    if (routeLandmarks.isEmpty) {
      routeLandmarks = await listApiDog.findRouteLandmarksByLocation(
          LocationFinderParameter(
              latitude: loc.latitude,
              limit: 2000,
              longitude: loc.longitude,
              radiusInKM: 5 * 1000));
    }
    routes.sort((a,b) => a.name!.compareTo(b.name!));
  }

  Future _getCities() async {
    pp('$mm ... _getNearestRoutes ...');
    final loc = await locationBloc.getLocation();

    cities = await localFinder.findNearestCities(
        latitude: loc.latitude,
        longitude: loc.longitude,
        radiusInMetres: 100 * 1000);

    if (routes.isEmpty) {
      routes = await listApiDog.findRoutesByLocation(LocationFinderParameter(
          latitude: loc.latitude,
          limit: 2000,
          longitude: loc.longitude,
          radiusInKM: 5 * 1000));
    }
    routeLandmarks = await localFinder.findNearestRouteLandmarks(
        latitude: loc.latitude, longitude: loc.longitude, radiusInMetres: 5000);
    if (routeLandmarks.isEmpty) {
      routeLandmarks = await listApiDog.findRouteLandmarksByLocation(
          LocationFinderParameter(
              latitude: loc.latitude,
              limit: 2000,
              longitude: loc.longitude,
              radiusInKM: 5 * 1000));
    }
    routes.sort((a,b) => a.name!.compareTo(b.name!));

  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  var cities = <lib.City>[];
  var startTaxiRequest = 'Start Taxi Request';
  var travellingTo = 'travellingTo';
  var travellingFrom = 'travellingFrom';
  var from = 'from', to = 'to';
  var whereWouldYou = 'Where would you like to go?';
  var taxiRoutesNearby = 'taxiRoutesNearby';
  var openRouteMap = 'Open Route Map';
  var sendTaxiRequest = 'sendTaxiRequest';
  var taxiRequest = 'Taxi Request';
  var hours = 'Hours';

  Future _setTexts() async {
    final c = await prefs.getColorAndLocale();
    final loc = c.locale;
    startTaxiRequest = await translator.translate('startTaxiRequest', loc);
    travellingTo = await translator.translate('travellingTo', loc);
    whereWouldYou = await translator.translate('whereWouldYou', loc);
    taxiRoutesNearby = await translator.translate('taxiRoutesNearby', loc);
    openRouteMap = await translator.translate('openRouteMap', loc);
    sendTaxiRequest = await translator.translate('SendTaxiRequest', loc);

    setState(() {});
  }

  void _navigateToHandler(lib.Route route) async {
    navigateWithScale(TaxiRequestHandler(route: route), context);
  }

  void _navigateToRouteMap(lib.Route route) async {
    navigateWithScale(CommuterRouteMap(route: route), context);
  }

  List<FocusedMenuItem> _getMenuItems(lib.Route route, BuildContext context) {
    List<FocusedMenuItem> list = [];

    list.add(FocusedMenuItem(
        title: Text(openRouteMap, style: myTextStyleMediumBlack(context)),
        // backgroundColor: Theme.of(context).primaryColor,
        trailingIcon: Icon(
          Icons.map,
          color: Theme.of(context).primaryColor,
        ),
        onPressed: () {
          _navigateToRouteMap(route);
        }));
    //
    list.add(FocusedMenuItem(
        title: Text(sendTaxiRequest, style: myTextStyleMediumBlack(context)),
        // backgroundColor: Theme.of(context).primaryColor,
        trailingIcon: Icon(
          Icons.send,
          color: Theme.of(context).primaryColor,
        ),
        onPressed: () {
          _navigateToHandler(route);
        }));
    //
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      appBar: AppBar(
        title: Text(startTaxiRequest),
        actions: [
          IconButton(onPressed: (){
            _refreshRoutes();
          }, icon: Icon(Icons.refresh, color: Theme.of(context).primaryColor,)),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
                shape: getRoundedBorder(radius: 16),
                elevation: 8,
                child: Column(
                  children: [
                    const SizedBox(
                      height: 64,
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        onShowDestinationCitySearch();
                      },
                      style: const ButtonStyle(
                          elevation: MaterialStatePropertyAll(8.0)),
                      icon: Icon(Icons.back_hand,
                          color: Theme.of(context).primaryColor),
                      label: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(whereWouldYou),
                      ),
                    ),
                    const SizedBox(
                      height: 48,
                    ),
                    Text(
                      taxiRoutesNearby,
                      style: myTextStyleMediumLargeWithColor(
                          context, Theme.of(context).primaryColor, 24),
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    Expanded(
                      child: bd.Badge(
                        badgeContent: Text('${routes.length}'),
                        position: bd.BadgePosition.topEnd(top: 8, end: 8),
                        badgeStyle: bd.BadgeStyle(
                          elevation: 12,
                          padding: const EdgeInsets.all(12),
                          badgeColor: Colors.pink.shade800,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: busy
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 4,
                                    backgroundColor: Colors.pink,
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: routes.length,
                                  itemBuilder: (ctx, index) {
                                    final route = routes.elementAt(index);
                                    return GestureDetector(
                                      onTap: () {
                                        _navigateToHandler(route);
                                      },
                                      child: FocusedMenuHolder(
                                        menuOffset: 24,
                                        duration:
                                            const Duration(milliseconds: 300),
                                        menuItems:
                                            _getMenuItems(route, context),
                                        animateMenuItems: true,
                                        openWithTap: true,
                                        onPressed: () {
                                          pp('💛️️ tapped FocusedMenuHolder ...');
                                        },
                                        child: Card(
                                          shape: getRoundedBorder(radius: 16),
                                          elevation: 8,
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.route,
                                                  color: Theme.of(context)
                                                      .primaryColor,
                                                ),
                                                const SizedBox(
                                                  width: 8,
                                                ),
                                                Flexible(
                                                  child: Text(
                                                    '${route.name}',
                                                    style: myTextStyleSmall(
                                                        context),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                        ),
                      ),
                    ),
                  ],
                )),
          ),
          _showOriginCitySearch
              ? Positioned(
                  child: CitySearch(
                      showScaffold: false,
                      onCitySelected: (c) {
                        setState(() {
                          startCity = c;
                        });
                        handleSearch();
                      },
                      cities: cities,
                      title: travellingFrom))
              : const SizedBox(),
          _showDestinationCitySearch
              ? Positioned(
                  child: CitySearch(
                      showScaffold: false,
                      onCitySelected: (c) {
                        setState(() {
                          endCity = c;
                        });
                        handleSearch();
                      },
                      cities: cities,
                      title: travellingTo))
              : const SizedBox()
        ],
      ),
    ));
  }

  handleSearch() async {
    pp('$mm ... handleSearch ...');
    if (startCity != null && endCity != null) {
      setState(() {
        _showRequestButton = true;
      });
    }
  }

  onShowDestinationCitySearch() {
    pp('$mm ... onShowDestinationCitySearch ...');
    setState(() {
      _showDestinationCitySearch = true;
    });
  }

  onShowOriginCitySearch() {
    pp('$mm ... onShowOriginCitySearch ...');
    setState(() {
      _showOriginCitySearch = true;
    });
  }

  onFindNearestRoute() async {
    pp('$mm ... onFindNearestRoute ...');
    final loc = await locationBloc.getLocation();
    routes = await localFinder.findNearestRoutes(
        latitude: loc.latitude,
        longitude: loc.longitude,
        radiusInMetres: 5 * 1000);
    pp('$mm ... onFindNearestRoute ... routes: ${routes.length}');
  }

  onSendRequest() {
    pp('$mm ... onSendRequest ...');
  }
}

class Body extends StatelessWidget {
  const Body(
      {super.key,
      required this.onShowDestinationCitySearch,
      required this.onShowOriginCitySearch,
      required this.onFindNearestRoute,
      required this.onSendRequest,
      required this.showRequestButton,
      required this.startCity,
      required this.endCity,
      required this.fontSize,
      required this.color,
      required this.from,
      required this.to});

  final Function onShowDestinationCitySearch;
  final Function onShowOriginCitySearch;
  final Function onFindNearestRoute;
  final Function onSendRequest;

  final bool showRequestButton;

  final String? startCity, endCity;
  final double fontSize;
  final Color color;
  final String from, to;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          FromTo(
            startCityName: startCity,
            endCityName: endCity,
            fontSize: fontSize,
            color: color,
            from: from,
            to: to,
          ),
          const SizedBox(
            height: 48,
          ),
          ElevatedButton.icon(
            onPressed: () {
              onShowDestinationCitySearch();
            },
            icon: Icon(Icons.back_hand, color: Theme.of(context).primaryColor),
            label: const Text('Where would you like to go?'),
          ),
          const SizedBox(
            height: 48,
          ),
          Text(
            'Will you be travelling from where you are now or would you like to search '
            'for the place you will be travelling from?',
            style: myTextStyleMediumLargeWithColor(context, color, 15),
          ),
          const SizedBox(
            height: 48,
          ),
          ElevatedButton.icon(
            onPressed: () {
              onFindNearestRoute();
            },
            icon: Icon(Icons.back_hand, color: Theme.of(context).primaryColor),
            label: const Text('Travel from where I am now'),
          ),
          const SizedBox(
            height: 48,
          ),
          ElevatedButton.icon(
            onPressed: () {
              onShowOriginCitySearch();
            },
            icon: Icon(Icons.back_hand, color: Theme.of(context).primaryColor),
            label: const Text('Travel from another place'),
          ),
          const SizedBox(
            height: 48,
          ),
          showRequestButton
              ? ElevatedButton(
                  onPressed: () {
                    onSendRequest();
                  },
                  child: const Text('Request Taxi'),
                )
              : const SizedBox(),
        ],
      ),
    );
  }
}

class FromTo extends StatelessWidget {
  const FromTo(
      {super.key,
      required this.startCityName,
      required this.endCityName,
      required this.fontSize,
      required this.color,
      required this.from,
      required this.to});

  final double fontSize;
  final Color color;
  final String? startCityName, endCityName;
  final String from, to;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Column(
        children: [
          Row(
            children: [
              Text(
                from,
                style: myTextStyleMediumLargeWithColor(
                    context, Colors.grey.shade600, 24),
              ),
              const SizedBox(
                width: 20,
              ),
              Text(
                startCityName == null ? '' : startCityName!,
                style: myTextStyleMediumLargeWithColor(
                    context, Theme.of(context).primaryColorLight, 20),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                to,
                style: myTextStyleMediumLargeWithColor(
                    context, Colors.grey.shade600, 24),
              ),
              const SizedBox(
                width: 20,
              ),
              Text(
                endCityName == null ? '' : endCityName!,
                style: myTextStyleMediumLargeWithColor(
                    context, Theme.of(context).primaryColorLight, 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
