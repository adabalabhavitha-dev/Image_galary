import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_gallery_app/providers/gallery_provider.dart';
import 'package:image_gallery_app/screens/main_nav_scaffold.dart';
import 'package:image_gallery_app/screens/permission_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PermissionScreen renders buttons and descriptive texts', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => GalleryProvider(),
          child: const PermissionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Access Your Photos'), findsOneWidget);
    expect(find.text('Grant Permission'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('MainNavScaffold contains 4 navigation destinations', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => GalleryProvider(),
          child: const MainNavScaffold(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
