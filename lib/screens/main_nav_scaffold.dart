import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gallery_provider.dart';
import 'albums_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// The root scaffold containing the Material 3 NavigationBar with 4 destinations:
/// Photos (Gallery), Albums, Favorites, and Settings.
///
/// Implements [WidgetsBindingObserver] to automatically refresh the gallery
/// when the user resumes the application from the camera or system settings.
class MainNavScaffold extends StatefulWidget {
  const MainNavScaffold({super.key});

  @override
  State<MainNavScaffold> createState() => _MainNavScaffoldState();
}

class _MainNavScaffoldState extends State<MainNavScaffold> with WidgetsBindingObserver {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    AlbumsScreen(),
    FavoritesScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final provider = Provider.of<GalleryProvider>(context, listen: false);
      provider.refreshGallery();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<GalleryProvider>(context);
    final favCount = provider.favoriteCount;
    final isMultiSelect = provider.isMultiSelectMode;

    return Scaffold(
      // Keep screens alive when switching tabs using IndexedStack
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      // Hide navigation bar during multi-selection to focus on selection actions
      bottomNavigationBar: isMultiSelect
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.photo_library_outlined),
                  selectedIcon: Icon(Icons.photo_library_rounded),
                  label: 'Photos',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.photo_album_outlined),
                  selectedIcon: Icon(Icons.photo_album_rounded),
                  label: 'Albums',
                ),
                NavigationDestination(
                  icon: favCount > 0
                      ? Badge(
                          label: Text('$favCount'),
                          child: const Icon(Icons.favorite_outline_rounded),
                        )
                      : const Icon(Icons.favorite_outline_rounded),
                  selectedIcon: favCount > 0
                      ? Badge(
                          label: Text('$favCount'),
                          child: const Icon(Icons.favorite_rounded),
                        )
                      : const Icon(Icons.favorite_rounded),
                  label: 'Favorites',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }
}
