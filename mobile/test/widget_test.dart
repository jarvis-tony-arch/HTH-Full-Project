import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hth_support/features/reviews/analyse_screen.dart';
import 'package:hth_support/features/reviews/link_parser.dart';
import 'package:hth_support/features/reviews/result_screen.dart';
import 'package:hth_support/features/reviews/rtheme.dart';

Widget _wrap(Widget child) => MaterialApp(theme: reviewTheme(Brightness.light), home: child);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('result screen shows verdict and sections from a real demo result', (tester) async {
    final raw = File('assets/demo/myntra_1753418.json').readAsStringSync();
    final result = (jsonDecode(raw) as Map).cast<String, dynamic>();
    await tester.pumpWidget(_wrap(ResultScreen(result: result, demo: true)));
    await tester.pumpAndSettle();
    expect(find.text('Should you buy it?'), findsOneWidget);
    expect(find.text(result['verdict']['label'] as String), findsOneWidget);
    expect(find.text('Is it like the photo?'), findsOneWidget);
    expect(find.text('What buyers say'), findsOneWidget);
  });

  testWidgets('unsupported link shows the friendly message', (tester) async {
    await tester.pumpWidget(_wrap(const Scaffold(body: UnsupportedLink(message: unsupportedMessage))));
    await tester.pumpAndSettle();
    expect(find.text(unsupportedMessage), findsOneWidget);
  });
}
