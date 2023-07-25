import 'package:flutter/material.dart';
import 'package:kasie_transie_commuter/auth/auth_service.dart';
import 'package:kasie_transie_commuter/ui/commuter_trip_setup.dart';
import 'package:kasie_transie_library/data/schemas.dart' as lib;
import 'package:kasie_transie_library/l10n/translation_handler.dart';
import 'package:kasie_transie_library/utils/emojis.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/utils/navigator_utils.dart';
import 'package:kasie_transie_library/utils/prefs.dart';
import 'package:kasie_transie_library/widgets/language_and_color_chooser.dart';
import 'package:kasie_transie_library/widgets/timer_widget.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  DashboardState createState() => DashboardState();
}

class DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  static const mm = '🍎🍎🍎🍎🍎 Dashboard 🔵🔵🔵';
  lib.Commuter? commuter;
  bool busy = false;
  var routes = <lib.Route>[];
  var loadingCommuterData =
      'Loading routes, cities and places to save on data costs when you run the app. This will happen only once and you will benefit from searching for taxis from your phone.';
  var loadingInformation = 'Loading info';
  var startTaxiRequest = 'Start Taxi Request';
  var findTaxi = 'Find a Taxi';
  @override
  void initState() {
    _controller = AnimationController(vsync: this);
    super.initState();
    _control();
  }

  void _control() async {
    await _setTexts();
    await _checkAuth();
  }
  Future _setTexts() async {
    final c = await prefs.getColorAndLocale();
    final loc = c.locale;
    loadingCommuterData =
        await translator.translate('loadingCommuterData', loc);
    loadingInformation = await translator.translate('loadingInformation', loc);
    startTaxiRequest = await translator.translate('startTaxiRequest', loc);
    findTaxi = await translator.translate('findTaxi', loc);
  }

  Future _checkAuth() async {
    pp('$mm ... _checkAuth: check if commuter needs to be added ...');
    try {
      final c = await prefs.getCommuter();
      if (c == null) {
            pp('$mm ... new commuter needs to be added '
                '${E.redDot}${E.redDot}...');
            setState(() {
              busy = true;
            });
            try {
              await authService.registerCommuter();
              setState(() {
                busy = false;
              });
              return;
            } catch (e) {
              pp(e);
              if (mounted) {
                showSnackBar(
                    backgroundColor: Colors.red.shade600,
                    textStyle: const TextStyle(color: Colors.white, fontSize: 16),
                    message:
                        'Sorry, something went wrong. Please restart the app and try again',
                    context: context);
              }
            }
          }
    } catch (e) {
      pp(e);
    }
    pp('$mm ... _checkAuth: commuter is already on the device '
        '${E.leaf2}${E.leaf2}${E.leaf2}...');
    setState(() {

    });
  }

  lib.City? startCity, endCity;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _navigateToTripSetup() async {
    pp('$mm ... _navigateToTripSetup ...');
    navigateWithScale(const CommuterTripSetup(), context);
  }

  _navigateToColor() async {
    pp('$mm ... _navigateToColor ...');
    navigateWithScale(LanguageAndColorChooser(onLanguageChosen: () {
      pp('$mm ... color chosen ...');
      _setTexts();
    }), context);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'KasieTransie',
            style: myTextStyleMediumLargeWithColor(
                context, Theme.of(context).primaryColor, 28),
          ),
          actions: [
            IconButton(
                onPressed: () {
                  _navigateToColor();
                },
                icon: Icon(
                  Icons.color_lens,
                  color: Theme.of(context).primaryColor,
                )),
          ],
        ),
        body: Stack(children: [
          SizedBox(
            width: width,
            child: Padding(
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
                        findTaxi,
                        style: myTextStyleMediumLargeWithColor(
                            context, Theme.of(context).primaryColor, 48),
                      ),
                      const SizedBox(
                        height: 48,
                      ),
                      ElevatedButton(
                        style: const ButtonStyle(
                          elevation: MaterialStatePropertyAll(8.0),
                        ),
                        onPressed: () {
                          _navigateToTripSetup();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(startTaxiRequest),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          busy
              ? Center(
                  child: TimerWidget(
                      title: loadingInformation, subTitle: loadingCommuterData))
              : const SizedBox(),
        ]),
      ),
    );
  }
}
