import 'package:flutter/material.dart';
import 'home_tab.dart';
import 'search_tab.dart';
import 'upload_tab.dart';
import 'trending_tab.dart';
import 'profile_tab.dart';
import '../app_state.dart';
import 'package:provider/provider.dart';
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeTab(),
    const SearchTab(),
    const UploadTab(),
    const TrendingTab(),
    const ProfileTab(),
  ];

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  Widget _buildSidebar(AppState state) {
    return Container(
      width: 250,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ai',
                  style: TextStyle(
                    fontSize: 26, // Slightly larger for desktop
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [Colors.purpleAccent, Colors.pinkAccent],
                      ).createShader(const Rect.fromLTWH(0.0, 0.0, 100.0, 70.0)),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('🎨', style: TextStyle(fontSize: 28, height: 1.1)),
                const SizedBox(width: 8),
                Text(
                  'Art',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [Colors.purpleAccent, Colors.pinkAccent],
                      ).createShader(const Rect.fromLTWH(0.0, 0.0, 100.0, 70.0)),
                  ),
                ),
              ],
            ),
          ),
        ),
          _buildSidebarItem(0, const Icon(Icons.home_outlined), const Icon(Icons.home), 'Home'),
          _buildSidebarItem(1, const Icon(Icons.search), const Icon(Icons.search), 'Search'),
          _buildSidebarItem(2, const Icon(Icons.add), const Icon(Icons.add), 'Create'),
          _buildSidebarItem(3, const Icon(Icons.trending_up_outlined), const Icon(Icons.trending_up), 'Trending'),
          _buildSidebarItem(4, const Icon(Icons.person_outline), const Icon(Icons.person), 'Profile'),
          const Spacer(),
          const Divider(color: Colors.black12),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.grey),
            title: const Text('Logout', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
            onTap: () async {
              await state.logout();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, Widget iconWidget, Widget activeIconWidget, String label) {
    bool isSelected = _currentIndex == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.deepPurple.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: IconTheme(
          data: IconThemeData(
            color: isSelected ? Colors.deepPurple : Colors.grey[700],
          ),
          child: isSelected ? activeIconWidget : iconWidget,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.deepPurple : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        onTap: () {
          if (_currentIndex == index) {
            // Pop to first route if tapping the same tab
            _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
      ),
    );
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _currentIndex,
      children: _pages.asMap().entries.map((entry) {
        return Navigator(
          key: _navigatorKeys[entry.key],
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (context) => entry.value,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final AppState appState = Provider.of<AppState>(context);
        if (constraints.maxWidth > 800) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Row(
              children: [
                _buildSidebar(appState),
                const VerticalDivider(thickness: 1, width: 1, color: Colors.black12),
                Expanded(child: _buildBody()),
              ],
            ),
          );
        }
        return Scaffold(
          backgroundColor: Colors.white,
          body: _buildBody(),
          bottomNavigationBar: Consumer<AppState>(
            builder: (context, state, child) {
              if (!state.isNavBarVisible) return const SizedBox.shrink();
              return BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  if (_currentIndex == index) {
                    // Pop to first route if tapping the same tab
                    _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
                  } else {
                    setState(() {
                      _currentIndex = index;
                    });
                  }
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                selectedItemColor: Colors.black,
                unselectedItemColor: Colors.grey,
                showSelectedLabels: false,
                showUnselectedLabels: false,
                items: [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.search),
                    activeIcon: Icon(Icons.search, size: 28),
                    label: 'Search',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.add),
                    activeIcon: Icon(Icons.add, size: 28),
                    label: 'Create',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.trending_up_outlined),
                    activeIcon: Icon(Icons.trending_up),
                    label: 'Trending',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
