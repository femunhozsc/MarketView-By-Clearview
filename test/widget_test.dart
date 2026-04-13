import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marketview/main.dart';
import 'package:marketview/providers/user_provider.dart';
import 'package:marketview/theme/theme_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('MarketView app bootstraps without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
        ],
        child: MarketViewApp(
          firebaseInitialization: Completer<FirebaseApp>().future,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
