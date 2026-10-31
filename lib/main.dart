import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/gallery_provider.dart';
import 'screens/main_nav_scaffold.dart';
import 'utils/constants.dart';
import 'utils/theme.dart';

void main() async {
  // Ensure Flutter engine bindings are initialized before calling async plugins
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI style defaults (translucent status bar)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ImageGalleryApp());
}

/// The root widget of the application.
class ImageGalleryApp extends StatelessWidget {
  const ImageGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Provide GalleryProvider globally throughout the widget tree
    return ChangeNotifierProvider<GalleryProvider>(
      create: (_) => GalleryProvider()..init(),
      child: Consumer<GalleryProvider>(
        builder: (context, galleryProvider, child) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,

            // Light & Dark Material 3 Themes
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: galleryProvider.themeMode,

            // Home Scaffold with BottomNavigationBar
            home: const MainNavScaffold(),
          );
        },
      ),
    );
  }
}
