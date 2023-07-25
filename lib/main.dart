import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:kasie_transie_commuter/ui/dashboard.dart';
import 'package:kasie_transie_library/bloc/theme_bloc.dart';
import 'package:kasie_transie_library/messaging/fcm_bloc.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/data/schemas.dart' as lib;
import 'package:kasie_transie_library/utils/prefs.dart';
import 'package:kasie_transie_library/widgets/splash_page.dart';
import 'package:page_transition/page_transition.dart';

import 'firebase_options.dart';

late FirebaseApp firebaseApp;
fb.User? fbAuthedUser;
int themeIndex = 0;
lib.Commuter? me;

const mx = '🔵🔵🔵🔵🔵 KasieTransie Commuter : main 🔵🔵';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();
  firebaseApp = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
  pp('\n\n$mx '
      ' Firebase App has been initialized: ${firebaseApp.name}, checking for authed current user\n');
  fbAuthedUser = fb.FirebaseAuth.instance.currentUser;
  if (fbAuthedUser != null) {
    pp('$mx fbAuthUser: ${fbAuthedUser!.uid}');
    pp("$mx .... fbAuthUser is cool! ........ on to the party!!");
  } else {
    pp('$mx fbAuthUser: is null. Need to authenticate the commuter!');
  }

  me = await prefs.getCommuter();
  if (me != null) {
    myPrettyJsonPrint(me!.toJson());
  }
// Background message handler
  FirebaseMessaging.onBackgroundMessage(kasieFirebaseMessagingBackgroundHandler);

  runApp(const CommuterApp());
}

class CommuterApp extends StatelessWidget {
  const CommuterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: themeBloc.localeAndThemeStream,
        builder: (ctx, snapshot) {
          if (snapshot.hasData) {
            pp(' 🔵 🔵 🔵'
                'build: theme index has been set to ${snapshot.data!.themeIndex}'
                '  and locale == ${snapshot.data!.locale.toString()}');
            themeIndex = snapshot.data!.themeIndex;
          }

          return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'KasieTransie',
              theme: themeBloc.getTheme(themeIndex).darkTheme,
              darkTheme: themeBloc.getTheme(themeIndex).darkTheme,
              themeMode: ThemeMode.system,
              home: AnimatedSplashScreen(
                splash: const SplashWidget(),
                animationDuration: const Duration(milliseconds: 2000),
                curve: Curves.easeInCirc,
                splashIconSize: 160.0,
                nextScreen: const Dashboard(),
                splashTransition: SplashTransition.fadeTransition,
                pageTransitionType: PageTransitionType.leftToRight,
                backgroundColor: Colors.deepOrange.shade900,
              ));
        });

  }
}
