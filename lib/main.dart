import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'providers/user_provider.dart';
import 'auth_wrapper.dart';
import 'widgets/launch_splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseApp = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _activateFirebaseAppCheck();
  final userProvider = UserProvider();
  await userProvider.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: userProvider),
      ],
      child: MarketViewApp(
        firebaseInitialization: Future<FirebaseApp>.value(firebaseApp),
      ),
    ),
  );
}

Future<void> _activateFirebaseAppCheck() async {
  const appCheckSiteKey = String.fromEnvironment('FIREBASE_APP_CHECK_SITE_KEY');

  if (kIsWeb) {
    if (appCheckSiteKey.isEmpty) return;
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider(appCheckSiteKey),
    );
    return;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      );
      return;
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      await FirebaseAppCheck.instance.activate(
        appleProvider: kDebugMode
            ? AppleProvider.debug
            : AppleProvider.appAttestWithDeviceCheckFallback,
      );
      return;
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return;
  }
}

class MarketViewApp extends StatelessWidget {
  const MarketViewApp({
    super.key,
    required this.firebaseInitialization,
  });

  final Future<FirebaseApp> firebaseInitialization;

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'MarketView',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: _AppBootstrap(firebaseInitialization: firebaseInitialization),
        );
      },
    );
  }
}

class _AppBootstrap extends StatelessWidget {
  const _AppBootstrap({required this.firebaseInitialization});

  final Future<FirebaseApp> firebaseInitialization;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: firebaseInitialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Material(
            color: Colors.white,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Nao foi possivel iniciar o app. Reinicie e tente novamente.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return const LaunchSplashScreen();
        }

        return const AuthWrapper();
      },
    );
  }
}
