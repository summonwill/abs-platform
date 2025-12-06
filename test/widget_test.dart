import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:abs_platform/main.dart';

void main() {
  setUpAll(() async {
    // Initialize Hive for testing
    await Hive.initFlutter();
  });

  tearDownAll(() async {
    // Clean up Hive
    await Hive.close();
  });

  testWidgets('App launches and shows projects screen', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(
      const ProviderScope(
        child: ABSApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify that the app launches successfully
    expect(find.text('Projects'), findsOneWidget);
  });
}
