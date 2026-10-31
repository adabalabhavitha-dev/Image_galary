import 'package:flutter_test/flutter_test.dart';
import 'package:image_gallery_app/main.dart';
import 'package:image_gallery_app/screens/permission_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Gallery App renders PermissionScreen when permission is not granted', (WidgetTester tester) async {
    await tester.pumpWidget(const ImageGalleryApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify that PermissionScreen is shown when permission is not yet granted
    expect(find.byType(PermissionScreen), findsOneWidget);
    expect(find.text('Access Your Photos'), findsOneWidget);
    expect(find.text('Grant Permission'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
  });
}
