import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final firebaseInitialization = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MarketViewApp(firebaseInitialization: firebaseInitialization),
    ),
  );
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
    return _InitialSplashGate(firebaseInitialization: firebaseInitialization);
  }
}

class _InitialSplashGate extends StatefulWidget {
  const _InitialSplashGate({required this.firebaseInitialization});

  final Future<FirebaseApp> firebaseInitialization;

  @override
  State<_InitialSplashGate> createState() => _InitialSplashGateState();
}

class _InitialSplashGateState extends State<_InitialSplashGate> {
  bool _showBrandSplash = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _showBrandSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showBrandSplash) {
      return const BrandSplashScreen();
    }

    return FutureBuilder<FirebaseApp>(
      future: widget.firebaseInitialization,
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
