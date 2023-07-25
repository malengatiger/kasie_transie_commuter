import 'package:firebase_auth/firebase_auth.dart';
import 'package:kasie_transie_library/bloc/data_api_dog.dart';
import 'package:kasie_transie_library/bloc/list_api_dog.dart';
import 'package:kasie_transie_library/isolates/country_cities_isolate.dart';
import 'package:kasie_transie_library/isolates/routes_isolate.dart';
import 'package:kasie_transie_library/isolates/vehicles_isolate.dart';
import 'package:kasie_transie_library/providers/kasie_providers.dart';
import 'package:kasie_transie_library/utils/device_location_bloc.dart';
import 'package:kasie_transie_library/utils/emojis.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/local_finder.dart';
import 'package:kasie_transie_library/utils/prefs.dart';
import 'package:realm/realm.dart';
import 'package:kasie_transie_library/data/schemas.dart' as lib;
import 'package:flutter_dotenv/flutter_dotenv.dart' as dot;

final AuthService authService = AuthService();

class AuthService {
  static const mm = '🥬🥬🥬🥬🥬🥬 AuthService 🍎🍎';

  Future registerCommuter() async {
    pp('$mm ... _registerCommuter: adding commuter  ...');
    await dot.dotenv.load();
    final email = dot.dotenv.get('EMAIL');
    final password = dot.dotenv.get('PASSWORD');
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      if (cred.user != null) {
        pp('$mm ... admin user signed in: $cred ${E.blueDot} adding commuter  ...');

        final id = DateTime.now().millisecondsSinceEpoch;
        final comm = lib.Commuter(
          ObjectId(),
          dateRegistered: DateTime.now().toUtc().toIso8601String(),
          name: 'Commuter_$id',
          email: 'commuter_$id@kasietransie.com',
          password: Uuid.v4().toString(),
        );
        final commuter = await dataApiDog.addCommuter(comm);
        myPrettyJsonPrint(commuter.toJson());
        await _signIn(commuter);
        await _initializeData(300);
      }
    } catch (e) {
      pp('$mm ... signing in new commuter with Firebase failed: '
          '${E.redDot}${E.redDot}${E.redDot}${E.redDot}... $e');

      pp(e);
      rethrow;
    }
  }

  Future _signIn(lib.Commuter commuter) async {
    pp('$mm ... signing in new commuter with Firebase ...');
    myPrettyJsonPrint(commuter!.toJson());
    var cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: commuter.email!, password: commuter.password!);
    if (cred.user != null) {
      await prefs.saveCommuter(commuter!);
      pp('$mm ... new commuter is signed in on this device ...');
    }
  }

  Future _initializeData(double radiusInKM) async {
    pp('$mm todo - based on location - load routes, cities etc. .... within 200 km');
    final loc = await locationBloc.getLocation();
    final routes = await listApiDog.findRoutesByLocation(
        LocationFinderParameter(
            latitude: loc.latitude,
            limit: 2000,
            longitude: loc.longitude,
            radiusInKM: radiusInKM));

    if (routes.isNotEmpty) {
      final countryId = routes.first.countryId!;
      final associationId = routes.first.associationId!;
      final landmarks = await listApiDog.findRouteLandmarksByLocation(
          LocationFinderParameter(
              latitude: loc.latitude,
              limit: 3000,
              longitude: loc.longitude,
              radiusInKM: radiusInKM));

      for (var element in routes) {
        await routesIsolate.getRoutePoints(element.routeId!, true);
      }

      final cars = await vehicleIsolate.getVehicles(associationId);
      final cities = await countryCitiesIsolate.getCountryCities(countryId);

      pp('\n\n$mm initialization done: .............'
          '\n 🔵🔵routes: ${routes.length}'
          '\n 🔵🔵landmarks: ${landmarks.length}'
          '\n 🔵🔵cars: ${cars.length}'
          '\n 🔵🔵cities: $cities\n\n');

    }
  }

  lib.User? user;
  var _cities = <lib.City>[];
  double radiusInKM = 200;

  void findCitiesByLocation(double radius) async {
    try {
      pp('... starting findCitiesByLocation 1...');
      final loc = await locationBloc.getLocation();
      user = await prefs.getUser();
      pp('... ended location GPS .2..');

      _cities = await localFinder.findNearestCities(
          latitude: loc.latitude,
          longitude: loc.longitude,
          radiusInMetres: (radius + 2) * 1000);

      pp('$mm cities found on realm cache by location: ${_cities.length} cities within $radius km ....');
      //todo - deal with magic number - put limit in settings

      if (_cities.isEmpty) {
        _cities = await listApiDog.findCitiesByLocation(LocationFinderParameter(
            associationId: user!.associationId,
            latitude: loc.latitude,
            longitude: loc.longitude,
            limit: 2000,
            radiusInKM: radius));

        radiusInKM = radius;
        pp('$mm cities found by location: ${_cities.length} cities within $radius km ....');
      }
    } catch (e) {
      pp(e);
    }
  }
}
